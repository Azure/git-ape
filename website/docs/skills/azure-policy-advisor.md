---
title: "Azure Policy Advisor"
sidebar_label: "Azure Policy Advisor"
description: "Assess Azure Policy compliance for ARM template resources. Queries existing subscription assignments and unassigned custom/built-in definitions, cross-references with Microsoft Learn recommendations. Produces per-resource policy recommendations with implementation options."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/azure-policy-advisor/SKILL.md -->


# Azure Policy Advisor

> Assess Azure Policy compliance for ARM template resources. Queries existing subscription assignments and unassigned custom/built-in definitions, cross-references with Microsoft Learn recommendations. Produces per-resource policy recommendations with implementation options.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/azure-policy-advisor/` |
| **Phase** | Pre-Deploy |
| **User Invocable** | ✅ Yes |
| **Usage** | `/azure-policy-advisor ARM template JSON or resource types to assess, and optionally a compliance framework (CIS, NIST, general)` |


## Documentation

# Azure Policy Advisor

Recommend Azure Policy assignments for ARM template resources by combining three sources of truth: existing Azure subscription policy state (assignments + definitions), Microsoft Learn built-in recommendations, and ARM template configuration analysis. Produces per-resource policy recommendations with severity ratings, built-in/custom definition IDs, and ready-to-use implementation options.

## When to Use

- After template generation — recommend policies that complement deployed resources
- Compliance audit — assess resources against CIS, NIST, or general best practices
- During onboarding — recommend baseline policies for a new subscription
- When user asks "what policies should we enforce?" or "are we compliant with X?"

## Procedure

### 1. Load Compliance Context and Identify Resources

Read compliance preferences from the `## Compliance & Azure Policy` section in `copilot-instructions.md` (available automatically in conversation context). Extract:

- **Compliance frameworks** (e.g., CIS Azure Foundations v3.0, NIST SP 800-53 Rev 5, general best practices)
- **Enforcement mode** (Audit or Deny)
- **Policy categories** (identity, networking, storage, compute, monitoring, tagging)

If no compliance section exists in copilot-instructions.md, ask the user:

```
Which compliance approach should I assess against?
1. General Azure best practices (recommended)
2. CIS Azure Foundations v3.0
3. NIST SP 800-53 Rev 5
4. Custom — tell me what to check
```

Then parse the ARM template (if provided) to extract all resource types:

```markdown
Extract for each resource:
- Resource type (e.g., Microsoft.Storage/storageAccounts)
- Resource name
- Current security-relevant properties (cross-reference with security-analyzer output if available)
```

### 2. Query Existing Policy Assignments in Azure Subscription

Before recommending new policies, discover what is **already enforced** in the target subscription. This prevents redundant recommendations and surfaces enforcement gaps.

**Query active assignments at subscription scope (including inherited from management groups):**

```bash
# List all policy assignments at subscription scope (includes inherited from management groups)
az policy assignment list \
  --subscription "{subscription-id}" \
  --query "[].{name:name, displayName:displayName, policyDefinitionId:policyDefinitionId, enforcementMode:enforcementMode, scope:scope}" \
  -o json

# List initiative (policy set) assignments separately
az policy assignment list \
  --subscription "{subscription-id}" \
  --query "[?contains(policyDefinitionId, 'policySetDefinitions')]" \
  -o json
```

**Parse each assignment to extract:**
- Assignment name and display name
- Policy definition ID (built-in or custom)
- Enforcement mode (`Default` or `DoNotEnforce`)
- Assignment scope (management group, subscription, or resource group)
- Whether it's an individual policy or part of an initiative

**Build an assignment index** keyed by policy definition ID for fast lookup in later steps:

```
assignedPolicies = {
  "/providers/Microsoft.Authorization/policyDefinitions/{id}": {
    "assignmentName": "...",
    "enforcementMode": "Default",
    "scope": "/subscriptions/{sub-id}",
    "source": "subscription"  // or "management-group-inherited"
  },
  ...
}
```

**If Azure CLI is not available** (e.g., no active session), skip this step and note in the report:

```markdown
⚠️ Could not query Azure subscription — existing assignments unknown.
   Recommendations are based on Microsoft Learn and template analysis only.
   Run `az login` and re-run for subscription-aware assessment.
```

### 3. Discover Unassigned Policy Definitions in Subscription

Query the subscription for policy definitions that **exist but are not currently assigned**. This surfaces custom policies created by the organization (e.g., org-specific NIST controls, industry-specific rules) that may be relevant to the resources being deployed.

**Query custom policy definitions:**

```bash
# List custom policy definitions scoped to the subscription
az policy definition list \
  --subscription "{subscription-id}" \
  --query "[?policyType=='Custom'].{name:name, displayName:displayName, description:description, category:metadata.category, policyRule:policyRule}" \
  -o json

# List custom initiative definitions
az policy set-definition list \
  --subscription "{subscription-id}" \
  --query "[?policyType=='Custom'].{name:name, displayName:displayName, description:description, policyDefinitions:policyDefinitions}" \
  -o json
```

**Also check management group scope** (custom policies are often defined at the management group level):

```bash
# If the subscription belongs to a management group
az policy definition list \
  --management-group "{mg-name}" \
  --query "[?policyType=='Custom'].{name:name, displayName:displayName, description:description, category:metadata.category}" \
  -o json
```

**For each custom definition, extract and classify:**

| Field | Purpose |
|-------|---------|
| `displayName` | Human-readable policy name |
| `metadata.category` | Maps to resource categories (Storage, Compute, Network, etc.) |
| `policyRule.if.field` | Which resource type/property it targets |
| `policyRule.then.effect` | What it enforces (Deny, Audit, etc.) |

**Match custom definitions to ARM template resource types:**

For each custom policy definition:
1. Parse `policyRule.if` conditions to extract the target resource type (e.g., `"field": "type", "equals": "Microsoft.Storage/storageAccounts"`)
2. If the target resource type matches a resource in the ARM template being assessed, flag it as **relevant**
3. Cross-reference with the assignment index from Step 2 — if the definition exists but has no matching assignment, mark it as **unassigned custom policy**

**Build a definitions index:**

```
unassignedDefinitions = {
  "/subscriptions/{sub-id}/providers/Microsoft.Authorization/policyDefinitions/{custom-id}": {
    "displayName": "Require NIST-compliant encryption on storage accounts",
    "category": "Storage",
    "targetResourceType": "Microsoft.Storage/storageAccounts",
    "effect": "Deny",
    "source": "custom"  // or "custom-management-group"
  },
  ...
}
```

**If Azure CLI is not available**, skip this step and note in the report:

```markdown
⚠️ Could not query Azure subscription — custom policy definitions unknown.
   Recommendations are based on Microsoft Learn built-in policies only.
```

### 4. Research Applicable Built-in Policies via Microsoft Learn

**For EACH resource type**, query Microsoft Learn for current built-in policy definitions:

```
Tool: microsoft_docs_search
Query: "Azure Policy built-in {resource-type-category}"

Examples:
- "Azure Policy built-in Storage Accounts"
- "Azure Policy built-in App Service Function Apps"
- "Azure Policy built-in SQL Server database"
- "Azure Policy built-in Key Vault"
- "Azure Policy built-in Kubernetes AKS"
- "Azure Policy built-in virtual machines compute"
- "Azure Policy built-in network security"
- "Azure Policy built-in monitoring diagnostic settings"
```

For **compliance frameworks**, also query:

```
Tool: microsoft_docs_search
Query: "Azure Policy built-in initiative {framework-name}"

Examples:
- "Azure Policy built-in initiative CIS Azure Foundations"
- "Azure Policy built-in initiative NIST SP 800-53"
- "Azure Policy regulatory compliance initiative"
```

When search results reference a high-value page, use `microsoft_docs_fetch` to retrieve the full content:

```
Tool: microsoft_docs_fetch
URL: https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies

Use this to get the complete list of built-in policies organized by category (Storage, App Service, SQL, Key Vault, Network, Monitoring, etc.)
```

Key Microsoft Learn reference pages:

| Content | URL |
|---------|-----|
| All built-in policies | `https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies` |
| Built-in initiatives | `https://learn.microsoft.com/azure/governance/policy/samples/built-in-initiatives` |
| Regulatory compliance | `https://learn.microsoft.com/azure/governance/policy/concepts/regulatory-compliance` |
| Policy assignment via ARM | `https://learn.microsoft.com/azure/governance/policy/assign-policy-template` |
| Policy effects reference | `https://learn.microsoft.com/azure/governance/policy/concepts/effect-basics` |

### 5. Classify and Prioritize Recommendations

Group recommended policies into severity tiers based on the enforcement mode from compliance context:

| Tier | Effect (Audit mode) | Effect (Deny mode) | When to Use |
|------|--------------------|--------------------|-------------|
| 🔴 **Critical** | Audit | Deny | Prevents insecure deployments: public storage access, missing HTTPS, no encryption |
| 🟠 **High** | Audit | Deny | Strong security posture: managed identity required, TLS 1.2, AAD-only auth |
| 🟡 **Medium** | Audit | Audit | Visibility and tracking: tag compliance, diagnostic settings, allowed locations |
| 🔵 **Low** | AuditIfNotExists | DeployIfNotExists | Auto-remediation: deploy diagnostic settings, enable monitoring |

**Per resource type, prioritize these policy categories:**

**Storage Accounts:**
1. 🔴 Require secure transfer (HTTPS)
2. 🔴 Disable public blob access
3. 🟠 Disable shared key access
4. 🟠 Require minimum TLS 1.2
5. 🟡 Require private endpoints (production)
6. 🟡 Enable soft delete for blobs and containers
7. 🔵 Deploy diagnostic settings

**App Service / Function Apps:**
1. 🔴 Require HTTPS only
2. 🔴 Require managed identity
3. 🟠 Require minimum TLS 1.2
4. 🟠 Disable FTP / require FTPS only
5. 🟡 Disable public network access (production)
6. 🔵 Enable resource logs

**SQL Servers / Databases:**
1. 🔴 Require AAD-only authentication
2. 🔴 Enable transparent data encryption
3. 🟠 Enable auditing
4. 🟠 Enable Advanced Threat Protection
5. 🟡 Require private endpoints (production)
6. 🔵 Deploy diagnostic settings

**Key Vault:**
1. 🔴 Enable RBAC authorization
2. 🔴 Enable soft delete and purge protection
3. 🟠 Disable public network access (production)
4. 🟡 Require private endpoints
5. 🔵 Deploy diagnostic settings for audit events

**Compute / VMs:**
1. 🔴 Require managed disks
2. 🟠 Require managed identity
3. 🟡 Restrict allowed VM SKUs
4. 🟡 Require approved extensions only
5. 🔵 Deploy monitoring agent

**AKS / Kubernetes:**
1. 🔴 Require managed identity
2. 🔴 Disable local accounts
3. 🟠 Require Azure Policy add-on
4. 🟠 Require network policy
5. 🟡 Require authorized IP ranges for API server
6. 🔵 Enable Container Insights

**Networking:**
1. 🟠 Require NSG flow logs
2. 🟡 Enable Network Watcher
3. 🟡 Restrict allowed locations
4. 🔵 Deploy DDoS protection (production)

**General / Cross-cutting:**
1. 🟡 Require tags on resources (ManagedBy, Environment, Project)
2. 🟡 Restrict allowed locations
3. 🔵 Require resource group tags inheritance

For each recommendation, cross-reference with the ARM template, existing assignments (Step 2), and available definitions (Step 3) to determine status:

- ✅ **Already assigned** — policy is actively assigned in the subscription (from Step 2). Note enforcement mode (`Default` vs `DoNotEnforce`) and scope
- 🔵 **Compliant via template** — ARM template already configures the property the policy would enforce, but policy is not assigned
- 🟣 **Unassigned custom policy available** — a custom policy definition exists in the subscription/management group (from Step 3) that covers this check, but it is not assigned. Flag for immediate assignment
- ⚠️ **Gap — not covered** — neither assigned nor available as a custom definition. Recommend the built-in policy from MS Learn
- 🔄 **Complementary** — policy would add enforcement on top of existing template config and/or existing assignments

**Priority when multiple sources cover the same check:**
1. If already assigned → report as ✅ (no action needed, unless enforcement mode is `DoNotEnforce`)
2. If a custom definition exists but is unassigned → recommend assigning it (🟣) over the built-in equivalent
3. If only a built-in definition exists → recommend the built-in (⚠️)

### 6. Generate Policy Recommendations Report

Present findings split into two clear action tracks: **template improvements** (changes to the ARM template) and **subscription-level actions** (policy/initiative assignments). This separation clarifies who needs to act and where.

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

### 7. Provide Implementation Options

Split implementation guidance into both tracks:

**Track 1: Template Changes (for gaps in Part 1)**

For each gap listed in Part 1, provide the exact ARM template JSON to add. Include:
- The full resource definition (type, apiVersion, name, properties)
- Required `dependsOn` references
- Any new variables needed (e.g., Log Analytics workspace name)

Present as ready-to-copy code blocks that the developer can insert into the nested template's `resources` array. Group related resources together (e.g., Log Analytics workspace + all diagnostic settings that depend on it).

**Track 2: Subscription-Level Assignments (for gaps in Part 2)**

**Option A: Azure CLI (quickest for individual policies)**

```bash
# Assign unassigned custom policies (prioritize — they already exist)
az policy assignment create \
  --name "{custom-policy-short-name}" \
  --display-name "{custom policy display name}" \
  --policy "{full-custom-definition-id-with-mg-scope}" \
  --scope "/subscriptions/{subscription-id}" \
  --enforcement-mode DoNotEnforce

# Assign a built-in policy at subscription scope
az policy assignment create \
  --name "{policy-short-name}" \
  --display-name "{policy display name}" \
  --policy "{built-in-definition-id}" \
  --scope "/subscriptions/{subscription-id}" \
  --params '{}' \
  --enforcement-mode Default

# Assign a compliance initiative
az policy assignment create \
  --name "{initiative-short-name}" \
  --display-name "{initiative display name}" \
  --policy-set-definition "{initiative-id}" \
  --scope "/subscriptions/{subscription-id}"
```

**Option B: ARM Template (for IaC-managed policies)**

```json
{
  "type": "Microsoft.Authorization/policyAssignments",
  "apiVersion": "2024-04-01",
  "name": "{assignment-name}",
  "properties": {
    "displayName": "{display name}",
    "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/{built-in-id}",
    "scope": "/subscriptions/{subscription-id}",
    "enforcementMode": "Default",
    "parameters": {}
  }
}
```

**Enforcement mode guidance:**

| Mode | When to Use |
|------|-------------|
| `Default` | Active enforcement — new non-compliant resources are denied or audited |
| `DoNotEnforce` | Audit-only — evaluates compliance without blocking. Recommended for initial rollout |

### 📋 Policy Gate

The policy gate is **advisory** — it surfaces findings without blocking deployment.

```markdown
### 📋 Policy Gate: ADVISORY

**Part 1 — Template Compliance:**
🔵 {T} of {R} checks pass via template configuration
🔧 {F} gaps can be fixed by updating the template (see Part 1)

**Part 2 — Subscription Enforcement:**
✅ {A} policies already assigned in subscription
🟣 {C} custom policies available but unassigned — assign for immediate coverage
⚠️ {S} subscription-level gaps — recommend assigning built-in policies or initiative
📊 Enforcement coverage: {percentage}% of recommended policies actively assigned

**Action items:**

_Template (developer):_
1. 🔧 {list of template changes from Part 1, e.g. "Add blob soft delete", "Add diagnostic settings"}

_Subscription (platform team):_
1. 🟣 Assign existing custom policies: {list — these already exist, just need assignment}
2. ⚠️ Assign built-in policies: {list of built-in policies to assign}
3. {initiative to assign if framework selected}
```

## Output Artifacts

When invoked during a deployment workflow, save results to the deployment directory:

| File | Format | Content |
|------|--------|---------|
| `policy-assessment.md` | Markdown | Full assessment report (Section 4 output) |
| `policy-recommendations.json` | JSON | Structured policy data for automation |

**JSON structure for `policy-recommendations.json`:**
```json
{
  "assessedAt": "2026-04-07T19:00:00Z",
  "deploymentId": "{deployment-id}",
  "framework": "{compliance-framework}",
  "enforcementMode": "Audit",
  "subscriptionState": "queried",
  "summary": {
    "totalRecommended": 16,
    "alreadyAssigned": 2,
    "templateCompliant": 8,
    "templateFixable": 3,
    "customAvailable": 1,
    "subscriptionGaps": 3
  },
  "existingAssignments": [
    {
      "name": "Secure transfer to storage accounts should be enabled",
      "definitionId": "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9",
      "enforcementMode": "Default",
      "scope": "/subscriptions/{subscription-id}",
      "assignedVia": "direct",
      "policyType": "BuiltIn",
      "relevantToDeployment": true
    }
  ],
  "unassignedCustomDefinitions": [
    {
      "name": "SFI-ID4.2.1 Storage Accounts - Safe Secrets Standard",
      "definitionId": "/providers/Microsoft.Management/managementGroups/{mg-id}/providers/Microsoft.Authorization/policyDefinitions/{custom-id}",
      "category": "Storage",
      "targetResourceType": "Microsoft.Storage/storageAccounts",
      "effect": "Modify",
      "definitionScope": "management-group",
      "actionTrack": "subscription"
    }
  ],
  "templateImprovements": [
    {
      "resourceType": "Microsoft.Storage/storageAccounts",
      "gap": "Blob soft delete not enabled",
      "complianceControl": "CP-9 (Contingency Planning)",
      "severity": "medium",
      "fix": "Add blobServices/default child resource with deleteRetentionPolicy.enabled: true",
      "actionTrack": "template"
    },
    {
      "resourceType": "Microsoft.Storage/storageAccounts",
      "gap": "No diagnostic settings",
      "complianceControl": "AU-2, AU-6, AU-12 (Audit & Accountability)",
      "severity": "high",
      "fix": "Add Log Analytics workspace + Microsoft.Insights/diagnosticSettings",
      "actionTrack": "template"
    }
  ],
  "policies": [
    {
      "name": "Secure transfer to storage accounts should be enabled",
      "definitionId": "404c3081-a854-4457-ae30-26a93ef643f9",
      "effect": "Deny",
      "severity": "critical",
      "category": "Storage",
      "status": "already-assigned",
      "policyType": "BuiltIn",
      "actionTrack": "none",
      "sourceUrl": "https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies#storage"
    },
    {
      "name": "Disable shared key access",
      "definitionId": "{built-in-id}",
      "effect": "Audit",
      "severity": "high",
      "category": "Storage",
      "status": "template-compliant",
      "policyType": "BuiltIn",
      "actionTrack": "subscription",
      "sourceUrl": "https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies#storage"
    },
    {
      "name": "Enable blob soft delete",
      "definitionId": null,
      "effect": null,
      "severity": "medium",
      "category": "Storage",
      "status": "template-fixable",
      "policyType": null,
      "actionTrack": "template",
      "sourceUrl": null
    },
    {
      "name": "NSG flow logs should be enabled",
      "definitionId": "27960feb-a23c-4577-8d36-ef8b5f35e0be",
      "effect": "Audit",
      "severity": "high",
      "category": "Networking",
      "status": "gap",
      "policyType": "BuiltIn",
      "actionTrack": "subscription",
      "sourceUrl": "https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies#network"
    }
  ],
  "initiative": {
    "name": "NIST SP 800-53 Rev. 5",
    "builtInId": "179d1daa-458f-4e47-8086-2a68d0d6c38f",
    "policyCount": 696,
    "status": "not-assigned",
    "coverage": "covers {N} of {M} recommended policies"
  }
}
```

**Status values for the `status` field:**

| Value | Meaning | Action Track |
|-------|---------|-------------|
| `already-assigned` | Policy actively assigned in subscription (✅) | `none` |
| `template-compliant` | ARM template satisfies the policy, not assigned (🔵) | `subscription` (assign to prevent drift) |
| `template-fixable` | Gap that can be closed by modifying the template (🔧) | `template` |
| `custom-available` | Custom definition exists but not assigned (🟣) | `subscription` |
| `gap` | Not covered — recommend built-in policy assignment (⚠️) | `subscription` |
| `complementary` | Would add enforcement on top of existing config (🔄) | `subscription` |

**Action track values for the `actionTrack` field:**

| Value | Meaning |
|-------|---------|
| `template` | Fix by modifying the ARM template (Part 1 — developer) |
| `subscription` | Fix by assigning a policy at subscription scope (Part 2 — platform team) |
| `none` | No action needed (already assigned or compliant) |

## Integration with Git-Ape

- **Template Generator:** After `/azure-security-analyzer`, optionally invoke `/azure-policy-advisor` to recommend subscription-level policies that complement the template
- **Onboarding:** After RBAC setup, the onboarding flow captures compliance preferences and adds them to `copilot-instructions.md` — this skill reads them automatically
- **Drift Detector:** Cross-reference drift findings with policy recommendations — drift items covered by assigned policies will auto-remediate
