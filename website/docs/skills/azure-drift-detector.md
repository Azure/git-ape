---
title: "Azure Drift Detector"
sidebar_label: "Azure Drift Detector"
description: "Detect configuration drift between deployed Azure resources and stored deployment state. Compare actual Azure configuration against desired state in .azure/deployments/, identify differences, and guide user through reconciliation options. Use when checking for manual changes, policy remediations, or unauthorized modifications."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/azure-drift-detector/SKILL.md -->


# Azure Drift Detector

> Detect configuration drift between deployed Azure resources and stored deployment state. Compare actual Azure configuration against desired state in .azure/deployments/, identify differences, and guide user through reconciliation options. Use when checking for manual changes, policy remediations, or unauthorized modifications.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/azure-drift-detector/` |
| **Phase** | Operations |
| **User Invocable** | ✅ Yes |
| **Usage** | `/azure-drift-detector` |


## Documentation

# Azure Drift Detector

## Overview

Detect when Azure resources have been modified outside of Git-Ape workflows (manual portal changes, Azure Policy remediations, external tools) and guide users through reconciliation.

**Triggers:**
- User asks: "check for drift", "has anything changed?", "compare deployed state"
- Scheduled drift detection (if configured)
- Pre-deployment validation to ensure clean starting state
- Post-incident review after Azure Policy remediation

## Procedure

### 1. Identify Target Deployment

Ask user which deployment to check for drift:

```markdown
Which deployment do you want to check for drift?

Recent deployments:
- deploy-20260218-143022 (func-api-dev-eastus) - Deployed 2 hours ago
- deploy-20260217-091530 (app-webapp-prod-eastus) - Deployed 1 day ago
- deploy-20260216-153045 (sql-data-prod-eastus) - Deployed 2 days ago

Or enter deployment ID:
```

**Load deployment state:**
```bash
DEPLOYMENT_ID="deploy-20260218-143022"
DEPLOYMENT_PATH=".azure/deployments/$DEPLOYMENT_ID"

# Load stored state
REQUIREMENTS=$(cat "$DEPLOYMENT_PATH/requirements.json")
TEMPLATE=$(cat "$DEPLOYMENT_PATH/template.json")
METADATA=$(cat "$DEPLOYMENT_PATH/metadata.json")

# Extract resource IDs
RESOURCE_IDS=$(jq -r '.resources[].id' "$DEPLOYMENT_PATH/metadata.json")
```

### 2. Query Current Azure State

For each resource in the deployment, fetch current configuration:

```bash
# Use Azure CLI to get current resource properties
for RESOURCE_ID in $RESOURCE_IDS; do
  CURRENT_STATE=$(az resource show --ids "$RESOURCE_ID" --output json)
  
  # Store for comparison
  echo "$CURRENT_STATE" > "$DEPLOYMENT_PATH/drift-analysis/current-state-$(basename $RESOURCE_ID).json"
done
```

**Alternative: Use Azure Resource Graph**
```bash
# Query multiple resources efficiently
az graph query -q "
  Resources
  | where id in ('$RESOURCE_ID_1', '$RESOURCE_ID_2')
  | project id, name, type, location, properties, tags
" --output json > "$DEPLOYMENT_PATH/drift-analysis/current-state.json"
```

### 3. Compare States

Use the drift detection script to identify differences:

```bash
# Run drift detection
.github/skills/azure-drift-detector/scripts/detect-drift.sh \
  --deployment-id "$DEPLOYMENT_ID" \
  --output-format "markdown"
```

**Script analyzes:**
- **Properties drift** - Configuration changes (SKU, runtime version, app settings, etc.)
- **Tags drift** - Added, removed, or modified tags
- **Security drift** - HTTPS settings, managed identity, firewall rules
- **Scale drift** - Instance count, auto-scale settings
- **Deleted resources** - Resources that should exist but don't
- **Unexpected resources** - Resources created outside workflow

**Drift categories:**
- 🔴 **Critical Drift** - Security settings, HTTPS enforcement, authentication
- 🟡 **Warning Drift** - Tags, non-security properties
- 🔵 **Info Drift** - Cosmetic changes, descriptions

### 4. Present Drift Report

Show user a comprehensive drift analysis:

```markdown
## Drift Detection Report

**Deployment:** deploy-20260218-143022
**Checked:** 2026-02-18 19:30:00 UTC
**Resources Analyzed:** 5

### Summary
- 🔴 Critical Drift: 1 resource
- 🟡 Warning Drift: 2 resources
- ✅ No Drift: 2 resources

---

### 🔴 CRITICAL: Function App (func-api-dev-eastus)

**Property:** `properties.httpsOnly`
- Expected (deployment state): `true`
- Current (Azure): `false`
- **Impact:** Security vulnerability - HTTP traffic allowed
- **Changed:** ~30 minutes ago (2026-02-18 19:00:00 UTC)
- **Likely Cause:** Manual portal change or policy remediation

**Property:** `properties.siteConfig.appSettings.FUNCTIONS_WORKER_RUNTIME`
- Expected: `python`
- Current: `node`
- **Impact:** Runtime mismatch - application may fail
- **Changed:** ~30 minutes ago

---

### 🟡 WARNING: Storage Account (stfuncdeveastus8k3m)

**Property:** `tags.Environment`
- Expected: `dev`
- Current: `development`
- **Impact:** Tag inconsistency - reporting/billing may be affected

**Property:** `properties.minimumTlsVersion`
- Expected: `TLS1_2`
- Current: `TLS1_0`
- **Impact:** Weak TLS version - security concern

---

### ✅ NO DRIFT: Application Insights (appi-api-dev-eastus)

All properties match deployment state.
```

### 5. Guide User Through Reconciliation

Present reconciliation options:

```markdown
## Drift Reconciliation Options

You have 3 options for handling this drift:

### A. **Accept Drift** (Update IaC to match Azure)
Update deployment state files to reflect current Azure configuration.
- Updates: requirements.json, template.json, metadata.json
- Next deployment will use new values as baseline
- **Use when:** The Azure changes are intentional and should be preserved

### B. **Revert Drift** (Restore desired state from IaC)
Redeploy resources to enforce original configuration.
- Reverts: httpsOnly → true, runtime → python, tags → original
- Creates new deployment: deploy-20260218-193000-revert
- **Use when:** Azure changes were unauthorized or incorrect

### C. **Selective Reconciliation** (Choose per property)
Review each drift and decide individually:
- Keep some Azure changes
- Revert others to deployment state
- **Use when:** Some changes are valid, others are not

### D. **Mark as Known Drift** (Ignore for now)
Document the drift but don't reconcile yet.
- Adds to: drift-analysis/known-drift.json
- Future checks won't alert on these specific changes
- **Use when:** Investigating before deciding action

---

**Which option would you like?** (Type A, B, C, or D)
```

### 6. Execute User's Choice

**Option A: Accept Drift**

```bash
# Update deployment state to match Azure
.github/skills/azure-drift-detector/scripts/accept-drift.sh \
  --deployment-id "$DEPLOYMENT_ID"

# Actions:
# 1. Fetch current Azure state
# 2. Update requirements.json with new values
# 3. Regenerate ARM template to match
# 4. Update metadata.json with drift acceptance record
# 5. Create git commit (if in version control)

# Log acceptance
cat >> "$DEPLOYMENT_PATH/drift-analysis/drift-log.jsonl" <<EOF
{
  "timestamp": "2026-02-18T19:30:00Z",
  "action": "accept",
  "user": "$(az account show --query user.name -o tsv)",
  "changes": {
    "httpsOnly": {"from": true, "to": false},
    "runtime": {"from": "python", "to": "node"}
  },
  "reason": "Intentional runtime change to Node.js"
}
EOF
```

**Option B: Revert Drift**

```bash
# Redeploy to enforce desired state
.github/skills/azure-drift-detector/scripts/revert-drift.sh \
  --deployment-id "$DEPLOYMENT_ID" \
  --confirm

# Actions:
# 1. Load original template.json and parameters.json
# 2. Create revert deployment: deploy-{timestamp}-revert
# 3. Deploy with mode: Incremental (only changes)
# 4. Monitor deployment
# 5. Verify drift resolved
# 6. Update metadata with revert record

# Confirmation prompt:
echo "⚠️  This will revert the following changes:"
echo "  - httpsOnly: false → true"
echo "  - runtime: node → python"
echo ""
echo "Type 'confirm revert' to proceed:"
read CONFIRMATION
```

**Option C: Selective Reconciliation**

```bash
# Present each drift individually
echo "Drift 1/4: httpsOnly changed from true to false"
echo ""
echo "What should we do?"
echo "  A. Keep Azure value (false) - Update IaC"
echo "  B. Revert to IaC value (true) - Redeploy"
echo "  S. Skip this property for now"
echo ""
echo "Your choice (A/B/S):"
read CHOICE_1

# Repeat for each drift
# Build reconciliation plan
# Execute combined update + revert
```

**Option D: Mark as Known Drift**

```bash
# Document known drift
cat >> "$DEPLOYMENT_PATH/drift-analysis/known-drift.json" <<EOF
{
  "resource": "func-api-dev-eastus",
  "properties": {
    "httpsOnly": {
      "expected": true,
      "actual": false,
      "markedBy": "arnaud@example.com",
      "markedAt": "2026-02-18T19:30:00Z",
      "reason": "Investigating runtime issue, temporarily allowing HTTP",
      "reviewBy": "2026-02-19T09:00:00Z"
    }
  }
}
EOF

# Future drift checks will skip these properties
```

## Integration with Main Workflow

**Scheduled Drift Detection:**

```bash
# Add to cron or Azure DevOps pipeline
# Run daily drift check on all active deployments

.github/scripts/drift-check-all.sh

# Output:
# Checking 15 active deployments...
# ✅ 12 deployments: No drift detected
# 🟡 2 deployments: Warning drift (tags only)
# 🔴 1 deployment: Critical drift (security settings)
#
# Details in: .azure/drift-reports/2026-02-18.md
```

**Pre-Deployment Drift Check:**

```markdown
User: @git-ape deploy changes to func-api-dev-eastus

Agent: Before deploying, let me check for configuration drift...

🔴 DRIFT DETECTED

The current Azure state differs from your last deployment.

Changes detected:
- httpsOnly: true → false (in Azure)
- tags.Environment: dev → development (in Azure)

What would you like to do?

A. Accept drift first, then deploy your changes on top
B. Revert drift, then deploy (restore original baseline)
C. Cancel deployment and investigate drift manually

This ensures we don't lose Azure changes or create conflicts.
```

## Drift Detection Scenarios

### Scenario 1: Azure Policy Remediation

```markdown
Azure Policy: "All Function Apps must use managed identity"

Policy remediation adds:
- identity.type: SystemAssigned

Drift detection shows:
🟡 WARNING: Managed identity added by Azure Policy

Recommendation: **Accept drift** - This is a policy-enforced improvement.
Update IaC to include managed identity in future deployments.
```

### Scenario 2: Emergency Hotfix

```markdown
Production incident: Function App scale limit reached

Manual portal change:
- properties.siteConfig.alwaysOn: true
- App Service Plan: Scaled from S1 to S2

Drift detection shows:
🔴 CRITICAL: SKU changed, Always On enabled

Recommendation: **Accept drift + Document** - Emergency change required.
Update IaC and create proper change request for next deployment.
```

### Scenario 3: Unauthorized Change

```markdown
Unknown change detected:
- properties.httpsOnly: true → false
- Changed: 2 days ago
- No change ticket or approved request

Drift detection shows:
🔴 CRITICAL: HTTPS enforcement disabled

Recommendation: **Revert drift immediately** - Security violation.
Investigate who made the change and why. Restore secure state.
```

### Scenario 4: Tag Drift from Billing Team

```markdown
Billing team added cost center tags:
- tags.CostCenter: "CC-12345"
- tags.BillingOwner: "finance@example.com"

Drift detection shows:
🟡 WARNING: New tags added

Recommendation: **Accept drift** - Valid tags for financial tracking.
Update IaC baseline to preserve these tags in future deployments.
```

## Continuous Drift Monitoring

**GitHub Action Example:**

```yaml
# .github/workflows/drift-detection.yml
name: Azure Drift Detection

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:      # Manual trigger

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Run Drift Detection
        run: |
          .github/scripts/drift-check-all.sh --format github-annotation
      
      - name: Create Issue if Critical Drift
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🔴 Critical Configuration Drift Detected',
              body: 'See workflow logs for details',
              labels: ['drift', 'security']
            })
```

## Best Practices

1. **Check drift before deployments** - Prevent conflicts and data loss
2. **Schedule regular drift checks** - Catch unauthorized changes early
3. **Document accepted drift** - Maintain audit trail of intentional changes
4. **Revert security drift immediately** - Don't accept security downgrades
5. **Use selective reconciliation** - Some drift may be valid (tags, scaling)
6. **Update IaC for accepted drift** - Keep deployment state as source of truth
7. **Alert on critical drift** - Monitor HTTPS, authentication, firewall rules

## Output Format

Save drift analysis to:
```
.azure/deployments/{deployment-id}/drift-analysis/
├── current-state.json           # Azure resource state at check time
├── drift-report.md              # Human-readable report
├── drift-details.json           # Machine-readable diff
├── known-drift.json             # Acknowledged drift to ignore
└── drift-log.jsonl              # Audit log of reconciliation actions
```

## Related Skills

- **azure-integration-tester** - Verify resources after drift revert
- **azure-naming-research** - Validate names during drift acceptance
- Main deployment workflow - Pre-deployment drift check integration
