---
title: "Drift Detection"
sidebar_label: "Drift Detection"
sidebar_position: 2
description: "Detecting and reconciling Azure configuration drift"
---

# Configuration Drift Detection Guide

:::warning
EXPERIMENTAL ONLY: Drift detection and reconciliation behavior is not production-grade.
Results may be incomplete, and automated accept/revert operations should be treated as test-only.
Do **not** use this workflow as your production compliance control.
:::
## Overview

Configuration drift occurs when Azure resources are modified outside the Infrastructure-as-Code (IaC) workflow. This can happen through:

- **Manual Portal Changes** - Developers or operators modify resources via Azure Portal
- **Azure Policy Remediations** - Compliance policies automatically fix non-compliant resources
- **Automated Tooling** - Third-party tools or scripts make changes
- **Emergency Hotfixes** - Production incidents requiring immediate changes

Git-Ape's drift detection system helps you:
1. **Detect** configuration differences between Azure and your IaC
2. **Analyze** the severity and impact of changes
3. **Reconcile** by accepting drift (update IaC) or reverting drift (redeploy)
4. **Audit** all drift actions with complete logging

## Quick Start

### Check for Drift

**Agent Workflow:**
```
User: @git-ape check for drift on deploy-20260218-143022

Agent: Running drift detection...

⚠️ Configuration Drift Detected
- Critical: 1 (security settings changed)
- Warning: 2 (tags and config modified)

What would you like to do?
A. Accept Drift (update IaC)
B. Revert Drift (redeploy original state)
C. Review Details
D. Ignore (mark as known)
```

**Command Line:**
```bash
# Check specific deployment
.github/skills/azure-drift-detector/scripts/detect-drift.sh \
  --deployment-id deploy-20260218-143022

# Check all deployments
.github/skills/azure-drift-detector/scripts/drift-check-all.sh
```

### Accept Drift (Update IaC to Match Azure)

**When to use:**
- Azure Policy enforced a security improvement
- Manual change was intentional and should be kept
- Emergency hotfix should become permanent

**Agent Workflow:**
```
User: A (Accept Drift)

Agent: Accepting drift...
✓ Backed up original requirements.json
✓ Updated IaC with current Azure state
✓ Logged acceptance to audit trail
✓ Created git commit (if --auto-commit)

Your IaC now matches Azure.
```

**Command Line:**
```bash
.github/skills/azure-drift-detector/scripts/accept-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --reason "Azure Policy compliance requirement" \
  --auto-commit
```

### Revert Drift (Restore IaC State)

**When to use:**
- Unauthorized change detected
- Security settings were weakened
- Change violated compliance policy

**Agent Workflow:**
```
User: B (Revert Drift)

Agent: ⚠️ This will redeploy resources to restore original state.
Type 'confirm revert' to proceed:

User: confirm revert

Agent: Reverting drift...
🚀 Deployment Started (revert)
✓ httpsOnly: false → true (restored)
✓ minimumTlsVersion: 1.0 → 1.2 (restored)
✅ Drift reverted successfully
```

**Command Line:**
```bash
.github/skills/azure-drift-detector/scripts/revert-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --confirm
```

## Drift Severity Levels

### 🔴 Critical Drift

**Security-impacting changes that introduce vulnerabilities**

Examples:
- `httpsOnly: true → false` - Allows unencrypted traffic
- `minimumTlsVersion: "1.2" → "1.0"` - Weakens encryption
- `publicNetworkAccess: Disabled → Enabled` - Exposes resource publicly
- Managed identity disabled
- Diagnostic logging disabled

**Recommended Action:** Revert immediately unless change was intentional and approved.

### 🟡 Warning Drift

**Configuration or compliance changes that don't directly impact security**

Examples:
- Tag changes (`Environment: dev → prod`)
- Runtime version changes (`python@3.11 → python@3.10`)
- Scaling configuration (`instanceCount: 2 → 4`)
- Non-critical app settings

**Recommended Action:** Review change reason, accept if intentional, revert if unauthorized.

### ℹ️ Info Drift

**Cosmetic or Azure-managed properties**

Examples:
- Last modified timestamp
- Azure-generated resource IDs
- Auto-scaling metrics
- System-managed tags

**Recommended Action:** Usually safe to accept or ignore.

## Drift Detection Workflow

### Step 1: Identify Target Deployment

List available deployments:
```bash
.github/scripts/deployment-manager.sh list
```

Output:
```
Recent Deployments:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID                      Status    Resource Type        Region
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
deploy-20260218-143022  success   Function App         eastus
deploy-20260217-100000  success   Web App + SQL        westus2
deploy-20260215-093022  success   Storage Account      eastus
```

### Step 2: Run Drift Detection

Detect changes between Azure and stored state:

```bash
.github/skills/azure-drift-detector/scripts/detect-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --output-format markdown \
  --verbose
```

**What happens:**
1. Loads deployment metadata from `.azure/deployments/deploy-20260218-143022/`
2. Queries current Azure state via `az resource show` for each resource
3. Compares properties by resource type:
   - Function Apps: `httpsOnly`, `FUNCTIONS_WORKER_RUNTIME`, identity
   - Storage: `minimumTlsVersion`, `supportsHttpsTrafficOnly`
   - All resources: tags
4. Classifies severity: Critical, Warning, Info
5. Generates report

**Output files:**
```
.azure/deployments/deploy-20260218-143022/drift-analysis/
├── drift-details.json          # Machine-readable drift data
├── drift-report.md             # Human-readable markdown report
├── current-func-*.json         # Current state snapshots
├── current-storage-*.json
└── drift-log.jsonl             # Audit log (created on accept/revert)
```

**Exit codes:**
- `0` - No drift detected
- `1` - Warning-level drift found
- `2` - Critical drift found

### Step 3: Review Drift Report

**Markdown Report Example:**
```markdown
# Drift Detection Report

**Deployment ID:** deploy-20260218-143022  
**Analyzed:** 2026-02-18 14:30:00 UTC  
**Resources Checked:** 3

## Summary

- 🔴 Critical Drift: 1
- 🟡 Warning Drift: 2
- ℹ️ Info Drift: 0
- **Total Drifts:** 3

## Drift Details

### Resource: func-api-dev-eastus (Microsoft.Web/sites)

🔴 **Critical Drift**
- **Property:** `properties.httpsOnly`
- **Expected:** `false`
- **Current:** `true`
- **Reason:** Azure Policy "Require HTTPS" enforced this change
- **Recommendation:** Accept (security improvement)

🟡 **Warning Drift**
- **Property:** `tags.CostCenter`
- **Expected:** `""`
- **Current:** `"12345"`
- **Reason:** Manually added via Azure Portal
- **Recommendation:** Accept if required for billing

### Resource: stfuncapidev8k3m (Microsoft.Storage/storageAccounts)

🟡 **Warning Drift**
- **Property:** `properties.minimumTlsVersion`
- **Expected:** `TLS1_0`
- **Current:** `TLS1_2`
- **Reason:** Security team policy
- **Recommendation:** Accept (security improvement)
```

**JSON Format:**
```json
{
  "deploymentId": "deploy-20260218-143022",
  "analyzedAt": "2026-02-18T14:30:00Z",
  "summary": {
    "totalDrifts": 3,
    "criticalDrift": 1,
    "warningDrift": 2,
    "infoDrift": 0
  },
  "drifts": [
    {
      "resourceId": "/subscriptions/.../func-api-dev-eastus",
      "resourceType": "Microsoft.Web/sites",
      "drifts": [
        {
          "property": "properties.httpsOnly",
          "expected": false,
          "current": true,
          "severity": "Critical"
        }
      ]
    }
  ]
}
```

### Step 4: Choose Reconciliation Option

**Option A: Accept Drift** (Update IaC)

Update your requirements.json to match current Azure state:

```bash
.github/skills/azure-drift-detector/scripts/accept-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --reason "Azure Policy compliance" \
  --auto-commit
```

**What happens:**
1. Backs up original `requirements.json` to timestamped directory
2. Loads current Azure state from drift analysis JSON
3. Updates `requirements.json` with Azure values:
   ```json
   {
     "resources": [{
       "httpsOnly": true,        // Updated from false
       "minimumTlsVersion": "1.2", // Updated from 1.0
       "tags": {
         "CostCenter": "12345"   // Added
       }
     }]
   }
   ```
4. Updates `metadata.json` with drift acceptance record
5. Appends to `drift-log.jsonl` for audit trail
6. Creates git commit (if `--auto-commit`)

**Option B: Revert Drift** (Redeploy)

Restore original configuration by redeploying:

```bash
.github/skills/azure-drift-detector/scripts/revert-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --confirm
```

**What happens:**
1. Shows drift summary and asks for confirmation
2. Loads original `template.json` and `parameters.json`
3. Creates new deployment with suffix `-revert`
4. Deploys using Azure CLI in Incremental mode:
   ```bash
   az deployment group create \
     --name deploy-20260218-164500-revert \
     --resource-group rg-api-dev-eastus \
     --template-file template.json \
     --mode Incremental
   ```
5. Logs revert action to `drift-log.jsonl`

**Option C: Selective Reconciliation**

Use the agent for interactive property-by-property reconciliation:

```
User: @git-ape review drift for deploy-20260218-143022

Agent: Found 3 drifts. Let's review each one:

Drift 1/3: httpsOnly (Critical)
- Current Azure: true
- Your IaC: false

This is a security improvement. Accept this change?
A. Yes (keep Azure value)
B. No (revert to IaC)

User: A

Agent: Accepted. Next...

Drift 2/3: tags.CostCenter (Warning)
- Current Azure: "12345"
- Your IaC: (not set)

Accept this tag?
A. Yes
B. No

User: B

[Continues for all drifts, then applies mixed reconciliation]
```

**Option D: Mark as Known Drift**

Flag drift as expected so it won't alert on future scans:

```bash
# Not yet implemented - future enhancement
.github/skills/azure-drift-detector/scripts/ignore-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --property "properties.httpsOnly"
```

## Automated Monitoring

### GitHub Actions Workflow

Create `.github/workflows/drift-detection.yml`:

```yaml
name: Azure Drift Detection

on:
  schedule:
    # Run every 6 hours
    - cron: '0 */6 * * *'
  
  # Allow manual trigger
  workflow_dispatch:

permissions:
  id-token: write
  contents: read
  issues: write

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Install Azure CLI
        run: |
          curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
      
      - name: Check All Deployments for Drift
        id: drift-check
        run: |
          .github/skills/azure-drift-detector/scripts/drift-check-all.sh \
            --format json > drift-report.json
          
          # Set outputs for subsequent steps
          CRITICAL=$(jq -r '.summary.totalCriticalDrift' drift-report.json)
          WARNING=$(jq -r '.summary.totalWarningDrift' drift-report.json)
          
          echo "critical=$CRITICAL" >> $GITHUB_OUTPUT
          echo "warning=$WARNING" >> $GITHUB_OUTPUT
      
      - name: Upload Drift Report
        uses: actions/upload-artifact@v4
        with:
          name: drift-report-${{ github.run_id }}
          path: drift-report.json
      
      - name: Notify on Critical Drift
        if: steps.drift-check.outputs.critical > 0
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
          payload: |
            {
              "text": "🔴 Critical Azure Configuration Drift Detected",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Critical Drift Detected*\n• Critical Drifts: ${{ steps.drift-check.outputs.critical }}\n• Warning Drifts: ${{ steps.drift-check.outputs.warning }}\n\n<https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Details>"
                  }
                }
              ]
            }
      
      - name: Create Issue on Critical Drift
        if: steps.drift-check.outputs.critical > 0
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = JSON.parse(fs.readFileSync('drift-report.json'));
            
            const criticalDeployments = report.deployments
              .filter(d => d.criticalDrift > 0)
              .map(d => `- **${d.deploymentId}**: ${d.criticalDrift} critical drifts`)
              .join('\n');
            
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🔴 Critical Azure Configuration Drift Detected',
              body: `## Critical Drift Alert\n\n${criticalDeployments}\n\n**Action Required:**\n1. Review drift report in GitHub Actions artifacts\n2. Investigate changes in Azure Portal activity logs\n3. Revert unauthorized changes or accept if intentional\n\n**Auto-generated by drift detection workflow**`,
              labels: ['azure', 'drift', 'security']
            });
```

### Scheduled Cron Job

For local or self-hosted runners:

```bash
# Add to crontab
0 */6 * * * cd /path/to/git-ape && .github/skills/azure-drift-detector/scripts/drift-check-all.sh --format json > /var/log/drift-$(date +\%Y\%m\%d).json
```

### Azure Monitor Alert Rule

Create alert rule for resource modifications:

```bash
az monitor activity-log alert create \
  --name "Resource Configuration Changes" \
  --resource-group rg-monitoring \
  --condition category=Administrative and operationName=Microsoft.Resources/deployments/write \
  --action-group drift-notification-group \
  --description "Alert when Azure resources are modified"
```

## Common Scenarios

### Scenario 1: Azure Policy Compliance

**Situation:** Azure Policy enforces HTTPS-only on all web apps

**Drift Detected:**
```
🔴 Critical Drift
- httpsOnly: false → true (enforced by policy)
```

**Resolution:**
```bash
# Accept drift - policy is a good thing
.github/skills/azure-drift-detector/scripts/accept-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --reason "Azure Policy: Require HTTPS on web apps" \
  --auto-commit
```

**Outcome:** Your IaC is updated to require HTTPS. Future deployments will align with policy.

### Scenario 2: Emergency Production Hotfix

**Situation:** Production outage requires immediate config change via portal

**Drift Detected:**
```
🟡 Warning Drift
- FUNCTIONS_WORKER_RUNTIME: python → dotnet
- appSettings.FeatureFlag: "false" → "true"
```

**Resolution:**
```
User: @git-ape what changed in production?

Agent: Found drift in deploy-20260215-093022 (production):
- Runtime changed from Python to .NET
- Feature flag enabled
- Modified by: john.doe@company.com at 03:45 AM

These look like emergency changes. Would you like to:
A. Accept temporarily (update IaC later with proper review)
B. Revert immediately (restore Python runtime)
C. Review incident logs first

User: A for now, we'll fix properly tomorrow

Agent: Accepted drift with note: "Emergency hotfix - will review in morning"
Created issue #123 to track proper fix
```

### Scenario 3: Security Vulnerability

**Situation:** Storage account TLS version was downgraded

**Drift Detected:**
```
🔴 Critical Drift
- minimumTlsVersion: "TLS1_2" → "TLS1_0" (security degradation)
```

**Resolution:**
```bash
# REVERT IMMEDIATELY
.github/skills/azure-drift-detector/scripts/revert-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --confirm

# Follow up:
# 1. Check Azure activity logs for who made change
# 2. Review RBAC permissions
# 3. Enable resource locks on production resources
```

### Scenario 4: Tag Governance

**Situation:** Finance team adds cost center tags via portal

**Drift Detected:**
```
🟡 Warning Drift
- tags.CostCenter: "" → "IT-12345"
- tags.Department: "" → "Engineering"
- tags.Owner: "" → "Platform Team"
```

**Resolution:**
```bash
# Accept tags - they're required for billing
.github/skills/azure-drift-detector/scripts/accept-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --reason "Finance team added required billing tags" \
  --auto-commit

# Update deployment process to include these tags by default
# Edit .github/copilot-instructions.md environment tags
```

## Best Practices

### 1. Run Drift Detection Regularly

**Frequency:**
- **Production**: Every 6 hours (or after each deployment)
- **Staging**: Daily
- **Development**: Weekly or on-demand

### 2. Classify and Prioritize

**Critical Drift → Immediate Action**
- Security settings weakened
- Public access enabled
- Encryption downgraded

**Warning Drift → Review Within 24 Hours**
- Configuration changes
- Tag modifications
- Non-security settings

**Info Drift → Accept or Ignore**
- Azure-managed properties
- Cosmetic changes

### 3. Maintain Audit Trail

All drift actions are logged to `drift-log.jsonl`:

```jsonl
{"timestamp":"2026-02-18T14:30:00Z","action":"accept","user":"john.doe","driftsAccepted":2,"reason":"Azure Policy compliance"}
{"timestamp":"2026-02-18T16:45:00Z","action":"revert","user":"jane.smith","revertDeploymentId":"deploy-20260218-164500-revert","driftsReverted":3}
```

**Query logs:**
```bash
# Show all drift acceptances
jq 'select(.action == "accept")' .azure/deployments/*/drift-analysis/drift-log.jsonl

# Count reverts by user
jq -r 'select(.action == "revert") | .user' .azure/deployments/*/drift-analysis/drift-log.jsonl | sort | uniq -c
```

### 4. Prevent Drift with Azure Locks

For critical production resources, enable resource locks:

```bash
az lock create \
  --name "Prevent Deletion" \
  --resource-group rg-webapp-prod-eastus \
  --lock-type CanNotDelete \
  --notes "Production resource - use IaC for changes"
```

Lock levels:
- **CanNotDelete** - Can modify but not delete
- **ReadOnly** - Cannot modify or delete (prevents all drift)

### 5. Use Azure Policy for Compliance

Define organizational standards with Azure Policy:

```bash
# Assign built-in policy: Require HTTPS
az policy assignment create \
  --name "require-https" \
  --policy "$(az policy definition list --query "[?displayName=='App Service apps should only be accessible over HTTPS'].id" -o tsv)" \
  --scope "/subscriptions/{subscription-id}"
```

When policy remediates resources, drift detection will show:
```
Reason: Azure Policy "Require HTTPS" enforced this change
Recommendation: Accept (compliance requirement)
```

### 6. Document Known Drift

For recurring acceptable drift (e.g., auto-scaling metrics), document in deployment metadata:

```json
{
  "knownDrift": [
    {
      "property": "properties.instanceCount",
      "reason": "Auto-scaling adjusts this value",
      "acceptedBy": "platform-team",
      "acceptedAt": "2026-02-15"
    }
  ]
}
```

## Troubleshooting

### Drift Detection Fails

**Error:** "Could not query Azure resource"

**Solutions:**
```bash
# Verify Azure CLI authentication
az account show

# Check resource still exists
az resource show --ids {resource-id}

# Verify permissions (Reader role required)
az role assignment list --scope {resource-id}
```

### False Positives

**Issue:** Azure-managed properties show as drift

**Solution:** Update detect-drift.sh to exclude these properties:

```bash
# In detect-drift.sh, add to IGNORED_PROPERTIES
IGNORED_PROPERTIES=(
  "properties.createdTime"
  "properties.lastModifiedTime"
  "systemData"
)
```

### Accept Drift Fails

**Error:** "Could not update requirements.json"

**Solutions:**
```bash
# Check file permissions
chmod +w .azure/deployments/{id}/requirements.json

# Check JSON syntax
jq . .azure/deployments/{id}/requirements.json

# Restore from backup
cp .azure/deployments/{id}/backups/{timestamp}/requirements.json \
   .azure/deployments/{id}/requirements.json
```

### Revert Deployment Fails

**Error:** "Deployment failed with InvalidTemplate"

**Solutions:**
```bash
# Validate template
az deployment group validate \
  --resource-group {rg} \
  --template-file .azure/deployments/{id}/template.json

# Check error log
cat .azure/deployments/{id}-revert/error.log

# Try manual deployment
az deployment group create \
  --resource-group {rg} \
  --template-file .azure/deployments/{id}/template.json \
  --mode Incremental \
  --debug
```

## Advanced Usage

### Custom Drift Checkers

Add custom property comparisons for specific resource types:

```bash
# In detect-drift.sh, add custom checker
check_custom_properties() {
  local RESOURCE_TYPE="$1"
  
  case "$RESOURCE_TYPE" in
    "Microsoft.Web/sites")
      # Your custom logic
      check_app_settings
      check_connection_strings
      ;;
  esac
}
```

### Integration with External Tools

**Terraform:**
```bash
# Export drift as Terraform-compatible format
jq -r '.drifts[] | .drifts[] | 
  "resource \"" + .resourceType + "\" \"" + .resourceName + "\" {\n  " + 
  .property + " = " + .current + "\n}"' \
  drift-details.json > drift.tf
```

**Ansible:**
```bash
# Generate Ansible playbook to accept drift
jq -r '.drifts[] | 
  "- name: Update " + .resourceName + "\n  azure_rm_webapp:\n    " + 
  .property + ": " + .current' \
  drift-details.json > accept-drift.yml
```

## Reference

### Script Options

**detect-drift.sh**
```
--deployment-id <id>           Required: Deployment to check
--output-format <fmt>          json | markdown | github (default: markdown)
--include-known-drift          Include previously accepted drift
--verbose                      Show detailed progress
```

**accept-drift.sh**
```
--deployment-id <id>           Required: Deployment to accept drift for
--reason <text>                Reason for acceptance (audit requirement)
--auto-commit                  Create git commit automatically
```

**revert-drift.sh**
```
--deployment-id <id>           Required: Deployment to revert
--confirm                      Skip confirmation prompt
--dry-run                      Show what would be reverted
```

**drift-check-all.sh**
```
--format <fmt>                 summary | detailed | json (default: summary)
--only-critical                Only report critical drift
--include-known-drift          Include accepted drift
--verbose                      Show detailed progress
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No drift detected / successful operation |
| 1 | Warning-level drift found |
| 2 | Critical drift found |
| 3+ | Error during execution |

## Related Documentation

- [Deployment State Management](./state)
- [Azure MCP Setup](../getting-started/azure-setup)
- [CAF Naming Conventions](https://github.com/Azure/git-ape/blob/main/.github/copilot-instructions.md)
- [Integration Testing](https://github.com/Azure/git-ape/blob/main/.github/skills/azure-integration-tester/SKILL.md)
