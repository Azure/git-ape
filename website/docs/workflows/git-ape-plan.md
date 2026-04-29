---
title: "Git-Ape: Plan"
sidebar_label: "Plan"
description: "GitHub Actions workflow: Git-Ape: Plan"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-plan.exampleyml -->


# Git-Ape: Plan

**Workflow file:** `.github/workflows/git-ape-plan.exampleyml`

## Triggers

- **`pull_request`** — paths: `.azure/deployments/**/template.json, .azure/deployments/**/parameters.json` — types: `opened, synchronize`


## Permissions

- `actions: read`
- `id-token: write`
- `contents: read`
- `pull-requests: write`
- `security-events: write`

## Jobs

### `detect-deployments`

| Property | Value |
|----------|-------|
| **Display Name** | Detect changed deployments |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 2 |

### `plan-local`

| Property | Value |
|----------|-------|
| **Display Name** | Plan Local: ${{ matrix.deployment_id }} |
| **Runs On** | `ubuntu-latest` |
| **Depends On** | `detect-deployments` |
| **Steps** | 10 |

### `plan-azure`

| Property | Value |
|----------|-------|
| **Display Name** | Plan Azure: ${{ matrix.deployment_id }} |
| **Runs On** | `ubuntu-latest` |
| **Depends On** | `detect-deployments` |
| **Steps** | 7 |

### `plan-comment`

| Property | Value |
|----------|-------|
| **Display Name** | Plan Comment: ${{ matrix.deployment_id }} |
| **Runs On** | `ubuntu-latest` |
| **Depends On** | `detect-deployments`, `plan-local`, `plan-azure` |
| **Steps** | 3 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
# Git-Ape Planning Workflow
# Triggers when a PR adds/modifies deployment artifacts under .azure/deployments/
# Validates the ARM template, runs what-if analysis, and posts the plan as a PR comment.

name: "Git-Ape: Plan"

env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - ".azure/deployments/**/template.json"
      - ".azure/deployments/**/parameters.json"

permissions:
  actions: read          # Download artifacts between jobs
  id-token: write         # OIDC token for Azure login
  contents: read           # Read repo contents
  pull-requests: write     # Post plan as PR comment
  security-events: write   # Upload SARIF results from template analyzer

concurrency:
  group: git-ape-plan-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  detect-deployments:
    name: Detect changed deployments
    runs-on: ubuntu-latest
    outputs:
      deployment_ids: ${{ steps.find.outputs.deployment_ids }}
      has_deployments: ${{ steps.find.outputs.has_deployments }}
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Find deployment directories with changes
        id: find
        run: |
          # Find all deployment directories that have template.json changes in this PR
          CHANGED_FILES=$(git diff --name-only origin/${{ github.base_ref }}...HEAD -- '.azure/deployments/*/template.json' '.azure/deployments/*/parameters.json')

          if [[ -z "$CHANGED_FILES" ]]; then
            echo "has_deployments=false" >> "$GITHUB_OUTPUT"
            echo "deployment_ids=[]" >> "$GITHUB_OUTPUT"
            echo "No deployment changes detected"
            exit 0
          fi

          # Extract unique deployment IDs
          DEPLOYMENT_IDS=$(echo "$CHANGED_FILES" | sed 's|.azure/deployments/\([^/]*\)/.*|\1|' | sort -u | jq -R -s -c 'split("\n") | map(select(. != ""))')

          echo "has_deployments=true" >> "$GITHUB_OUTPUT"
          echo "deployment_ids=$DEPLOYMENT_IDS" >> "$GITHUB_OUTPUT"
          echo "Detected deployments: $DEPLOYMENT_IDS"

  plan-local:
    name: "Plan Local: ${{ matrix.deployment_id }}"
    needs: detect-deployments
    if: needs.detect-deployments.outputs.has_deployments == 'true'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        deployment_id: ${{ fromJson(needs.detect-deployments.outputs.deployment_ids) }}
      fail-fast: false

    steps:
      - uses: actions/checkout@v6

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
          else
            LOCATION="eastus"
          fi

          echo "location=$LOCATION" >> "$GITHUB_OUTPUT"
          echo "deploy_dir=$DEPLOY_DIR" >> "$GITHUB_OUTPUT"

      - name: Enforce required tags
        id: tags
        run: |
          TEMPLATE="${{ steps.params.outputs.deploy_dir }}/template.json"
          REQUIRED_TAGS=("Environment" "Project" "ManagedBy" "CreatedDate")
          MISSING_TAGS=""

          HAS_TAG_VAR=$(jq 'has("variables") and (.variables | has("tags"))' "$TEMPLATE")
          RESOURCES_WITHOUT_TAGS=$(jq -r '
            [.resources[] |
              select(.type == "Microsoft.Resources/resourceGroups") |
              select(.tags == null or .tags == "") |
              .name
            ] | join(", ")
          ' "$TEMPLATE")

          if [[ -n "$RESOURCES_WITHOUT_TAGS" ]]; then
            MISSING_TAGS="Resource groups missing tags: $RESOURCES_WITHOUT_TAGS"
          fi

          if [[ "$HAS_TAG_VAR" == "true" ]]; then
            for TAG in "${REQUIRED_TAGS[@]}"; do
              TAG_EXISTS=$(jq --arg t "$TAG" '.variables.tags | has($t)' "$TEMPLATE")
              if [[ "$TAG_EXISTS" != "true" ]]; then
                MISSING_TAGS="${MISSING_TAGS}Missing required tag: $TAG\n"
              fi
            done
          fi

          if [[ -n "$MISSING_TAGS" ]]; then
            echo "tag_status=failed" >> "$GITHUB_OUTPUT"
            echo "tag_details<<EOF" >> "$GITHUB_OUTPUT"
            echo -e "$MISSING_TAGS" >> "$GITHUB_OUTPUT"
            echo "EOF" >> "$GITHUB_OUTPUT"
            echo "::warning::Tag enforcement: missing required tags"
          else
            echo "tag_status=passed" >> "$GITHUB_OUTPUT"
            echo "All required tags present: ${REQUIRED_TAGS[*]}"
          fi

      - name: Estimate deployment cost
        id: cost
        run: |
          TEMPLATE="${{ steps.params.outputs.deploy_dir }}/template.json"
          REGION="${{ steps.params.outputs.location }}"
          COST_TABLE="| Resource Type | SKU | Est. Monthly |\n|---|---|---|\n"
          TOTAL=0
          COST_NOTES=""

          COST_FILE="${{ steps.params.outputs.deploy_dir }}/cost-estimate.json"
          if [[ -f "$COST_FILE" ]]; then
            TOTAL=$(jq -r '.monthlyTotal // 0' "$COST_FILE")
            COST_TABLE=$(jq -r '.resources[] | "| \(.type) | \(.sku // "-") | $\(.monthlyEstimate) |"' "$COST_FILE" | sort)
            COST_TABLE="| Resource Type | SKU | Est. Monthly |\n|---|---|---|\n${COST_TABLE}"
          else
            VM_SKUS=$(jq -r '
              [.. | objects | select(.type? == "Microsoft.Compute/virtualMachines") | .properties.hardwareProfile.vmSize // empty] | unique | .[]
            ' "$TEMPLATE" 2>/dev/null || true)

            ASP_SKUS=$(jq -r '
              [.. | objects | select(.type? == "Microsoft.Web/serverfarms") | .sku.name // empty] | unique | .[]
            ' "$TEMPLATE" 2>/dev/null || true)

            for SKU in $VM_SKUS; do
              PRICE=$(curl -sf "https://prices.azure.com/api/retail/prices?\$filter=serviceName%20eq%20%27Virtual%20Machines%27%20and%20armRegionName%20eq%20%27${REGION}%27%20and%20armSkuName%20eq%20%27${SKU}%27%20and%20priceType%20eq%20%27Consumption%27" \
                | jq '[.Items[] | select(.isPrimaryMeterRegion == true and (.productName | test("Windows") | not))] | .[0].retailPrice // 0' 2>/dev/null || echo 0)
              MONTHLY=$(echo "$PRICE * 730" | bc -l 2>/dev/null | xargs printf "%.2f" 2>/dev/null || echo "0.00")
              COST_TABLE="${COST_TABLE}| Virtual Machine | ${SKU} | \$${MONTHLY} |\n"
              TOTAL=$(echo "$TOTAL + $MONTHLY" | bc -l 2>/dev/null || echo "$TOTAL")
            done

            for SKU in $ASP_SKUS; do
              PRICE=$(curl -sf "https://prices.azure.com/api/retail/prices?\$filter=serviceName%20eq%20%27Azure%20App%20Service%27%20and%20armRegionName%20eq%20%27${REGION}%27%20and%20armSkuName%20eq%20%27${SKU}%27%20and%20priceType%20eq%20%27Consumption%27" \
                | jq '[.Items[] | select(.isPrimaryMeterRegion == true)] | .[0].retailPrice // 0' 2>/dev/null || echo 0)
              MONTHLY=$(echo "$PRICE * 730" | bc -l 2>/dev/null | xargs printf "%.2f" 2>/dev/null || echo "0.00")
              COST_TABLE="${COST_TABLE}| App Service Plan | ${SKU} | \$${MONTHLY} |\n"
              TOTAL=$(echo "$TOTAL + $MONTHLY" | bc -l 2>/dev/null || echo "$TOTAL")
            done

            HAS_FUNCTIONS=$(jq '[.. | objects | select(.type? == "Microsoft.Web/sites" and (.kind? // "" | test("functionapp")))] | length' "$TEMPLATE" 2>/dev/null || echo 0)
            if [[ "$HAS_FUNCTIONS" -gt 0 ]]; then
              COST_TABLE="${COST_TABLE}| Function App (Consumption) | - | \$0.00* |\n"
              COST_NOTES="*Function Apps on Consumption plan: first 1M executions + 400K GB-s free/month"
            fi
          fi

          TOTAL_FMT=$(printf "%.2f" "$TOTAL" 2>/dev/null || echo "0.00")
          echo "cost_total=$TOTAL_FMT" >> "$GITHUB_OUTPUT"
          echo "cost_table<<EOF" >> "$GITHUB_OUTPUT"
          echo -e "$COST_TABLE" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"
          echo "cost_notes<<EOF" >> "$GITHUB_OUTPUT"
          echo "$COST_NOTES" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"

      - name: Read architecture diagram
        id: architecture
        run: |
          ARCH_FILE="${{ steps.params.outputs.deploy_dir }}/architecture.md"
          if [[ -f "$ARCH_FILE" ]]; then
            echo "has_architecture=true" >> "$GITHUB_OUTPUT"
            {
              echo "architecture_content<<EOF"
              cat "$ARCH_FILE"
              echo "EOF"
            } >> "$GITHUB_OUTPUT"
          else
            echo "has_architecture=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Run Microsoft Defender for DevOps template analyzer
        id: security_scan
        continue-on-error: true
        uses: microsoft/security-devops-action@v1
        with:
          tools: templateanalyzer
        env:
          GDN_TEMPLATEANALYZER_INPUT: ${{ steps.params.outputs.deploy_dir }}/template.json

      - name: Upload SARIF results (non-blocking)
        id: sarif_upload
        if: always() && steps.security_scan.outputs.sarifFile != ''
        continue-on-error: true
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: ${{ steps.security_scan.outputs.sarifFile }}
          category: templateanalyzer

      - name: Parse security scan results
        id: scan_results
        if: always()
        run: |
          SARIF_FILE="${{ steps.security_scan.outputs.sarifFile }}"
          if [[ -f "$SARIF_FILE" ]]; then
            ERRORS=$(jq '[.runs[].results[] | select(.level == "error")] | length' "$SARIF_FILE" 2>/dev/null || echo 0)
            WARNINGS=$(jq '[.runs[].results[] | select(.level == "warning")] | length' "$SARIF_FILE" 2>/dev/null || echo 0)
            NOTES=$(jq '[.runs[].results[] | select(.level == "note" or .level == "none")] | length' "$SARIF_FILE" 2>/dev/null || echo 0)

            echo "scan_errors=$ERRORS" >> "$GITHUB_OUTPUT"
            echo "scan_warnings=$WARNINGS" >> "$GITHUB_OUTPUT"
            echo "scan_notes=$NOTES" >> "$GITHUB_OUTPUT"

            if [[ "$ERRORS" -gt 0 ]]; then
              echo "scan_status=failed" >> "$GITHUB_OUTPUT"
            else
              echo "scan_status=passed" >> "$GITHUB_OUTPUT"
            fi

            FINDINGS=$(jq -r '.runs[].results[] | "- **\(.level | ascii_upcase):** \(.message.text) (\(.ruleId))"' "$SARIF_FILE" 2>/dev/null || echo "")
            echo "scan_findings<<EOF" >> "$GITHUB_OUTPUT"
            echo "$FINDINGS" >> "$GITHUB_OUTPUT"
            echo "EOF" >> "$GITHUB_OUTPUT"
          else
            echo "scan_status=skipped" >> "$GITHUB_OUTPUT"
            echo "scan_errors=0" >> "$GITHUB_OUTPUT"
            echo "scan_warnings=0" >> "$GITHUB_OUTPUT"
            echo "scan_notes=0" >> "$GITHUB_OUTPUT"
            echo "scan_findings=" >> "$GITHUB_OUTPUT"
          fi

      - name: Build local summary artifact
        if: always()
        env:
          DEPLOYMENT_ID: ${{ matrix.deployment_id }}
          TAG_STATUS: ${{ steps.tags.outputs.tag_status }}
          TAG_DETAILS: ${{ steps.tags.outputs.tag_details }}
          COST_TOTAL: ${{ steps.cost.outputs.cost_total }}
          COST_TABLE: ${{ steps.cost.outputs.cost_table }}
          COST_NOTES: ${{ steps.cost.outputs.cost_notes }}
          HAS_ARCHITECTURE: ${{ steps.architecture.outputs.has_architecture }}
          ARCHITECTURE_CONTENT: ${{ steps.architecture.outputs.architecture_content }}
          SCAN_STATUS: ${{ steps.scan_results.outputs.scan_status }}
          SCAN_ERRORS: ${{ steps.scan_results.outputs.scan_errors }}
          SCAN_WARNINGS: ${{ steps.scan_results.outputs.scan_warnings }}
          SCAN_NOTES: ${{ steps.scan_results.outputs.scan_notes }}
          SCAN_FINDINGS: ${{ steps.scan_results.outputs.scan_findings }}
          SARIF_UPLOAD_OUTCOME: ${{ steps.sarif_upload.outcome }}
          SECURITY_SCAN_OUTCOME: ${{ steps.security_scan.outcome }}
        run: |
          mkdir -p .git-ape-plan
          jq -n \
            --arg deploymentId "$DEPLOYMENT_ID" \
            --arg tagStatus "$TAG_STATUS" \
            --arg tagDetails "$TAG_DETAILS" \
            --arg costTotal "$COST_TOTAL" \
            --arg costTable "$COST_TABLE" \
            --arg costNotes "$COST_NOTES" \
            --arg hasArchitecture "$HAS_ARCHITECTURE" \
            --arg architectureContent "$ARCHITECTURE_CONTENT" \
            --arg scanStatus "$SCAN_STATUS" \
            --arg scanErrors "$SCAN_ERRORS" \
            --arg scanWarnings "$SCAN_WARNINGS" \
            --arg scanNotes "$SCAN_NOTES" \
            --arg scanFindings "$SCAN_FINDINGS" \
            --arg sarifUploadOutcome "$SARIF_UPLOAD_OUTCOME" \
            --arg securityScanOutcome "$SECURITY_SCAN_OUTCOME" \
            '{
              deploymentId: $deploymentId,
              tagStatus: $tagStatus,
              tagDetails: $tagDetails,
              costTotal: $costTotal,
              costTable: $costTable,
              costNotes: $costNotes,
              hasArchitecture: $hasArchitecture,
              architectureContent: $architectureContent,
              scanStatus: $scanStatus,
              scanErrors: $scanErrors,
              scanWarnings: $scanWarnings,
              scanNotes: $scanNotes,
              scanFindings: $scanFindings,
              sarifUploadOutcome: $sarifUploadOutcome,
              securityScanOutcome: $securityScanOutcome
            }' > ".git-ape-plan/plan-local-${DEPLOYMENT_ID}.json"

      - name: Upload local summary artifact
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: plan-local-${{ matrix.deployment_id }}
          path: .git-ape-plan/plan-local-${{ matrix.deployment_id }}.json
          if-no-files-found: error
          retention-days: 1

  plan-azure:
    name: "Plan Azure: ${{ matrix.deployment_id }}"
    needs: detect-deployments
    if: needs.detect-deployments.outputs.has_deployments == 'true'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        deployment_id: ${{ fromJson(needs.detect-deployments.outputs.deployment_ids) }}
      fail-fast: false

    steps:
      - uses: actions/checkout@v6

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
          else
            LOCATION="eastus"
          fi

          echo "location=$LOCATION" >> "$GITHUB_OUTPUT"
          echo "deploy_dir=$DEPLOY_DIR" >> "$GITHUB_OUTPUT"

      - name: Azure Login (OIDC)
        id: azure_login
        continue-on-error: true
        uses: azure/login@v3
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Validate template
        id: validate
        if: steps.azure_login.outcome == 'success'
        run: |
          echo "### Validating ARM template..."

          RESULT=$(az deployment sub validate \
            --location "${{ steps.params.outputs.location }}" \
            --template-file "${{ steps.params.outputs.deploy_dir }}/template.json" \
            --parameters @"${{ steps.params.outputs.deploy_dir }}/parameters.json" \
            --output json 2>&1) || true

          # Guard against non-JSON output (e.g. auth/CLI errors) — jq exits non-zero
          # on invalid input which would crash the script under bash -e.
          ERROR=$(echo "$RESULT" | jq -r '.error // empty' 2>/dev/null || echo "")

          if [[ -n "$ERROR" && "$ERROR" != "null" ]]; then
            echo "validation_status=failed" >> "$GITHUB_OUTPUT"
            echo "validation_error<<EOF" >> "$GITHUB_OUTPUT"
            echo "$RESULT" >> "$GITHUB_OUTPUT"
            echo "EOF" >> "$GITHUB_OUTPUT"
          elif echo "$RESULT" | jq -e . >/dev/null 2>&1; then
            echo "validation_status=passed" >> "$GITHUB_OUTPUT"
          else
            # az returned non-JSON (e.g. a plain-text error or auth failure)
            echo "validation_status=failed" >> "$GITHUB_OUTPUT"
            echo "validation_error<<EOF" >> "$GITHUB_OUTPUT"
            echo "$RESULT" >> "$GITHUB_OUTPUT"
            echo "EOF" >> "$GITHUB_OUTPUT"
          fi

      - name: Run what-if analysis
        id: whatif
        if: steps.validate.outputs.validation_status == 'passed'
        run: |
          WHATIF_OUTPUT=$(az deployment sub what-if \
            --location "${{ steps.params.outputs.location }}" \
            --template-file "${{ steps.params.outputs.deploy_dir }}/template.json" \
            --parameters @"${{ steps.params.outputs.deploy_dir }}/parameters.json" \
            --no-prompt 2>&1) || true

          echo "whatif_result<<EOF" >> "$GITHUB_OUTPUT"
          echo "$WHATIF_OUTPUT" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"

      - name: Build Azure summary artifact
        if: always()
        env:
          DEPLOYMENT_ID: ${{ matrix.deployment_id }}
          AZURE_LOGIN_OUTCOME: ${{ steps.azure_login.outcome }}
          VALIDATION_STATUS: ${{ steps.validate.outputs.validation_status }}
          VALIDATION_ERROR: ${{ steps.validate.outputs.validation_error }}
          WHATIF_RESULT: ${{ steps.whatif.outputs.whatif_result }}
        run: |
          mkdir -p .git-ape-plan
          FINAL_VALIDATION_STATUS="$VALIDATION_STATUS"
          if [[ -z "$FINAL_VALIDATION_STATUS" ]]; then
            if [[ "$AZURE_LOGIN_OUTCOME" == "failure" ]]; then
              FINAL_VALIDATION_STATUS="login_failed"
            else
              FINAL_VALIDATION_STATUS="skipped"
            fi
          fi

          jq -n \
            --arg deploymentId "$DEPLOYMENT_ID" \
            --arg azureLoginOutcome "$AZURE_LOGIN_OUTCOME" \
            --arg validationStatus "$FINAL_VALIDATION_STATUS" \
            --arg validationError "$VALIDATION_ERROR" \
            --arg whatifResult "$WHATIF_RESULT" \
            '{
              deploymentId: $deploymentId,
              azureLoginOutcome: $azureLoginOutcome,
              validationStatus: $validationStatus,
              validationError: $validationError,
              whatifResult: $whatifResult
            }' > ".git-ape-plan/plan-azure-${DEPLOYMENT_ID}.json"

      - name: Upload Azure summary artifact
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: plan-azure-${{ matrix.deployment_id }}
          path: .git-ape-plan/plan-azure-${{ matrix.deployment_id }}.json
          if-no-files-found: error
          retention-days: 1

  plan-comment:
    name: "Plan Comment: ${{ matrix.deployment_id }}"
    needs: [detect-deployments, plan-local, plan-azure]
    if: always() && needs.detect-deployments.outputs.has_deployments == 'true'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        deployment_id: ${{ fromJson(needs.detect-deployments.outputs.deployment_ids) }}
      fail-fast: false

    steps:
      - name: Download local summary artifact
        continue-on-error: true
        uses: actions/download-artifact@v8
        with:
          name: plan-local-${{ matrix.deployment_id }}
          path: .git-ape-plan/local

      - name: Download Azure summary artifact
        continue-on-error: true
        uses: actions/download-artifact@v8
        with:
          name: plan-azure-${{ matrix.deployment_id }}
          path: .git-ape-plan/azure

      - name: Post plan as PR comment
        uses: actions/github-script@v8
        with:
          script: |
            const fs = require('fs');
            const deploymentId = '${{ matrix.deployment_id }}';

            function loadSummary(kind) {
              const path = `.git-ape-plan/${kind}/plan-${kind}-${deploymentId}.json`;
              if (!fs.existsSync(path)) {
                return null;
              }
              return JSON.parse(fs.readFileSync(path, 'utf8'));
            }

            const local = loadSummary('local') || {};
            const azure = loadSummary('azure') || {};

            const validationStatus = azure.validationStatus || 'skipped';
            const validationError = azure.validationError || '';
            const whatifResult = azure.whatifResult || '';
            const azureLoginOutcome = azure.azureLoginOutcome || '';
            const scanStatus = local.scanStatus || 'skipped';
            const scanErrors = local.scanErrors || '0';
            const scanWarnings = local.scanWarnings || '0';
            const scanNotes = local.scanNotes || '0';
            const scanFindings = local.scanFindings || '';
            const sarifUploadOutcome = local.sarifUploadOutcome || '';
            const securityScanOutcome = local.securityScanOutcome || '';
            const tagStatus = local.tagStatus || '';
            const tagDetails = local.tagDetails || '';
            const costTotal = local.costTotal || '';
            const costTable = local.costTable || '';
            const costNotes = local.costNotes || '';
            const hasArchitecture = local.hasArchitecture === 'true';
            const architectureContent = local.architectureContent || '';

            let comment = `## Git-Ape Plan: \`${deploymentId}\`\n\n`;

            if (validationStatus === 'passed') {
              comment += `### ✅ Template Validation: Passed\n\n`;
            } else if (validationStatus === 'failed') {
              comment += `### ❌ Template Validation: Failed\n\n`;
              comment += `\`\`\`\n${validationError}\n\`\`\`\n\n`;
              comment += `> Fix the template and push again to re-run validation.\n\n`;
            } else if (validationStatus === 'login_failed') {
              comment += `### ❌ Azure Login: Failed\n\n`;
              comment += `> OIDC login failed, so Azure validation and what-if did not run.\n\n`;
            } else {
              comment += `### ⚠️ Template Validation: Skipped\n\n`;
            }

            if (tagStatus === 'passed') {
              comment += `### ✅ Tag Enforcement: Passed\n\n`;
            } else if (tagStatus === 'failed') {
              comment += `### ⚠️ Tag Enforcement: Issues Found\n\n`;
              comment += `${tagDetails}\n\n`;
            }

            if (validationStatus === 'passed') {
              if (securityScanOutcome === 'failure' && scanStatus === 'skipped') {
                comment += `### ⚠️ Security Scan: Tool Execution Failed\n\n`;
              } else if (scanStatus === 'passed') {
                comment += `### ✅ Security Scan: Passed`;
                if (parseInt(scanWarnings) > 0 || parseInt(scanNotes) > 0) {
                  comment += ` (${scanWarnings} warning(s), ${scanNotes} note(s))`;
                }
                comment += `\n\n`;
              } else if (scanStatus === 'failed') {
                comment += `### ❌ Security Scan: Failed (${scanErrors} error(s), ${scanWarnings} warning(s))\n\n`;
              } else {
                comment += `### ⚠️ Security Scan: Skipped\n\n`;
              }

              if (scanFindings) {
                comment += `<details>\n<summary>Security findings</summary>\n\n${scanFindings}\n\n</details>\n\n`;
              }
              if (sarifUploadOutcome === 'failure') {
                comment += `> SARIF upload to GitHub code scanning failed, but this does not block plan generation.\n\n`;
              }
            }

            if (costTotal && validationStatus === 'passed') {
              comment += `### 💰 Estimated Monthly Cost: $${costTotal}\n\n`;
              comment += `${costTable}\n`;
              if (costNotes) {
                comment += `\n> ${costNotes}\n\n`;
              }
              comment += `*Retail pay-as-you-go pricing from Azure Retail Prices API*\n\n`;
            }

            if (hasArchitecture) {
              comment += `### Architecture\n\n${architectureContent}\n\n`;
            }

            if (validationStatus === 'passed' && whatifResult) {
              comment += `### What-If Analysis\n\n`;
              comment += `\`\`\`\n${whatifResult}\n\`\`\`\n\n`;
            }

            if (validationStatus === 'passed') {
              comment += `---\n`;
              comment += `### Next Steps\n\n`;
              comment += `1. Review the plan above\n`;
              comment += `2. Approve and merge this PR to trigger deployment\n`;
              comment += `3. Or comment \`/deploy\` to deploy from this branch before merging\n`;
            }

            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
            });

            const marker = `<!-- git-ape-plan:${deploymentId} -->`;
            comment = marker + '\n' + comment;
            const existing = comments.find(c => c.body.includes(marker));

            if (existing) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: existing.id,
                body: comment,
              });
            } else {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: comment,
              });
            }

```

</details>
