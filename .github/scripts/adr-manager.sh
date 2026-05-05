#!/bin/bash
# Architecture Decision Record (ADR) Manager
# Generates, updates, and indexes ADRs for Git-Ape deployments

set -euo pipefail

ADRS_DIR=".azure/adrs"
DEPLOYMENTS_DIR=".azure/deployments"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the next ADR number
get_next_adr_number() {
    local LAST_NUM=0
    if [[ -d "$WORKSPACE_ROOT/$ADRS_DIR" ]]; then
        LAST_NUM=$(ls "$WORKSPACE_ROOT/$ADRS_DIR" 2>/dev/null | grep -oP '^\d+' | sort -n | tail -1 || echo "0")
    fi
    echo $((LAST_NUM + 1))
}

# Format ADR number with zero-padding (4 digits)
format_adr_number() {
    printf "%04d" "$1"
}

# Command: generate
# Generate an ADR from a deployment
generate_adr() {
    local DEPLOYMENT_ID="$1"
    local DEPLOYMENT_PATH="$WORKSPACE_ROOT/$DEPLOYMENTS_DIR/$DEPLOYMENT_ID"

    if [[ ! -d "$DEPLOYMENT_PATH" ]]; then
        echo -e "${RED}Deployment not found: $DEPLOYMENT_ID${NC}"
        exit 1
    fi

    if [[ ! -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
        echo -e "${RED}metadata.json not found for deployment: $DEPLOYMENT_ID${NC}"
        exit 1
    fi

    # Read deployment metadata
    local STATUS
    STATUS=$(jq -r '.status // "unknown"' "$DEPLOYMENT_PATH/metadata.json")
    local PROJECT
    PROJECT=$(jq -r '.project // "unknown"' "$DEPLOYMENT_PATH/metadata.json")
    local ENVIRONMENT
    ENVIRONMENT=$(jq -r '.environment // "unknown"' "$DEPLOYMENT_PATH/metadata.json")
    local REGION
    REGION=$(jq -r '.region // "unknown"' "$DEPLOYMENT_PATH/metadata.json")
    local TIMESTAMP
    TIMESTAMP=$(jq -r '.timestamp // empty' "$DEPLOYMENT_PATH/metadata.json")
    TIMESTAMP="${TIMESTAMP:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
    local USER
    USER=$(jq -r '.user // .createdBy // "unknown"' "$DEPLOYMENT_PATH/metadata.json")
    local RESOURCE_GROUP
    RESOURCE_GROUP=$(jq -r '.resourceGroup // "unknown"' "$DEPLOYMENT_PATH/metadata.json")

    # Read resources
    local RESOURCES_LIST=""
    if jq -e '.resources' "$DEPLOYMENT_PATH/metadata.json" > /dev/null 2>&1; then
        RESOURCES_LIST=$(jq -r '.resources[] | "- \(.type) / \(.name)"' "$DEPLOYMENT_PATH/metadata.json" 2>/dev/null || echo "")
    fi

    # Read requirements context
    local CONTEXT_TEXT="Deployment of Azure resources for the $PROJECT project in $ENVIRONMENT environment."
    if [[ -f "$DEPLOYMENT_PATH/requirements.json" ]]; then
        local REQ_TYPE
        REQ_TYPE=$(jq -r '.type // "single-resource"' "$DEPLOYMENT_PATH/requirements.json")
        local REQ_RESOURCES
        REQ_RESOURCES=$(jq -r '.resources[]? | "- \(.type) (\(.name)) in \(.region)"' "$DEPLOYMENT_PATH/requirements.json" 2>/dev/null || echo "")
        if [[ -n "$REQ_RESOURCES" ]]; then
            CONTEXT_TEXT="$CONTEXT_TEXT

Requested resources:
$REQ_RESOURCES"
        fi
    fi

    # Read WAF review trade-offs if available
    local TRADEOFFS=""
    if [[ -f "$DEPLOYMENT_PATH/waf-review.md" ]]; then
        TRADEOFFS=$(sed -n '/## Trade-off/,/## /p' "$DEPLOYMENT_PATH/waf-review.md" | head -20 || echo "")
        if [[ -z "$TRADEOFFS" ]]; then
            TRADEOFFS="See [WAF Review](../deployments/$DEPLOYMENT_ID/waf-review.md) for full assessment."
        fi
    fi

    # Read architecture diagram reference
    local ARCHITECTURE_REF=""
    if [[ -f "$DEPLOYMENT_PATH/architecture.md" ]]; then
        ARCHITECTURE_REF="See [Architecture Diagram](../deployments/$DEPLOYMENT_ID/architecture.md) for the full resource topology."
    fi

    # Read cost estimate if available
    local COST_INFO=""
    if jq -e '.estimatedMonthlyCost' "$DEPLOYMENT_PATH/metadata.json" > /dev/null 2>&1; then
        COST_INFO=$(jq -r '.estimatedMonthlyCost' "$DEPLOYMENT_PATH/metadata.json")
    fi

    # Determine ADR number and title
    local ADR_NUM
    ADR_NUM=$(get_next_adr_number)
    local ADR_NUM_FMT
    ADR_NUM_FMT=$(format_adr_number "$ADR_NUM")
    local TITLE="Deploy ${PROJECT} ${ENVIRONMENT} infrastructure in ${REGION}"
    local ADR_FILENAME="${ADR_NUM_FMT}-deploy-${PROJECT}-${ENVIRONMENT}.md"

    # Create ADR directory
    mkdir -p "$WORKSPACE_ROOT/$ADRS_DIR"

    # Generate ADR content
    cat > "$WORKSPACE_ROOT/$ADRS_DIR/$ADR_FILENAME" <<EOF
# ADR-${ADR_NUM_FMT}: ${TITLE}

## Status

Accepted

## Date

${TIMESTAMP%%T*}

## Deployment

- **Deployment ID:** ${DEPLOYMENT_ID}
- **Project:** ${PROJECT}
- **Environment:** ${ENVIRONMENT}
- **Region:** ${REGION}
- **Resource Group:** ${RESOURCE_GROUP}
- **Initiated by:** ${USER}

## Context

${CONTEXT_TEXT}

## Decision

Deploy the following resources as a subscription-level ARM template deployment:

${RESOURCES_LIST:-_No resource details available._}

Configuration choices:
- **Region:** ${REGION} (selected for latency and compliance requirements)
- **Resource Group:** ${RESOURCE_GROUP} (included in ARM template for atomic deployment)
${COST_INFO:+- **Estimated Monthly Cost:** ${COST_INFO}}

## Consequences

### Positive

- Infrastructure is defined as code and version-controlled
- Deployment is repeatable and auditable via Git-Ape state management
- Security gate passed before deployment execution

### Negative

- Resources incur ongoing Azure costs${COST_INFO:+ (estimated ${COST_INFO}/month)}
- Changes require a new deployment cycle through Git-Ape

### Trade-offs

${TRADEOFFS:-_No trade-off analysis recorded for this deployment._}

## Architecture

${ARCHITECTURE_REF:-_No architecture diagram available._}

## Amendments

_No amendments yet._
EOF

    # Update deployment metadata to reference the ADR
    if [[ -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
        jq --arg adr "$ADRS_DIR/$ADR_FILENAME" --argjson num "$ADR_NUM" \
            '. + {"adrFile": $adr, "adrNumber": $num}' \
            "$DEPLOYMENT_PATH/metadata.json" > "$DEPLOYMENT_PATH/metadata.json.tmp" \
            && mv "$DEPLOYMENT_PATH/metadata.json.tmp" "$DEPLOYMENT_PATH/metadata.json"
    fi

    # Update the index
    update_index

    echo -e "${GREEN}Generated ADR: $ADRS_DIR/$ADR_FILENAME${NC}"
    echo "  Number: ADR-${ADR_NUM_FMT}"
    echo "  Title: ${TITLE}"
    echo "  Deployment: ${DEPLOYMENT_ID}"
}

# Command: amend
# Amend an existing ADR when a deployment is updated or destroyed
amend_adr() {
    local DEPLOYMENT_ID="$1"
    local REASON="${2:-Deployment updated}"
    local DEPLOYMENT_PATH="$WORKSPACE_ROOT/$DEPLOYMENTS_DIR/$DEPLOYMENT_ID"

    if [[ ! -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
        echo -e "${RED}metadata.json not found for deployment: $DEPLOYMENT_ID${NC}"
        exit 1
    fi

    # Find linked ADR
    local ADR_FILE
    ADR_FILE=$(jq -r '.adrFile // empty' "$DEPLOYMENT_PATH/metadata.json")

    if [[ -z "$ADR_FILE" || ! -f "$WORKSPACE_ROOT/$ADR_FILE" ]]; then
        echo -e "${YELLOW}No ADR linked to deployment $DEPLOYMENT_ID, generating new one${NC}"
        generate_adr "$DEPLOYMENT_ID"
        return
    fi

    local STATUS
    STATUS=$(jq -r '.status // "unknown"' "$DEPLOYMENT_PATH/metadata.json")
    local TIMESTAMP
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Append amendment to the ADR
    local AMENDMENT_TEXT="### Amendment — ${TIMESTAMP%%T*}

- **Reason:** ${REASON}
- **New Status:** ${STATUS}
- **Deployment:** ${DEPLOYMENT_ID}
- **Date:** ${TIMESTAMP}"

    # Replace or append to amendments section
    if grep -q "^_No amendments yet._$" "$WORKSPACE_ROOT/$ADR_FILE"; then
        # Remove the placeholder and append amendment
        sed -i '/^_No amendments yet._$/d' "$WORKSPACE_ROOT/$ADR_FILE"
        echo "" >> "$WORKSPACE_ROOT/$ADR_FILE"
        echo "$AMENDMENT_TEXT" >> "$WORKSPACE_ROOT/$ADR_FILE"
    else
        echo "" >> "$WORKSPACE_ROOT/$ADR_FILE"
        echo "$AMENDMENT_TEXT" >> "$WORKSPACE_ROOT/$ADR_FILE"
    fi

    # Update ADR status if deployment was destroyed
    if [[ "$STATUS" == "destroyed" || "$STATUS" == "destroy-requested" ]]; then
        sed -i 's/^Accepted$/Superseded/' "$WORKSPACE_ROOT/$ADR_FILE"
    fi

    # Update index
    update_index

    echo -e "${GREEN}Amended ADR: $ADR_FILE${NC}"
    echo "  Reason: ${REASON}"
    echo "  Status: ${STATUS}"
}

# Command: index
# Rebuild the ADR index
update_index() {
    local INDEX_FILE="$WORKSPACE_ROOT/$ADRS_DIR/INDEX.md"
    mkdir -p "$WORKSPACE_ROOT/$ADRS_DIR"

    cat > "$INDEX_FILE" <<'EOF'
# Architecture Decision Records

This index is auto-maintained by Git-Ape. Do not edit manually.

| # | Title | Status | Date | Deployment |
|---|-------|--------|------|------------|
EOF

    # Parse each ADR file and add to index
    for ADR_FILE in $(ls "$WORKSPACE_ROOT/$ADRS_DIR"/*.md 2>/dev/null | grep -v INDEX.md | sort); do
        local FILENAME
        FILENAME=$(basename "$ADR_FILE")
        local NUM
        NUM=$(echo "$FILENAME" | grep -oP '^\d+' || echo "?")
        local TITLE
        TITLE=$(head -1 "$ADR_FILE" | sed 's/^# //')
        local STATUS
        STATUS=$(sed -n '/^## Status$/,/^## /{/^## Status$/d;/^## /d;/^$/d;p;}' "$ADR_FILE" | head -1 | xargs)
        local DATE
        DATE=$(sed -n '/^## Date$/,/^## /{/^## Date$/d;/^## /d;/^$/d;p;}' "$ADR_FILE" | head -1 | xargs)
        local DEPLOY_ID
        DEPLOY_ID=$(sed -n 's/.*\*\*Deployment ID:\*\* //p' "$ADR_FILE" | head -1 | xargs)

        echo "| ${NUM} | [${TITLE}](./${FILENAME}) | ${STATUS} | ${DATE} | ${DEPLOY_ID:-—} |" >> "$INDEX_FILE"
    done

    echo -e "${GREEN}Updated ADR index: $ADRS_DIR/INDEX.md${NC}"
}

# Command: list
# List all ADRs
list_adrs() {
    echo -e "${BLUE}Architecture Decision Records${NC}"
    echo "-----------------------------------------------------------"

    if [[ ! -d "$WORKSPACE_ROOT/$ADRS_DIR" ]]; then
        echo -e "${YELLOW}No ADRs found${NC}"
        return 0
    fi

    for ADR_FILE in $(ls "$WORKSPACE_ROOT/$ADRS_DIR"/*.md 2>/dev/null | grep -v INDEX.md | sort); do
        local FILENAME
        FILENAME=$(basename "$ADR_FILE")
        local TITLE
        TITLE=$(head -1 "$ADR_FILE" | sed 's/^# //')
        local STATUS
        STATUS=$(sed -n '/^## Status$/,/^## /{/^## Status$/d;/^## /d;/^$/d;p;}' "$ADR_FILE" | head -1 | xargs)

        case "$STATUS" in
            "Accepted")
                echo -e "  ${GREEN}✓${NC} ${TITLE} [${STATUS}]"
                ;;
            "Superseded")
                echo -e "  ${YELLOW}○${NC} ${TITLE} [${STATUS}]"
                ;;
            *)
                echo -e "  ${BLUE}•${NC} ${TITLE} [${STATUS}]"
                ;;
        esac
    done
}

# Main command dispatcher
main() {
    local COMMAND="${1:-}"

    case "$COMMAND" in
        generate)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 generate <deployment-id>"
                exit 1
            fi
            generate_adr "$2"
            ;;
        amend)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 amend <deployment-id> [reason]"
                exit 1
            fi
            amend_adr "$2" "${3:-Deployment updated}"
            ;;
        index)
            update_index
            ;;
        list)
            list_adrs
            ;;
        *)
            echo "Architecture Decision Record (ADR) Manager"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  generate <deployment-id>          Generate ADR from a deployment"
            echo "  amend <deployment-id> [reason]    Amend ADR for an updated deployment"
            echo "  index                             Rebuild the ADR index"
            echo "  list                              List all ADRs"
            echo ""
            echo "Examples:"
            echo "  $0 generate deploy-20260218-143022"
            echo "  $0 amend deploy-20260218-143022 \"Scaled to production SKU\""
            echo "  $0 index"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
