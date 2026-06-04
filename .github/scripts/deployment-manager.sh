#!/bin/bash
# Azure Deployment State Manager
# Utility script for managing deployment artifacts and state persistence

set -euo pipefail

DEPLOYMENTS_DIR=".azure/deployments"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Command: list
# List all deployments with status
list_deployments() {
    echo -e "${BLUE}Recent Deployments${NC}"
    echo "-----------------------------------------------------------"
    
    if [[ ! -d "$WORKSPACE_ROOT/$DEPLOYMENTS_DIR" ]]; then
        echo -e "${YELLOW}No deployments found${NC}"
        return 0
    fi
    
    cd "$WORKSPACE_ROOT/$DEPLOYMENTS_DIR"
    
    for dir in $(ls -t); do
        if [[ -d "$dir" ]]; then
            METADATA_FILE="$dir/metadata.json"
            
            if [[ -f "$METADATA_FILE" ]]; then
                STATUS=$(jq -r '.status // "unknown"' "$METADATA_FILE")
                TIMESTAMP=$(jq -r '.timestamp // "N/A"' "$METADATA_FILE")
                RESOURCES=$(jq -r '.resources // [] | length' "$METADATA_FILE")
                
                # Color code based on status
                case "$STATUS" in
                    "succeeded"|"completed")
                        COLOR=$GREEN
                        SYMBOL="✓"
                        ;;
                    "failed")
                        COLOR=$RED
                        SYMBOL="✗"
                        ;;
                    "in-progress")
                        COLOR=$YELLOW
                        SYMBOL="⧗"
                        ;;
                    "rolled-back")
                        COLOR=$YELLOW
                        SYMBOL="↶"
                        ;;
                    *)
                        COLOR=$NC
                        SYMBOL="?"
                        ;;
                esac
                
                echo -e "${COLOR}${SYMBOL} ${dir}${NC}"
                echo -e "  Status: ${STATUS} | Resources: ${RESOURCES} | Time: ${TIMESTAMP}"
            else
                echo -e "${YELLOW}? ${dir}${NC}"
                echo "  (missing metadata.json)"
            fi
            echo ""
        fi
    done
}

# Command: show
# Show details of a specific deployment
show_deployment() {
    local DEPLOYMENT_ID="$1"
    local DEPLOYMENT_PATH="$WORKSPACE_ROOT/$DEPLOYMENTS_DIR/$DEPLOYMENT_ID"
    
    if [[ ! -d "$DEPLOYMENT_PATH" ]]; then
        echo -e "${RED}Deployment not found: $DEPLOYMENT_ID${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Deployment Details: $DEPLOYMENT_ID${NC}"
    echo "-----------------------------------------------------------"
    
    # Show metadata if available
    if [[ -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
        echo -e "\n${GREEN}Metadata:${NC}"
        jq '.' "$DEPLOYMENT_PATH/metadata.json"
    fi
    
    # Show requirements if available
    if [[ -f "$DEPLOYMENT_PATH/requirements.json" ]]; then
        echo -e "\n${GREEN}Requirements:${NC}"
        jq '.resources[] | {type, name, region}' "$DEPLOYMENT_PATH/requirements.json"
    fi
    
    # Show deployment status
    if [[ -f "$DEPLOYMENT_PATH/deployment.log" ]]; then
        echo -e "\n${GREEN}Deployment Log (last 20 lines):${NC}"
        tail -20 "$DEPLOYMENT_PATH/deployment.log"
    fi
    
    # Show test results if available
    if [[ -f "$DEPLOYMENT_PATH/tests.json" ]]; then
        echo -e "\n${GREEN}Test Results:${NC}"
        jq '.tests[] | {name, status, result}' "$DEPLOYMENT_PATH/tests.json"
    fi
    
    # Show linked ADR if available
    if [[ -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
        local ADR_FILE
        ADR_FILE=$(jq -r '.adrFile // empty' "$DEPLOYMENT_PATH/metadata.json")
        if [[ -n "$ADR_FILE" && -f "$WORKSPACE_ROOT/$ADR_FILE" ]]; then
            local ADR_NUM
            ADR_NUM=$(jq -r '.adrNumber // "?"' "$DEPLOYMENT_PATH/metadata.json")
            echo -e "\n${GREEN}Architecture Decision Record:${NC}"
            echo "  ADR-$(printf "%04d" "$ADR_NUM"): $ADR_FILE"
        fi
    fi

    # Show errors if any
    if [[ -f "$DEPLOYMENT_PATH/error.log" ]]; then
        echo -e "\n${RED}Errors:${NC}"
        cat "$DEPLOYMENT_PATH/error.log"
    fi
}

# Command: clean
# Clean up old/failed deployments
clean_deployments() {
    local KEEP_COUNT="${1:-10}"
    
    echo -e "${YELLOW}Cleaning up old deployments (keeping $KEEP_COUNT most recent)...${NC}"
    
    if [[ ! -d "$WORKSPACE_ROOT/$DEPLOYMENTS_DIR" ]]; then
        echo "No deployments to clean"
        return 0
    fi
    
    cd "$WORKSPACE_ROOT/$DEPLOYMENTS_DIR"
    
    # Count total deployments
    TOTAL=$(ls -d */ 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $TOTAL -le $KEEP_COUNT ]]; then
        echo "Only $TOTAL deployments found, nothing to clean"
        return 0
    fi
    
    # List deployments sorted by time (oldest first)
    TO_DELETE=$(ls -tr | head -n -"$KEEP_COUNT")
    
    echo "Will delete the following deployments:"
    echo "$TO_DELETE"
    echo ""
    echo -n "Proceed? (y/N): "
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        for dir in $TO_DELETE; do
            echo "Deleting $dir..."
            rm -rf "$dir"
        done
        echo -e "${GREEN}Cleanup complete${NC}"
    else
        echo "Cancelled"
    fi
}

# Command: export
# Export deployment artifacts as a reusable template
export_deployment() {
    local DEPLOYMENT_ID="$1"
    local OUTPUT_FILE="${2:-.azure/templates/${DEPLOYMENT_ID}.json}"
    local DEPLOYMENT_PATH="$WORKSPACE_ROOT/$DEPLOYMENTS_DIR/$DEPLOYMENT_ID"
    
    if [[ ! -f "$DEPLOYMENT_PATH/template.json" ]]; then
        echo -e "${RED}Template not found for deployment: $DEPLOYMENT_ID${NC}"
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    
    # Copy template
    cp "$DEPLOYMENT_PATH/template.json" "$OUTPUT_FILE"
    
    # Copy parameters if available
    if [[ -f "$DEPLOYMENT_PATH/parameters.json" ]]; then
        cp "$DEPLOYMENT_PATH/parameters.json" "${OUTPUT_FILE%.json}.parameters.json"
    fi
    
    echo -e "${GREEN}Exported deployment template to:${NC}"
    echo "  Template: $OUTPUT_FILE"
    echo "  Parameters: ${OUTPUT_FILE%.json}.parameters.json"
}

# Command: init
# Initialize deployment state directory structure
init_deployment() {
    local DEPLOYMENT_ID="${1:-deploy-$(date +%Y%m%d-%H%M%S)}"
    local DEPLOYMENT_PATH="$WORKSPACE_ROOT/$DEPLOYMENTS_DIR/$DEPLOYMENT_ID"
    
    if [[ -d "$DEPLOYMENT_PATH" ]]; then
        echo -e "${YELLOW}Deployment already exists: $DEPLOYMENT_ID${NC}"
        exit 1
    fi
    
    # Create directory structure
    mkdir -p "$DEPLOYMENT_PATH"
    
    # Create initial metadata
    cat > "$DEPLOYMENT_PATH/metadata.json" <<EOF
{
  "deploymentId": "$DEPLOYMENT_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "user": "$(az account show --query user.name -o tsv 2>/dev/null || echo 'unknown')",
  "status": "initialized",
  "resources": []
}
EOF
    
    # Create empty deployment log
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Deployment initialized" > "$DEPLOYMENT_PATH/deployment.log"
    
    echo -e "${GREEN}Initialized deployment: $DEPLOYMENT_ID${NC}"
    echo "Path: $DEPLOYMENT_PATH"
    echo ""
    echo "Next steps:"
    echo "  1. Save requirements to: $DEPLOYMENT_PATH/requirements.json"
    echo "  2. Save template to: $DEPLOYMENT_PATH/template.json"
    echo "  3. Update status in: $DEPLOYMENT_PATH/metadata.json"
}

# Command: validate
# Validate deployment state files
validate_deployment() {
    local DEPLOYMENT_ID="$1"
    local DEPLOYMENT_PATH="$WORKSPACE_ROOT/$DEPLOYMENTS_DIR/$DEPLOYMENT_ID"
    
    if [[ ! -d "$DEPLOYMENT_PATH" ]]; then
        echo -e "${RED}Deployment not found: $DEPLOYMENT_ID${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Validating deployment: $DEPLOYMENT_ID${NC}"
    echo "-----------------------------------------------------------"
    
    local ERRORS=0
    
    # Check required files
    if [[ ! -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
        echo -e "${RED}✗ Missing metadata.json${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ metadata.json found${NC}"
        # Validate JSON
        if ! jq empty "$DEPLOYMENT_PATH/metadata.json" 2>/dev/null; then
            echo -e "${RED}  ✗ Invalid JSON format${NC}"
            ((ERRORS++))
        fi
    fi
    
    if [[ -f "$DEPLOYMENT_PATH/requirements.json" ]]; then
        echo -e "${GREEN}✓ requirements.json found${NC}"
        if ! jq empty "$DEPLOYMENT_PATH/requirements.json" 2>/dev/null; then
            echo -e "${RED}  ✗ Invalid JSON format${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}⚠ requirements.json not found${NC}"
    fi
    
    if [[ -f "$DEPLOYMENT_PATH/template.json" ]]; then
        echo -e "${GREEN}✓ template.json found${NC}"
        if ! jq empty "$DEPLOYMENT_PATH/template.json" 2>/dev/null; then
            echo -e "${RED}  ✗ Invalid JSON format${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}⚠ template.json not found${NC}"
    fi
    
    echo ""
    if [[ $ERRORS -eq 0 ]]; then
        echo -e "${GREEN}✓ Deployment state is valid${NC}"
        return 0
    else
        echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
        return 1
    fi
}

# Main command dispatcher
main() {
    local COMMAND="${1:-}"
    
    case "$COMMAND" in
        list)
            list_deployments
            ;;
        show)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 show <deployment-id>"
                exit 1
            fi
            show_deployment "$2"
            ;;
        clean)
            clean_deployments "${2:-10}"
            ;;
        export)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 export <deployment-id> [output-file]"
                exit 1
            fi
            export_deployment "$2" "${3:-}"
            ;;
        init)
            init_deployment "${2:-}"
            ;;
        validate)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 validate <deployment-id>"
                exit 1
            fi
            validate_deployment "$2"
            ;;
        *)
            echo "Azure Deployment State Manager"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  list                    List all deployments with status"
            echo "  show <id>               Show details of a specific deployment"
            echo "  clean [keep-count]      Clean up old deployments (default: keep 10)"
            echo "  export <id> [file]      Export deployment as reusable template"
            echo "  init [id]               Initialize new deployment directory"
            echo "  validate <id>           Validate deployment state files"
            echo ""
            echo "Examples:"
            echo "  $0 list"
            echo "  $0 show deploy-20260218-143022"
            echo "  $0 export deploy-20260218-143022 my-template.json"
            echo "  $0 clean 5"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
