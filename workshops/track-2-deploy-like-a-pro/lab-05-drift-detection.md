# Lab 5: Drift Detection

> 5 minutes | Azure required (uses deployed resources from Lab 2)

Introduce a manual change in Azure, detect it as drift, and choose a reconciliation action.

## What Is Drift?

**Drift** happens when the actual Azure configuration differs from what's defined in your IaC templates. Common causes:

- Manual changes in the Azure Portal
- Azure Policy remediations
- Automated scripts or unauthorized modifications

## Step 1: Introduce Drift Manually

Go to the Azure Portal or use the CLI to make a change that wasn't in your template.

**Option A: Azure Portal**

1. Navigate to your storage account (`sthelloworlddev...` or similar)
2. Go to **Networking** > **Firewalls and virtual networks**
3. Change "Public network access" from "Enabled" to "Enabled from selected virtual networks and IP addresses"
4. Add your current IP address
5. Save

**Option B: Azure CLI**

```bash
# Get your storage account name
STORAGE_NAME=$(az storage account list --resource-group rg-inventoryapp-dev-eastus \
  --query "[0].name" -o tsv)

# Add a network rule (this creates drift from the template)
az storage account update --name "$STORAGE_NAME" \
  --resource-group rg-inventoryapp-dev-eastus \
  --default-action Deny
```

> You just made a change that's not in the ARM template. The deployed state now differs from the IaC definition.

## Step 2: Detect the Drift

In Copilot Chat:

```text
/azure-drift-detector
```

Point it at your deployment ID (shown in `.azure/deployments/`).

The drift detector compares the actual Azure configuration against the stored `state.json` and reports:

```
⚠️ Drift Detected

Storage Account (sthelloworlddev...)
  - networkAcls.defaultAction: Allow → Deny (CHANGED)
  - Classification: Warning
  - Likely cause: Manual change or Azure Policy remediation
```

## Step 3: Choose a Reconciliation Action

The drift detector offers options:

| Option | What It Does |
|--------|-------------|
| **Accept drift** | Update the IaC template to match the current Azure state |
| **Revert drift** | Redeploy the original template to undo the manual change |
| **Review details** | See the full diff before deciding |

For this lab, choose **revert drift** to restore the original configuration:

```text
Revert the drift — redeploy the original template
```

The resource is redeployed with the original network configuration.

## Step 4: Verify

Run the drift detector again:

```text
/azure-drift-detector
```

```
✅ No drift detected. Azure state matches IaC definition.
```

## What You Learned

| Concept | What It Means |
|---------|--------------|
| **Drift** | Mismatch between IaC definition and actual Azure state |
| **Drift detection** | Compares live Azure config against stored state |
| **Classification** | Critical, Warning, or Info based on security impact |
| **Reconciliation** | Accept (update IaC), Revert (redeploy), or Review (inspect) |
| **Audit trail** | Every drift action is recorded for compliance |

> **Track 2 complete.** You deployed a multi-resource architecture, broke and fixed security, estimated costs, reviewed architecture, and detected drift. Total time: ~60 minutes.

## What's Next?

- **Track 3:** [Platform Engineering](../track-3-platform-engineering/) — CI/CD pipelines, headless mode, multi-environment, policy compliance (90 min)
- **Clean up:** Delete the workshop resources:

```bash
az group delete --name rg-inventoryapp-dev-eastus --yes --no-wait
```

## Step 6: Drift severity

- Critical: security regression. REVERT IMMEDIATELY.
- Warning: scale/capacity.
- Info: cosmetic.

Security-drift example: manually disable HTTPS, re-run detector. Result is Critical, must revert.

## Step 7: Four reconciliation options

- Accept: update stored state.
- Revert: re-apply stored template (Critical default).
- Selective: pick properties.
- Mark known: tag as accepted-known-drift.

## Step 8: Operationalize

- Schedule via .github/workflows/git-ape-drift.md template.
- Drift log audit trail.
- Review known-drift list quarterly.
