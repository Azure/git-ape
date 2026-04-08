#!/bin/bash
# Azure Drift Detection Script
# Compares deployed Azure resources with stored deployment state

set -euo pipefail

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FORMAT="markdown"
DEPLOYMENT_ID=""
VERBOSE=false
IGNORE_KNOWN_DRIFT=true

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

usage() {
    cat <<EOF
Azure Drift Detection Script

Usage: $0 --deployment-id <id> [OPTIONS]

Required:
  --deployment-id <id>     Deployment ID to check for drift

Options:
  --output-format <fmt>    Output format: markdown, json, github (default: markdown)
  --include-known-drift    Include known drift in report (default: exclude)
  --verbose                Show detailed comparison
  -h, --help              Show this help message

Examples:
  $0 --deployment-id deploy-20260218-143022
  $0 --deployment-id deploy-20260218-143022 --output-format json
  $0 --deployment-id deploy-20260218-143022 --verbose

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --deployment-id)
            DEPLOYMENT_ID="$2"
            shift 2
            ;;
        --output-format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --include-known-drift)
            IGNORE_KNOWN_DRIFT=false
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

# Validate required parameters
if [[ -z "$DEPLOYMENT_ID" ]]; then
    echo "Error: --deployment-id is required"
    usage
fi

DEPLOYMENT_PATH="$WORKSPACE_ROOT/.azure/deployments/$DEPLOYMENT_ID"

# Check if deployment exists
if [[ ! -d "$DEPLOYMENT_PATH" ]]; then
    echo -e "${RED}Error: Deployment not found: $DEPLOYMENT_ID${NC}"
    exit 1
fi

# Create drift analysis directory
DRIFT_DIR="$DEPLOYMENT_PATH/drift-analysis"
mkdir -p "$DRIFT_DIR"

# Timestamp for this drift check
CHECK_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo -e "${BLUE}Starting drift detection for: $DEPLOYMENT_ID${NC}"
echo "Timestamp: $CHECK_TIMESTAMP"
echo ""

# Load deployment metadata
if [[ ! -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
    echo -e "${RED}Error: metadata.json not found${NC}"
    exit 1
fi

METADATA=$(cat "$DEPLOYMENT_PATH/metadata.json")
RESOURCE_COUNT=$(echo "$METADATA" | jq -r '.resources | length')

echo "Resources to check: $RESOURCE_COUNT"
echo ""

# Load known drift if exists and ignoring is enabled
KNOWN_DRIFT_FILE="$DRIFT_DIR/known-drift.json"
if [[ "$IGNORE_KNOWN_DRIFT" == "true" ]] && [[ -f "$KNOWN_DRIFT_FILE" ]]; then
    KNOWN_DRIFT=$(cat "$KNOWN_DRIFT_FILE")
    echo -e "${YELLOW}Note: Ignoring known drift entries${NC}"
    echo ""
else
    KNOWN_DRIFT="{}"
fi

# Initialize drift counters
CRITICAL_DRIFT=0
WARNING_DRIFT=0
NO_DRIFT=0
TOTAL_DRIFTS=0

# Drift details array
DRIFT_REPORT="[]"

# Check each resource
echo "Querying Azure resources..."

RESOURCE_IDS=$(echo "$METADATA" | jq -r '.resources[].id')

for RESOURCE_ID in $RESOURCE_IDS; do
    RESOURCE_NAME=$(basename "$RESOURCE_ID")
    RESOURCE_TYPE=$(echo "$RESOURCE_ID" | grep -oE '/providers/[^/]+/[^/]+' | cut -d/ -f3,4)
    
    echo -e "${BLUE}Checking: $RESOURCE_NAME ($RESOURCE_TYPE)${NC}"
    
    # Fetch current Azure state
    CURRENT_STATE=$(az resource show --ids "$RESOURCE_ID" --output json 2>/dev/null || echo "{}")
    
    if [[ "$CURRENT_STATE" == "{}" ]]; then
        echo -e "${RED}  ✗ Resource not found in Azure (deleted?)${NC}"
        CRITICAL_DRIFT=$((CRITICAL_DRIFT + 1))
        
        DRIFT_REPORT=$(echo "$DRIFT_REPORT" | jq \
            --arg name "$RESOURCE_NAME" \
            --arg type "$RESOURCE_TYPE" \
            '. += [{
                "resource": $name,
                "type": $type,
                "severity": "critical",
                "issue": "resource_deleted",
                "message": "Resource exists in deployment state but not found in Azure"
            }]')
        continue
    fi
    
    # Save current state
    echo "$CURRENT_STATE" > "$DRIFT_DIR/current-${RESOURCE_NAME}.json"
    
    # Load expected state from requirements
    if [[ -f "$DEPLOYMENT_PATH/requirements.json" ]]; then
        EXPECTED_STATE=$(jq \
            --arg id "$RESOURCE_ID" \
            '.resources[] | select(.id == $id // .name == $id)' \
            "$DEPLOYMENT_PATH/requirements.json" 2>/dev/null || echo "{}")
    else
        EXPECTED_STATE="{}"
    fi
    
    # Compare key properties based on resource type
    RESOURCE_DRIFT="[]"
    
    case "$RESOURCE_TYPE" in
        "Microsoft.Web/sites")
            # Function App / App Service
            
            # Check httpsOnly
            EXPECTED_HTTPS=$(echo "$EXPECTED_STATE" | jq -r '.configuration.httpsOnly // true')
            CURRENT_HTTPS=$(echo "$CURRENT_STATE" | jq -r '.properties.httpsOnly')
            
            if [[ "$EXPECTED_HTTPS" != "$CURRENT_HTTPS" ]]; then
                RESOURCE_DRIFT=$(echo "$RESOURCE_DRIFT" | jq \
                    --arg prop "httpsOnly" \
                    --arg expected "$EXPECTED_HTTPS" \
                    --arg current "$CURRENT_HTTPS" \
                    '. += [{
                        "property": $prop,
                        "expected": $expected,
                        "current": $current,
                        "severity": "critical",
                        "impact": "Security vulnerability - HTTP traffic may be allowed"
                    }]')
                CRITICAL_DRIFT=$((CRITICAL_DRIFT + 1))
                TOTAL_DRIFTS=$((TOTAL_DRIFTS + 1))
            fi
            
            # Check runtime (if Function App)
            KIND=$(echo "$CURRENT_STATE" | jq -r '.kind')
            if [[ "$KIND" == *"functionapp"* ]]; then
                EXPECTED_RUNTIME=$(echo "$EXPECTED_STATE" | jq -r '.runtime // empty')
                CURRENT_RUNTIME=$(echo "$CURRENT_STATE" | jq -r '.properties.siteConfig.appSettings[] | select(.name == "FUNCTIONS_WORKER_RUNTIME") | .value' 2>/dev/null || echo "")
                
                if [[ -n "$EXPECTED_RUNTIME" ]] && [[ "$EXPECTED_RUNTIME" != "$CURRENT_RUNTIME" ]]; then
                    RESOURCE_DRIFT=$(echo "$RESOURCE_DRIFT" | jq \
                        --arg prop "runtime" \
                        --arg expected "$EXPECTED_RUNTIME" \
                        --arg current "$CURRENT_RUNTIME" \
                        '. += [{
                            "property": $prop,
                            "expected": $expected,
                            "current": $current,
                            "severity": "critical",
                            "impact": "Runtime mismatch - application may fail"
                        }]')
                    CRITICAL_DRIFT=$((CRITICAL_DRIFT + 1))
                    TOTAL_DRIFTS=$((TOTAL_DRIFTS + 1))
                fi
            fi
            ;;
            
        "Microsoft.Storage/storageAccounts")
            # Storage Account
            
            # Check minimum TLS version
            EXPECTED_TLS=$(echo "$EXPECTED_STATE" | jq -r '.configuration.minimumTlsVersion // "TLS1_2"')
            CURRENT_TLS=$(echo "$CURRENT_STATE" | jq -r '.properties.minimumTlsVersion')
            
            if [[ "$EXPECTED_TLS" != "$CURRENT_TLS" ]]; then
                SEVERITY="warning"
                if [[ "$CURRENT_TLS" < "TLS1_2" ]]; then
                    SEVERITY="critical"
                    CRITICAL_DRIFT=$((CRITICAL_DRIFT + 1))
                else
                    WARNING_DRIFT=$((WARNING_DRIFT + 1))
                fi
                
                RESOURCE_DRIFT=$(echo "$RESOURCE_DRIFT" | jq \
                    --arg prop "minimumTlsVersion" \
                    --arg expected "$EXPECTED_TLS" \
                    --arg current "$CURRENT_TLS" \
                    --arg severity "$SEVERITY" \
                    '. += [{
                        "property": $prop,
                        "expected": $expected,
                        "current": $current,
                        "severity": $severity,
                        "impact": "TLS version changed - security concern"
                    }]')
                TOTAL_DRIFTS=$((TOTAL_DRIFTS + 1))
            fi
            
            # Check secure transfer
            EXPECTED_HTTPS=$(echo "$EXPECTED_STATE" | jq -r '.configuration.supportsHttpsTrafficOnly // true')
            CURRENT_HTTPS=$(echo "$CURRENT_STATE" | jq -r '.properties.supportsHttpsTrafficOnly')
            
            if [[ "$EXPECTED_HTTPS" != "$CURRENT_HTTPS" ]]; then
                RESOURCE_DRIFT=$(echo "$RESOURCE_DRIFT" | jq \
                    --arg prop "supportsHttpsTrafficOnly" \
                    --arg expected "$EXPECTED_HTTPS" \
                    --arg current "$CURRENT_HTTPS" \
                    '. += [{
                        "property": $prop,
                        "expected": $expected,
                        "current": $current,
                        "severity": "critical",
                        "impact": "Secure transfer requirement changed"
                    }]')
                CRITICAL_DRIFT=$((CRITICAL_DRIFT + 1))
                TOTAL_DRIFTS=$((TOTAL_DRIFTS + 1))
            fi
            ;;
    esac
    
    # Check tags (common to all resources)
    EXPECTED_TAGS=$(echo "$EXPECTED_STATE" | jq -r '.tags // {}')
    CURRENT_TAGS=$(echo "$CURRENT_STATE" | jq -r '.tags // {}')
    
    # Compare tags
    TAG_DIFF=$(jq -n \
        --argjson expected "$EXPECTED_TAGS" \
        --argjson current "$CURRENT_TAGS" \
        '$expected | to_entries | map(select(.key as $k | $current[$k] != .value)) | from_entries')
    
    if [[ "$TAG_DIFF" != "{}" ]]; then
        TAG_KEYS=$(echo "$TAG_DIFF" | jq -r 'keys[]')
        for TAG_KEY in $TAG_KEYS; do
            EXPECTED_VAL=$(echo "$EXPECTED_TAGS" | jq -r --arg k "$TAG_KEY" '.[$k] // "null"')
            CURRENT_VAL=$(echo "$CURRENT_TAGS" | jq -r --arg k "$TAG_KEY" '.[$k] // "null"')
            
            RESOURCE_DRIFT=$(echo "$RESOURCE_DRIFT" | jq \
                --arg prop "tags.$TAG_KEY" \
                --arg expected "$EXPECTED_VAL" \
                --arg current "$CURRENT_VAL" \
                '. += [{
                    "property": $prop,
                    "expected": $expected,
                    "current": $current,
                    "severity": "warning",
                    "impact": "Tag mismatch - reporting/billing may be affected"
                }]')
            WARNING_DRIFT=$((WARNING_DRIFT + 1))
            TOTAL_DRIFTS=$((TOTAL_DRIFTS + 1))
        done
    fi
    
    # Add resource drift to report
    if [[ $(echo "$RESOURCE_DRIFT" | jq 'length') -gt 0 ]]; then
        DRIFT_REPORT=$(echo "$DRIFT_REPORT" | jq \
            --arg name "$RESOURCE_NAME" \
            --arg type "$RESOURCE_TYPE" \
            --argjson drifts "$RESOURCE_DRIFT" \
            '. += [{
                "resource": $name,
                "type": $type,
                "drifts": $drifts
            }]')
        
        echo -e "${YELLOW}  ⚠ Drift detected ($(echo "$RESOURCE_DRIFT" | jq 'length') properties)${NC}"
    else
        echo -e "${GREEN}  ✓ No drift detected${NC}"
        NO_DRIFT=$((NO_DRIFT + 1))
    fi
    
    echo ""
done

# Save drift report
DRIFT_SUMMARY=$(jq -n \
    --arg timestamp "$CHECK_TIMESTAMP" \
    --arg deployment "$DEPLOYMENT_ID" \
    --argjson critical "$CRITICAL_DRIFT" \
    --argjson warning "$WARNING_DRIFT" \
    --argjson no_drift "$NO_DRIFT" \
    --argjson total "$TOTAL_DRIFTS" \
    --argjson drifts "$DRIFT_REPORT" \
    '{
        "timestamp": $timestamp,
        "deploymentId": $deployment,
        "summary": {
            "criticalDrift": $critical,
            "warningDrift": $warning,
            "noDrift": $no_drift,
            "totalDrifts": $total
        },
        "drifts": $drifts
    }')

echo "$DRIFT_SUMMARY" > "$DRIFT_DIR/drift-details.json"

# Generate output based on format
case "$OUTPUT_FORMAT" in
    "json")
        echo "$DRIFT_SUMMARY" | jq '.'
        ;;
        
    "markdown")
        cat > "$DRIFT_DIR/drift-report.md" <<EOF
# Drift Detection Report

**Deployment:** $DEPLOYMENT_ID
**Checked:** $CHECK_TIMESTAMP
**Resources Analyzed:** $RESOURCE_COUNT

## Summary
- 🔴 Critical Drift: $CRITICAL_DRIFT $([ $CRITICAL_DRIFT -gt 0 ] && echo "resource(s)" || echo "")
- 🟡 Warning Drift: $WARNING_DRIFT $([ $WARNING_DRIFT -gt 0 ] && echo "resource(s)" || echo "")
- ✅ No Drift: $NO_DRIFT resource(s)

EOF
        
        # Add detailed drift information
        echo "$DRIFT_REPORT" | jq -r '.[] | 
            "---\n\n### " + 
            (if (.drifts | map(select(.severity == "critical")) | length) > 0 then "🔴 CRITICAL" 
             elif (.drifts | map(select(.severity == "warning")) | length) > 0 then "🟡 WARNING" 
             else "✅ NO DRIFT" end) + 
            ": " + .resource + "\n\n" + 
            (.drifts[] | 
                "**Property:** `" + .property + "`\n" +
                "- Expected: `" + .expected + "`\n" +
                "- Current: `" + .current + "`\n" +
                "- **Impact:** " + .impact + "\n"
            )' >> "$DRIFT_DIR/drift-report.md"
        
        cat "$DRIFT_DIR/drift-report.md"
        ;;
        
    "github")
        # GitHub Actions annotation format
        if [[ $CRITICAL_DRIFT -gt 0 ]]; then
            echo "::error::Critical drift detected in $DEPLOYMENT_ID: $CRITICAL_DRIFT resource(s)"
            exit 1
        elif [[ $WARNING_DRIFT -gt 0 ]]; then
            echo "::warning::Warning drift detected in $DEPLOYMENT_ID: $WARNING_DRIFT resource(s)"
        else
            echo "::notice::No drift detected in $DEPLOYMENT_ID"
        fi
        ;;
esac

# Exit code based on drift severity
if [[ $CRITICAL_DRIFT -gt 0 ]]; then
    exit 2
elif [[ $WARNING_DRIFT -gt 0 ]]; then
    exit 1
else
    exit 0
fi
