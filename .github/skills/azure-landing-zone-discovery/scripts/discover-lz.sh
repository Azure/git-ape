#!/bin/bash
# Azure Landing Zone Discovery Script
# Auto-discovers management groups, subscriptions, policies, networking, and shared services

set -euo pipefail

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FORMAT="json"
OUTPUT_FILE=""
VERBOSE=false
SKIP_NETWORK=false
SKIP_POLICIES=false
SKIP_SHARED_SERVICES=false

usage() {
    cat <<EOF
Azure Landing Zone Discovery Script

Discovers management group hierarchy, subscription classification, policy
assignments, network topology, and shared services from the current Azure context.

Usage: $0 [OPTIONS]

Options:
  --output-format <fmt>    Output format: json, markdown (default: json)
  --output-file <path>     Output file path (default: stdout)
  --skip-network           Skip network topology discovery
  --skip-policies          Skip policy assignment discovery
  --skip-shared-services   Skip shared services discovery
  --verbose                Show detailed discovery progress
  -h, --help               Show this help message

Examples:
  $0 --output-file .azure/landing-zone-context.json
  $0 --output-format markdown
  $0 --output-file .azure/landing-zone-context.json --skip-network
  $0 --verbose

Exit Codes:
  0  Discovery completed successfully
  1  Partial discovery (some targets failed, results still usable)
  2  Discovery failed (no Azure access or critical error)

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --output-file)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --skip-network)
            SKIP_NETWORK=true
            shift
            ;;
        --skip-policies)
            SKIP_POLICIES=true
            shift
            ;;
        --skip-shared-services)
            SKIP_SHARED_SERVICES=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate Azure CLI is available and logged in
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI (az) is not installed${NC}"
    exit 2
fi

if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged in to Azure. Run 'az login' first.${NC}"
    exit 2
fi

# Timestamp for this discovery
DISCOVERY_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo -e "${BLUE}Starting Azure Landing Zone Discovery${NC}"
echo "Timestamp: $DISCOVERY_TIMESTAMP"
echo ""

# Track partial failures
PARTIAL_FAILURE=false

# ─────────────────────────────────────────────────────────────────────────────
# Current Identity
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${CYAN}[1/7] Discovering current identity...${NC}"

CURRENT_ACCOUNT=$(az account show --output json 2>/dev/null)
CURRENT_USER=$(echo "$CURRENT_ACCOUNT" | jq -r '.user.name // "unknown"')
CURRENT_TENANT_ID=$(echo "$CURRENT_ACCOUNT" | jq -r '.tenantId // "unknown"')
CURRENT_SUB_ID=$(echo "$CURRENT_ACCOUNT" | jq -r '.id // "unknown"')
CURRENT_SUB_NAME=$(echo "$CURRENT_ACCOUNT" | jq -r '.name // "unknown"')

echo -e "  User: ${GREEN}$CURRENT_USER${NC}"
echo -e "  Tenant: $CURRENT_TENANT_ID"
echo -e "  Subscription: $CURRENT_SUB_NAME ($CURRENT_SUB_ID)"
echo ""

IDENTITY_JSON=$(jq -n \
    --arg user "$CURRENT_USER" \
    --arg tenantId "$CURRENT_TENANT_ID" \
    --arg subId "$CURRENT_SUB_ID" \
    --arg subName "$CURRENT_SUB_NAME" \
    '{
        user: $user,
        tenantId: $tenantId,
        currentSubscription: { id: $subId, name: $subName },
        roles: []
    }')

# ─────────────────────────────────────────────────────────────────────────────
# Management Group Hierarchy
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${CYAN}[2/7] Discovering management group hierarchy...${NC}"

MG_HIERARCHY="[]"
MG_ROOT=""
HAS_MANAGEMENT_GROUPS=false

MG_LIST=$(az account management-group list --output json 2>/dev/null || echo "[]")

if [[ "$MG_LIST" != "[]" ]] && [[ -n "$MG_LIST" ]]; then
    HAS_MANAGEMENT_GROUPS=true
    MG_COUNT=$(echo "$MG_LIST" | jq 'length')
    echo -e "  Found ${GREEN}$MG_COUNT${NC} management groups"

    # Find root management group (Tenant Root Group)
    MG_ROOT=$(echo "$MG_LIST" | jq -r '
        [.[] | select(
            .displayName == "Tenant Root Group" or
            .name == .tenantId or
            (.properties.details.parent == null)
        )] | first | .displayName // "Tenant Root Group"
    ')

    # Classify management groups by canonical ALZ name first, then fall back to
    # substring matching for non-canonical naming. Canonical names come from the
    # Azure Landing Zone accelerator: https://azure.github.io/Azure-Landing-Zones/accelerator/
    MG_HIERARCHY=$(echo "$MG_LIST" | jq '[
        .[] | . as $mg | (.displayName // .name | ascii_downcase) as $n | {
            id: .id,
            name: .name,
            displayName: .displayName,
            role: (
                if .displayName == "Tenant Root Group" or .name == .tenantId then "root"
                # --- Exact-name ALZ archetypes (high precision) ---
                elif $n == "platform" then "platform"
                elif $n == "connectivity" then "connectivity"
                elif $n == "identity" then "identity"
                elif $n == "management" then "management"
                elif $n == "landing zones" or $n == "landingzones" or $n == "landing-zones" then "landing-zones"
                elif $n == "corp" then "corp"
                elif $n == "online" then "online"
                elif $n == "sandbox" then "sandbox"
                elif $n == "decommissioned" then "decommissioned"
                # --- Substring fallback for custom-named environments (lower precision) ---
                elif ($n | test("platform|infra")) then "platform"
                elif ($n | test("connectivity|network|hub")) then "connectivity"
                elif ($n | test("identity|aad|entra")) then "identity"
                elif ($n | test("management|logging|monitor")) then "management"
                elif ($n | test("landing.?zone|workload|application")) then "landing-zones"
                elif ($n | test("sandbox|dev.?test")) then "sandbox"
                elif ($n | test("decommission|deprecated|retired")) then "decommissioned"
                # corp/online matched last so the more specific archetypes win first.
                # The ALZ accelerator prefixes MG names (e.g. "alz-corp"), so the
                # exact-name checks above never fire — these substring tests are what
                # actually classify Corp/Online landing-zone archetypes in practice.
                elif ($n | test("corp")) then "corp"
                elif ($n | test("online")) then "online"
                else "other"
                end
            ),
            parentId: (.properties.details.parent.id // null)
        }
    ]')

    if [[ "$VERBOSE" == "true" ]]; then
        echo "  Management group classification:"
        echo "$MG_HIERARCHY" | jq -r '.[] | "    \(.displayName) → \(.role)"'
    fi
else
    echo -e "  ${YELLOW}No management groups found (flat subscription model)${NC}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Subscription Discovery & Classification
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${CYAN}[3/7] Discovering and classifying subscriptions...${NC}"

SUBSCRIPTIONS=$(az account list --query "[?state=='Enabled']" --output json 2>/dev/null || echo "[]")
SUB_COUNT=$(echo "$SUBSCRIPTIONS" | jq 'length')
echo -e "  Found ${GREEN}$SUB_COUNT${NC} enabled subscriptions"

PLATFORM_SUBS="[]"
LZ_SUBS="[]"

for SUB_ID in $(echo "$SUBSCRIPTIONS" | jq -r '.[].id'); do
    SUB_NAME=$(echo "$SUBSCRIPTIONS" | jq -r --arg id "$SUB_ID" '.[] | select(.id == $id) | .name')
    # Try to get management group path
    MG_PATH=""
    if [[ "$HAS_MANAGEMENT_GROUPS" == "true" ]]; then
        MG_PATH=$(az account management-group subscription show \
            --subscription-id "$SUB_ID" \
            --query "managementGroupAncestorsChain[].displayName" \
            --output tsv 2>/dev/null | tr '\n' '/' | sed 's/\/$//' || echo "")
    fi

    # Classify subscription. Per the Azure Landing Zone accelerator, management
    # group placement is the authoritative signal — workloads land under
    # Landing Zones/<archetype>, platform subs under Platform/<role>. Fall back
    # to subscription name patterns only when no MG hierarchy exists.
    SUB_NAME_LOWER=$(echo "$SUB_NAME" | tr '[:upper:]' '[:lower:]')
    MG_PATH_LOWER=$(echo "$MG_PATH" | tr '[:upper:]' '[:lower:]')
    ROLE="landing-zone"
    ENVIRONMENT=""

    if [[ -n "$MG_PATH_LOWER" ]]; then
        # Prefer MG-path classification (canonical ALZ placement)
        case "$MG_PATH_LOWER" in
            */connectivity*)                 ROLE="connectivity" ;;
            */identity*)                     ROLE="identity" ;;
            */management*)                   ROLE="management" ;;
            *platform*)                      ROLE="platform-other" ;;
            *landing*zones*)                 ROLE="landing-zone" ;;
            *sandbox*)                       ROLE="sandbox" ;;
            *decommission*)                  ROLE="decommissioned" ;;
        esac
    fi

    # Name-based fallback only when MG path didn't classify (still "landing-zone")
    if [[ "$ROLE" == "landing-zone" ]]; then
        case "$SUB_NAME_LOWER" in
            *connectivity*)                  ROLE="connectivity" ;;
            *identity*|*aad*|*entra*)        ROLE="identity" ;;
            *management*|*logging*|*monitor*) ROLE="management" ;;
        esac
    fi

    # Determine environment for landing zone subscriptions
    if [[ "$ROLE" == "landing-zone" ]]; then
        case "$SUB_NAME_LOWER" in
            *production*)
                ENVIRONMENT="prod" ;;
            *prod*)
                ENVIRONMENT="prod" ;;
            *staging*|*stg*|*uat*|*qa*)
                ENVIRONMENT="staging" ;;
            *develop*|*test*|*sandbox*)
                ENVIRONMENT="dev" ;;
            *dev*)
                ENVIRONMENT="dev" ;;
            *)
                ENVIRONMENT="unknown" ;;
        esac
    fi

    SUB_ENTRY=$(jq -n \
        --arg id "$SUB_ID" \
        --arg name "$SUB_NAME" \
        --arg role "$ROLE" \
        --arg mgPath "$MG_PATH" \
        --arg env "$ENVIRONMENT" \
        '{
            id: $id,
            name: $name,
            role: $role,
            mgPath: $mgPath,
            environment: (if $env != "" then $env else null end)
        }')

    if [[ "$ROLE" == "connectivity" ]] || [[ "$ROLE" == "identity" ]] || [[ "$ROLE" == "management" ]] || [[ "$ROLE" == "platform-other" ]]; then
        PLATFORM_SUBS=$(echo "$PLATFORM_SUBS" | jq --argjson entry "$SUB_ENTRY" '. += [$entry]')
    else
        LZ_SUBS=$(echo "$LZ_SUBS" | jq --argjson entry "$SUB_ENTRY" '. += [$entry]')
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo "    $SUB_NAME → $ROLE${ENVIRONMENT:+ ($ENVIRONMENT)}"
    fi
done

echo -e "  Platform subscriptions: ${GREEN}$(echo "$PLATFORM_SUBS" | jq 'length')${NC}"
echo -e "  Landing zone subscriptions: ${GREEN}$(echo "$LZ_SUBS" | jq 'length')${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Policy Discovery
# ─────────────────────────────────────────────────────────────────────────────
POLICIES_JSON='{"denyEffects":[],"auditEffects":[],"allowedLocations":[],"requiredTags":[],"alzCanonicalAssignments":[]}'

if [[ "$SKIP_POLICIES" != "true" ]]; then
    echo -e "${CYAN}[4/7] Discovering policy assignments...${NC}"

    DENY_POLICIES="[]"
    AUDIT_POLICIES="[]"
    ALLOWED_LOCATIONS="[]"
    REQUIRED_TAGS="[]"
    ALZ_CANONICAL="[]"

    # Get policy assignments at current subscription scope
    POLICY_ASSIGNMENTS=$(az policy assignment list \
        --query "[?enforcementMode=='Default']" \
        --output json 2>/dev/null || echo "[]")

    # Canonical ALZ policies are assigned at management-group scope (e.g. the
    # "alz" and "alz-platform" MGs), not the subscription — so a sub-scope-only
    # query misses them entirely. Enumerate each discovered MG scope and merge.
    # NOTE: use the default atScope() filter (a bare --scope). The
    # --disable-scope-strict-match (atScopeAndBelow) flag is unsupported at MG
    # scope and errors out, so we query each MG explicitly instead.
    if [[ "$HAS_MANAGEMENT_GROUPS" == "true" ]]; then
        for MG_SCOPE in $(echo "$MG_LIST" | jq -r '.[].id'); do
            MG_POLICY_ASSIGNMENTS=$(az policy assignment list \
                --scope "$MG_SCOPE" \
                --query "[?enforcementMode=='Default']" \
                --output json 2>/dev/null || echo "[]")
            POLICY_ASSIGNMENTS=$(jq -n \
                --argjson a "$POLICY_ASSIGNMENTS" \
                --argjson b "$MG_POLICY_ASSIGNMENTS" \
                '$a + $b')
        done
        # Deduplicate by assignment id (a given assignment lives at exactly one scope)
        POLICY_ASSIGNMENTS=$(echo "$POLICY_ASSIGNMENTS" | jq 'unique_by(.id)')
    fi

    POLICY_COUNT=$(echo "$POLICY_ASSIGNMENTS" | jq 'length')
    echo -e "  Found ${GREEN}$POLICY_COUNT${NC} enforced policy assignments (subscription + management-group scopes)"

    if [[ "$POLICY_COUNT" -gt 0 ]]; then
        # Resolve each assignment's effect from the parameters block. Initiatives
        # (policySetDefinitions) bundle many inner definitions, so we cannot infer
        # a single effect from the assignment alone — those get effect="initiative"
        # and are excluded from both denyEffects and auditEffects.
        # Single-definition assignments without an effect parameter get "unknown".
        DENY_POLICIES=$(echo "$POLICY_ASSIGNMENTS" | jq '[
            .[] |
            select(.displayName != null) |
            (
                (.parameters // {}) as $p |
                (
                    ($p.effect.value // $p.Effect.value // "") | tostring | ascii_downcase
                )
            ) as $effect |
            select($effect == "deny") |
            {
                name: .displayName,
                scope: .scope,
                policyDefinitionId: .policyDefinitionId,
                effect: $effect,
                impact: (
                    if (.displayName | ascii_downcase | test("public.?ip")) then "Blocks public IP creation"
                    elif (.displayName | ascii_downcase | test("location|region")) then "Restricts allowed regions"
                    elif (.displayName | ascii_downcase | test("storage.*public")) then "Blocks public storage access"
                    elif (.displayName | ascii_downcase | test("tag")) then "Requires specific tags"
                    elif (.displayName | ascii_downcase | test("subnet.*nsg")) then "Requires NSG on subnets"
                    elif (.displayName | ascii_downcase | test("sql.*public")) then "Blocks public SQL access"
                    else "Blocks deployments matching this policy"
                    end
                )
            }
        ]' 2>/dev/null || echo "[]")

        # Extract audit-effect policies (Audit, AuditIfNotExists)
        AUDIT_POLICIES=$(echo "$POLICY_ASSIGNMENTS" | jq '[
            .[] |
            select(.displayName != null) |
            (
                (.parameters // {}) as $p |
                (
                    ($p.effect.value // $p.Effect.value // "") | tostring | ascii_downcase
                )
            ) as $effect |
            select($effect | startswith("audit")) |
            {
                name: .displayName,
                scope: .scope,
                policyDefinitionId: .policyDefinitionId,
                effect: $effect
            }
        ]' 2>/dev/null || echo "[]")

        # Check for allowed locations policy (Deny + listOfAllowedLocations param)
        ALLOWED_LOCATIONS=$(echo "$POLICY_ASSIGNMENTS" | jq '[
            .[] |
            select(.displayName != null) |
            select(.parameters.listOfAllowedLocations.value != null) |
            .parameters.listOfAllowedLocations.value | .[]
        ] | unique' 2>/dev/null || echo "[]")

        # Check for required tags (Require-Tag style policies expose tagName)
        REQUIRED_TAGS=$(echo "$POLICY_ASSIGNMENTS" | jq '[
            .[] |
            select(.displayName != null) |
            select(.parameters.tagName.value != null) |
            .parameters.tagName.value
        ] | unique' 2>/dev/null || echo "[]")

        # Match against canonical ALZ accelerator policy assignment names.
        # Reference: https://github.com/Azure/Enterprise-Scale/wiki/ALZ-Policies
        # These names are deployed by the ALZ accelerator and are a high-precision
        # ALZ signature regardless of effect. The accelerator periodically renames
        # assignments (e.g. Deploy-AzActivity-Log -> Deploy-AzActivityLog), so the
        # pattern tolerates both old and new spellings.
        ALZ_CANONICAL=$(echo "$POLICY_ASSIGNMENTS" | jq '[
            .[] |
            select(.displayName != null or .name != null) |
            # The canonical token (e.g. "Deploy-VM-Monitoring") lives in the
            # assignment .name; .displayName is a long human description that
            # rarely contains it. Test BOTH fields, emit the .name as the label.
            (((.name // "") + " " + (.displayName // "")) | tostring) as $hay |
            ((.name // .displayName) | tostring) as $label |
            select($hay | test("Deploy-MDFC-Config|Deploy-MDEndpoints|Deploy-AzActivity-?Log|Deploy-Diag-LogsCat-LAW|Deploy-Diagnostics-LogAnalytics|Deploy-VM-Monitoring|Deploy-VMSS-Monitoring|Deploy-VM-Backup|Enforce-Encryption-CMK|Enforce-EncryptTransit|Enforce-TLS-SSL|Enforce-ACSB|Deny-Classic-Resources|Deny-PublicIP|Deny-Public-Endpoints|Deny-RDP-From-Internet|Deny-MgmtPorts-From-Internet|Deny-Subnet-Without-Nsg|Deny-Storage-http|Deploy-Resource-Diag|Deploy-Private-DNS-Zones|Audit-UnusedResources"; "i")) |
            $label
        ] | unique' 2>/dev/null || echo "[]")

        if [[ "$VERBOSE" == "true" ]] && [[ $(echo "$ALZ_CANONICAL" | jq 'length') -gt 0 ]]; then
            echo "  Canonical ALZ policy assignments found:"
            echo "$ALZ_CANONICAL" | jq -r '.[] | "    \u2713 \(.)"'
        fi
    fi

    POLICIES_JSON=$(jq -n \
        --argjson deny "$DENY_POLICIES" \
        --argjson audit "$AUDIT_POLICIES" \
        --argjson locations "$ALLOWED_LOCATIONS" \
        --argjson tags "$REQUIRED_TAGS" \
        --argjson alzCanonical "$ALZ_CANONICAL" \
        '{
            denyEffects: $deny,
            auditEffects: $audit,
            allowedLocations: $locations,
            requiredTags: $tags,
            alzCanonicalAssignments: $alzCanonical
        }')

    if [[ "$VERBOSE" == "true" ]] && [[ $(echo "$DENY_POLICIES" | jq 'length') -gt 0 ]]; then
        echo "  Deny-effect policies:"
        echo "$DENY_POLICIES" | jq -r '.[] | "    ⚠️  \(.name) — \(.impact)"'
    fi
else
    echo -e "${CYAN}[4/7] Skipping policy discovery (--skip-policies)${NC}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Network Topology Discovery
# ─────────────────────────────────────────────────────────────────────────────
NETWORKING_JSON='{"topology":"unknown","hubs":[],"privateDnsZones":[],"peerings":[]}'

if [[ "$SKIP_NETWORK" != "true" ]]; then
    echo -e "${CYAN}[5/7] Discovering network topology...${NC}"

    HUB_VNETS="[]"
    PEERINGS="[]"
    DNS_ZONES="[]"
    TOPOLOGY="unknown"

    # Try Azure Resource Graph first (faster, cross-subscription)
    HAS_GRAPH=true
    az graph query -q "Resources | take 1" --output json &> /dev/null || HAS_GRAPH=false

    if [[ "$HAS_GRAPH" == "true" ]]; then
        # Find hub VNets via Resource Graph
        HUB_VNETS=$(az graph query -q "
            Resources
            | where type == 'microsoft.network/virtualnetworks'
            | where name contains 'hub' or tags['network-role'] == 'hub' or tags['NetworkRole'] == 'Hub'
            | project id, name, location, subscriptionId,
              addressPrefixes=properties.addressSpace.addressPrefixes
        " --query "data" --output json 2>/dev/null || echo "[]")

        HUB_COUNT=$(echo "$HUB_VNETS" | jq 'length')

        if [[ "$HUB_COUNT" -gt 0 ]]; then
            TOPOLOGY="hub-spoke"
            echo -e "  Topology: ${GREEN}Hub-Spoke${NC} ($HUB_COUNT hub VNets found)"
        else
            # Discovery ran successfully but found no hub — record as 'flat'
            # so downstream consumers can distinguish from skipped/failed runs.
            TOPOLOGY="flat"
            echo -e "  Topology: ${YELLOW}Flat${NC} (no hub VNets found)"
        fi

        # Find VNet peerings
        PEERINGS=$(az graph query -q "
            Resources
            | where type == 'microsoft.network/virtualnetworks'
            | mv-expand peering=properties.virtualNetworkPeerings
            | project vnetName=name, vnetId=id,
              peerName=peering.name,
              remoteVnet=peering.properties.remoteVirtualNetwork.id,
              peeringState=peering.properties.peeringState
        " --query "data" --output json 2>/dev/null || echo "[]")

        PEERING_COUNT=$(echo "$PEERINGS" | jq 'length')
        if [[ "$PEERING_COUNT" -gt 0 ]]; then
            echo -e "  VNet peerings: ${GREEN}$PEERING_COUNT${NC}"
        fi

        # Find private DNS zones
        DNS_ZONES=$(az graph query -q "
            Resources
            | where type == 'microsoft.network/privatednszones'
            | project id, name, subscriptionId
        " --query "data" --output json 2>/dev/null || echo "[]")

        DNS_ZONE_NAMES=$(echo "$DNS_ZONES" | jq '[.[].name] | unique')
        DNS_COUNT=$(echo "$DNS_ZONE_NAMES" | jq 'length')
        if [[ "$DNS_COUNT" -gt 0 ]]; then
            echo -e "  Private DNS zones: ${GREEN}$DNS_COUNT${NC}"
        fi
    else
        echo -e "  ${YELLOW}Azure Resource Graph not available, using direct queries${NC}"
        PARTIAL_FAILURE=true

        # Fallback: query VNets in current subscription
        HUB_VNETS=$(az network vnet list \
            --query "[?contains(name, 'hub') || tags.\"network-role\" == 'hub']" \
            --output json 2>/dev/null | jq '[.[] | {
                id: .id,
                name: .name,
                location: .location,
                subscriptionId: (.id | split("/")[2]),
                addressPrefixes: .addressSpace.addressPrefixes
            }]' || echo "[]")

        HUB_COUNT=$(echo "$HUB_VNETS" | jq 'length')
        if [[ "$HUB_COUNT" -gt 0 ]]; then
            TOPOLOGY="hub-spoke"
            echo -e "  Topology: ${GREEN}Hub-Spoke${NC} ($HUB_COUNT hub VNets in current subscription)"
        else
            # Fallback path completed without finding a hub in the current sub.
            # Mark as 'flat' to distinguish from skipped/failed network discovery.
            TOPOLOGY="flat"
            echo -e "  Topology: ${YELLOW}Flat${NC} (no hub VNets in current subscription)"
        fi

        DNS_ZONE_NAMES="[]"
    fi

    # Format hub VNets for output
    HUBS_OUTPUT=$(echo "$HUB_VNETS" | jq '[.[] | {
        id: .id,
        name: .name,
        subscription: .subscriptionId,
        location: .location,
        addressPrefixes: .addressPrefixes
    }]')

    NETWORKING_JSON=$(jq -n \
        --arg topology "$TOPOLOGY" \
        --argjson hubs "$HUBS_OUTPUT" \
        --argjson dnsZones "$DNS_ZONE_NAMES" \
        --argjson peerings "$PEERINGS" \
        '{
            topology: $topology,
            hubs: $hubs,
            privateDnsZones: $dnsZones,
            peerings: $peerings
        }')
else
    echo -e "${CYAN}[5/7] Skipping network discovery (--skip-network)${NC}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Shared Services Discovery
# ─────────────────────────────────────────────────────────────────────────────
SHARED_SERVICES_JSON='{}'

if [[ "$SKIP_SHARED_SERVICES" != "true" ]]; then
    echo -e "${CYAN}[6/7] Discovering shared services...${NC}"

    LOG_ANALYTICS="{}"
    CONTAINER_REGISTRY="{}"
    KEY_VAULT="{}"

    if [[ "$HAS_GRAPH" == "true" ]]; then
        # Find shared Log Analytics workspaces
        LA_RESULTS=$(az graph query -q "
            Resources
            | where type == 'microsoft.operationalinsights/workspaces'
            | where tags['shared'] == 'true' or name contains 'platform' or name contains 'central' or name contains 'shared'
            | project id, name, subscriptionId, location,
              sku=properties.sku.name, retentionDays=properties.retentionInDays
            | take 5
        " --query "data" --output json 2>/dev/null || echo "[]")

        LA_COUNT=$(echo "$LA_RESULTS" | jq 'length')
        if [[ "$LA_COUNT" -gt 0 ]]; then
            LOG_ANALYTICS=$(echo "$LA_RESULTS" | jq 'first | {
                id: .id,
                name: .name,
                subscription: .subscriptionId,
                location: .location
            }')
            LA_NAME=$(echo "$LOG_ANALYTICS" | jq -r '.name')
            echo -e "  Log Analytics: ${GREEN}$LA_NAME${NC}"
        else
            echo -e "  Log Analytics: ${YELLOW}none found${NC}"
        fi

        # Find shared Container Registries
        ACR_RESULTS=$(az graph query -q "
            Resources
            | where type == 'microsoft.containerregistry/registries'
            | where tags['shared'] == 'true' or sku.name == 'Premium'
            | project id, name, subscriptionId, location, sku=sku.name,
              loginServer=properties.loginServer
            | take 5
        " --query "data" --output json 2>/dev/null || echo "[]")

        ACR_COUNT=$(echo "$ACR_RESULTS" | jq 'length')
        if [[ "$ACR_COUNT" -gt 0 ]]; then
            CONTAINER_REGISTRY=$(echo "$ACR_RESULTS" | jq 'first | {
                id: .id,
                name: .name,
                subscription: .subscriptionId,
                location: .location,
                loginServer: .loginServer
            }')
            ACR_NAME=$(echo "$CONTAINER_REGISTRY" | jq -r '.name')
            echo -e "  Container Registry: ${GREEN}$ACR_NAME${NC}"
        else
            echo -e "  Container Registry: ${YELLOW}none found${NC}"
        fi

        # Find shared Key Vaults
        KV_RESULTS=$(az graph query -q "
            Resources
            | where type == 'microsoft.keyvault/vaults'
            | where tags['shared'] == 'true' or name contains 'platform' or name contains 'shared'
            | project id, name, subscriptionId, location
            | take 5
        " --query "data" --output json 2>/dev/null || echo "[]")

        KV_COUNT=$(echo "$KV_RESULTS" | jq 'length')
        if [[ "$KV_COUNT" -gt 0 ]]; then
            KEY_VAULT=$(echo "$KV_RESULTS" | jq 'first | {
                id: .id,
                name: .name,
                subscription: .subscriptionId,
                location: .location
            }')
            KV_NAME=$(echo "$KEY_VAULT" | jq -r '.name')
            echo -e "  Key Vault: ${GREEN}$KV_NAME${NC}"
        else
            echo -e "  Key Vault: ${YELLOW}none found${NC}"
        fi
    else
        echo -e "  ${YELLOW}Azure Resource Graph not available, skipping shared services${NC}"
        PARTIAL_FAILURE=true
    fi

    SHARED_SERVICES_JSON=$(jq -n \
        --argjson logAnalytics "$LOG_ANALYTICS" \
        --argjson containerRegistry "$CONTAINER_REGISTRY" \
        --argjson keyVault "$KEY_VAULT" \
        '{
            logAnalytics: $logAnalytics,
            containerRegistry: $containerRegistry,
            keyVault: $keyVault
        }')
else
    echo -e "${CYAN}[6/7] Skipping shared services discovery (--skip-shared-services)${NC}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Landing Zone Detection & Confidence Scoring
# ─────────────────────────────────────────────────────────────────────────────
# Scores the discovered topology against canonical Azure Landing Zone (ALZ)
# accelerator signals: https://azure.github.io/Azure-Landing-Zones/accelerator/
#
# Weighted signals (max 100):
#   Top-level MGs (Platform/Landing zones/Sandbox/Decommissioned)  0–30
#   Platform children (Connectivity/Identity/Management)           0–20
#   Landing-zone archetypes (Corp + Online)                        0 or 10
#   Platform subscriptions                                         0–10
#   Hub-spoke topology                                             0 or  5
#   Hub VNet in a connectivity-classified subscription             0 or  5
#   Canonical ALZ policy assignment names                          0–15
#
# Confidence buckets: high ≥ 70, medium ≥ 40, low ≥ 10, none < 10.
# isLandingZone = (confidenceScore ≥ 40).
echo -e "${CYAN}[7/7] Scoring landing zone confidence...${NC}"

DETECTION_JSON=$(jq -n \
    --argjson mgHierarchy "$MG_HIERARCHY" \
    --argjson platformSubs "$PLATFORM_SUBS" \
    --argjson lzSubs "$LZ_SUBS" \
    --argjson networking "$NETWORKING_JSON" \
    --argjson policies "$POLICIES_JSON" \
    '
    ($mgHierarchy | map(.role // "other")) as $roles |
    {
        hasPlatform:       ($roles | any(. == "platform")),
        hasLandingZones:   ($roles | any(. == "landing-zones")),
        hasSandbox:        ($roles | any(. == "sandbox")),
        hasDecommissioned: ($roles | any(. == "decommissioned")),
        hasConnectivity:   ($roles | any(. == "connectivity")),
        hasIdentity:       ($roles | any(. == "identity")),
        hasManagement:     ($roles | any(. == "management")),
        hasCorp:           ($roles | any(. == "corp")),
        hasOnline:         ($roles | any(. == "online"))
    } as $f |

    ([$f.hasPlatform, $f.hasLandingZones, $f.hasSandbox, $f.hasDecommissioned]
        | map(select(.)) | length) as $topLevel |
    ([$f.hasConnectivity, $f.hasIdentity, $f.hasManagement]
        | map(select(.)) | length) as $platChildren |
    ($platformSubs | length) as $platSubCount |
    ($networking.topology == "hub-spoke") as $hasHubSpoke |
    ($networking.hubs // []) as $hubs |
    ([$platformSubs[]? | select(.role == "connectivity") | .id]) as $connSubIds |
    ($hubs | any(.subscription as $h | $connSubIds | any(. == $h))) as $hubInConn |
    (($policies.alzCanonicalAssignments // []) | length) as $alzPolCount |
    (($policies.alzCanonicalAssignments // []) | sort) as $alzPolList |

    # Points per signal
    (if   $topLevel == 4 then 30
     elif $topLevel == 3 then 20
     elif $topLevel == 2 then 10
     else 0 end) as $ptsTop |
    (if   $platChildren == 3 then 20
     elif $platChildren == 2 then 10
     else 0 end) as $ptsChildren |
    (if $f.hasCorp and $f.hasOnline then 10 else 0 end) as $ptsArchetypes |
    (if   $platSubCount >= 3 then 10
     elif $platSubCount >= 1 then 5
     else 0 end) as $ptsPlatSubs |
    (if $hasHubSpoke then 5 else 0 end) as $ptsHubSpoke |
    (if $hubInConn then 5 else 0 end) as $ptsHubInConn |
    ([$alzPolCount * 5, 15] | min) as $ptsAlzPols |

    ($ptsTop + $ptsChildren + $ptsArchetypes + $ptsPlatSubs +
     $ptsHubSpoke + $ptsHubInConn + $ptsAlzPols) as $score |

    (if   $score >= 70 then "high"
     elif $score >= 40 then "medium"
     elif $score >= 10 then "low"
     else "none" end) as $confidence |

    {
        isLandingZone: ($score >= 40),
        confidence: $confidence,
        confidenceScore: $score,
        reference: "https://azure.github.io/Azure-Landing-Zones/accelerator/",
        matchedSignals: [
            (if $topLevel > 0 then {
                signal: "alz-top-level-mgs", points: $ptsTop,
                evidence: "\($topLevel)/4 canonical top-level MGs (Platform, Landing zones, Sandbox, Decommissioned)"
            } else empty end),
            (if $platChildren > 0 then {
                signal: "platform-children", points: $ptsChildren,
                evidence: "\($platChildren)/3 platform children (Connectivity, Identity, Management)"
            } else empty end),
            (if $f.hasCorp and $f.hasOnline then {
                signal: "alz-lz-archetypes", points: $ptsArchetypes,
                evidence: "Corp and Online MGs present under Landing zones"
            } else empty end),
            (if $platSubCount > 0 then {
                signal: "platform-subscriptions", points: $ptsPlatSubs,
                evidence: "\($platSubCount) platform subscription(s) classified"
            } else empty end),
            (if $hasHubSpoke then {
                signal: "hub-spoke-topology", points: $ptsHubSpoke,
                evidence: "Hub VNet(s): \([$hubs[]?.name] | join(", "))"
            } else empty end),
            (if $hubInConn then {
                signal: "hub-in-connectivity-sub", points: $ptsHubInConn,
                evidence: "Hub VNet sits in a connectivity-classified subscription"
            } else empty end),
            (if $alzPolCount > 0 then {
                signal: "alz-canonical-policies", points: $ptsAlzPols,
                evidence: "\($alzPolCount) canonical ALZ policy assignment(s): \($alzPolList | join(", "))"
            } else empty end)
        ],
        missingSignals: [
            (if $topLevel < 4 then "alz-top-level-mgs (\($topLevel)/4)" else empty end),
            (if $platChildren < 3 then "platform-children (\($platChildren)/3)" else empty end),
            (if ($f.hasCorp and $f.hasOnline | not) then "alz-lz-archetypes (Corp/Online MGs)" else empty end),
            (if $platSubCount < 3 then "platform-subscriptions (\($platSubCount)/3+)" else empty end),
            (if ($hasHubSpoke | not) then "hub-spoke-topology" else empty end),
            (if ($hubInConn | not) then "hub-in-connectivity-sub" else empty end),
            (if $alzPolCount == 0 then "alz-canonical-policies" else empty end)
        ],
        checks: {
            topLevelMgs: {
                platform: $f.hasPlatform,
                landingZones: $f.hasLandingZones,
                sandbox: $f.hasSandbox,
                decommissioned: $f.hasDecommissioned
            },
            platformChildren: {
                connectivity: $f.hasConnectivity,
                identity: $f.hasIdentity,
                management: $f.hasManagement
            },
            lzChildren: { corp: $f.hasCorp, online: $f.hasOnline },
            platformSubscriptionCount: $platSubCount,
            hubSpoke: $hasHubSpoke,
            hubInConnectivitySubscription: $hubInConn,
            knownAlzPolicies: $alzPolList
        }
    }
    ')

DET_CONF=$(echo "$DETECTION_JSON" | jq -r '.confidence')
DET_SCORE=$(echo "$DETECTION_JSON" | jq -r '.confidenceScore')
case "$DET_CONF" in
    high)   echo -e "  Landing zone detection: ${GREEN}high${NC} ($DET_SCORE/100) — canonical ALZ deployment" ;;
    medium) echo -e "  Landing zone detection: ${GREEN}medium${NC} ($DET_SCORE/100) — partial ALZ alignment" ;;
    low)    echo -e "  Landing zone detection: ${YELLOW}low${NC} ($DET_SCORE/100) — some LZ signals" ;;
    *)      echo -e "  Landing zone detection: ${YELLOW}none${NC} ($DET_SCORE/100) — no canonical signals" ;;
esac

if [[ "$VERBOSE" == "true" ]]; then
    echo "  Matched signals:"
    echo "$DETECTION_JSON" | jq -r '.matchedSignals[] | "    + \(.points) pts — \(.signal): \(.evidence)"'
    MISSING_COUNT=$(echo "$DETECTION_JSON" | jq '.missingSignals | length')
    if [[ "$MISSING_COUNT" -gt 0 ]]; then
        echo "  Missing signals:"
        echo "$DETECTION_JSON" | jq -r '.missingSignals[] | "    - \(.)"'
    fi
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Assemble Output
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}Assembling landing zone context...${NC}"

MG_SECTION=$(jq -n \
    --arg root "$MG_ROOT" \
    --argjson hierarchy "$MG_HIERARCHY" \
    --argjson hasMG "$HAS_MANAGEMENT_GROUPS" \
    '{
        root: $root,
        hasManagementGroups: $hasMG,
        hierarchy: $hierarchy
    }')

SUBS_SECTION=$(jq -n \
    --argjson platform "$PLATFORM_SUBS" \
    --argjson landingZones "$LZ_SUBS" \
    '{
        platform: $platform,
        landingZones: $landingZones
    }')

CONTEXT_JSON=$(jq -n \
    --arg discoveredAt "$DISCOVERY_TIMESTAMP" \
    --arg discoveryMethod "auto" \
    --argjson managementGroups "$MG_SECTION" \
    --argjson subscriptions "$SUBS_SECTION" \
    --argjson sharedServices "$SHARED_SERVICES_JSON" \
    --argjson networking "$NETWORKING_JSON" \
    --argjson policies "$POLICIES_JSON" \
    --argjson currentIdentity "$IDENTITY_JSON" \
    --argjson landingZoneDetection "$DETECTION_JSON" \
    '{
        discoveredAt: $discoveredAt,
        discoveryMethod: $discoveryMethod,
        landingZoneDetection: $landingZoneDetection,
        managementGroups: $managementGroups,
        subscriptions: $subscriptions,
        sharedServices: $sharedServices,
        networking: $networking,
        policies: $policies,
        currentIdentity: $currentIdentity
    }')

# ─────────────────────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────────────────────

if [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
    # Markdown output
    OUTPUT=""
    OUTPUT+="# Landing Zone Discovery Report\n\n"
    OUTPUT+="**Discovered:** $DISCOVERY_TIMESTAMP\n"
    OUTPUT+="**User:** $CURRENT_USER\n"
    OUTPUT+="**Tenant:** $CURRENT_TENANT_ID\n\n"

    OUTPUT+="## Management Groups\n\n"
    if [[ "$HAS_MANAGEMENT_GROUPS" == "true" ]]; then
        OUTPUT+="Root: $MG_ROOT\n\n"
        OUTPUT+="| Management Group | Role | ID |\n"
        OUTPUT+="|------------------|------|----|\n"
        while IFS= read -r line; do
            MG_NAME=$(echo "$line" | jq -r '.displayName')
            MG_ROLE=$(echo "$line" | jq -r '.role')
            MG_ID=$(echo "$line" | jq -r '.name')
            OUTPUT+="| $MG_NAME | $MG_ROLE | $MG_ID |\n"
        done <<< "$(echo "$MG_HIERARCHY" | jq -c '.[]')"
    else
        OUTPUT+="No management groups found (flat subscription model)\n"
    fi
    OUTPUT+="\n"

    OUTPUT+="## Subscriptions\n\n"
    OUTPUT+="### Platform\n\n"
    PLATFORM_COUNT=$(echo "$PLATFORM_SUBS" | jq 'length')
    if [[ "$PLATFORM_COUNT" -gt 0 ]]; then
        OUTPUT+="| Name | Role | MG Path |\n"
        OUTPUT+="|------|------|---------|\n"
        while IFS= read -r line; do
            S_NAME=$(echo "$line" | jq -r '.name')
            S_ROLE=$(echo "$line" | jq -r '.role')
            S_MG=$(echo "$line" | jq -r '.mgPath // "N/A"')
            OUTPUT+="| $S_NAME | $S_ROLE | $S_MG |\n"
        done <<< "$(echo "$PLATFORM_SUBS" | jq -c '.[]')"
    else
        OUTPUT+="No platform subscriptions found\n"
    fi
    OUTPUT+="\n"

    OUTPUT+="### Landing Zones\n\n"
    LZ_COUNT=$(echo "$LZ_SUBS" | jq 'length')
    if [[ "$LZ_COUNT" -gt 0 ]]; then
        OUTPUT+="| Name | Environment | MG Path |\n"
        OUTPUT+="|------|-------------|---------|\n"
        while IFS= read -r line; do
            S_NAME=$(echo "$line" | jq -r '.name')
            S_ENV=$(echo "$line" | jq -r '.environment // "N/A"')
            S_MG=$(echo "$line" | jq -r '.mgPath // "N/A"')
            OUTPUT+="| $S_NAME | $S_ENV | $S_MG |\n"
        done <<< "$(echo "$LZ_SUBS" | jq -c '.[]')"
    else
        OUTPUT+="No landing zone subscriptions found\n"
    fi
    OUTPUT+="\n"

    if [[ -n "$OUTPUT_FILE" ]]; then
        echo -e "$OUTPUT" > "$OUTPUT_FILE"
    else
        echo -e "$OUTPUT"
    fi
else
    # JSON output (default)
    if [[ -n "$OUTPUT_FILE" ]]; then
        # Ensure output directory exists
        mkdir -p "$(dirname "$OUTPUT_FILE")"
        echo "$CONTEXT_JSON" | jq '.' > "$OUTPUT_FILE"
        echo -e "${GREEN}Landing zone context saved to: $OUTPUT_FILE${NC}"
    else
        echo "$CONTEXT_JSON" | jq '.'
    fi
fi

echo ""

# Summary
echo -e "${BLUE}Discovery Summary:${NC}"
echo -e "  Management Groups: $(if [[ "$HAS_MANAGEMENT_GROUPS" == "true" ]]; then echo -e "${GREEN}$(echo "$MG_HIERARCHY" | jq 'length') found${NC}"; else echo -e "${YELLOW}none (flat model)${NC}"; fi)"
echo -e "  Platform Subscriptions: ${GREEN}$(echo "$PLATFORM_SUBS" | jq 'length')${NC}"
echo -e "  Landing Zone Subscriptions: ${GREEN}$(echo "$LZ_SUBS" | jq 'length')${NC}"
echo -e "  Network Topology: $(if [[ "$SKIP_NETWORK" == "true" ]]; then echo "skipped"; else echo "$TOPOLOGY"; fi)"
echo -e "  Policy Assignments: $(if [[ "$SKIP_POLICIES" == "true" ]]; then echo "skipped"; else echo "$(echo "$POLICIES_JSON" | jq '.denyEffects | length') deny-effect"; fi)"
echo ""

if [[ "$PARTIAL_FAILURE" == "true" ]]; then
    echo -e "${YELLOW}⚠️ Partial discovery — some targets could not be reached. Results are still usable.${NC}"
    echo -e "${YELLOW}   Consider manual injection for missing data: .github/skills/azure-landing-zone-discovery/scripts/inject-lz.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Landing zone discovery complete${NC}"
exit 0
