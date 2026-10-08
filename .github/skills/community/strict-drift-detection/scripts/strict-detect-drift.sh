#!/bin/bash
# Strict Drift Detection Script
#
# Performs a deep, baseline-based recursive diff of the FULL resolved
# Azure resource state (every nested property, array-aware), rather than
# a curated list of per-resource-type properties.
#
# On first run per resource, captures a baseline snapshot (the actual
# `az resource show` output) under drift-analysis/strict-baseline/. All
# subsequent runs diff the live resource against that baseline.

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

OUTPUT_FORMAT="markdown"
DEPLOYMENT_ID=""
REFRESH_BASELINE=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

IGNORE_FILE="$SCRIPT_DIR/ignore-properties.json"
RULES_FILE="$SCRIPT_DIR/drift-rules.json"
ARRAY_KEYS_FILE="$SCRIPT_DIR/array-keys.json"
DEEP_DIFF_JQ="$SCRIPT_DIR/deep-diff.jq"

usage() {
    cat <<EOF
Strict Drift Detection Script

Usage: $0 --deployment-id <id> [OPTIONS]

Required:
  --deployment-id <id>     Deployment ID to check for drift

Options:
  --output-format <fmt>    Output format: markdown, json, github (default: markdown)
  --refresh-baseline       Recapture baseline from current Azure state (resets drift history)
  --ignore-file <path>     Override ignore-properties.json
  --rules-file <path>      Override drift-rules.json
  -h, --help               Show this help message

Examples:
  $0 --deployment-id deploy-20260218-143022
  $0 --deployment-id deploy-20260218-143022 --refresh-baseline
  $0 --deployment-id deploy-20260218-143022 --output-format json

EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
        --output-format) OUTPUT_FORMAT="$2"; shift 2 ;;
        --refresh-baseline) REFRESH_BASELINE=true; shift ;;
        --ignore-file) IGNORE_FILE="$2"; shift 2 ;;
        --rules-file) RULES_FILE="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$DEPLOYMENT_ID" ]]; then
    echo "Error: --deployment-id is required"
    usage
fi

DEPLOYMENT_PATH="$WORKSPACE_ROOT/.azure/deployments/$DEPLOYMENT_ID"

if [[ ! -d "$DEPLOYMENT_PATH" ]]; then
    echo -e "${RED}Error: Deployment not found: $DEPLOYMENT_ID${NC}"
    exit 1
fi

if [[ ! -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
    echo -e "${RED}Error: metadata.json not found. Run the git-ape azure-drift-detector baseline first.${NC}"
    exit 1
fi

DRIFT_DIR="$DEPLOYMENT_PATH/drift-analysis"
BASELINE_DIR="$DRIFT_DIR/strict-baseline"
mkdir -p "$BASELINE_DIR"

IGNORE_PATTERNS=$(cat "$IGNORE_FILE")
RULES=$(cat "$RULES_FILE")
ARRAY_KEYS=$(cat "$ARRAY_KEYS_FILE")

CHECK_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo -e "${BLUE}Starting STRICT drift detection for: $DEPLOYMENT_ID${NC}"
echo "Timestamp: $CHECK_TIMESTAMP"
echo "Mode: full recursive property diff (baseline-based)"
echo ""

METADATA=$(cat "$DEPLOYMENT_PATH/metadata.json")

# Supports both git-ape's legacy `.resources[]` and extended
# `.managedResources[]` schema.
RESOURCE_IDS=$(echo "$METADATA" | jq -r '
  (.managedResources // .resources // [])[] | (.id // .resourceId // .)
')

if [[ -z "$RESOURCE_IDS" ]]; then
    echo -e "${RED}Error: No resources found in metadata.json${NC}"
    exit 1
fi

CRITICAL_DRIFT=0
WARNING_DRIFT=0
INFO_DRIFT=0
NO_DRIFT=0
BASELINED=0
RESOURCE_COUNT=0

DRIFT_REPORT="[]"

classify_severity() {
    local path="$1"
    # NOTE: `.pattern` must be captured as $pat before piping $p into test(),
    # otherwise test()'s argument is evaluated against $p (a string), not the
    # rule object, raising "Cannot index string with string".
    echo "$RULES" | jq -r --arg p "$path" '
      ( [ .[] | select(.pattern as $pat | $p | test($pat)) ] | first ) as $m
      | ($m.severity // "info") + "\u0001" + ($m.impact // "Property differs from recorded baseline")
    '
}

for RESOURCE_ID in $RESOURCE_IDS; do
    RESOURCE_COUNT=$((RESOURCE_COUNT + 1))
    RESOURCE_NAME=$(basename "$RESOURCE_ID")
    RESOURCE_TYPE=$(echo "$RESOURCE_ID" | grep -oE '/providers/[^/]+/[^/]+' | cut -d/ -f3,4 || echo "unknown")

    echo -e "${BLUE}Checking: $RESOURCE_NAME ($RESOURCE_TYPE)${NC}"

    CURRENT_STATE=$(az resource show --ids "$RESOURCE_ID" --output json 2>/dev/null || echo "{}")

    if [[ "$CURRENT_STATE" == "{}" ]]; then
        echo -e "${RED}  resource not found in Azure (deleted?)${NC}"
        CRITICAL_DRIFT=$((CRITICAL_DRIFT + 1))
        DRIFT_REPORT=$(echo "$DRIFT_REPORT" | jq \
            --arg name "$RESOURCE_NAME" --arg type "$RESOURCE_TYPE" \
            '. += [{"resource": $name, "type": $type, "drifts": [{"path": "(resource)", "status": "removed", "severity": "critical", "impact": "Resource exists in baseline but not found in Azure"}]}]')
        continue
    fi

    BASELINE_FILE="$BASELINE_DIR/${RESOURCE_NAME}.json"

    if [[ "$REFRESH_BASELINE" == "true" ]] || [[ ! -f "$BASELINE_FILE" ]]; then
        echo "$CURRENT_STATE" > "$BASELINE_FILE"
        BASELINED=$((BASELINED + 1))
        echo -e "${GREEN}  baseline captured (first run or refresh) - nothing to diff yet${NC}"
        echo ""
        continue
    fi

    BASELINE_STATE=$(cat "$BASELINE_FILE")

    # Diff full resolved resource bodies (properties + tags + sku + identity),
    # not just a curated subset.
    DIFFS=$(jq -n \
        --argjson base "$BASELINE_STATE" \
        --argjson curr "$CURRENT_STATE" \
        --argjson array_keys "$ARRAY_KEYS" \
        --argjson ignore "$IGNORE_PATTERNS" \
        -f "$DEEP_DIFF_JQ")

    DIFF_COUNT=$(echo "$DIFFS" | jq 'length')

    if [[ "$DIFF_COUNT" -eq 0 ]]; then
        echo -e "${GREEN}  no drift detected ($DIFF_COUNT properties diffed)${NC}"
        NO_DRIFT=$((NO_DRIFT + 1))
        echo ""
        continue
    fi

    RESOURCE_DRIFT="[]"
    for row in $(echo "$DIFFS" | jq -c '.[]'); do
        PATH_VAL=$(echo "$row" | jq -r '.path')
        STATUS_VAL=$(echo "$row" | jq -r '.status')
        BASE_VAL=$(echo "$row" | jq -c '.baseline')
        CURR_VAL=$(echo "$row" | jq -c '.current')

        IFS=$'\001' read -r SEVERITY IMPACT <<< "$(classify_severity "$PATH_VAL")"

        case "$SEVERITY" in
            critical) CRITICAL_DRIFT=$((CRITICAL_DRIFT + 1)) ;;
            warning)  WARNING_DRIFT=$((WARNING_DRIFT + 1)) ;;
            *)        INFO_DRIFT=$((INFO_DRIFT + 1)) ;;
        esac

        RESOURCE_DRIFT=$(echo "$RESOURCE_DRIFT" | jq \
            --arg path "$PATH_VAL" --arg status "$STATUS_VAL" \
            --arg severity "$SEVERITY" --arg impact "$IMPACT" \
            --argjson baseline "$BASE_VAL" --argjson current "$CURR_VAL" \
            '. += [{"path": $path, "status": $status, "severity": $severity, "impact": $impact, "baseline": $baseline, "current": $current}]')
    done

    DRIFT_REPORT=$(echo "$DRIFT_REPORT" | jq \
        --arg name "$RESOURCE_NAME" --arg type "$RESOURCE_TYPE" \
        --argjson drifts "$RESOURCE_DRIFT" \
        '. += [{"resource": $name, "type": $type, "drifts": $drifts}]')

    echo -e "${YELLOW}  drift detected ($DIFF_COUNT properties)${NC}"
    echo ""
done

DRIFT_SUMMARY=$(jq -n \
    --arg timestamp "$CHECK_TIMESTAMP" --arg deployment "$DEPLOYMENT_ID" \
    --argjson critical "$CRITICAL_DRIFT" --argjson warning "$WARNING_DRIFT" \
    --argjson info "$INFO_DRIFT" --argjson no_drift "$NO_DRIFT" --argjson baselined "$BASELINED" \
    --argjson resourceCount "$RESOURCE_COUNT" --argjson drifts "$DRIFT_REPORT" \
    '{
        timestamp: $timestamp,
        deploymentId: $deployment,
        mode: "strict-recursive",
        summary: {
            resourcesAnalyzed: $resourceCount,
            criticalDrift: $critical,
            warningDrift: $warning,
            infoDrift: $info,
            noDrift: $no_drift,
            baselinesCaptured: $baselined
        },
        drifts: $drifts
    }')

echo "$DRIFT_SUMMARY" > "$DRIFT_DIR/strict-drift-details.json"

case "$OUTPUT_FORMAT" in
    json)
        echo "$DRIFT_SUMMARY" | jq '.'
        ;;
    markdown)
        {
            echo "# Strict Drift Detection Report"
            echo ""
            echo "**Deployment:** $DEPLOYMENT_ID"
            echo "**Checked:** $CHECK_TIMESTAMP"
            echo "**Mode:** full recursive property diff (baseline-based, array-aware)"
            echo "**Resources Analyzed:** $RESOURCE_COUNT"
            echo ""
            echo "## Summary"
            echo "- Critical Drift: $CRITICAL_DRIFT propert$([ "$CRITICAL_DRIFT" = 1 ] && echo y || echo ies)"
            echo "- Warning Drift: $WARNING_DRIFT propert$([ "$WARNING_DRIFT" = 1 ] && echo y || echo ies)"
            echo "- Info Drift: $INFO_DRIFT propert$([ "$INFO_DRIFT" = 1 ] && echo y || echo ies)"
            echo "- No Drift: $NO_DRIFT resource(s)"
            echo "- Baselines Captured This Run: $BASELINED resource(s)"
            echo ""
            echo "$DRIFT_REPORT" | jq -r '.[] |
                "---\n\n### " + .resource + " (" + .type + ")\n" +
                (.drifts[] |
                    "\n**" + (.severity | ascii_upcase) + "** `" + .path + "` (" + .status + ")\n" +
                    "- Baseline: `" + (.baseline | tostring) + "`\n" +
                    "- Current: `" + (.current | tostring) + "`\n" +
                    "- Impact: " + .impact + "\n"
                )'
        } > "$DRIFT_DIR/strict-drift-report.md"
        cat "$DRIFT_DIR/strict-drift-report.md"
        ;;
    github)
        if [[ $CRITICAL_DRIFT -gt 0 ]]; then
            echo "::error::Critical strict drift detected in $DEPLOYMENT_ID: $CRITICAL_DRIFT propert(y/ies)"
            exit 1
        elif [[ $WARNING_DRIFT -gt 0 ]]; then
            echo "::warning::Warning strict drift detected in $DEPLOYMENT_ID: $WARNING_DRIFT propert(y/ies)"
        else
            echo "::notice::No strict drift detected in $DEPLOYMENT_ID"
        fi
        ;;
esac

if [[ $CRITICAL_DRIFT -gt 0 ]]; then
    exit 2
elif [[ $WARNING_DRIFT -gt 0 ]]; then
    exit 1
else
    exit 0
fi
