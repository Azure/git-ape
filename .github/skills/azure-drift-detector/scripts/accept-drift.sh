#!/bin/bash
# Accept Azure drift and update IaC to match current Azure state

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOYMENT_ID=""
REASON=""
AUTO_COMMIT=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

usage() {
    cat <<EOF
Accept Drift Script - Update IaC to match Azure state

Usage: $0 --deployment-id <id> [OPTIONS]

Required:
  --deployment-id <id>     Deployment ID to accept drift for

Options:
  --reason <text>          Reason for accepting drift (for audit log)
  --auto-commit            Create git commit with changes
  -h, --help              Show this help message

Example:
  $0 --deployment-id deploy-20260218-143022 --reason "Policy remediation accepted"

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
        --reason) REASON="$2"; shift 2 ;;
        --auto-commit) AUTO_COMMIT=true; shift ;;
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

echo -e "${BLUE}Accepting drift for: $DEPLOYMENT_ID${NC}"
echo ""

# Load drift details
DRIFT_DETAILS=$(cat "$DRIFT_DIR/drift-details.json")
TOTAL_DRIFTS=$(echo "$DRIFT_DETAILS" | jq -r '.summary.totalDrifts')

if [[ "$TOTAL_DRIFTS" -eq 0 ]]; then
    echo -e "${GREEN}No drift to accept.${NC}"
    exit 0
fi

echo "Found $TOTAL_DRIFTS drift(s) to accept"
echo ""

# Prompt for reason if not provided
if [[ -z "$REASON" ]]; then
    echo "Please provide a reason for accepting this drift:"
    read -r REASON
fi

# Backup original state
BACKUP_DIR="$DEPLOYMENT_PATH/drift-analysis/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$DEPLOYMENT_PATH/requirements.json" "$BACKUP_DIR/" 2>/dev/null || true
cp "$DEPLOYMENT_PATH/template.json" "$BACKUP_DIR/" 2>/dev/null || true
echo -e "${GREEN}✓ Backed up original state to: $BACKUP_DIR${NC}"

# Update requirements.json with current Azure state
echo -e "${BLUE}Updating requirements.json...${NC}"

RESOURCES=$(echo "$DRIFT_DETAILS" | jq -r '.drifts[].resource')

for RESOURCE_NAME in $RESOURCES; do
    CURRENT_STATE_FILE="$DRIFT_DIR/current-${RESOURCE_NAME}.json"
    
    if [[ -f "$CURRENT_STATE_FILE" ]]; then
        CURRENT_STATE=$(cat "$CURRENT_STATE_FILE")
        
        # Extract relevant properties
        HTTPS_ONLY=$(echo "$CURRENT_STATE" | jq -r '.properties.httpsOnly // null')
        MIN_TLS=$(echo "$CURRENT_STATE" | jq -r '.properties.minimumTlsVersion // null')
        TAGS=$(echo "$CURRENT_STATE" | jq -r '.tags // {}')
        
        # Update requirements.json
        REQUIREMENTS=$(cat "$DEPLOYMENT_PATH/requirements.json")
        
        # Update configuration properties
        if [[ "$HTTPS_ONLY" != "null" ]]; then
            REQUIREMENTS=$(echo "$REQUIREMENTS" | jq \
                --arg name "$RESOURCE_NAME" \
                --argjson https "$HTTPS_ONLY" \
                '(.resources[] | select(.name == $name) | .configuration.httpsOnly) |= $https')
        fi
        
        if [[ "$MIN_TLS" != "null" ]]; then
            REQUIREMENTS=$(echo "$REQUIREMENTS" | jq \
                --arg name "$RESOURCE_NAME" \
                --arg tls "$MIN_TLS" \
                '(.resources[] | select(.name == $name) | .configuration.minimumTlsVersion) |= $tls')
        fi
        
        # Update tags
        REQUIREMENTS=$(echo "$REQUIREMENTS" | jq \
            --arg name "$RESOURCE_NAME" \
            --argjson tags "$TAGS" \
            '(.resources[] | select(.name == $name) | .tags) |= $tags')
        
        echo "$REQUIREMENTS" > "$DEPLOYMENT_PATH/requirements.json"
        
        echo -e "${GREEN}  ✓ Updated $RESOURCE_NAME${NC}"
    fi
done

# Update metadata to mark drift as accepted
METADATA=$(cat "$DEPLOYMENT_PATH/metadata.json")
METADATA=$(echo "$METADATA" | jq \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg user "$(az account show --query user.name -o tsv 2>/dev/null || echo 'unknown')" \
    --arg reason "$REASON" \
    '.driftAccepted = {
        "timestamp": $timestamp,
        "user": $user,
        "reason": $reason,
        "driftsAccepted": '"$TOTAL_DRIFTS"'
    }')
echo "$METADATA" > "$DEPLOYMENT_PATH/metadata.json"

# Log acceptance to drift log
cat >> "$DRIFT_DIR/drift-log.jsonl" <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","action":"accept","user":"$(az account show --query user.name -o tsv 2>/dev/null || echo 'unknown')","reason":"$REASON","driftsAccepted":$TOTAL_DRIFTS}
EOF

echo ""
echo -e "${GREEN}✓ Drift accepted and IaC updated${NC}"
echo ""
echo "Summary:"
echo "  - Updated requirements.json with current Azure state"
echo "  - Backed up original state to: $BACKUP_DIR"
echo "  - Logged acceptance to drift-log.jsonl"

# Git commit if requested
if [[ "$AUTO_COMMIT" == "true" ]]; then
    if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
        echo ""
        echo -e "${BLUE}Creating git commit...${NC}"
        
        git add "$DEPLOYMENT_PATH/requirements.json" "$DEPLOYMENT_PATH/metadata.json"
        git commit -m "Accept drift for $DEPLOYMENT_ID

Reason: $REASON
Drifts accepted: $TOTAL_DRIFTS
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)

Changes:
$(echo "$DRIFT_DETAILS" | jq -r '.drifts[].drifts[] | "- " + .property + ": " + .expected + " → " + .current')"

        echo -e "${GREEN}✓ Git commit created${NC}"
    else
        echo -e "${YELLOW}⚠ Not in a git repository or git not available${NC}"
    fi
fi

echo ""
echo "Next steps:"
echo "  1. Review updated requirements.json"
echo "  2. Future deployments will use the new baseline"
echo "  3. Consider regenerating ARM template if needed"
