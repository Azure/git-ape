#!/bin/bash
# azure-stack-destroy / destroy-stack.sh
#
# Destroy a Git-Ape deployment via az stack sub delete (preferred) or
# az group delete (fallback), then purge soft-deleted resources that are
# not purge-protected. Mirrors .github/workflows/git-ape-destroy.exampleyml
# so local destroys produce identical state.json transitions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
DEPLOYMENTS_DIR=".azure/deployments"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOYMENT_ID=""
YES_FLAG="false"
WAIT_FLAG="false"      # default: fast mode (submit + poll RGs)
POLL_TIMEOUT=600       # max seconds to wait for managed RGs to disappear in fast mode
POLL_INTERVAL=10       # seconds between RG-existence checks

usage() {
    cat <<EOF
Azure Stack Destroy — destroy a Deployment Stack and purge soft-deletables

Usage: $0 --deployment-id <id> [OPTIONS]

Required:
  --deployment-id <id>     Folder name under .azure/deployments/

Options:
  --yes                    Skip the typed 'destroy' confirmation prompt
  --wait                   Sync mode (matches CI): block on 'az stack sub delete'
                           until Azure has cleaned up stack metadata. Slower but
                           fully deterministic. Default is fast mode (run the
                           same command in the background, then poll managed
                           resource groups until they are gone, ~2-3× faster).
  --poll-timeout <sec>     Fast-mode timeout per managed RG poll (default: 600)
  -h, --help               Show this help

Examples:
  $0 --deployment-id deploy-20260506-001            # fast (interactive default)
  $0 --deployment-id deploy-20260506-001 --yes      # fast, no prompt
  $0 --deployment-id deploy-20260506-001 --wait     # CI-equivalent sync wait
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
        --yes)           YES_FLAG="true"; shift ;;
        --wait)          WAIT_FLAG="true"; shift ;;
        --poll-timeout)  POLL_TIMEOUT="$2"; shift 2 ;;
        -h|--help)       usage ;;
        *) echo "Unknown argument: $1"; usage ;;
    esac
done

[[ -n "$DEPLOYMENT_ID" ]] || usage

DEPLOYMENT_PATH="$WORKSPACE_ROOT/$DEPLOYMENTS_DIR/$DEPLOYMENT_ID"
STATE_FILE="$DEPLOYMENT_PATH/state.json"

if [[ ! -d "$DEPLOYMENT_PATH" ]]; then
    echo -e "${RED}Deployment not found: $DEPLOYMENT_ID${NC}"
    exit 1
fi
if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${RED}state.json not found: $STATE_FILE${NC}"
    echo "Cannot destroy without deployment state."
    exit 1
fi

STACK_ID=$(jq -r '.stackId // empty' "$STATE_FILE")
DEPLOY_METHOD=$(jq -r '.deployMethod // "subscription"' "$STATE_FILE")
RG_NAME=$(jq -r '.resourceGroup // empty' "$STATE_FILE")
MANAGED_RGS_JSON=$(jq -c '.resourceGroups // []' "$STATE_FILE")
MANAGED_RESOURCES=$(jq -c '.managedResources // []' "$STATE_FILE")
SOFT_DELETABLE=$(echo "$MANAGED_RESOURCES" | jq -c '[.[] | select(.softDeletable == true)]')

if [[ -z "$STACK_ID" && -z "$RG_NAME" ]]; then
    echo -e "${RED}No stackId or resourceGroup in state.json — cannot destroy.${NC}"
    exit 1
fi

# Plan -----------------------------------------------------------------------

echo -e "${YELLOW}=== Destroy Plan ===${NC}"
echo "Deployment:   $DEPLOYMENT_ID"
echo "Method:       $DEPLOY_METHOD"
[[ -n "$STACK_ID" ]] && echo "Stack ID:     $STACK_ID"
[[ -n "$RG_NAME" ]]  && echo "Resource RG:  $RG_NAME"

SOFT_COUNT=$(echo "$SOFT_DELETABLE" | jq 'length')
if [[ "$SOFT_COUNT" -gt 0 ]]; then
    echo "Soft-deletable: $SOFT_COUNT resource(s) — will purge non-protected after delete"
    echo "$SOFT_DELETABLE" | jq -r '.[] | "  - \(.type): \(.id)" + (if .purgeProtected then " (purge-protected)" else "" end)'
fi
echo -e "${YELLOW}====================${NC}"

if [[ "$YES_FLAG" != "true" ]]; then
    echo -n "Proceed with destroy? Type 'destroy' to confirm: "
    read -r CONFIRM
    if [[ "$CONFIRM" != "destroy" ]]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Execute --------------------------------------------------------------------

STACK_DELETED="false"
RG_DELETED="false"
ALREADY_GONE="true"
# Tracks whether a stack/RG delete command was actually invoked. Used to
# distinguish a partial failure (attempted but did not complete →
# partially-destroyed) from the catch-all destroy-failed, mirroring CI.
DELETE_ATTEMPTED="false"
START_TIME=$(date +%s)

# Primary path: stack delete
#
# Two modes:
#   --wait (sync, matches CI):    az stack sub delete --yes  (blocks until
#                                  Azure has finished both resource deletion
#                                  and stack-metadata cleanup; ~5 min for a
#                                  small stack)
#   default (fast, interactive):   start the same command in the background,
#                                  poll each managed RG with `az group exists`
#                                  until it returns false (~90s for the same
#                                  small stack), then return. Azure CLI does
#                                  not expose --no-wait on `az stack sub
#                                  delete`, so the slow stack-metadata cleanup
#                                  finishes asynchronously after the script
#                                  exits.
if [[ -n "$STACK_ID" ]]; then
    STACK_EXISTS=$(az stack sub show --name "$DEPLOYMENT_ID" --query "id" -o tsv 2>/dev/null || echo "")
    if [[ -n "$STACK_EXISTS" ]]; then
        ALREADY_GONE="false"
        DELETE_ATTEMPTED="true"
        if [[ "$WAIT_FLAG" == "true" ]]; then
            echo -e "${BLUE}🗑️  Deleting deployment stack (sync wait): $DEPLOYMENT_ID${NC}"
            # --bypass-stack-out-of-sync-error: a destroy run is one-shot; we
            # don't need the safety check that protects against stale manifests
            # during iterative updates.
            if az stack sub delete \
                --name "$DEPLOYMENT_ID" \
                --action-on-unmanage deleteAll \
                --bypass-stack-out-of-sync-error true \
                --yes 2>&1; then
                STACK_DELETED="true"
            else
                echo -e "${RED}❌ Stack delete failed${NC}"
            fi
        else
            MANAGED_RG_COUNT=$(echo "$MANAGED_RGS_JSON" | jq 'length')
            if [[ "$MANAGED_RG_COUNT" -eq 0 ]]; then
                echo -e "${YELLOW}⚠️  No resourceGroups[] in state.json — falling back to sync wait${NC}"
                if az stack sub delete \
                    --name "$DEPLOYMENT_ID" \
                    --action-on-unmanage deleteAll \
                    --bypass-stack-out-of-sync-error true \
                    --yes 2>&1; then
                    STACK_DELETED="true"
                else
                    echo -e "${RED}❌ Stack delete failed${NC}"
                fi
            else
                echo -e "${BLUE}🗑️  Submitting stack delete (fast mode): $DEPLOYMENT_ID${NC}"
                STACK_DELETE_LOG=$(mktemp)
                # Background the blocking stack delete; we exit as soon as the
                # managed RGs are gone, leaving Azure to finish stack-metadata
                # cleanup asynchronously.
                nohup az stack sub delete \
                    --name "$DEPLOYMENT_ID" \
                    --action-on-unmanage deleteAll \
                    --bypass-stack-out-of-sync-error true \
                    --yes > "$STACK_DELETE_LOG" 2>&1 &
                STACK_BG_PID=$!
                # Do NOT disown — we need `wait` to retrieve the exit code.
                # nohup already insulates against HUP signals.

                echo -e "${BLUE}⏳ Polling $MANAGED_RG_COUNT managed resource group(s) (timeout: ${POLL_TIMEOUT}s)...${NC}"
                POLL_START=$(date +%s)
                POLL_FAILED="false"
                for RG in $(echo "$MANAGED_RGS_JSON" | jq -r '.[]'); do
                    while true; do
                        ELAPSED=$(($(date +%s) - POLL_START))
                        if [[ $ELAPSED -ge $POLL_TIMEOUT ]]; then
                            echo -e "${RED}  ⚠️  Timeout (${ELAPSED}s) polling $RG${NC}"
                            if [[ -s "$STACK_DELETE_LOG" ]]; then
                                echo -e "${YELLOW}  Background stack-delete output:${NC}"
                                sed 's/^/    /' "$STACK_DELETE_LOG"
                            fi
                            echo -e "${YELLOW}  Rerun with --wait for synchronous diagnostics${NC}"
                            POLL_FAILED="true"
                            break
                        fi
                        # If the bg process already failed, surface it early
                        if ! kill -0 "$STACK_BG_PID" 2>/dev/null; then
                            BG_EXIT=0
                            wait "$STACK_BG_PID" 2>/dev/null || BG_EXIT=$?
                            if [[ $BG_EXIT -ne 0 ]]; then
                                EXISTS=$(az group exists --name "$RG" 2>/dev/null || echo "true")
                                if [[ "$EXISTS" == "true" ]]; then
                                    echo -e "${RED}  ❌ Background stack-delete exited (code $BG_EXIT) before $RG was removed${NC}"
                                    if [[ -s "$STACK_DELETE_LOG" ]]; then
                                        sed 's/^/    /' "$STACK_DELETE_LOG"
                                    fi
                                    POLL_FAILED="true"
                                    break
                                fi
                            fi
                        fi
                        EXISTS=$(az group exists --name "$RG" 2>/dev/null || echo "false")
                        if [[ "$EXISTS" != "true" ]]; then
                            echo -e "${GREEN}  ✓ $RG gone (${ELAPSED}s)${NC}"
                            break
                        fi
                        sleep "$POLL_INTERVAL"
                    done
                    [[ "$POLL_FAILED" == "true" ]] && break
                done
                rm -f "$STACK_DELETE_LOG"
                if [[ "$POLL_FAILED" == "true" ]]; then
                    STACK_DELETED="false"
                else
                    STACK_DELETED="true"
                    echo -e "${BLUE}ℹ️  Azure is finishing stack-metadata cleanup asynchronously${NC}"
                fi
            fi
        fi
    else
        echo -e "${YELLOW}Stack not found for stackId in state.json — falling back to RG/state-driven delete${NC}"
        STACK_DELETED="false"
        STACK_ID=""
    fi
fi

# Fallback path: resource group delete (only when no stack was used)
if [[ -z "$STACK_ID" && -n "$RG_NAME" ]]; then
    RG_EXISTS=$(az group exists --name "$RG_NAME" 2>/dev/null || echo "false")
    if [[ "$RG_EXISTS" == "true" ]]; then
        ALREADY_GONE="false"
        DELETE_ATTEMPTED="true"
        echo -e "${BLUE}🗑️  Deleting resource group: $RG_NAME${NC}"
        if az group delete --name "$RG_NAME" --yes 2>&1; then
            RG_DELETED="true"
        else
            echo -e "${RED}❌ Resource group delete failed${NC}"
        fi
    else
        echo -e "${YELLOW}Resource group already gone — skipping${NC}"
        RG_DELETED="true"
    fi
fi

# Soft-delete purge sweep
PURGE_RESULTS="[]"
RETAINED_COUNT=0
if [[ "$SOFT_COUNT" -gt 0 ]] && [[ "$STACK_DELETED" == "true" || "$RG_DELETED" == "true" ]]; then
    echo -e "${BLUE}🧹 Purging soft-deleted resources...${NC}"
    for ROW in $(echo "$SOFT_DELETABLE" | jq -r '.[] | @base64'); do
        DECODED=$(echo "$ROW" | base64 -d)
        RES_TYPE=$(echo "$DECODED" | jq -r '.type')
        RES_ID=$(echo "$DECODED" | jq -r '.id')
        PURGE_PROTECTED=$(echo "$DECODED" | jq -r '.purgeProtected')
        RES_NAME=$(echo "$RES_ID" | awk -F/ '{print $NF}')

        case "$RES_TYPE" in
            "Microsoft.KeyVault/vaults")
                DELETED_VAULT=$(az keyvault list-deleted --query "[?name=='$RES_NAME']" -o json 2>/dev/null || echo "[]")
                if [[ "$(echo "$DELETED_VAULT" | jq 'length')" -gt 0 ]]; then
                    if [[ "$PURGE_PROTECTED" == "true" ]]; then
                        echo "  ⚠️  $RES_NAME: soft-deleted but purge-protected — retained"
                        RETAINED_COUNT=$((RETAINED_COUNT + 1))
                        PURGE_RESULTS=$(echo "$PURGE_RESULTS" | jq --arg n "$RES_NAME" --arg t "$RES_TYPE" \
                            '. + [{name:$n, type:$t, action:"retained-soft-deleted", reason:"purge-protected"}]')
                    else
                        echo "  🗑️  Purging vault: $RES_NAME"
                        if az keyvault purge --name "$RES_NAME" 2>/dev/null; then
                            PURGE_RESULTS=$(echo "$PURGE_RESULTS" | jq --arg n "$RES_NAME" --arg t "$RES_TYPE" \
                                '. + [{name:$n, type:$t, action:"purged"}]')
                        else
                            echo "  ⚠️  Failed to purge vault: $RES_NAME"
                            RETAINED_COUNT=$((RETAINED_COUNT + 1))
                            PURGE_RESULTS=$(echo "$PURGE_RESULTS" | jq --arg n "$RES_NAME" --arg t "$RES_TYPE" \
                                '. + [{name:$n, type:$t, action:"purge-failed"}]')
                        fi
                    fi
                else
                    echo "  ✓ $RES_NAME: not in soft-deleted state"
                fi
                ;;
            "Microsoft.CognitiveServices/accounts")
                if [[ "$PURGE_PROTECTED" != "true" ]]; then
                    # Cognitive Services account IDs are resource-group scoped and
                    # contain no /locations/<region> segment, so the region must be
                    # resolved from the soft-deleted account list. The resource
                    # group comes from the original resource ID.
                    LOC=$(az cognitiveservices account list-deleted \
                        --query "[?name=='$RES_NAME'] | [0].location" -o tsv 2>/dev/null || echo "")
                    RES_RG=$(echo "$RES_ID" | sed -n 's#.*/resourceGroups/\([^/]*\)/.*#\1#p')
                    if [[ -n "$LOC" ]]; then
                        az cognitiveservices account purge --name "$RES_NAME" --location "$LOC" \
                            --resource-group "$RES_RG" 2>/dev/null || true
                    fi
                fi
                ;;
            *)
                echo "  ℹ️  $RES_TYPE: no purge implementation (soft-delete will expire naturally)"
                ;;
        esac
    done
fi

# Clean subscription deployment history entry to stay under the 800/scope limit
az deployment sub delete --name "$DEPLOYMENT_ID" 2>/dev/null || true

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Determine final status
if [[ "$ALREADY_GONE" == "true" ]]; then
    STATUS="already-destroyed"
elif [[ "$STACK_DELETED" == "true" || "$RG_DELETED" == "true" ]]; then
    if [[ "$RETAINED_COUNT" -gt 0 ]]; then
        STATUS="retained-soft-deleted"
    else
        STATUS="destroyed"
    fi
elif [[ "$DELETE_ATTEMPTED" == "true" ]]; then
    # A stack/RG existed and a delete was invoked, but it did not complete
    # (e.g. fast-mode poll timeout or a failed delete command). Some resources
    # may remain. Mirrors CI: stack/RG delete status == failed →
    # partially-destroyed (distinct from the destroy-failed catch-all).
    STATUS="partially-destroyed"
else
    STATUS="destroy-failed"
fi

# Update state.json + metadata.json
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ACTOR=$(az account show --query user.name -o tsv 2>/dev/null || echo unknown)
jq --arg status "$STATUS" --arg ts "$TIMESTAMP" \
    --arg actor "$ACTOR" \
    --arg duration "${DURATION}s" \
    --argjson purgeResults "$PURGE_RESULTS" \
    '. + {status:$status, destroyedAt:$ts, destroyedBy:$actor, destroyDuration:$duration, purgeResults:$purgeResults}' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

if [[ -f "$DEPLOYMENT_PATH/metadata.json" ]]; then
    jq --arg status "$STATUS" '.status = $status' \
        "$DEPLOYMENT_PATH/metadata.json" > "$DEPLOYMENT_PATH/metadata.json.tmp" \
        && mv "$DEPLOYMENT_PATH/metadata.json.tmp" "$DEPLOYMENT_PATH/metadata.json"
fi

echo ""
echo -e "${GREEN}=== Destroy Summary ===${NC}"
echo "Status:   $STATUS"
echo "Duration: ${DURATION}s"
if [[ "$RETAINED_COUNT" -gt 0 ]]; then
    echo -e "${YELLOW}Retained: $RETAINED_COUNT soft-deleted resource(s) (purge-protected)${NC}"
fi
echo -e "${GREEN}=======================${NC}"
