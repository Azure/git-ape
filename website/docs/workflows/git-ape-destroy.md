---
title: "Git-Ape: Destroy"
sidebar_label: "Destroy"
description: "GitHub Actions workflow: Git-Ape: Destroy"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-destroy.exampleyml -->


# Git-Ape: Destroy

**Workflow file:** `.github/workflows/git-ape-destroy.exampleyml`

## Triggers

- **`push`** — branches: `["main"]` — paths: `.azure/deployments/**/metadata.json, .azure/deployments/**/state.json`
- **`workflow_dispatch`**


## Permissions

- `id-token: write`
- `contents: write`
- `issues: write`
- `pull-requests: write`

## Jobs

### `detect-destroys`

| Property | Value |
|----------|-------|
| **Display Name** | Detect destroy requests |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 2 |

### `destroy`

| Property | Value |
|----------|-------|
| **Display Name** | Destroy: ${{ matrix.deployment_id }} |
| **Runs On** | `ubuntu-latest` |
| **Environment** | `azure-destroy` |
| **Depends On** | `detect-destroys` |
| **Steps** | 9 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
# Git-Ape Destroy Workflow
# Triggers on:
#   1. PR merge to main that sets metadata.json status to "destroy-requested"
#   2. Manual workflow dispatch (emergency fallback)
# Deletes the Azure resource group for a tracked deployment.

name: "Git-Ape: Destroy"

env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

on:
  push:
    branches: [main]
    paths:
      - ".azure/deployments/**/metadata.json"
      - ".azure/deployments/**/state.json"

  workflow_dispatch:
    inputs:
      deployment_id:
        description: "Deployment ID (e.g., deploy-20260218-220000)"
        required: true
        type: string
      confirm:
        description: "Type 'destroy' to confirm"
        required: true
        type: string

permissions:
  id-token: write       # OIDC token for Azure login
  contents: write        # Commit updated state files
  issues: write          # Post result on linked issues
  pull-requests: write   # Post result on merged PR

concurrency:
  group: git-ape-destroy-${{ github.sha }}
  cancel-in-progress: false   # Never cancel in-progress destroys

jobs:
  detect-destroys:
    name: Detect destroy requests
    runs-on: ubuntu-latest
    outputs:
      deployment_ids: ${{ steps.find.outputs.deployment_ids }}
      has_destroys: ${{ steps.find.outputs.has_destroys }}
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 2

      - name: Find destroy-requested deployments
        id: find
        run: |
          if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
            CONFIRM="${{ inputs.confirm }}"
            if [[ "$CONFIRM" != "destroy" ]]; then
              echo "::error::Confirmation must be 'destroy'"
              echo "has_destroys=false" >> "$GITHUB_OUTPUT"
              echo "deployment_ids=[]" >> "$GITHUB_OUTPUT"
              exit 1
            fi
            DEPLOYMENT_IDS='["${{ inputs.deployment_id }}"]'
            echo "has_destroys=true" >> "$GITHUB_OUTPUT"
            echo "deployment_ids=$DEPLOYMENT_IDS" >> "$GITHUB_OUTPUT"
            echo "Manual destroy requested: ${{ inputs.deployment_id }}"
            exit 0
          fi

          # On push: find deployments where metadata.json changed and status is destroy-requested
          CHANGED_FILES=$(git diff --name-only HEAD~1...HEAD -- '.azure/deployments/*/metadata.json' '.azure/deployments/*/state.json' 2>/dev/null || true)

          if [[ -z "$CHANGED_FILES" ]]; then
            echo "has_destroys=false" >> "$GITHUB_OUTPUT"
            echo "deployment_ids=[]" >> "$GITHUB_OUTPUT"
            echo "No deployment metadata changes found"
            exit 0
          fi

          # Extract unique deployment IDs from changed files
          DEPLOY_DIRS=$(echo "$CHANGED_FILES" | sed 's|.azure/deployments/\([^/]*\)/.*|\1|' | sort -u)

          # Filter to only those with status "destroy-requested"
          DESTROY_IDS=""
          for DIR in $DEPLOY_DIRS; do
            METADATA=".azure/deployments/$DIR/metadata.json"
            if [[ -f "$METADATA" ]]; then
              STATUS=$(jq -r '.status // ""' "$METADATA")
              if [[ "$STATUS" == "destroy-requested" ]]; then
                DESTROY_IDS="$DESTROY_IDS $DIR"
                echo "Found destroy request: $DIR"
              fi
            fi
          done

          if [[ -z "$DESTROY_IDS" ]]; then
            echo "has_destroys=false" >> "$GITHUB_OUTPUT"
            echo "deployment_ids=[]" >> "$GITHUB_OUTPUT"
            echo "No destroy-requested deployments found"
            exit 0
          fi

          DEPLOYMENT_IDS=$(echo "$DESTROY_IDS" | tr ' ' '\n' | grep -v '^$' | jq -R -s -c 'split("\n") | map(select(. != ""))')
          echo "has_destroys=true" >> "$GITHUB_OUTPUT"
          echo "deployment_ids=$DEPLOYMENT_IDS" >> "$GITHUB_OUTPUT"
          echo "Deployments to destroy: $DEPLOYMENT_IDS"

  destroy:
    name: "Destroy: ${{ matrix.deployment_id }}"
    needs: detect-destroys
    if: needs.detect-destroys.outputs.has_destroys == 'true'
    runs-on: ubuntu-latest
    environment: azure-destroy
    strategy:
      matrix:
        deployment_id: ${{ fromJson(needs.detect-destroys.outputs.deployment_ids) }}
      max-parallel: 1
      fail-fast: false
    steps:
      - uses: actions/checkout@v6

      - name: Load deployment state
        id: state
        run: |
          DEPLOYMENT_ID="${{ matrix.deployment_id }}"
          STATE_FILE=".azure/deployments/$DEPLOYMENT_ID/state.json"

          if [[ ! -f "$STATE_FILE" ]]; then
            echo "::error::Deployment state not found: $STATE_FILE"
            echo "found=false" >> "$GITHUB_OUTPUT"
            exit 1
          fi

          RG_NAME=$(jq -r '.resourceGroup // empty' "$STATE_FILE")

          if [[ -z "$RG_NAME" ]]; then
            echo "::error::No resource group found in state file"
            echo "found=false" >> "$GITHUB_OUTPUT"
            exit 1
          fi

          echo "found=true" >> "$GITHUB_OUTPUT"
          echo "resource_group=$RG_NAME" >> "$GITHUB_OUTPUT"
          echo "Will destroy resource group: $RG_NAME"

      - name: Azure Login (OIDC)
        if: steps.state.outputs.found == 'true'
        uses: azure/login@v3
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Build destroy plan
        id: check
        if: steps.state.outputs.found == 'true'
        run: |
          RG="${{ steps.state.outputs.resource_group }}"
          DEPLOYMENT_ID="${{ matrix.deployment_id }}"

          # Check if resource group exists
          EXISTS=$(az group exists --name "$RG")
          echo "exists=$EXISTS" >> "$GITHUB_OUTPUT"

          if [[ "$EXISTS" != "true" ]]; then
            echo "Resource group $RG does not exist (already deleted?)"
            echo "resource_count=0" >> "$GITHUB_OUTPUT"
            echo "sub_count=0" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          # Inventory RG resources
          RESOURCES=$(az resource list --resource-group "$RG" \
            --query "[].{name:name, type:type, id:id, provisioningState:provisioningState}" \
            --output json 2>/dev/null || echo "[]")
          RESOURCE_COUNT=$(echo "$RESOURCES" | jq 'length')

          echo "resource_count=$RESOURCE_COUNT" >> "$GITHUB_OUTPUT"
          echo "resources<<EOF" >> "$GITHUB_OUTPUT"
          echo "$RESOURCES" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"

          echo "Resource group $RG has $RESOURCE_COUNT resources"
          echo "$RESOURCES" | jq -r '.[] | "  - \(.type)/\(.name) (\(.provisioningState))"'

          # Query deployment operations to find subscription-scoped resources
          # These are NOT deleted by az group delete (e.g. role assignments, policy assignments)
          SUB_RESOURCES="[]"

          OPS=$(az deployment operation sub list \
            --name "$DEPLOYMENT_ID" \
            --query "[?properties.provisioningState=='Succeeded' && properties.targetResource.id != null].properties.targetResource" \
            -o json 2>/dev/null || echo "[]")

          if [[ "$OPS" != "[]" ]]; then
            # Find subscription-scoped authorization/policy resources (role assignments, etc.)
            # These live outside the RG and survive az group delete
            SUB_RESOURCES=$(echo "$OPS" | jq -c '[
              .[] | select(
                (.resourceType // "" | test("Microsoft.Authorization|Microsoft.Policy")) and
                (.id // "" | test("/resourceGroups/") | not)
              )
            ]')

            # Check nested deployments for RG-scoped role assignments too
            NESTED_NAMES=$(echo "$OPS" | jq -r '[
              .[] | select(.resourceType == "Microsoft.Resources/deployments")
            ] | .[].resourceName // empty')

            for NESTED_NAME in $NESTED_NAMES; do
              NESTED_OPS=$(az deployment operation group list \
                --resource-group "$RG" --name "$NESTED_NAME" \
                --query "[?properties.provisioningState=='Succeeded' && properties.targetResource.id != null].properties.targetResource" \
                -o json 2>/dev/null || echo "[]")

              # Role assignments scoped to resources within the RG
              NESTED_AUTH=$(echo "$NESTED_OPS" | jq -c '[
                .[] | select(
                  (.resourceType // "" | test("Microsoft.Authorization"))
                )
              ]')

              SUB_RESOURCES=$(jq -n --argjson a "$SUB_RESOURCES" --argjson b "$NESTED_AUTH" '$a + $b')
            done
          fi

          SUB_COUNT=$(echo "$SUB_RESOURCES" | jq 'length')

          echo "sub_count=$SUB_COUNT" >> "$GITHUB_OUTPUT"
          echo "sub_resources<<EOF" >> "$GITHUB_OUTPUT"
          echo "$SUB_RESOURCES" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"

          echo ""
          echo "=== Destroy Plan ==="
          echo "Resource group:              $RG ($RESOURCE_COUNT resources)"
          echo "Subscription-scoped resources: $SUB_COUNT"
          if [[ "$SUB_COUNT" -gt 0 ]]; then
            echo "$SUB_RESOURCES" | jq -r '.[] | "  - \(.resourceType): \(.resourceName) (\(.id))"'
          fi
          echo "==================="

      - name: Delete subscription-scoped resources
        id: destroy_sub
        if: steps.check.outputs.exists == 'true' && steps.check.outputs.sub_count != '0'
        run: |
          echo "🗑️ Deleting subscription-scoped resources first..."
          FAILED=0

          echo '${{ steps.check.outputs.sub_resources }}' | jq -r '.[].id' | while read -r RESOURCE_ID; do
            echo "  Deleting: $RESOURCE_ID"
            if ! az resource delete --ids "$RESOURCE_ID" 2>&1; then
              echo "::warning::Failed to delete $RESOURCE_ID"
              FAILED=$((FAILED + 1))
            fi
          done

          if [[ "$FAILED" -gt 0 ]]; then
            echo "::warning::$FAILED subscription-scoped resource(s) failed to delete"
          fi

      - name: Delete resource group
        id: destroy
        if: steps.check.outputs.exists == 'true'
        run: |
          RG="${{ steps.state.outputs.resource_group }}"
          echo "🗑️ Deleting resource group: $RG"
          echo "This will block until the resource group is fully deleted..."

          START_TIME=$(date +%s)

          az group delete --name "$RG" --yes 2>&1 || {
            echo "destroy_status=failed" >> "$GITHUB_OUTPUT"
            echo "::error::Failed to delete resource group $RG"
            exit 1
          }

          END_TIME=$(date +%s)
          DURATION=$((END_TIME - START_TIME))
          echo "destroy_status=succeeded" >> "$GITHUB_OUTPUT"
          echo "destroy_duration=${DURATION}s" >> "$GITHUB_OUTPUT"
          echo "✅ Resource group deleted in ${DURATION}s: $RG"

      - name: Update deployment state
        if: always() && steps.state.outputs.found == 'true'
        run: |
          DEPLOYMENT_ID="${{ matrix.deployment_id }}"
          DEPLOY_DIR=".azure/deployments/$DEPLOYMENT_ID"
          STATE_FILE="$DEPLOY_DIR/state.json"
          TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

          if [[ "${{ steps.check.outputs.exists }}" == "false" ]]; then
            STATUS="already-destroyed"
          elif [[ "${{ steps.destroy.outputs.destroy_status }}" == "succeeded" ]]; then
            STATUS="destroyed"
          else
            STATUS="destroy-failed"
          fi

          # Update state file
          if [[ -f "$STATE_FILE" ]]; then
            jq --arg status "$STATUS" --arg ts "$TIMESTAMP" --arg actor "${{ github.actor }}" \
              --arg duration "${{ steps.destroy.outputs.destroy_duration }}" \
              '. + {status: $status, destroyedAt: $ts, destroyedBy: $actor, destroyDuration: $duration}' \
              "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
          fi

          # Update metadata.json status
          if [[ -f "$DEPLOY_DIR/metadata.json" ]]; then
            jq --arg status "$STATUS" '.status = $status' \
              "$DEPLOY_DIR/metadata.json" > "$DEPLOY_DIR/metadata.json.tmp" \
              && mv "$DEPLOY_DIR/metadata.json.tmp" "$DEPLOY_DIR/metadata.json"
          fi

          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add "$DEPLOY_DIR/state.json" "$DEPLOY_DIR/metadata.json"
          git diff --cached --quiet || git commit -m "git-ape: mark ${{ matrix.deployment_id }} as $STATUS"
          git push || echo "::warning::Could not push state update"

      - name: Post summary
        if: always()
        run: |
          DEPLOY_ID="${{ matrix.deployment_id }}"
          RG="${{ steps.state.outputs.resource_group }}"
          STATUS="${{ steps.destroy.outputs.destroy_status }}"
          DURATION="${{ steps.destroy.outputs.destroy_duration }}"
          RESOURCE_COUNT="${{ steps.check.outputs.resource_count }}"
          SUB_COUNT="${{ steps.check.outputs.sub_count }}"
          EXISTS="${{ steps.check.outputs.exists }}"
          RUN_URL="${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"

          echo "============================================"
          echo "Git-Ape Destroy Summary"
          echo "============================================"
          echo "Deployment:     $DEPLOY_ID"
          echo "Resource Group: $RG"
          if [[ "$EXISTS" == "false" ]]; then
            echo "Result:         Already destroyed"
          elif [[ "$STATUS" == "succeeded" ]]; then
            echo "Result:         ✅ Destroyed ($RESOURCE_COUNT RG resources + $SUB_COUNT subscription-scoped)"
            echo "Duration:       $DURATION"
          else
            echo "Result:         ❌ Failed"
          fi
          echo "Run:            $RUN_URL"
          echo "============================================"

      - name: Notify via Slack
        if: always()
        continue-on-error: true
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          if [[ -z "$SLACK_WEBHOOK_URL" ]]; then exit 0; fi

          DEPLOY_ID="${{ matrix.deployment_id }}"
          RG="${{ steps.state.outputs.resource_group }}"
          STATUS="${{ steps.destroy.outputs.destroy_status }}"
          RUN_URL="${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"

          if [[ "$STATUS" == "succeeded" ]]; then
            EMOJI="🗑️"
            MSG="Resource group *$RG* ($DEPLOY_ID) destroyed"
          else
            EMOJI="❌"
            MSG="Destroy failed for *$RG* ($DEPLOY_ID)"
          fi

          curl -sf -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-type: application/json' \
            -d "{
              \"text\": \"$EMOJI $MSG\",
              \"blocks\": [
                {
                  \"type\": \"section\",
                  \"text\": {
                    \"type\": \"mrkdwn\",
                    \"text\": \"$EMOJI *Git-Ape Destroy: $DEPLOY_ID*\\n\\n$MSG\\n\\nTriggered by: ${{ github.actor }}\\n<$RUN_URL|View logs>\"
                  }
                }
              ]
            }" || echo "::warning::Slack notification failed"

```

</details>
