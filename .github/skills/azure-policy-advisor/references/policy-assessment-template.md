# Azure Policy Assessment Report Template

This is the full markdown report template emitted by Step 6 of the
`azure-policy-advisor` skill. The skill SKILL.md only includes a short
outline; this file holds the verbatim template that the skill instantiates
when writing `policy-assessment.md` to the deployment directory.

The report is split into two clear action tracks — **template improvements**
(changes to the ARM template) and **subscription-level actions** (policy /
initiative assignments) — so it's obvious who needs to act and where.

---

```markdown
## Azure Policy Compliance Assessment

**Scope:** {subscription or resource group}
**Deployment:** {deployment ID or "general subscription audit"}
**Compliance Framework:** {framework from copilot-instructions.md or user input}
**Enforcement Mode:** {Audit or Deny}
**Subscription Policy State:** {Queried | Not available (no az login)}

### Summary

| Category | Recommended | Already Assigned | Template Compliant | Template Fixable | Subscription-Level Gap |
|----------|-------------|-----------------|-------------------|-----------------|----------------------|
| Storage | 7 | 2 | 3 | 1 | 1 |
| Key Vault | 5 | 0 | 4 | 1 | 0 |
| Networking | 4 | 0 | 1 | 1 | 2 |
| Total | 16 | 2 | 8 | 3 | 3 |

---

## Part 1: Template Improvements

_Changes to apply directly in the ARM template to close compliance gaps. These make the deployment itself compliant, independent of policy enforcement._

**Who acts:** Template author / developer
**Where:** `.azure/deployments/{deployment-id}/template.json`

### Gaps Fixable in the Template

_These gaps can be closed by adding or modifying resources in the ARM template. For each gap, provide the exact ARM template JSON to add — including the full resource definition (type, apiVersion, name, properties), required `dependsOn` references, and any new variables needed._

| # | Resource Type | Gap | Compliance Control | Fix |
|---|--------------|-----|-------------------|-----|
| 1 | Storage Account | Blob soft delete not enabled | CP-9 (Contingency Planning) | Add `blobServices/default` child resource with `deleteRetentionPolicy.enabled: true` |
| 2 | Storage Account | No diagnostic settings | AU-2, AU-6, AU-12 (Audit & Accountability) | Add Log Analytics workspace + diagnostic settings resource |
| 3 | Key Vault | No resource logs | AU-2, AU-6 (Audit & Accountability) | Add diagnostic settings for AuditEvent category |
| 4 | NSGs | No flow logs | AU-2, SI-4 (System Monitoring) | Add `networkWatchers/flowLogs` resources |

> After applying these changes, re-run the assessment to verify compliance.

### Already Compliant in Template

_These properties are correctly configured. No template changes needed. Corresponding policies in Part 2 would prevent future drift._

| # | Resource Type | Property | Template Value | Compliance Control |
|---|--------------|----------|---------------|-------------------|
| 1 | Storage Account | HTTPS only | `supportsHttpsTrafficOnly: true` | SC-8 (Transmission Confidentiality) |
| 2 | Storage Account | Public access disabled | `allowBlobPublicAccess: false` | AC-3 (Access Enforcement) |
| 3 | Storage Account | Shared key disabled | `allowSharedKeyAccess: false` | IA-2 (Identification & Authentication) |
| 4 | Key Vault | RBAC enabled | `enableRbacAuthorization: true` | AC-3 (Access Enforcement) |

---

## Part 2: Subscription-Level Actions

_Policy and initiative assignments at subscription or management group scope. These enforce compliance across ALL resources — not just this deployment._

**Who acts:** Platform team / subscription admin
**Where:** Azure subscription `{subscription-id}`

### Existing Policy Assignments (from Azure)

_Already active. No action needed unless enforcement mode should change._

| # | Policy/Initiative | Scope | Enforcement | Type | Relevant to Deployment? |
|---|------------------|-------|-------------|------|------------------------|
| 1 | {assignment name} | Subscription | Default | Built-in | ✅/❌ |
| 2 | {assignment name} | Mgmt Group (inherited) | Default | Initiative | ✅/❌ |

### Unassigned Custom Policies (from Azure)

_Custom definitions exist in your subscription or management group but are NOT assigned. These were created by your organization and may cover requirements that built-in policies do not._

| # | Policy | Category | Target Resource | Effect | Scope |
|---|--------|----------|----------------|--------|-------|
| 1 | {custom policy name} | Storage | Microsoft.Storage/storageAccounts | Modify | Mgmt Group |

> 🟣 **Action:** These already exist — they just need assignment. Prioritize over built-in equivalents.

### Recommended Built-in Policy Assignments

_Policies from Microsoft Learn that are not covered by existing assignments or custom definitions._

| # | Policy | Effect | Severity | Definition ID | Category | Source |
|---|--------|--------|----------|--------------|----------|--------|
| 1 | NSG flow logs | Audit | 🟠 High | 27960feb-... | Networking | [MS Learn]({url}) |
| 2 | Allowed locations | Audit | 🟡 Medium | e56962a6-... | General | [MS Learn]({url}) |

### Recommended Compliance Initiative

_If a compliance framework was selected:_

| Initiative | Policies | Built-in ID | Status |
|------------|----------|-------------|--------|
| NIST SP 800-53 Rev. 5 | 696 | 179d1daa-... | ⚠️ Not assigned |

Assigning this initiative covers {N} of the {M} individual policies recommended above.
Remaining {M-N} policies need individual assignment.
```
