---
title: "Git-Ape: Verify Setup"
sidebar_label: "Verify Setup"
description: "GitHub Actions workflow: Git-Ape: Verify Setup"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/git-ape-onboarding/templates/workflows/git-ape-verify.yml -->


# Git-Ape: Verify Setup

**Workflow file:** `.github/skills/git-ape-onboarding/templates/workflows/git-ape-verify.yml`

:::info[Scaffolded by `/git-ape-onboarding`]
This workflow is **shipped as a template** under `.github/skills/git-ape-onboarding/templates/workflows/` and copied into your repository's `.github/workflows/` by the [`/git-ape-onboarding`](/docs/skills/git-ape-onboarding) flow. It does **not** run in the git-ape repo itself.
:::

## Triggers

- **`workflow_dispatch`**


## Permissions

- `id-token: write`
- `contents: read`

## Jobs

### `verify`

| Property | Value |
|----------|-------|
| **Display Name** | Verify Git-Ape configuration |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 6 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
# Git-Ape Setup Verification Workflow
# Run manually after onboarding to verify OIDC, RBAC, and GitHub configuration.

name: "Git-Ape: Verify Setup"

on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  verify:
    name: Verify Git-Ape configuration
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Check required secrets and variables
        id: secrets
        env:
          # Route secret/variable presence through env booleans rather than inlining
          # ${{ secrets.* }} into shell conditionals (GitHub Actions hardening).
          HAS_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID != '' }}
          HAS_TENANT_ID: ${{ secrets.AZURE_TENANT_ID != '' }}
          HAS_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID != '' }}
          HAS_COPILOT_TOKEN: ${{ secrets.COPILOT_GITHUB_TOKEN != '' }}
        run: |
          MISSING=0

          if [[ "$HAS_CLIENT_ID" != "true" ]]; then
            echo "::error::Missing secret: AZURE_CLIENT_ID"
            MISSING=$((MISSING + 1))
          else
            echo "✅ AZURE_CLIENT_ID is set"
          fi

          if [[ "$HAS_TENANT_ID" != "true" ]]; then
            echo "::error::Missing secret: AZURE_TENANT_ID"
            MISSING=$((MISSING + 1))
          else
            echo "✅ AZURE_TENANT_ID is set"
          fi

          if [[ "$HAS_SUBSCRIPTION_ID" != "true" ]]; then
            echo "::error::Missing variable: AZURE_SUBSCRIPTION_ID"
            MISSING=$((MISSING + 1))
          else
            echo "✅ AZURE_SUBSCRIPTION_ID is set"
          fi

          # COPILOT_GITHUB_TOKEN is OPTIONAL — only the agentic drift-detection
          # workflow (git-ape-drift) needs it. Report as a warning and never
          # count it toward MISSING, so plan/deploy/destroy verification still
          # passes when drift detection is not enabled.
          if [[ "$HAS_COPILOT_TOKEN" != "true" ]]; then
            echo "::warning::COPILOT_GITHUB_TOKEN not set — optional, required only for the drift-detection workflow (git-ape-drift)"
            echo "⚠️ COPILOT_GITHUB_TOKEN not set (optional — needed only for drift detection)"
          else
            echo "✅ COPILOT_GITHUB_TOKEN is set (drift detection enabled)"
          fi

          echo "missing=$MISSING" >> "$GITHUB_OUTPUT"

      - name: Test OIDC login
        id: login
        if: steps.secrets.outputs.missing == '0'
        uses: azure/login@v3
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Verify Azure access
        if: steps.secrets.outputs.missing == '0'
        env:
          AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
        run: |
          echo "## Azure Connection"
          echo ""

          # Show account info
          ACCOUNT=$(az account show -o json)
          SUB_NAME=$(echo "$ACCOUNT" | jq -r '.name')
          SUB_ID=$(echo "$ACCOUNT" | jq -r '.id')
          TENANT=$(echo "$ACCOUNT" | jq -r '.tenantId')

          echo "✅ Logged in successfully"
          echo "  Subscription: $SUB_NAME ($SUB_ID)"
          echo "  Tenant: $TENANT"

          # Check RBAC roles
          echo ""
          echo "## RBAC Roles"
          SP_ID=$(az ad sp show --id "$AZURE_CLIENT_ID" --query id -o tsv 2>/dev/null || echo "")
          if [[ -n "$SP_ID" ]]; then
            az role assignment list --assignee "$SP_ID" \
              --query "[].{role:roleDefinitionName, scope:scope}" -o table
          else
            echo "⚠️ Could not resolve service principal"
          fi

          # Test resource group listing (read access)
          echo ""
          echo "## Read Access Test"
          RG_COUNT=$(az group list --query "length(@)" -o tsv 2>/dev/null || echo "0")
          echo "✅ Can list resource groups ($RG_COUNT found)"

          # Test subscription-level deployment validation
          echo ""
          echo "## Deployment Permission Test"
          VALIDATE=$(az deployment sub validate \
            --location eastus \
            --template-file /dev/stdin <<'EOF' 2>&1 || true
          {
            "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
            "contentVersion": "1.0.0.0",
            "resources": []
          }
          EOF
          )

          if echo "$VALIDATE" | grep -q "error"; then
            echo "❌ Deployment validation failed — may lack Contributor role"
            echo "$VALIDATE" | head -5
          else
            echo "✅ Subscription-level deployment validation passed"
          fi

      - name: Check workflow files
        run: |
          echo "## Workflow Files"
          echo ""

          WORKFLOWS=(
            "git-ape-plan.yml:Git-Ape: Plan"
            "git-ape-deploy.yml:Git-Ape: Deploy"
            "git-ape-destroy.yml:Git-Ape: Destroy"
            "git-ape-verify.yml:Git-Ape: Verify Setup"
            "git-ape-drift.lock.yml:Git-Ape: Drift Detection"
          )

          for WF in "${WORKFLOWS[@]}"; do
            FILE=$(echo "$WF" | cut -d: -f1)
            NAME=$(echo "$WF" | cut -d: -f2)
            if [[ -f ".github/workflows/$FILE" ]]; then
              echo "✅ $NAME ($FILE)"
            else
              echo "⚠️ $NAME ($FILE) — not found"
            fi
          done

      - name: Print summary
        if: always()
        run: |
          echo ""
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo ""

          if [[ "${{ steps.secrets.outputs.missing }}" != "0" ]]; then
            echo "❌ Setup incomplete — ${{ steps.secrets.outputs.missing }} required value(s) missing"
            echo "   Run: @Git-Ape Onboarding or /git-ape-onboarding"
          else
            echo "✅ Git-Ape setup verified successfully!"
            echo ""
            echo "Next steps:"
            echo "  1. Add a deployment under .azure/deployments/"
            echo "  2. Open a PR to trigger the plan workflow"
            echo "  3. Merge to main to deploy"
          fi

```

</details>
