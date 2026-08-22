#!/bin/bash
# azure-stack-deploy / deploy-stack.sh
#
# Deploy a Git-Ape deployment artifact as a subscription-scoped
# Azure Deployment Stack. Mirrors the logic of
# .github/workflows/git-ape-deploy.exampleyml so local CLI / VS Code
# deployments produce identical state.json (schemaVersion 1.0).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
DEPLOYMENTS_DIR=".azure/deployments"

# Soft-deletable resource types (must match the CI workflow list)
SOFT_DELETABLE_TYPES="Microsoft.KeyVault/vaults Microsoft.CognitiveServices/accounts Microsoft.AppConfiguration/configurationStores Microsoft.ApiManagement/service Microsoft.MachineLearningServices/workspaces Microsoft.RecoveryServices/vaults"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOYMENT_ID=""
LOCATION_OVERRIDE=""
NO_FALLBACK="false"

usage() {
    cat <<EOF
Azure Stack Deploy — deploy as subscription-scoped Deployment Stack

Usage: $0 --deployment-id <id> [OPTIONS]

Required:
  --deployment-id <id>     Folder name under .azure/deployments/

Options:
  --location <region>      Override location from parameters.json
  --no-fallback            Fail loudly if stack create fails (no fallback to az deployment sub create)
  -h, --help               Show this help

Examples:
  $0 --deployment-id deploy-20260506-001
  $0 --deployment-id deploy-20260506-001 --location westus2
  $0 --deployment-id deploy-20260506-001 --no-fallback
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
        --location)      LOCATION_OVERRIDE="$2"; shift 2 ;;
        --no-fallback)   NO_FALLBACK="true"; shift ;;
        -h|--help)       usage ;;
        *) echo "Unknown argument: $1"; usage ;;
    esac
done

[[ -n "$DEPLOYMENT_ID" ]] || usage

DEPLOYMENT_PATH="$WORKSPACE_ROOT/$DEPLOYMENTS_DIR/$DEPLOYMENT_ID"

if [[ ! -d "$DEPLOYMENT_PATH" ]]; then
    echo -e "${RED}Deployment not found: $DEPLOYMENT_ID${NC}"
    exit 1
fi
if [[ ! -f "$DEPLOYMENT_PATH/template.json" ]]; then
    echo -e "${RED}Template not found: $DEPLOYMENT_PATH/template.json${NC}"
    exit 1
fi

# Internal helpers ------------------------------------------------------------

# Classify a resource ID -> JSON object {id, type, scope, softDeletable, purgeProtected}
_classify_resource() {
    local RES_ID="$1"
    local RES_TYPE
    RES_TYPE=$(echo "$RES_ID" | grep -oE 'providers/[^/]+/[^/]+' | tail -1 | sed 's|providers/||')

    local RES_SCOPE="resourceGroup"
    echo "$RES_ID" | grep -q "/resourceGroups/" || RES_SCOPE="subscription"

    local IS_SOFT="false"
    local SD_TYPE
    for SD_TYPE in $SOFT_DELETABLE_TYPES; do
        if [[ "$RES_TYPE" == "$SD_TYPE" ]]; then
            IS_SOFT="true"
            break
        fi
    done

    local PURGE_PROTECTED="false"
    if [[ "$RES_TYPE" == "Microsoft.KeyVault/vaults" ]]; then
        PURGE_PROTECTED=$(az resource show --ids "$RES_ID" \
            --query "properties.enablePurgeProtection // \`false\`" -o tsv 2>/dev/null || echo "false")
        [[ -z "$PURGE_PROTECTED" ]] && PURGE_PROTECTED="false"
    fi

    jq -n \
        --arg id "$RES_ID" --arg type "$RES_TYPE" --arg scope "$RES_SCOPE" \
        --argjson sd "$IS_SOFT" --argjson pp "$PURGE_PROTECTED" \
        '{id:$id, type:$type, scope:$scope, softDeletable:$sd, purgeProtected:$pp}'
}

# Build managedResources[] array from a list of resource IDs (one per line on stdin)
_build_managed_resources() {
    local OUT="[]"
    local RES_ID CLASSIFIED
    while IFS= read -r RES_ID; do
        [[ -z "$RES_ID" ]] && continue
        CLASSIFIED=$(_classify_resource "$RES_ID")
        OUT=$(echo "$OUT" | jq --argjson r "$CLASSIFIED" '. + [$r]')
    done
    echo "$OUT"
}

# Resolve deployment parameters ----------------------------------------------

PARAMS_ARG=()
LOCATION="eastus"
PROJECT="unknown"
ENVIRONMENT="dev"
if [[ -f "$DEPLOYMENT_PATH/parameters.json" ]]; then
    PARAMS_ARG=(--parameters "@$DEPLOYMENT_PATH/parameters.json")
    LOCATION=$(jq -r '.parameters.location.value // "eastus"' "$DEPLOYMENT_PATH/parameters.json")
    PROJECT=$(jq -r '.parameters.project.value // .parameters.projectName.value // "unknown"' "$DEPLOYMENT_PATH/parameters.json")
    ENVIRONMENT=$(jq -r '.parameters.environment.value // "dev"' "$DEPLOYMENT_PATH/parameters.json")
fi
[[ -n "$LOCATION_OVERRIDE" ]] && LOCATION="$LOCATION_OVERRIDE"

SUBSCRIPTION=$(az account show --query id -o tsv 2>/dev/null || echo "")
if [[ -z "$SUBSCRIPTION" ]]; then
    echo -e "${RED}Not logged in to Azure. Run 'az login' first.${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Deploying $DEPLOYMENT_ID${NC}"
echo "  Subscription: $SUBSCRIPTION"
echo "  Location:     $LOCATION"
echo "  Method:       stack (az stack sub create --action-on-unmanage deleteAll)"

# Deploy ----------------------------------------------------------------------

START_TIME=$(date +%s)
DEPLOY_METHOD="stack"
STACK_ID=""
DEPLOY_OUTPUT=""
EXIT_CODE=0
# Verbose output goes to a temp file so it does not contaminate the JSON we
# need to feed to jq. We surface the verbose log only when something fails.
VERBOSE_LOG=$(mktemp)
trap 'rm -f "$VERBOSE_LOG"' EXIT

if ! DEPLOY_OUTPUT=$(az stack sub create \
    --name "$DEPLOYMENT_ID" \
    --location "$LOCATION" \
    --template-file "$DEPLOYMENT_PATH/template.json" \
    "${PARAMS_ARG[@]}" \
    --action-on-unmanage deleteAll \
    --deny-settings-mode none \
    --description "Git-Ape deployment $DEPLOYMENT_ID" \
    --tags "managedBy=git-ape" "deploymentId=$DEPLOYMENT_ID" \
    --yes \
    --verbose \
    --output json 2>"$VERBOSE_LOG"); then

    if [[ "$NO_FALLBACK" == "true" ]]; then
        echo -e "${RED}❌ Stack deploy failed and --no-fallback was set${NC}"
        echo "$DEPLOY_OUTPUT"
        cat "$VERBOSE_LOG" >&2
        EXIT_CODE=1
    else
        echo -e "${YELLOW}⚠ Stack deploy failed; check whether Deployment Stacks are available in this subscription/region.${NC}"
        echo "$DEPLOY_OUTPUT"
        cat "$VERBOSE_LOG" >&2
        echo -e "${YELLOW}Falling back to az deployment sub create (NOT idempotent for soft-delete / multi-RG).${NC}"
        DEPLOY_METHOD="subscription"
        if ! DEPLOY_OUTPUT=$(az deployment sub create \
            --name "$DEPLOYMENT_ID" \
            --location "$LOCATION" \
            --template-file "$DEPLOYMENT_PATH/template.json" \
            "${PARAMS_ARG[@]}" \
            --output json 2>"$VERBOSE_LOG"); then
            cat "$VERBOSE_LOG" >&2
            EXIT_CODE=1
        fi
    fi
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo -e "${RED}❌ Deployment failed${NC}"
    echo "$DEPLOY_OUTPUT"
    # Surface underlying failed operations — the stack/deployment top-level
    # error is usually a summary; the real root cause lives in the per-resource
    # operations list.
    echo ""
    echo -e "${YELLOW}── Underlying failed operations ──${NC}"
    az deployment operation sub list --name "$DEPLOYMENT_ID" --output json 2>/dev/null \
        | jq -r '.[] | select(.properties.provisioningState == "Failed") |
            "──────────\nResource : \(.properties.targetResource.resourceName // "n/a") (\(.properties.targetResource.resourceType // "n/a"))\nStatus   : \(.properties.statusCode // "n/a")\nMessage  : \(.properties.statusMessage.error.message // .properties.statusMessage // "n/a")"' \
        2>/dev/null || echo "(no per-operation details available — deployment may not have reached Azure)"
    exit 1
fi

# Capture state ---------------------------------------------------------------

if [[ "$DEPLOY_METHOD" == "stack" ]]; then
    STACK_ID=$(echo "$DEPLOY_OUTPUT" | jq -r '.id // empty')
    OUTPUTS=$(echo "$DEPLOY_OUTPUT" | jq -r '.outputs // {}')
else
    OUTPUTS=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.outputs // {}')
fi
RG_NAME=$(echo "$OUTPUTS" | jq -r '.resourceGroupName.value // empty')

echo -e "${GREEN}✅ Deployment succeeded in ${DURATION}s (method: $DEPLOY_METHOD)${NC}"

if [[ "$DEPLOY_METHOD" == "stack" && -n "$STACK_ID" ]]; then
    STACK_RESOURCES=$(az stack sub show --name "$DEPLOYMENT_ID" --query "resources[].id" -o json 2>/dev/null || echo "[]")
    MANAGED_RESOURCES=$(echo "$STACK_RESOURCES" | jq -r '.[]' | _build_managed_resources)
else
    OPS=$(az deployment operation sub list --name "$DEPLOYMENT_ID" \
        --query "[?properties.provisioningState=='Succeeded' && properties.targetResource.id != null].properties.targetResource.id" \
        -o tsv 2>/dev/null || echo "")
    MANAGED_RESOURCES=$(echo "$OPS" | _build_managed_resources)
fi

RESOURCE_GROUPS=$(echo "$MANAGED_RESOURCES" | jq -c '[.[].id | capture("/resourceGroups/(?<rg>[^/]+)") | .rg] | unique')
[[ "$(echo "$RESOURCE_GROUPS" | jq 'length')" == "0" && -n "$RG_NAME" ]] && RESOURCE_GROUPS="[\"$RG_NAME\"]"

STATE_FILE="$DEPLOYMENT_PATH/state.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n \
    --arg schemaVersion "1.0" \
    --arg deploymentId "$DEPLOYMENT_ID" \
    --arg timestamp "$TIMESTAMP" \
    --arg status "succeeded" \
    --arg duration "${DURATION}s" \
    --arg subscription "$SUBSCRIPTION" \
    --arg location "$LOCATION" \
    --arg project "$PROJECT" \
    --arg environment "$ENVIRONMENT" \
    --arg resourceGroup "$RG_NAME" \
    --arg deployMethod "$DEPLOY_METHOD" \
    --arg stackId "$STACK_ID" \
    --argjson managedResources "$MANAGED_RESOURCES" \
    --argjson resourceGroups "$RESOURCE_GROUPS" \
    '{
        schemaVersion: $schemaVersion,
        deploymentId: $deploymentId,
        timestamp: $timestamp,
        status: $status,
        duration: $duration,
        subscription: $subscription,
        location: $location,
        project: $project,
        environment: $environment,
        resourceGroup: $resourceGroup,
        deployMethod: $deployMethod,
        stackId: (if $stackId == "" then null else $stackId end),
        managedResources: $managedResources,
        resourceGroups: $resourceGroups,
        subscriptions: [$subscription],
        externalReferences: []
    }' > "$STATE_FILE"

if [[ -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
    jq --arg status "succeeded" --arg method "$DEPLOY_METHOD" --argjson rgs "$RESOURCE_GROUPS" \
        '.status = $status | .deployMethod = $method | .resourceGroups = $rgs' \
        "$DEPLOYMENT_PATH/metadata.json" > "$DEPLOYMENT_PATH/metadata.json.tmp" \
        && mv "$DEPLOYMENT_PATH/metadata.json.tmp" "$DEPLOYMENT_PATH/metadata.json"
fi

echo -e "${GREEN}State written to: $STATE_FILE${NC}"
[[ -n "$STACK_ID" ]] && echo "Stack ID: $STACK_ID"
echo ""
echo "To destroy this deployment:"
echo "  /azure-stack-destroy $DEPLOYMENT_ID"
