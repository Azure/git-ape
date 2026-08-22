# Lab 3: Multi-Environment Promotion

> 15 minutes | Azure required

Set up dev and staging environments with separate parameter files and promote a deployment.

## What You Learn

- How to structure parameter files for multiple environments
- How GitHub environments provide deployment isolation
- How to promote from dev to staging

## Step 1: Understand the Environment Structure

Git-Ape supports multi-environment deployments with:

- **Separate Azure subscriptions** (or resource groups) per environment
- **Environment-specific parameter files** that override defaults
- **GitHub environments** with protection rules

## Step 2: Create Environment Parameter Files

Create a deployment directory with environment-specific parameters:

**Bash / macOS / Linux:**

```bash
mkdir -p .azure/deployments/multi-env-demo
```

**PowerShell / Windows:**

```powershell
New-Item -ItemType Directory -Force -Path .azure/deployments/multi-env-demo
```

Create the dev parameter file:

**Bash / macOS / Linux:**

```bash
cat > .azure/deployments/multi-env-demo/parameters.dev.json << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "dev" },
    "location": { "value": "eastus" },
    "appServicePlanSku": { "value": "B1" },
    "sqlDatabaseSku": { "value": "Basic" }
  }
}
EOF
```

**PowerShell / Windows:**

```powershell
@'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "dev" },
    "location": { "value": "eastus" },
    "appServicePlanSku": { "value": "B1" },
    "sqlDatabaseSku": { "value": "Basic" }
  }
}
'@ | Set-Content .azure/deployments/multi-env-demo/parameters.dev.json
```

Create the staging parameter file with upgraded SKUs:

**Bash / macOS / Linux:**

```bash
cat > .azure/deployments/multi-env-demo/parameters.staging.json << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "staging" },
    "location": { "value": "eastus" },
    "appServicePlanSku": { "value": "S1" },
    "sqlDatabaseSku": { "value": "S0" }
  }
}
EOF
```

**PowerShell / Windows:**

```powershell
@'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "staging" },
    "location": { "value": "eastus" },
    "appServicePlanSku": { "value": "S1" },
    "sqlDatabaseSku": { "value": "S0" }
  }
}
'@ | Set-Content .azure/deployments/multi-env-demo/parameters.staging.json
```

## Step 3: Deploy to Dev First

In Copilot Chat:

```text
@git-ape deploy using the multi-env-demo template with dev parameters
```

Review the plan, confirm, and deploy.

## Step 4: Promote to Staging

After dev succeeds, promote to staging by pointing at the staging parameter file:

```text
@git-ape deploy using the multi-env-demo template with staging parameters
```

Notice the differences:

- Resource names change: `rg-...-dev-...` → `rg-...-staging-...`
- SKUs upgrade: B1 → S1, Basic → S0
- Cost estimate increases with higher tiers

## Step 5: Compare Environments

Use the cost estimator to compare:

```text
/azure-cost-estimator compare dev and staging for multi-env-demo
```

| Resource | Dev (B1/Basic) | Staging (S1/S0) |
|----------|---------------|-----------------|
| App Service Plan | $13.14 | $73.00 |
| SQL Database | $4.99 | $15.03 |
| **Total** | **$20.96** | **$92.03** |

## What You Learned

| Concept | What It Means |
|---------|--------------|
| **Environment-specific parameters** | Same template, different configurations per environment |
| **SKU promotion** | Dev uses cheap tiers, staging/prod uses production-grade tiers |
| **Environment isolation** | Separate subscriptions and GitHub environments per stage |
| **Cost comparison** | Easily see cost impact of promoting to higher environments |

**Next:** [Lab 4 — Policy Compliance](lab-04-policy-compliance.md)

## Step 6: Environment parameter files

Promotion uses per-env parameter files alongside ONE template:

.azure/deployments/<id>/
  template.json
  parameters.dev.json
  parameters.staging.json
  parameters.prod.json
  metadata.json

Git-Ape selects the file based on environment label in PR title or metadata.json env field.

## Step 7: Promotion verification

Before promoting to staging:

- Plan-comment checks PASSED.
- Cost delta is expected.
- Integration tests passed in dev (tests.json).
- No drift since dev deploy.

## Step 8: Promotion workflow

- One PR per env promotion.
- Each PR triggers Plan against target-env params.
- Approve + merge to promote.
- state.json is per-env so destroy is per-env.
