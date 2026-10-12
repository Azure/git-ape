# Lab 4: Policy Compliance

> 15 minutes | Azure subscription helpful but not required

Assess ARM templates against Azure Policy compliance frameworks and understand enforcement options.

## What You Learn

- How the Policy Advisor assesses templates against CIS/NIST frameworks
- How to read policy recommendations
- The difference between audit and deny enforcement

## Step 1: Run the Policy Advisor

In Copilot Chat:

```text
@azure-policy-advisor assess my deployment against CIS Azure Foundations
```

Point it at a deployment template from a previous lab.

## Step 2: Read the Assessment

The Policy Advisor produces a two-part report:

### Part 1: Template Improvements

Findings that can be fixed directly in the ARM template:

```
✅ Storage account encryption: Enabled (Microsoft-managed keys)
✅ HTTPS-only: Enforced on all web resources
✅ TLS minimum version: 1.2
⚠️ Diagnostic settings: Not configured on SQL Server
   → Recommendation: Add diagnostic settings to send logs to Log Analytics
⚠️ Network access: Storage account allows public access
   → Recommendation: Restrict to VNet or private endpoint
```

### Part 2: Subscription-Level Policies

Azure Policy assignments recommended for your subscription:

```
🔵 Audit: Storage accounts should restrict network access
   Policy ID: 34c877ad-507e-4c82-993e-3452a6e0ad3c
   Effect: Audit (surfaces non-compliance without blocking)

🔵 Audit: SQL servers should have auditing enabled
   Policy ID: a6fb4358-5bf4-4ad7-ba82-2cd2f41ceae9
   Effect: Audit
```

## Step 3: Understand Enforcement Modes

| Mode | Effect | When to Use |
|------|--------|-------------|
| **Audit** | Log non-compliance, don't block | Initial rollout — see what would be caught |
| **AuditIfNotExists** | Log when a companion resource is missing | Check for diagnostic settings, locks |
| **Deny** | Block non-compliant deployments | Production hardening — enforce standards |

> **Git-Ape default:** Audit mode for policy assessment. The security gate handles blocking for security-specific issues.

## Step 4: Review the Compliance Summary

```
CIS Azure Foundations v3.0 Assessment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Compliant:  14 controls
⚠️ Partially:  3 controls (recommendations provided)
❌ Non-compliant: 0 controls
ℹ️ Not applicable: 5 controls
```

## Step 5: Apply a Recommendation (Optional)

If the advisor recommends adding diagnostic settings, ask Git-Ape to implement it:

```text
@git-ape add diagnostic settings to the SQL server, sending logs to the Log Analytics workspace
```

Re-run the policy advisor to confirm the recommendation is resolved.

## What You Learned

| Concept | What It Means |
|---------|--------------|
| **Policy assessment** | Templates checked against CIS/NIST frameworks before deployment |
| **Two-part report** | Part 1: template fixes. Part 2: subscription policy assignments. |
| **Audit vs Deny** | Audit observes non-compliance. Deny prevents it. |
| **Advisory gate** | Policy assessment is non-blocking (unlike security gate which blocks) |
| **Compliance score** | Per-framework compliance summary with actionable recommendations |

**Next:** [Lab 5 — IaC Export](lab-05-iac-export.md)

## Step 6: Policy is advisory, not blocking

The Policy Advisor is ADVISORY: it surfaces findings but does NOT block deployment. Enforcement is your subscription's responsibility:

- Audit mode (recommended default): policies log non-compliance, allow deploys.
- Deny mode (production hardening): policies block deploys; requires Azure Policy assignment at sub/MG scope.

The advisor tells you what would happen under Deny so you can decide.

## Step 7: Where the advisor saves output

Two files in the deployment directory:

- policy-assessment.md: human-readable per-policy report.
- policy-recommendations.json: machine-readable; used by PR comments.

If missing in a deploy, the advisor did not run; check workflow.

## Step 8: Live subscription queries

The advisor queries YOUR subscription's actual policy assignments, not a hardcoded list:

az policy assignment list --subscription <sub-id> -o table

It also catalogs unassigned custom definitions you could enforce.

## Going further

- Skill: .github/skills/azure-policy-advisor/SKILL.md
- Agent: .github/agents/azure-policy-advisor.agent.md
