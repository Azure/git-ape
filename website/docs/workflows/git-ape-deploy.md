---
title: "Git-Ape: Deploy"
sidebar_label: "Deploy"
description: "GitHub Actions workflow: Git-Ape: Deploy"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-deploy.exampleyml -->


# Git-Ape: Deploy

**Workflow file:** `.github/workflows/git-ape-deploy.exampleyml`

## Triggers

- **`push`** — branches: `["main"]` — paths: `.azure/deployments/**/template.json, .azure/deployments/**/parameters.json`
- **`issue_comment`** — types: `created`


## Permissions

- `id-token: write`
- `contents: write`
- `pull-requests: write`
- `issues: write`
- `security-events: write`
- `actions: read`

## Jobs

### `check-comment-trigger`

| Property | Value |
|----------|-------|
| **Display Name** | Check /deploy trigger |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 1 |

### `detect-deployments`

| Property | Value |
|----------|-------|
| **Display Name** | Detect deployments to execute |
| **Runs On** | `ubuntu-latest` |
| **Depends On** | `check-comment-trigger` |
| **Steps** | 2 |

### `deploy`

| Property | Value |
|----------|-------|
| **Display Name** | Deploy: ${{ matrix.deployment_id }} |
| **Runs On** | `ubuntu-latest` |
| **Environment** | `azure-deploy` |
| **Depends On** | `detect-deployments`, `check-comment-trigger` |
| **Steps** | 13 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
# Git-Ape Deploy Workflow
# Triggers on:
#   1. PR merge to main (when deployment files are included)
#   2. `/deploy` comment on an approved PR (deploys from branch before merge)
# Runs the actual ARM deployment, captures outputs, and runs integration tests.

name: "Git-Ape: Deploy"

env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

on:
  # Trigger 1: PR merged to main with deployment artifacts
  push:
    branches: [main]
    paths:
      - ".azure/deployments/**/template.json"
      - ".azure/deployments/**/parameters.json"

  # Trigger 2: `/deploy` comment on a PR
  issue_comment:
    types: [created]

permissions:
  id-token: write         # OIDC token for Azure login
  contents: write          # Commit state files back to repo
  pull-requests: write     # Post deployment results as PR comment
  issues: write            # Post on issue comments
  security-events: write   # Upload SARIF results from template analyzer
  actions: read            # Required by codeql-action/upload-sarif to read workflow run context

concurrency:
  group: git-ape-deploy-${{ github.event_name == 'push' && github.sha || github.event.comment.id }}
  cancel-in-progress: false   # Never cancel in-progress deployments

jobs:
  # Gate: Only run on `/deploy` comments on approved PRs
  check-comment-trigger:
    name: Check /deploy trigger
    if: github.event_name == 'issue_comment'
    runs-on: ubuntu-latest
    outputs:
      should_deploy: ${{ steps.check.outputs.should_deploy }}
      pr_ref: ${{ steps.check.outputs.pr_ref }}
    steps:
      - name: Check comment and PR status
        id: check
        uses: actions/github-script@v8
        with:
          script: |
            const comment = context.payload.comment.body.trim();
            if (!comment.startsWith('/deploy')) {
              core.setOutput('should_deploy', 'false');
              return;
            }

            // Must be on a PR (not a regular issue)
            if (!context.payload.issue.pull_request) {
              core.setOutput('should_deploy', 'false');
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: '❌ `/deploy` can only be used on pull requests.',
              });
              return;
            }

            // Get PR details
            const { data: pr } = await github.rest.pulls.get({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number,
            });

            // Check PR is approved
            const { data: reviews } = await github.rest.pulls.listReviews({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number,
            });
            const approved = reviews.some(r => r.state === 'APPROVED');

            if (!approved) {
              core.setOutput('should_deploy', 'false');
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: '❌ PR must be **approved** before deploying. Get a review approval first.',
              });
              return;
            }

            core.setOutput('should_deploy', 'true');
            core.setOutput('pr_ref', pr.head.ref);

            // React to the comment
            await github.rest.reactions.createForIssueComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              comment_id: context.payload.comment.id,
              content: 'rocket',
            });

  detect-deployments:
    name: Detect deployments to execute
    needs: [check-comment-trigger]
    if: |
      always() &&
      (github.event_name == 'push' ||
       (github.event_name == 'issue_comment' && needs.check-comment-trigger.outputs.should_deploy == 'true'))
    runs-on: ubuntu-latest
    outputs:
      deployment_ids: ${{ steps.find.outputs.deployment_ids }}
      has_deployments: ${{ steps.find.outputs.has_deployments }}
    steps:
      - uses: actions/checkout@v6
        with:
          ref: ${{ needs.check-comment-trigger.outputs.pr_ref || github.ref }}
          fetch-depth: 0

      - name: Find deployment directories
        id: find
        run: |
          if [[ "${{ github.event_name }}" == "push" ]]; then
            # On merge: find deployments changed in the merge commit
            CHANGED_FILES=$(git diff --name-only HEAD~1...HEAD -- '.azure/deployments/*/template.json' 2>/dev/null || true)
          else
            # On /deploy comment: find all deployments with template.json on the branch
            CHANGED_FILES=$(git diff --name-only origin/main...HEAD -- '.azure/deployments/*/template.json' 2>/dev/null || true)
          fi

          if [[ -z "$CHANGED_FILES" ]]; then
            echo "has_deployments=false" >> "$GITHUB_OUTPUT"
            echo "deployment_ids=[]" >> "$GITHUB_OUTPUT"
            echo "No deployments found"
            exit 0
          fi

          DEPLOYMENT_IDS=$(echo "$CHANGED_FILES" | sed 's|.azure/deployments/\([^/]*\)/.*|\1|' | sort -u | jq -R -s -c 'split("\n") | map(select(. != ""))')

          echo "has_deployments=true" >> "$GITHUB_OUTPUT"
          echo "deployment_ids=$DEPLOYMENT_IDS" >> "$GITHUB_OUTPUT"
          echo "Deployments to execute: $DEPLOYMENT_IDS"

  deploy:
    name: "Deploy: ${{ matrix.deployment_id }}"
    needs: [detect-deployments, check-comment-trigger]
    if: |
      always() &&
      needs.detect-deployments.outputs.has_deployments == 'true'
    runs-on: ubuntu-latest
    environment: azure-deploy
    strategy:
      matrix:
        deployment_id: ${{ fromJson(needs.detect-deployments.outputs.deployment_ids) }}
      max-parallel: 1    # Deploy sequentially to avoid conflicts
      fail-fast: false

    steps:
      - uses: actions/checkout@v6
        with:
          ref: ${{ needs.check-comment-trigger.outputs.pr_ref || github.ref }}

      - name: Read deployment parameters
        id: params
        run: |
          DEPLOY_DIR=".azure/deployments/${{ matrix.deployment_id }}"

          if [[ ! -f "$DEPLOY_DIR/template.json" ]]; then
            echo "::error::Template not found: $DEPLOY_DIR/template.json"
            exit 1
          fi

          if [[ -f "$DEPLOY_DIR/parameters.json" ]]; then
            LOCATION=$(jq -r '.parameters.location.value // "eastus"' "$DEPLOY_DIR/parameters.json")
            PROJECT=$(jq -r '.parameters.project.value // .parameters.projectName.value // "unknown"' "$DEPLOY_DIR/parameters.json")
            ENVIRONMENT=$(jq -r '.parameters.environment.value // "dev"' "$DEPLOY_DIR/parameters.json")
          else
            LOCATION="eastus"
            PROJECT="unknown"
            ENVIRONMENT="dev"
          fi

          echo "location=$LOCATION" >> "$GITHUB_OUTPUT"
          echo "project=$PROJECT" >> "$GITHUB_OUTPUT"
          echo "environment=$ENVIRONMENT" >> "$GITHUB_OUTPUT"
          echo "deploy_dir=$DEPLOY_DIR" >> "$GITHUB_OUTPUT"

      - name: Azure Login (OIDC)
        uses: azure/login@v3
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Validate before deploy
        run: |
          az deployment sub validate \
            --location "${{ steps.params.outputs.location }}" \
            --template-file "${{ steps.params.outputs.deploy_dir }}/template.json" \
            --parameters @"${{ steps.params.outputs.deploy_dir }}/parameters.json" \
            --output json

      - name: Run Microsoft Defender for DevOps template analyzer
        id: security_scan
        continue-on-error: true
        uses: microsoft/security-devops-action@v1
        with:
          tools: templateanalyzer
        env:
          GDN_TEMPLATEANALYZER_INPUT: ${{ steps.params.outputs.deploy_dir }}/template.json

      - name: Upload SARIF results
        if: always() && steps.security_scan.outputs.sarifFile != ''
        continue-on-error: true
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: ${{ steps.security_scan.outputs.sarifFile }}
          category: templateanalyzer

      - name: Check security scan results
        id: scan_gate
        run: |
          SARIF_FILE="${{ steps.security_scan.outputs.sarifFile }}"
          if [[ -f "$SARIF_FILE" ]]; then
            ERRORS=$(jq '[.runs[].results[] | select(.level == "error")] | length' "$SARIF_FILE" 2>/dev/null || echo 0)
            if [[ "$ERRORS" -gt 0 ]]; then
              echo "::error::Template analyzer found $ERRORS security error(s). Deployment blocked."
              jq -r '.runs[].results[] | select(.level == "error") | "  ERROR: \(.message.text) (\(.ruleId))"' "$SARIF_FILE"
              exit 1
            fi
            echo "Security scan passed — no errors found"
          fi

      - name: Deploy to Azure
        id: deploy
        run: |
          echo "🚀 Starting deployment: ${{ matrix.deployment_id }}"
          START_TIME=$(date +%s)

          DEPLOY_OUTPUT=$(az deployment sub create \
            --name "${{ matrix.deployment_id }}" \
            --location "${{ steps.params.outputs.location }}" \
            --template-file "${{ steps.params.outputs.deploy_dir }}/template.json" \
            --parameters @"${{ steps.params.outputs.deploy_dir }}/parameters.json" \
            --output json 2>&1)

          EXIT_CODE=$?
          END_TIME=$(date +%s)
          DURATION=$((END_TIME - START_TIME))

          echo "deploy_duration=${DURATION}s" >> "$GITHUB_OUTPUT"

          if [[ $EXIT_CODE -ne 0 ]]; then
            echo "deploy_status=failed" >> "$GITHUB_OUTPUT"
            echo "deploy_error<<EOF" >> "$GITHUB_OUTPUT"
            echo "$DEPLOY_OUTPUT" >> "$GITHUB_OUTPUT"
            echo "EOF" >> "$GITHUB_OUTPUT"
            echo ""
            echo "=========================================="
            echo "❌ DEPLOYMENT FAILED"
            echo "=========================================="
            echo "$DEPLOY_OUTPUT"
            echo "=========================================="
            echo "::error::Deployment failed — see output above for details"
            exit 1
          fi

          echo "deploy_status=succeeded" >> "$GITHUB_OUTPUT"

          # Extract outputs
          OUTPUTS=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.outputs // {}')
          echo "deploy_outputs<<EOF" >> "$GITHUB_OUTPUT"
          echo "$OUTPUTS" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"

          # Extract resource group name
          RG_NAME=$(echo "$OUTPUTS" | jq -r '.resourceGroupName.value // empty')
          echo "resource_group=$RG_NAME" >> "$GITHUB_OUTPUT"

          echo "✅ Deployment succeeded in ${DURATION}s"

      - name: Run integration tests
        id: tests
        if: steps.deploy.outputs.deploy_status == 'succeeded'
        run: |
          RG_NAME="${{ steps.deploy.outputs.resource_group }}"

          if [[ -z "$RG_NAME" ]]; then
            echo "⚠️ No resource group name in outputs, skipping integration tests"
            echo "test_status=skipped" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          echo "Running integration tests for RG: $RG_NAME"

          # List deployed resources
          RESOURCES=$(az resource list --resource-group "$RG_NAME" \
            --query "[].{name:name, type:type, provisioningState:provisioningState}" \
            --output json 2>/dev/null || echo "[]")

          echo "resources<<EOF" >> "$GITHUB_OUTPUT"
          echo "$RESOURCES" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"

          # Check all resources provisioned successfully
          FAILED=$(echo "$RESOURCES" | jq '[.[] | select(.provisioningState != "Succeeded")] | length')
          if [[ "$FAILED" -gt 0 ]]; then
            echo "test_status=failed" >> "$GITHUB_OUTPUT"
            echo "::warning::$FAILED resource(s) not in Succeeded state"
          else
            echo "test_status=passed" >> "$GITHUB_OUTPUT"
          fi

          # Test HTTP endpoints (Container Apps, Function Apps, Web Apps)
          ENDPOINTS=$(echo "$RESOURCES" | jq -r '.[] | select(.type == "Microsoft.App/containerApps" or .type == "Microsoft.Web/sites") | .name')
          TEST_RESULTS=""

          for NAME in $ENDPOINTS; do
            RESOURCE_TYPE=$(echo "$RESOURCES" | jq -r ".[] | select(.name == \"$NAME\") | .type")

            if [[ "$RESOURCE_TYPE" == "Microsoft.App/containerApps" ]]; then
              FQDN=$(az containerapp show -n "$NAME" -g "$RG_NAME" --query "properties.configuration.ingress.fqdn" -o tsv 2>/dev/null || echo "")
            else
              FQDN=$(az webapp show -n "$NAME" -g "$RG_NAME" --query "defaultHostName" -o tsv 2>/dev/null || echo "")
            fi

            if [[ -n "$FQDN" ]]; then
              HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "https://$FQDN" 2>/dev/null || echo "000")
              TEST_RESULTS="${TEST_RESULTS}\n- ${NAME}: https://${FQDN} → HTTP ${HTTP_CODE}"

              if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 400 ]]; then
                echo "✅ $NAME: HTTP $HTTP_CODE"
              else
                echo "⚠️ $NAME: HTTP $HTTP_CODE (may still be starting)"
              fi
            fi
          done

          echo "test_endpoints<<EOF" >> "$GITHUB_OUTPUT"
          echo -e "$TEST_RESULTS" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"

      - name: Save deployment state
        if: always()
        run: |
          DEPLOY_DIR="${{ steps.params.outputs.deploy_dir }}"
          STATUS="${{ steps.deploy.outputs.deploy_status || 'failed' }}"
          TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

          # Create/update state.json
          cat > "$DEPLOY_DIR/state.json" <<EOF
          {
            "deploymentId": "${{ matrix.deployment_id }}",
            "timestamp": "$TIMESTAMP",
            "status": "$STATUS",
            "duration": "${{ steps.deploy.outputs.deploy_duration }}",
            "subscription": "${{ secrets.AZURE_SUBSCRIPTION_ID }}",
            "location": "${{ steps.params.outputs.location }}",
            "project": "${{ steps.params.outputs.project }}",
            "environment": "${{ steps.params.outputs.environment }}",
            "resourceGroup": "${{ steps.deploy.outputs.resource_group }}",
            "triggeredBy": "${{ github.actor }}",
            "triggerEvent": "${{ github.event_name }}",
            "runId": "${{ github.run_id }}",
            "runUrl": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
          }
          EOF

      - name: Commit deployment state
        if: always()
        run: |
          DEPLOY_DIR="${{ steps.params.outputs.deploy_dir }}"
          STATUS="${{ steps.deploy.outputs.deploy_status }}"
          STATUS=${STATUS:-failed}

          # Update metadata.json status from pending to actual result
          if [[ -f "$DEPLOY_DIR/metadata.json" ]]; then
            jq --arg status "$STATUS" '.status = $status' \
              "$DEPLOY_DIR/metadata.json" > "$DEPLOY_DIR/metadata.json.tmp" \
              && mv "$DEPLOY_DIR/metadata.json.tmp" "$DEPLOY_DIR/metadata.json"
          fi

          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

          # Stash the updated state and metadata files before switching branches
          cp "$DEPLOY_DIR/state.json" /tmp/state.json 2>/dev/null || true
          cp "$DEPLOY_DIR/metadata.json" /tmp/metadata.json 2>/dev/null || true

          # Ensure we push to main regardless of which ref was checked out
          git fetch origin main
          git checkout main

          # Restore the updated state and metadata files onto main
          cp /tmp/state.json "$DEPLOY_DIR/state.json" 2>/dev/null || true
          cp /tmp/metadata.json "$DEPLOY_DIR/metadata.json" 2>/dev/null || true

          git add "$DEPLOY_DIR/state.json" "$DEPLOY_DIR/metadata.json"
          git diff --cached --quiet || git commit -m "git-ape: update state for ${{ matrix.deployment_id }} [$STATUS]"
          git push || echo "::warning::Could not push state update to main"

      - name: Post deployment result
        if: always() && github.event_name == 'issue_comment'
        uses: actions/github-script@v8
        with:
          script: |
            const deploymentId = '${{ matrix.deployment_id }}';
            const status = '${{ steps.deploy.outputs.deploy_status }}' || 'failed';
            const duration = '${{ steps.deploy.outputs.deploy_duration }}';
            const outputs = `${{ steps.deploy.outputs.deploy_outputs }}`;
            const resources = `${{ steps.tests.outputs.resources }}`;
            const testEndpoints = `${{ steps.tests.outputs.test_endpoints }}`;
            const runUrl = `${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}`;

            let comment = `## Git-Ape Deploy: \`${deploymentId}\`\n\n`;

            if (status === 'succeeded') {
              comment += `### ✅ Deployment Succeeded\n\n`;
              comment += `- **Duration:** ${duration}\n`;
              comment += `- **Workflow Run:** [View logs](${runUrl})\n\n`;

              if (testEndpoints) {
                comment += `### Endpoints\n\n${testEndpoints}\n\n`;
              }

              if (resources) {
                try {
                  const parsed = JSON.parse(resources);
                  comment += `### Resources (${parsed.length})\n\n`;
                  comment += `| Name | Type | Status |\n|------|------|--------|\n`;
                  for (const r of parsed) {
                    const icon = r.provisioningState === 'Succeeded' ? '✅' : '⚠️';
                    comment += `| ${r.name} | ${r.type} | ${icon} ${r.provisioningState} |\n`;
                  }
                  comment += '\n';
                } catch {}
              }
            } else {
              comment += `### ❌ Deployment Failed\n\n`;
              comment += `- **Workflow Run:** [View logs](${runUrl})\n\n`;
              const error = `${{ steps.deploy.outputs.deploy_error }}`;
              if (error) {
                comment += `\`\`\`\n${error.substring(0, 2000)}\n\`\`\`\n\n`;
              }
            }

            const marker = `<!-- git-ape-deploy:${deploymentId} -->`;
            comment = marker + '\n' + comment;

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: comment,
            });

      - name: Notify via Slack
        if: always()
        continue-on-error: true
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          if [[ -z "$SLACK_WEBHOOK_URL" ]]; then exit 0; fi

          STATUS="${{ steps.deploy.outputs.deploy_status }}"
          DEPLOY_ID="${{ matrix.deployment_id }}"
          DURATION="${{ steps.deploy.outputs.deploy_duration }}"
          RUN_URL="${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"

          if [[ "$STATUS" == "succeeded" ]]; then
            EMOJI="✅"
            MSG="Deployment *$DEPLOY_ID* succeeded in $DURATION"
          else
            EMOJI="❌"
            MSG="Deployment *$DEPLOY_ID* failed"
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
                    \"text\": \"$EMOJI *Git-Ape Deploy: $DEPLOY_ID*\\n\\n$MSG\\n\\nTriggered by: ${{ github.actor }}\\n<$RUN_URL|View logs>\"
                  }
                }
              ]
            }" || echo "::warning::Slack notification failed"

```

</details>
