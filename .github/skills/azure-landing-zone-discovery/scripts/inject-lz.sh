#!/bin/bash
# Azure Landing Zone Manual Injection Script
# Creates or updates .azure/landing-zone-context.json from user-provided values
# Use when auto-discovery is not possible (cross-tenant, limited RBAC, air-gapped)

set -euo pipefail

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
HUB_VNET_ID=""
LOG_ANALYTICS_ID=""
ACR_ID=""
KEY_VAULT_ID=""
ALLOWED_LOCATIONS=""
REQUIRED_TAGS=""
DENY_PUBLIC_IP=false
DENY_PUBLIC_STORAGE=false
OUTPUT_FILE=".azure/landing-zone-context.json"
MERGE_MODE=false
CONFIDENCE=""
CONFIDENCE_EXPLICIT=false

usage() {
    cat <<EOF
Azure Landing Zone Manual Injection Script

Creates or updates .azure/landing-zone-context.json from user-provided values.
Use when auto-discovery is not possible (cross-tenant, limited RBAC, air-gapped).

Usage: $0 [OPTIONS]

Options:
  --hub-vnet-id <id>         Azure resource ID of the hub VNet
  --log-analytics-id <id>    Azure resource ID of the shared Log Analytics workspace
  --acr-id <id>              Azure resource ID of the shared Container Registry
  --key-vault-id <id>        Azure resource ID of the shared Key Vault
  --allowed-locations <list> Comma-separated list of allowed Azure regions
  --required-tags <list>     Comma-separated list of required tag names
  --deny-public-ip           Flag: public IPs are denied by policy
  --deny-public-storage      Flag: public storage access is denied by policy
  --output-file <path>       Output file path (default: .azure/landing-zone-context.json)
  --merge                    Merge with existing context file instead of replacing
  --confidence <level>       Assert landing zone confidence: high|medium|low|none
                             (default: high — manual injection is an explicit
                             assertion that this tenant is landing-zone managed)
  --not-landing-zone         Shorthand for --confidence none (assert NOT a landing zone)
  -h, --help                 Show this help message

Examples:
  # Inject hub VNet and Log Analytics
  $0 --hub-vnet-id "/subscriptions/.../providers/Microsoft.Network/virtualNetworks/vnet-hub" \\
     --log-analytics-id "/subscriptions/.../providers/Microsoft.OperationalInsights/workspaces/log-central"

  # Inject policy constraints
  $0 --allowed-locations "eastus,westus2,westeurope" \\
     --required-tags "Environment,Project,CostCenter" \\
     --deny-public-ip

  # Declare "I know my tenant is ALZ-managed" with no other data
  $0 --confidence high

  # Merge with existing discovery
  $0 --merge --acr-id "/subscriptions/.../providers/Microsoft.ContainerRegistry/registries/crshared"

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hub-vnet-id)
            HUB_VNET_ID="$2"
            shift 2
            ;;
        --log-analytics-id)
            LOG_ANALYTICS_ID="$2"
            shift 2
            ;;
        --acr-id)
            ACR_ID="$2"
            shift 2
            ;;
        --key-vault-id)
            KEY_VAULT_ID="$2"
            shift 2
            ;;
        --allowed-locations)
            ALLOWED_LOCATIONS="$2"
            shift 2
            ;;
        --required-tags)
            REQUIRED_TAGS="$2"
            shift 2
            ;;
        --deny-public-ip)
            DENY_PUBLIC_IP=true
            shift
            ;;
        --deny-public-storage)
            DENY_PUBLIC_STORAGE=true
            shift
            ;;
        --output-file)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --merge)
            MERGE_MODE=true
            shift
            ;;
        --confidence)
            CONFIDENCE="$2"
            CONFIDENCE_EXPLICIT=true
            shift 2
            ;;
        --not-landing-zone)
            CONFIDENCE="none"
            CONFIDENCE_EXPLICIT=true
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

# Check if at least one value was provided
if [[ -z "$HUB_VNET_ID" ]] && [[ -z "$LOG_ANALYTICS_ID" ]] && [[ -z "$ACR_ID" ]] && \
   [[ -z "$KEY_VAULT_ID" ]] && [[ -z "$ALLOWED_LOCATIONS" ]] && [[ -z "$REQUIRED_TAGS" ]] && \
   [[ "$DENY_PUBLIC_IP" == "false" ]] && [[ "$DENY_PUBLIC_STORAGE" == "false" ]] && \
   [[ "$CONFIDENCE_EXPLICIT" == "false" ]]; then
    echo -e "${RED}Error: At least one landing zone parameter must be provided${NC}"
    echo ""
    usage
fi

# ─────────────────────────────────────────────────────────────────────────────
# Resolve landing zone detection.
#
# Manual injection is an explicit assertion that this tenant is landing-zone
# managed, so unless the caller says otherwise we record a high-confidence,
# source="manual" detection. This is what allows the manual fallback to flip
# LZ-aware behaviour in downstream agents (the auto-scorer is bypassed here).
# ─────────────────────────────────────────────────────────────────────────────
if [[ -z "$CONFIDENCE" ]]; then
    CONFIDENCE="high"
fi
CONFIDENCE=$(echo "$CONFIDENCE" | tr '[:upper:]' '[:lower:]')
case "$CONFIDENCE" in
    high)   CONF_SCORE=90 ;;
    medium) CONF_SCORE=50 ;;
    low)    CONF_SCORE=20 ;;
    none)   CONF_SCORE=0 ;;
    *)
        echo -e "${RED}Error: --confidence must be one of: high, medium, low, none${NC}"
        exit 1
        ;;
esac
# isLandingZone threshold matches discover-lz.sh (score >= 40)
if [[ "$CONF_SCORE" -ge 40 ]]; then
    IS_LANDING_ZONE=true
else
    IS_LANDING_ZONE=false
fi

INJECTION_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo -e "${BLUE}Injecting landing zone context...${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Helper: extract name and subscription from resource ID
# ─────────────────────────────────────────────────────────────────────────────
extract_name() {
    echo "$1" | grep -oE '[^/]+$'
}

extract_subscription() {
    echo "$1" | grep -oE 'subscriptions/[^/]+' | cut -d/ -f2
}

extract_location_from_name() {
    # Try to extract location hint from resource name (e.g., vnet-hub-eastus)
    local name="$1"
    local locations=("eastus" "eastus2" "westus" "westus2" "westus3" "centralus" "northcentralus" "southcentralus" "westeurope" "northeurope" "uksouth" "ukwest" "southeastasia" "eastasia" "australiaeast" "japaneast" "brazilsouth" "canadacentral" "francecentral" "germanywestcentral" "norwayeast" "switzerlandnorth")
    for loc in "${locations[@]}"; do
        if echo "$name" | grep -qi "$loc"; then
            echo "$loc"
            return
        fi
    done
    echo "unknown"
}

# ─────────────────────────────────────────────────────────────────────────────
# Build shared services section
# ─────────────────────────────────────────────────────────────────────────────
SHARED_SERVICES='{}'

if [[ -n "$HUB_VNET_ID" ]]; then
    VNET_NAME=$(extract_name "$HUB_VNET_ID")
    VNET_SUB=$(extract_subscription "$HUB_VNET_ID")
    VNET_LOC=$(extract_location_from_name "$VNET_NAME")
    echo -e "  Hub VNet: ${GREEN}$VNET_NAME${NC} (sub: $VNET_SUB)"
fi

if [[ -n "$LOG_ANALYTICS_ID" ]]; then
    LA_NAME=$(extract_name "$LOG_ANALYTICS_ID")
    LA_SUB=$(extract_subscription "$LOG_ANALYTICS_ID")
    LA_LOC=$(extract_location_from_name "$LA_NAME")
    SHARED_SERVICES=$(echo "$SHARED_SERVICES" | jq \
        --arg id "$LOG_ANALYTICS_ID" \
        --arg name "$LA_NAME" \
        --arg sub "$LA_SUB" \
        --arg loc "$LA_LOC" \
        '. + { logAnalytics: { id: $id, name: $name, subscription: $sub, location: $loc } }')
    echo -e "  Log Analytics: ${GREEN}$LA_NAME${NC}"
fi

if [[ -n "$ACR_ID" ]]; then
    ACR_NAME=$(extract_name "$ACR_ID")
    ACR_SUB=$(extract_subscription "$ACR_ID")
    ACR_LOC=$(extract_location_from_name "$ACR_NAME")
    SHARED_SERVICES=$(echo "$SHARED_SERVICES" | jq \
        --arg id "$ACR_ID" \
        --arg name "$ACR_NAME" \
        --arg sub "$ACR_SUB" \
        --arg loc "$ACR_LOC" \
        '. + { containerRegistry: { id: $id, name: $name, subscription: $sub, location: $loc } }')
    echo -e "  Container Registry: ${GREEN}$ACR_NAME${NC}"
fi

if [[ -n "$KEY_VAULT_ID" ]]; then
    KV_NAME=$(extract_name "$KEY_VAULT_ID")
    KV_SUB=$(extract_subscription "$KEY_VAULT_ID")
    KV_LOC=$(extract_location_from_name "$KV_NAME")
    SHARED_SERVICES=$(echo "$SHARED_SERVICES" | jq \
        --arg id "$KEY_VAULT_ID" \
        --arg name "$KV_NAME" \
        --arg sub "$KV_SUB" \
        --arg loc "$KV_LOC" \
        '. + { keyVault: { id: $id, name: $name, subscription: $sub, location: $loc } }')
    echo -e "  Key Vault: ${GREEN}$KV_NAME${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Build networking section
# ─────────────────────────────────────────────────────────────────────────────
NETWORKING='{"topology":"unknown","hubs":[],"privateDnsZones":[],"peerings":[]}'

if [[ -n "$HUB_VNET_ID" ]]; then
    NETWORKING=$(echo "$NETWORKING" | jq \
        --arg topology "hub-spoke" \
        --arg id "$HUB_VNET_ID" \
        --arg name "$VNET_NAME" \
        --arg sub "$VNET_SUB" \
        --arg loc "$VNET_LOC" \
        '.topology = $topology | .hubs = [{ id: $id, name: $name, subscription: $sub, location: $loc, addressPrefixes: [] }]')
fi

# ─────────────────────────────────────────────────────────────────────────────
# Build policies section
# ─────────────────────────────────────────────────────────────────────────────
DENY_EFFECTS="[]"
LOCATIONS_JSON="[]"
TAGS_JSON="[]"

if [[ "$DENY_PUBLIC_IP" == "true" ]]; then
    DENY_EFFECTS=$(echo "$DENY_EFFECTS" | jq '. += [{
        "name": "Deny-Public-IP",
        "scope": "manual-injection",
        "impact": "Blocks public IP creation"
    }]')
    echo -e "  Policy: ${YELLOW}Deny-Public-IP${NC}"
fi

if [[ "$DENY_PUBLIC_STORAGE" == "true" ]]; then
    DENY_EFFECTS=$(echo "$DENY_EFFECTS" | jq '. += [{
        "name": "Deny-Storage-Public-Access",
        "scope": "manual-injection",
        "impact": "Blocks public storage access"
    }]')
    echo -e "  Policy: ${YELLOW}Deny-Storage-Public-Access${NC}"
fi

if [[ -n "$ALLOWED_LOCATIONS" ]]; then
    LOCATIONS_JSON=$(echo "$ALLOWED_LOCATIONS" | tr ',' '\n' | jq -R . | jq -s .)
    echo -e "  Allowed locations: ${GREEN}$ALLOWED_LOCATIONS${NC}"
fi

if [[ -n "$REQUIRED_TAGS" ]]; then
    TAGS_JSON=$(echo "$REQUIRED_TAGS" | tr ',' '\n' | jq -R . | jq -s .)
    echo -e "  Required tags: ${GREEN}$REQUIRED_TAGS${NC}"
fi

POLICIES_JSON=$(jq -n \
    --argjson deny "$DENY_EFFECTS" \
    --argjson locations "$LOCATIONS_JSON" \
    --argjson tags "$TAGS_JSON" \
    '{
        denyEffects: $deny,
        auditEffects: [],
        allowedLocations: $locations,
        requiredTags: $tags
    }')

# ─────────────────────────────────────────────────────────────────────────────
# Assemble context file
# ─────────────────────────────────────────────────────────────────────────────
echo ""

NEW_CONTEXT=$(jq -n \
    --arg discoveredAt "$INJECTION_TIMESTAMP" \
    --arg discoveryMethod "manual" \
    --argjson isLandingZone "$IS_LANDING_ZONE" \
    --arg confidence "$CONFIDENCE" \
    --argjson confidenceScore "$CONF_SCORE" \
    --argjson sharedServices "$SHARED_SERVICES" \
    --argjson networking "$NETWORKING" \
    --argjson policies "$POLICIES_JSON" \
    '{
        discoveredAt: $discoveredAt,
        discoveryMethod: $discoveryMethod,
        landingZoneDetection: {
            isLandingZone: $isLandingZone,
            confidence: $confidence,
            confidenceScore: $confidenceScore,
            source: "manual",
            reference: "https://azure.github.io/Azure-Landing-Zones/accelerator/",
            matchedSignals: [
                { signal: "manual-injection", points: $confidenceScore,
                  evidence: "Landing zone context asserted via inject-lz.sh (--confidence \($confidence))" }
            ],
            missingSignals: []
        },
        managementGroups: { root: "", hasManagementGroups: false, hierarchy: [] },
        subscriptions: { platform: [], landingZones: [] },
        sharedServices: $sharedServices,
        networking: $networking,
        policies: $policies,
        currentIdentity: { user: "manual-injection", tenantId: "", currentSubscription: { id: "", name: "" }, roles: [] }
    }')

# Merge with existing if requested
if [[ "$MERGE_MODE" == "true" ]] && [[ -f "$OUTPUT_FILE" ]]; then
    echo -e "${BLUE}Merging with existing context file...${NC}"
    EXISTING=$(cat "$OUTPUT_FILE")

    # Deep merge: new values override existing, arrays are replaced
    MERGED=$(echo "$EXISTING" "$NEW_CONTEXT" | jq -s \
        --argjson confExplicit "$CONFIDENCE_EXPLICIT" '
        .[0] as $existing |
        .[1] as $new |
        ($existing.landingZoneDetection // null) as $existingLz |
        ($new.landingZoneDetection) as $newLz |
        # Reconcile detection: an explicit --confidence forces the injected value
        # (so the caller can raise OR lower it); otherwise injection can only
        # raise confidence, never silently downgrade a real discovery result.
        (if $confExplicit then $newLz
         elif ($existingLz == null) then $newLz
         elif (($newLz.confidenceScore // 0) >= ($existingLz.confidenceScore // 0)) then $newLz
         else $existingLz end) as $mergedLz |
        $existing * {
            discoveredAt: $new.discoveredAt,
            discoveryMethod: "merged",
            landingZoneDetection: $mergedLz,
            sharedServices: ($existing.sharedServices * $new.sharedServices),
            networking: (
                if ($new.networking.topology != "unknown") then $new.networking
                else $existing.networking end
            ),
            policies: {
                denyEffects: (($existing.policies.denyEffects // []) + ($new.policies.denyEffects // []) | unique_by(.name)),
                auditEffects: (($existing.policies.auditEffects // []) + ($new.policies.auditEffects // []) | unique_by(.name)),
                allowedLocations: (if ($new.policies.allowedLocations | length) > 0 then $new.policies.allowedLocations else ($existing.policies.allowedLocations // []) end),
                requiredTags: (($existing.policies.requiredTags // []) + ($new.policies.requiredTags // []) | unique)
            }
        }
    ')
    FINAL_CONTEXT="$MERGED"
else
    FINAL_CONTEXT="$NEW_CONTEXT"
fi

# Write output
mkdir -p "$(dirname "$OUTPUT_FILE")"
echo "$FINAL_CONTEXT" | jq '.' > "$OUTPUT_FILE"

echo -e "${GREEN}✅ Landing zone context saved to: $OUTPUT_FILE${NC}"
echo ""
echo -e "To verify: ${BLUE}cat $OUTPUT_FILE | jq '.'${NC}"
echo -e "To merge with auto-discovery: ${BLUE}.github/skills/azure-landing-zone-discovery/scripts/discover-lz.sh --output-file $OUTPUT_FILE${NC}"
exit 0
