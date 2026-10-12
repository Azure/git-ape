# Lab 7: Advanced Drift Operations

> 20 minutes | Azure required (uses deployed resources from Track 2 Lab 2 or fresh deploy)

Detect multi-type drift across a deployed architecture, triage by severity, apply different reconciliation strategies, and operationalize with scheduled detection.

> **How this differs from Track 2 Lab 5:** That lab introduces drift with a single change and a single action (revert). This lab simulates a real-world scenario where *multiple* unauthorized changes happen simultaneously, each requiring a *different* reconciliation strategy — and then shows how platform teams operationalize drift detection across their fleet.

## What You Learn

| Concept | What It Means |
|---------|--------------|
| **Multi-type drift** | Security, scale, and tag drift can happen simultaneously |
| **Severity classification** | Critical (security) vs Warning (scale) vs Info (cosmetic) |
| **Selective reconciliation** | Revert some drift, accept other drift, mark the rest as known |
| **Scheduled detection** | Automated daily drift scans via CI workflow |
| **Fleet scanning** | Check all deployments at once with `drift-check-all.sh` |

## Prerequisites

- Completed Track 2 Lab 2 (or have any active Git-Ape deployment with a storage account)
- Azure CLI authenticated (`az login`)
- Copilot Chat available

> **No deployment from Lab 2?** Deploy a quick baseline:
>
> ```text
> Deploy a storage account and a web app in resource group rg-driftlab-dev-eastus. Use Container Apps hosting. Project name: driftlab, environment: dev.
> ```

## Step 1: Confirm Your Baseline

Verify your deployed resources exist and identify the ones you'll modify:

```bash
# List resources in your deployment's resource group
RESOURCE_GROUP="rg-inventoryapp-dev-eastus"   # adjust to match your deployment

az resource list --resource-group "$RESOURCE_GROUP" \
  --query "[].{Name:name, Type:type}" -o table
```

You should see resources including a **storage account** and a **web app** (or Container App).

Identify your storage account name:

```bash
STORAGE_NAME=$(az storage account list --resource-group "$RESOURCE_GROUP" \
  --query "[0].name" -o tsv)
echo "Storage account: $STORAGE_NAME"
```

Record the current state so you can compare later:

```bash
# Capture current storage config
az storage account show --name "$STORAGE_NAME" \
  --query "{sku:sku.name, httpsOnly:supportsHttpsTrafficOnly, tags:tags}" -o json
```

## Step 2: Introduce Multi-Type Drift

Now simulate what happens in real organizations: multiple people make multiple unauthorized changes.

### Drift 1: Security Regression (Critical)

A developer disables HTTPS-only on the storage account via the portal — "just to test something":

```bash
az storage account update --name "$STORAGE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --https-only false
```

### Drift 2: SKU Change (Warning)

An ops script upgrades the storage redundancy — possibly intentional, but not in the template:

```bash
az storage account update --name "$STORAGE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Standard_GRS
```

### Drift 3: Tag Removal (Info)

Someone removes the compliance tags during a cleanup script:

```bash
az tag update --resource-id $(az storage account show --name "$STORAGE_NAME" \
  --resource-group "$RESOURCE_GROUP" --query id -o tsv) \
  --operation replace --tags "Temporary=true"
```

> You just created three types of drift simultaneously. The deployed state now diverges from the IaC definition in three distinct ways.

## Step 3: Detect All Drift

In Copilot Chat:

```text
/azure-drift-detector
```

Point it at your deployment ID (shown in `.azure/deployments/`). The detector compares live Azure state against the stored deployment state and reports:

```
⚠️ Drift Detected — 3 differences found

Storage Account (st...)
  🔴 CRITICAL: supportsHttpsTrafficOnly: true → false
     Impact: HTTP traffic now allowed — data in transit is unencrypted
     Likely cause: Manual portal or CLI change

  🟡 WARNING: sku.name: Standard_LRS → Standard_GRS
     Impact: Storage redundancy changed — cost increase
     Likely cause: Ops script or manual upgrade

  🔵 INFO: tags: {Environment: dev, Project: inventoryapp, ...} → {Temporary: true}
     Impact: Compliance tags removed — reporting/billing affected
     Likely cause: Cleanup script or manual deletion
```

## Step 4: Understand Drift Severity

The drift detector classifies every difference by its operational impact:

| Severity | Meaning | Examples | Default Action |
|----------|---------|----------|----------------|
| 🔴 **Critical** | Security regression | HTTPS disabled, firewall opened, auth removed, TLS downgraded | **Revert immediately** |
| 🟡 **Warning** | Scale/capacity/cost change | SKU changed, instance count modified, retention period altered | **Review, then decide** |
| 🔵 **Info** | Cosmetic/metadata | Tags changed, descriptions modified | **Acknowledge** |

> **Key insight:** Not all drift is bad. A SKU upgrade might be an intentional capacity decision that should be accepted into IaC. The drift detector helps you *decide*, not just detect.

## Step 5: Selective Reconciliation

This is where it gets interesting. Instead of reverting everything, apply the right action for each drift type:

### 5a: Revert the Critical Drift (HTTPS)

Security regressions must be restored immediately:

```text
Revert the HTTPS drift — redeploy with supportsHttpsTrafficOnly: true
```

The detector runs the revert script, which redeploys the template to restore the original security posture.

Verify:

```bash
az storage account show --name "$STORAGE_NAME" \
  --query "supportsHttpsTrafficOnly" -o tsv
# Expected: true
```

### 5b: Accept the Warning Drift (SKU)

After confirming with the ops team that the GRS upgrade was intentional:

```text
Accept the SKU drift — update the IaC baseline to Standard_GRS
```

This updates `requirements.json` and `template.json` to reflect the new SKU as the desired state. Future deployments will use `Standard_GRS` as the baseline.

### 5c: Mark the Info Drift as Known

The tag removal was a one-time cleanup. We want the tags restored but want to log this as a known event:

```text
Mark the tag drift as known drift — we'll restore tags in the next deployment
```

This records the drift in `known-drift.json` with a timestamp and justification. The detector will still report it but won't flag it as new drift.

## Step 6: Verify Reconciliation

Re-run the detector:

```text
/azure-drift-detector
```

Expected result:

```
✅ Drift Status: Mostly Clean

Storage Account (st...)
  ✅ supportsHttpsTrafficOnly: true (reverted)
  ✅ sku.name: Standard_GRS (accepted into baseline)
  ⓘ tags: Known drift (recorded 2026-06-03, reason: cleanup script)

Reconciliation Summary:
  - 1 Critical drift reverted
  - 1 Warning drift accepted into IaC
  - 1 Info drift recorded as known
```

## Bonus: Operationalize Drift Detection

> The remaining steps are optional extensions for platform teams.

### Bonus A: Scheduled Drift Workflow

Git-Ape includes a scheduled drift detection workflow that runs daily:

```bash
# View the drift workflow template
cat .github/workflows/git-ape-drift.md
```

Key features of the workflow:

- **Runs daily at 06:00 UTC** via `schedule` trigger
- **OIDC authentication** — no stored credentials
- **Snapshots all deployments** — captures current Azure state before analysis
- **Creates issues** for Critical drift that needs human review
- **Audit trail** — every drift event is logged with timestamps

> In a production setup, you'd configure this workflow during onboarding (Lab 1) and it runs automatically. No manual drift checks needed.

### Bonus B: Multi-Deployment Scan

If you have multiple deployments, scan them all at once:

```bash
# View the fleet scanner
cat .github/skills/azure-drift-detector/scripts/drift-check-all.sh
```

The `drift-check-all.sh` script:

1. Discovers all deployment directories in `.azure/deployments/`
2. Runs drift detection on each
3. Aggregates results into a fleet-wide drift report
4. Classifies overall fleet health: **Clean / Warning / Critical**

> This is how platform teams monitor dozens of deployments without checking each one manually.

## What You Learned

| Concept | Track 2 Lab 5 | This Lab |
|---------|--------------|----------|
| **Drift types** | Single (network rule) | Multiple (security + scale + tags) |
| **Reconciliation** | One action (revert) | Three strategies (revert, accept, known-drift) |
| **Scope** | One resource | One deployment, fleet overview |
| **Operationalization** | Manual only | Scheduled CI workflow |
| **Decision-making** | "Fix it" | "Triage, then decide per-drift" |

## What's Next

- **Lab 8:** [Agent Evaluation](lab-08-agent-evals.md) — Verify agent behavior with automated eval suites
- **Clean up** (if not continuing): Delete workshop resources:

```bash
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
```
