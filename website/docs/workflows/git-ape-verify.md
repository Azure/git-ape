---
title: "Git-Ape: Verify Setup"
sidebar_label: "Verify Setup"
description: "GitHub Actions workflow: Git-Ape: Verify Setup"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-verify.exampleyml -->


# Git-Ape: Verify Setup

**Workflow file:** `.github/workflows/git-ape-verify.exampleyml`

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

      - name: Check required secrets
        id: secrets
        run: |
          MISSING=0

          if [[ -z "${{ secrets.AZURE_CLIENT_ID }}" ]]; then
            echo "::error::Missing secret: AZURE_CLIENT_ID"
            MISSING=$((MISSING + 1))
          else
            echo "✅ AZURE_CLIENT_ID is set"
          fi

          if [[ -z "${{ secrets.AZURE_TENANT_ID }}" ]]; then
            echo "::error::Missing secret: AZURE_TENANT_ID"
            MISSING=$((MISSING + 1))
          else
            echo "✅ AZURE_TENANT_ID is set"
          fi

          if [[ -z "${{ secrets.AZURE_SUBSCRIPTION_ID }}" ]]; then
            echo "::error::Missing secret: AZURE_SUBSCRIPTION_ID"
            MISSING=$((MISSING + 1))
          else
            echo "✅ AZURE_SUBSCRIPTION_ID is set"
          fi

          echo "missing=$MISSING" >> "$GITHUB_OUTPUT"

      - name: Test OIDC login
        id: login
        if: steps.secrets.outputs.missing == '0'
        uses: azure/login@v3
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Verify Azure access
        if: steps.secrets.outputs.missing == '0'
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
          SP_ID=$(az ad sp show --id "${{ secrets.AZURE_CLIENT_ID }}" --query id -o tsv 2>/dev/null || echo "")
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
            "git-ape-drift.yml:Git-Ape: Drift Detection"
            "git-ape-ttl-reaper.yml:Git-Ape: TTL Reaper"
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
            echo "❌ Setup incomplete — ${{ steps.secrets.outputs.missing }} secret(s) missing"
            echo "   Run: @Git-Ape Onboarding or /git-ape-onboarding"
          else
            echo "✅ Git-Ape setup verified successfully!"
            echo ""
            echo "Next steps:"
            echo "  1. Add a deployment under .azure/deployments/"
            echo "  2. Open a PR to trigger the plan workflow"
            echo "  3. Merge or comment /deploy to deploy"
          fi

```

</details>
