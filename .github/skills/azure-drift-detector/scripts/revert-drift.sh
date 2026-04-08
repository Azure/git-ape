#!/bin/bash
# Revert Azure drift by redeploying from IaC to enforce desired state

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOYMENT_ID=""
CONFIRM=false
DRY_RUN=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

usage() {
    cat <<EOF
Revert Drift Script - Redeploy to enforce IaC state

Usage: $0 --deployment-id <id> [OPTIONS]

Required:
  --deployment-id <id>     Deployment ID to revert drift for

Options:
  --confirm                Skip confirmation prompt
  --dry-run                Show what would be reverted without executing
  -h, --help              Show this help message

Example:
  $0 --deployment-id deploy-20260218-143022
  $0 --deployment-id deploy-20260218-143022 --confirm

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
        --confirm) CONFIRM=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$DEPLOYMENT_ID" ]]; then
    echo "Error: --deployment-id is required"
    usage
fi

DEPLOYMENT_PATH="$WORKSPACE_ROOT/.azure/deployments/$DEPLOYMENT_ID"
DRIFT_DIR="$DEPLOYMENT_PATH/drift-analysis"

if [[ ! -f "$DRIFT_DIR/drift-details.json" ]]; then
    echo -e "${RED}Error: No drift analysis found. Run detect-drift.sh first.${NC}"
    exit 1
fi

echo -e "${BLUE}Reverting drift for: $DEPLOYMENT_ID${NC}"
echo ""

# Load drift details
DRIFT_DETAILS=$(cat "$DRIFT_DIR/drift-details.json")
CRITICAL_DRIFTS=$(echo "$DRIFT_DETAILS" | jq -r '.summary.criticalDrift')
WARNING_DRIFTS=$(echo "$DRIFT_DETAILS" | jq -r '.summary.warningDrift')
TOTAL_DRIFTS=$(echo "$DRIFT_DETAILS" | jq -r '.summary.totalDrifts')

if [[ "$TOTAL_DRIFTS" -eq 0 ]]; then
    echo -e "${GREEN}No drift to revert.${NC}"
    exit 0
fi

echo "Drift summary:"
echo -e "  🔴 Critical: $CRITICAL_DRIFTS"
echo -e "  🟡 Warning: $WARNING_DRIFTS"
echo -e "  Total: $TOTAL_DRIFTS"
echo ""

# Show what will be reverted
echo -e "${YELLOW}Changes that will be reverted:${NC}"
echo "$DRIFT_DETAILS" | jq -r '.drifts[].drifts[] | 
    "  " + .property + ": " + .current + " → " + .expected + 
    " (" + .severity + ")"'
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${BLUE}DRY RUN - No changes will be made${NC}"
    exit 0
fi

# Confirmation
if [[ "$CONFIRM" != "true" ]]; then
    echo -e "${RED}⚠️  This will redeploy resources to revert the changes above.${NC}"
    echo ""
    echo "Type 'confirm revert' to proceed:"
    read -r CONFIRMATION
    
    if [[ "$CONFIRMATION" != "confirm revert" ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Load original template and parameters
if [[ ! -f "$DEPLOYMENT_PATH/template.json" ]]; then
    echo -e "${RED}Error: template.json not found${NC}"
    exit 1
fi

TEMPLATE="$DEPLOYMENT_PATH/template.json"
PARAMETERS="$DEPLOYMENT_PATH/parameters.json"

# Get resource group from metadata
RG_NAME=$(jq -r '.resources[0].id' "$DEPLOYMENT_PATH/metadata.json" | grep -oE 'resourceGroups/[^/]+' | cut -d/ -f2)

if [[ -z "$RG_NAME" ]]; then
    echo -e "${RED}Error: Could not determine resource group${NC}"
    exit 1
fi

echo -e "${BLUE}Deploying to resource group: $RG_NAME${NC}"
echo ""

# Create revert deployment
REVERT_DEPLOYMENT_ID="deploy-$(date +%Y%m%d-%H%M%S)-revert"
REVERT_PATH="$WORKSPACE_ROOT/.azure/deployments/$REVERT_DEPLOYMENT_ID"
mkdir -p "$REVERT_PATH"

# Copy original state
cp "$TEMPLATE" "$REVERT_PATH/template.json"
[[ -f "$PARAMETERS" ]] && cp "$PARAMETERS" "$REVERT_PATH/parameters.json"

# Create metadata for revert deployment
cat > "$REVERT_PATH/metadata.json" <<EOF
{
  "deploymentId": "$REVERT_DEPLOYMENT_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "user": "$(az account show --query user.name -o tsv 2>/dev/null || echo 'unknown')",
  "type": "drift-revert",
  "originalDeployment": "$DEPLOYMENT_ID",
  "status": "in-progress"
}
EOF

echo -e "${BLUE}Executing deployment...${NC}"

# Deploy using Azure CLI
if [[ -f "$PARAMETERS" ]]; then
    DEPLOY_OUTPUT=$(az deployment group create \
        --name "$REVERT_DEPLOYMENT_ID" \
        --resource-group "$RG_NAME" \
        --template-file "$TEMPLATE" \
        --parameters "@$PARAMETERS" \
        --mode Incremental \
        --output json 2>&1)
else
    DEPLOY_OUTPUT=$(az deployment group create \
        --name "$REVERT_DEPLOYMENT_ID" \
        --resource-group "$RG_NAME" \
        --template-file "$TEMPLATE" \
        --mode Incremental \
        --output json 2>&1)
fi

DEPLOY_STATUS=$?

if [[ $DEPLOY_STATUS -eq 0 ]]; then
    echo -e "${GREEN}✓ Deployment succeeded${NC}"
    
    # Update metadata
    jq '.status = "succeeded"' "$REVERT_PATH/metadata.json" > "$REVERT_PATH/metadata.json.tmp"
    mv "$REVERT_PATH/metadata.json.tmp" "$REVERT_PATH/metadata.json"
    
    # Log revert to drift log
    cat >> "$DRIFT_DIR/drift-log.jsonl" <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","action":"revert","user":"$(az account show --query user.name -o tsv 2>/dev/null || echo 'unknown')","revertDeploymentId":"$REVERT_DEPLOYMENT_ID","driftsReverted":$TOTAL_DRIFTS}
EOF
    
    echo ""
    echo "Revert deployment: $REVERT_DEPLOYMENT_ID"
    echo "Path: $REVERT_PATH"
    echo ""
    echo "Next steps:"
    echo "  1. Run drift detection again to verify revert"
    echo "  2. Review deployment logs in Azure Portal"
    
else
    echo -e "${RED}✗ Deployment failed${NC}"
    echo "$DEPLOY_OUTPUT"
    
    # Update metadata
    jq '.status = "failed"' "$REVERT_PATH/metadata.json" > "$REVERT_PATH/metadata.json.tmp"
    mv "$REVERT_PATH/metadata.json.tmp" "$REVERT_PATH/metadata.json"
    
    # Save error log
    echo "$DEPLOY_OUTPUT" > "$REVERT_PATH/error.log"
    
    echo ""
    echo "Error details saved to: $REVERT_PATH/error.log"
    exit 1
fi
