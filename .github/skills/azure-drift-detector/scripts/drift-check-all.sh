#!/bin/bash
# Check all deployments for configuration drift

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OUTPUT_FORMAT="summary"
VERBOSE=false
INCLUDE_KNOWN=false
ONLY_CRITICAL=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEPLOYMENTS_DIR="$WORKSPACE_ROOT/.azure/deployments"

usage() {
    cat <<EOF
Drift Check All - Scan all deployments for configuration drift

Usage: $0 [OPTIONS]

Options:
  --format <fmt>           Output format: summary|detailed|json (default: summary)
  --only-critical          Only report critical drift
  --include-known-drift    Include previously accepted drift
  --verbose                Show detailed progress
  -h, --help              Show this help message

Output Formats:
  summary   - One line per deployment with drift count
  detailed  - Full drift report for each deployment
  json      - Machine-readable JSON output

Example:
  $0
  $0 --format detailed --only-critical
  $0 --format json > drift-report.json

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --format) OUTPUT_FORMAT="$2"; shift 2 ;;
        --only-critical) ONLY_CRITICAL=true; shift ;;
        --include-known-drift) INCLUDE_KNOWN=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ ! -d "$DEPLOYMENTS_DIR" ]]; then
    echo -e "${YELLOW}No deployments found at: $DEPLOYMENTS_DIR${NC}"
    exit 0
fi

# Find all deployment directories
DEPLOYMENTS=$(find "$DEPLOYMENTS_DIR" -maxdepth 1 -type d -name 'deploy-*' | sort)
DEPLOYMENT_COUNT=$(echo "$DEPLOYMENTS" | wc -l | tr -d ' ')

if [[ -z "$DEPLOYMENTS" || "$DEPLOYMENT_COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}No deployments found${NC}"
    exit 0
fi

echo -e "${BLUE}Scanning $DEPLOYMENT_COUNT deployments for drift...${NC}"
echo ""

# Results tracking
TOTAL_CHECKED=0
TOTAL_WITH_DRIFT=0
TOTAL_CRITICAL=0
TOTAL_WARNINGS=0
DRIFT_DETAILS=()

# JSON output array
JSON_OUTPUT="[]"

for DEPLOYMENT_PATH in $DEPLOYMENTS; do
    DEPLOYMENT_ID=$(basename "$DEPLOYMENT_PATH")
    
    # Skip revert deployments
    if [[ "$DEPLOYMENT_ID" == *"-revert" ]]; then
        [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}Skipping revert deployment: $DEPLOYMENT_ID${NC}"
        continue
    fi
    
    # Check if metadata exists
    if [[ ! -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
        [[ "$VERBOSE" == "true" ]] && echo -e "${YELLOW}Skipping $DEPLOYMENT_ID (no metadata)${NC}"
        continue
    fi
    
    # Check deployment status
    STATUS=$(jq -r '.status' "$DEPLOYMENT_PATH/metadata.json")
    if [[ "$STATUS" != "success" && "$STATUS" != "succeeded" ]]; then
        [[ "$VERBOSE" == "true" ]] && echo -e "${YELLOW}Skipping $DEPLOYMENT_ID (status: $STATUS)${NC}"
        continue
    fi
    
    TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
    
    [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}Checking: $DEPLOYMENT_ID${NC}"
    
    # Run drift detection
    DRIFT_ARGS="--deployment-id $DEPLOYMENT_ID --output-format json"
    [[ "$INCLUDE_KNOWN" == "true" ]] && DRIFT_ARGS="$DRIFT_ARGS --include-known-drift"
    
    DRIFT_OUTPUT=$("$SCRIPT_DIR/detect-drift.sh" $DRIFT_ARGS 2>&1 || true)
    DRIFT_EXIT_CODE=$?
    
    # Parse drift results
    DRIFT_FILE="$DEPLOYMENT_PATH/drift-analysis/drift-details.json"
    
    if [[ -f "$DRIFT_FILE" ]]; then
        CRITICAL=$(jq -r '.summary.criticalDrift' "$DRIFT_FILE")
        WARNING=$(jq -r '.summary.warningDrift' "$DRIFT_FILE")
        TOTAL_DRIFTS=$(jq -r '.summary.totalDrifts' "$DRIFT_FILE")
        
        if [[ "$TOTAL_DRIFTS" -gt 0 ]]; then
            TOTAL_WITH_DRIFT=$((TOTAL_WITH_DRIFT + 1))
            TOTAL_CRITICAL=$((TOTAL_CRITICAL + CRITICAL))
            TOTAL_WARNINGS=$((TOTAL_WARNINGS + WARNING))
            
            # Store details
            DRIFT_DETAILS+=("$DEPLOYMENT_ID|$CRITICAL|$WARNING|$TOTAL_DRIFTS")
            
            # Build JSON output
            DEPLOYMENT_JSON=$(jq -n \
                --arg id "$DEPLOYMENT_ID" \
                --argjson critical "$CRITICAL" \
                --argjson warning "$WARNING" \
                --argjson total "$TOTAL_DRIFTS" \
                --arg path "$DEPLOYMENT_PATH" \
                '{deploymentId: $id, criticalDrift: $critical, warningDrift: $warning, totalDrift: $total, path: $path}')
            
            JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq ". += [$DEPLOYMENT_JSON]")
            
            # Summary output
            if [[ "$OUTPUT_FORMAT" == "summary" ]]; then
                if [[ "$CRITICAL" -gt 0 ]]; then
                    echo -e "${RED}🔴 $DEPLOYMENT_ID - Critical: $CRITICAL, Warning: $WARNING${NC}"
                elif [[ "$ONLY_CRITICAL" != "true" ]]; then
                    echo -e "${YELLOW}🟡 $DEPLOYMENT_ID - Warning: $WARNING${NC}"
                fi
            fi
        else
            [[ "$VERBOSE" == "true" ]] && echo -e "${GREEN}✓ $DEPLOYMENT_ID - No drift${NC}"
        fi
    else
        [[ "$VERBOSE" == "true" ]] && echo -e "${YELLOW}⚠ $DEPLOYMENT_ID - Could not detect drift${NC}"
    fi
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}Drift Scan Results${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""
echo "Deployments checked: $TOTAL_CHECKED"
echo "Deployments with drift: $TOTAL_WITH_DRIFT"

if [[ "$TOTAL_WITH_DRIFT" -gt 0 ]]; then
    echo -e "${RED}Critical drifts: $TOTAL_CRITICAL${NC}"
    echo -e "${YELLOW}Warning drifts: $TOTAL_WARNINGS${NC}"
    echo ""
    
    if [[ "$OUTPUT_FORMAT" == "detailed" ]]; then
        echo -e "${BLUE}Detailed Drift Reports:${NC}"
        echo ""
        
        for DETAIL in "${DRIFT_DETAILS[@]}"; do
            IFS='|' read -r DEP_ID CRIT WARN TOTAL <<< "$DETAIL"
            
            echo -e "${BLUE}Deployment: $DEP_ID${NC}"
            echo "  Critical: $CRIT, Warning: $WARN, Total: $TOTAL"
            
            DRIFT_REPORT="$DEPLOYMENTS_DIR/$DEP_ID/drift-analysis/drift-report.md"
            if [[ -f "$DRIFT_REPORT" ]]; then
                echo ""
                cat "$DRIFT_REPORT"
                echo ""
            fi
            echo "---"
            echo ""
        done
    fi
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        SUMMARY_JSON=$(jq -n \
            --argjson checked "$TOTAL_CHECKED" \
            --argjson withDrift "$TOTAL_WITH_DRIFT" \
            --argjson critical "$TOTAL_CRITICAL" \
            --argjson warning "$TOTAL_WARNINGS" \
            --argjson deployments "$JSON_OUTPUT" \
            '{
                summary: {
                    deploymentsChecked: $checked,
                    deploymentsWithDrift: $withDrift,
                    totalCriticalDrift: $critical,
                    totalWarningDrift: $warning
                },
                deployments: $deployments
            }')
        
        echo "$SUMMARY_JSON"
    fi
    
    EXIT_CODE=0
    [[ "$TOTAL_CRITICAL" -gt 0 ]] && EXIT_CODE=2
    [[ "$TOTAL_WARNINGS" -gt 0 ]] && EXIT_CODE=1
    
    exit $EXIT_CODE
else
    echo -e "${GREEN}✓ All deployments are in sync with Azure${NC}"
    exit 0
fi
