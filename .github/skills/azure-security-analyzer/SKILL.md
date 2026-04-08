---
name: azure-security-analyzer
description: "Analyze Azure resource configurations against security best practices using Azure MCP bestpractices service. Produces per-resource security assessment with severity ratings and recommendations. Use during template generation before deployment confirmation."
argument-hint: "Resource types and their configurations from the ARM template"
user-invocable: true
---

# Azure Security Analyzer

Analyze Azure resource configurations against Microsoft security best practices and produce a per-resource security assessment report.

## When to Use

- During template generation (invoked by the template generator before deployment confirmation)
- To audit an existing ARM template for security gaps
- When user asks "is this secure?" or "check security" for a deployment
- Post-deployment security review

## Verification Integrity Rules (CRITICAL)

**Every claim in the security report MUST be verifiable against the ARM template.** Never fabricate, assume, or misrepresent security status.

### Rule 1: Cite Exact Evidence

Every "✅ Applied" status **MUST cite the exact ARM template property path and its value** that proves the control is in place. If you cannot point to a specific property in the template JSON, you cannot mark it as applied.

```markdown
# ✅ CORRECT — cites exact property
| HTTPS-only | 🔴 Critical | ✅ Applied | `properties.httpsOnly: true` | Explicitly set in template |

# ❌ WRONG — no evidence from template
| Disk encryption | 🔴 Critical | ✅ Applied | `managedDisk.storageAccountType` | This property is the performance tier, NOT encryption |
```

### Rule 2: Distinguish Explicit Config vs Platform Defaults

Azure provides some security controls by default (e.g., SSE at rest on managed disks). These are NOT the same as explicitly configured controls.

| Status | Icon | Meaning | When to Use |
|--------|------|---------|-------------|
| **✅ Applied** | ✅ | Explicitly configured in the ARM template | Property exists in template JSON with secure value |
| **🔄 Platform Default** | 🔄 | Azure provides this automatically, NOT in template | Control exists due to Azure platform behavior, not template config |
| **⚠️ Not applied** | ⚠️ | Control is missing and should be considered | Property absent from template, no platform default covers it |
| **❌ Misconfigured** | ❌ | Property exists but set to an insecure value | Property in template with wrong/insecure value |

```markdown
# ✅ CORRECT — distinguishes platform default from explicit config
| SSE at rest (managed disks) | 🟡 Medium | 🔄 Platform Default | Not in template | Azure encrypts all managed disks at rest with platform-managed keys automatically |
| Encryption at host (ADE) | 🟡 Medium | ⚠️ Not applied | `securityProfile.encryptionAtHost` absent | Not enabled — would encrypt temp disks and caches too |

# ❌ WRONG — claims explicit config for a platform default
| Managed disk encryption | 🔴 Critical | ✅ Applied | `managedDisk.storageAccountType` | WRONG: storageAccountType is performance tier, not encryption |
```

### Rule 3: Never Use Misleading Framing

Describe security status **accurately and literally**. Do not soften or reframe risks.

```markdown
# ❌ WRONG — misleading framing
| No open SSH to internet | 🔴 Critical | ✅ Applied |
# This is misleading: the VM HAS a public IP with port 22 open.
# IP-restriction reduces risk but port 22 IS internet-reachable.

# ✅ CORRECT — accurate framing
| SSH not open to 0.0.0.0/0 | 🔴 Critical | ✅ Applied | `sourceAddressPrefix: 175.x.x.x/32` | Restricted to single IP |
| VM is internet-facing (public IP + port 22) | 🟠 High | ⚠️ Risk accepted | Public IP attached to NIC | Port 22 reachable from internet (IP-restricted). Safer: Azure Bastion |
```

**Specific rules:**
- If a VM has a public IP → it IS internet-facing. Always flag this.
- If any port is open, even IP-restricted → state the port IS open and note the restriction as mitigation, not as "closed."
- If encryption is platform-default → say "platform default", not "applied."
- If a property is absent from the template → say "not configured", not "applied" based on assumptions.

### Rule 4: Verify Before Reporting

Before generating the security report, perform this verification checklist:

1. **For each "✅ Applied" entry**: Search the ARM template JSON for the cited property. If not found → change status.
2. **For each security claim**: Confirm the ARM property cited actually controls what you claim. (e.g., `storageAccountType` is NOT encryption)
3. **For network exposure**: Check if any `publicIPAddress` resource is attached to a NIC. If yes → VM is internet-facing, period.
4. **For encryption claims**: Distinguish between SSE (automatic), ADE (explicit extension), and encryption at host (explicit VM property).
5. **Cross-check property paths**: Use the correct ARM template property paths, not invented or approximate ones.

### Rule 5: When Uncertain, Mark as Unknown

If you cannot determine a security status with certainty:

```markdown
| {check} | {severity} | ❓ Unknown | {property} | Unable to verify — property path unclear or resource type not in checklist |
```

**Never guess. Never fabricate. When in doubt, flag it.**

## Procedure

### 1. Extract Resources from Template

Parse the ARM template or requirements to identify all resources and their configurations:

```markdown
Input: ARM template JSON or resource configuration list

Extract for each resource:
- Resource type (e.g., Microsoft.Storage/storageAccounts)
- Resource name
- All security-relevant properties
- Current configuration values
```

### 2. Query Azure MCP Best Practices (Per Resource)

**For EACH resource type**, query the Azure MCP `bestpractices` service to get security recommendations:

```
Tool: mcp_azure_mcp_search
Intent: "bestpractices {resource-type}"

Examples:
- "bestpractices Microsoft.Storage/storageAccounts"
- "bestpractices Microsoft.Web/sites"
- "bestpractices Microsoft.Sql/servers"
- "bestpractices Microsoft.DocumentDB/databaseAccounts"
- "bestpractices Microsoft.KeyVault/vaults"
- "bestpractices Microsoft.ContainerApp/containerApps"
```

Parse the MCP response for:
- Security recommendations with severity levels
- Configuration best practices
- Compliance alignment notes (CIS, SOC2, PCI-DSS)
- Microsoft Defender for Cloud recommendations

### 3. Check Resource-Specific Security Properties

Cross-reference MCP recommendations against the template configuration.

**Storage Accounts (Microsoft.Storage/storageAccounts):**

| # | Check | Property | Severity | Secure Value |
|---|-------|----------|----------|--------------|
| 1 | HTTPS-only transfer | `supportsHttpsTrafficOnly` | 🔴 Critical | `true` |
| 2 | TLS 1.2 minimum | `minimumTlsVersion` | 🔴 Critical | `TLS1_2` |
| 3 | Disable public blob access | `allowBlobPublicAccess` | 🟠 High | `false` |
| 4 | Blob soft delete | `deleteRetentionPolicy.enabled` | 🟠 High | `true` |
| 5 | Container soft delete | `containerDeleteRetentionPolicy.enabled` | 🟡 Medium | `true` |
| 6 | Disable shared key access | `allowSharedKeyAccess` | � High | `false` |
| 7 | Network rules / firewall | `networkAcls.defaultAction` | 🟡 Medium | `Deny` (prod) |
| 8 | Private endpoint | Private endpoint resource | 🟡 Medium | Configured (prod) |
| 9 | Infrastructure encryption | `encryption.requireInfrastructureEncryption` | 🔵 Low | `true` |
| 10 | Immutability policy | `immutableStorageWithVersioning` | 🔵 Low | Enabled (compliance) |

**Function Apps / App Services (Microsoft.Web/sites):**

| # | Check | Property | Severity | Secure Value |
|---|-------|----------|----------|--------------|
| 1 | HTTPS-only | `httpsOnly` | 🔴 Critical | `true` |
| 2 | TLS 1.2 minimum | `siteConfig.minTlsVersion` | 🔴 Critical | `1.2` |
| 3 | Managed identity | `identity.type` | 🔴 Critical | `SystemAssigned` |
| 4 | Identity-based storage access | `AzureWebJobsStorage__accountName` (not `AzureWebJobsStorage`) | 🔴 Critical | Identity-based |
| 5 | RBAC for storage | Role assignments for MI → Storage | 🔴 Critical | Storage Blob Data Owner + Storage Account Contributor |
| 6 | FTP disabled | `siteConfig.ftpsState` | 🟠 High | `Disabled` |
| 7 | Remote debugging off | `siteConfig.remoteDebuggingEnabled` | 🟠 High | `false` |
| 8 | Latest runtime version | `siteConfig.linuxFxVersion` or `netFrameworkVersion` | 🟠 High | Latest stable |
| 9 | App Insights connected | `APPINSIGHTS_INSTRUMENTATIONKEY` in appSettings | 🟡 Medium | Set |
| 8 | Health check enabled | `siteConfig.healthCheckPath` | 🟡 Medium | Set |
| 9 | CORS not wildcard | `siteConfig.cors.allowedOrigins` | 🟡 Medium | Not `*` |
| 10 | VNet integration | `virtualNetworkSubnetId` | 🟡 Medium | Configured (prod) |
| 11 | IP restrictions | `siteConfig.ipSecurityRestrictions` | 🔵 Low | Configured |
| 12 | HTTP/2 enabled | `siteConfig.http20Enabled` | 🔵 Low | `true` |

**SQL Servers (Microsoft.Sql/servers):**

| # | Check | Property | Severity | Secure Value |
|---|-------|----------|----------|--------------|
| 1 | TDE enabled | `transparentDataEncryption.status` | 🔴 Critical | `Enabled` |
| 2 | AAD-only auth | `administrators.azureADOnlyAuthentication` | 🔴 Critical | `true` |
| 3 | Minimal TLS 1.2 | `minimalTlsVersion` | 🔴 Critical | `1.2` |
| 4 | Auditing enabled | `auditingSettings.state` | 🟠 High | `Enabled` |
| 5 | Advanced threat protection | `securityAlertPolicies.state` | 🟠 High | `Enabled` |
| 6 | Firewall rules restrictive | `firewallRules` | 🟠 High | No `0.0.0.0/0` (prod) |
| 7 | Vulnerability assessment | `vulnerabilityAssessments` | 🟡 Medium | Enabled |
| 8 | Private endpoint | Private endpoint resource | 🟡 Medium | Configured (prod) |
| 9 | Long-term backup retention | `backupLongTermRetentionPolicies` | 🟡 Medium | Configured |
| 10 | Connection policy | `connectionPolicies.connectionType` | 🔵 Low | `Redirect` |

**Cosmos DB (Microsoft.DocumentDB/databaseAccounts):**

| # | Check | Property | Severity | Secure Value |
|---|-------|----------|----------|--------------|
| 1 | Firewall configured | `ipRules` or `virtualNetworkRules` | 🔴 Critical | Not empty |
| 2 | Disable key-based metadata writes | `disableKeyBasedMetadataWriteAccess` | 🟠 High | `true` |
| 3 | RBAC-based access | `disableLocalAuth` | 🟠 High | `true` (prefer RBAC) |
| 4 | Continuous backup | `backupPolicy.type` | 🟡 Medium | `Continuous` |
| 5 | Customer-managed keys | `keyVaultKeyUri` | 🟡 Medium | Set (prod) |
| 6 | Diagnostic logging | Diagnostic setting resource | 🟡 Medium | Enabled |
| 7 | Private endpoint | Private endpoint resource | 🟡 Medium | Configured (prod) |

**Key Vault (Microsoft.KeyVault/vaults):**

| # | Check | Property | Severity | Secure Value |
|---|-------|----------|----------|--------------|
| 1 | Soft delete enabled | `enableSoftDelete` | 🔴 Critical | `true` (now default) |
| 2 | Purge protection | `enablePurgeProtection` | 🔴 Critical | `true` |
| 3 | RBAC authorization | `enableRbacAuthorization` | 🟠 High | `true` |
| 4 | Network rules | `networkAcls.defaultAction` | 🟡 Medium | `Deny` (prod) |
| 5 | Private endpoint | Private endpoint resource | 🟡 Medium | Configured (prod) |
| 6 | Diagnostic logging | Diagnostic setting resource | 🟡 Medium | Enabled |

**Container Apps (Microsoft.App/containerApps):**

| # | Check | Property | Severity | Secure Value |
|---|-------|----------|----------|--------------|
| 1 | Ingress HTTPS only | `ingress.transport` | 🔴 Critical | `http` with `allowInsecure: false` |
| 2 | Managed identity | `identity.type` | 🟠 High | `SystemAssigned` |
| 3 | Min replicas > 0 (prod) | `scale.minReplicas` | 🟡 Medium | `> 0` for prod |
| 4 | VNet integration | Container Apps Environment | 🟡 Medium | Configured |
| 5 | Secret management | `secrets` with Key Vault refs | 🟡 Medium | Key Vault references |

**Virtual Machines (Microsoft.Compute/virtualMachines):**

| # | Check | Property | Severity | Secure Value |
|---|-------|----------|----------|--------------|
| 1 | Password authentication disabled | `osProfile.linuxConfiguration.disablePasswordAuthentication` | 🔴 Critical | `true` |
| 2 | SSH key configured | `osProfile.linuxConfiguration.ssh.publicKeys` | 🔴 Critical | At least one key |
| 3 | Internet exposure (public IP) | Check if NIC references `publicIPAddress` | 🟠 High | No public IP (use Bastion). If public IP present → flag as internet-facing |
| 4 | NSG SSH not open to 0.0.0.0/0 | NSG `securityRules[].sourceAddressPrefix` for port 22 | 🔴 Critical | Not `*` or `Internet` — must be specific IP/CIDR |
| 5 | Encryption at host | `securityProfile.encryptionAtHost` | 🟡 Medium | `true` (encrypts temp disks + caches) |
| 6 | Azure Disk Encryption (ADE) | ADE VM extension resource | 🟡 Medium | Extension present |
| 7 | SSE at rest (managed disks) | Platform default — NOT a template property | 🔵 Info | 🔄 Platform Default — Azure encrypts all managed disks automatically. Do NOT mark as "✅ Applied" |
| 8 | Boot diagnostics | `diagnosticsProfile.bootDiagnostics.enabled` | 🟡 Medium | `true` |
| 9 | Managed identity | `identity.type` | 🟡 Medium | `SystemAssigned` (if VM accesses Azure resources) |
| 10 | Automatic OS updates | `osProfile.linuxConfiguration.patchSettings.patchMode` | 🔵 Low | `AutomaticByPlatform` |
| 11 | Trusted launch | `securityProfile.securityType` | 🟡 Medium | `TrustedLaunch` with vTPM and secure boot |

**⚠️ VM Internet Exposure Rule:** If ANY `Microsoft.Network/publicIPAddresses` resource is attached to the VM's NIC, the VM IS internet-facing. Always flag this explicitly, even if NSG rules restrict source IPs. An IP-restricted port is still internet-reachable — the restriction is a mitigation, not a closure.

**Network Security Groups (Microsoft.Network/networkSecurityGroups):**

| # | Check | Property | Severity | Secure Value |
|---|-------|----------|----------|--------------|
| 1 | No rules with source `*` or `Internet` on management ports (22, 3389) | `securityRules[].sourceAddressPrefix` | 🔴 Critical | Specific IP/CIDR only |
| 2 | Explicit deny-all inbound rule | Custom deny rule at high priority | 🟠 High | Present |
| 3 | No overly permissive rules (`*` destination port) | `securityRules[].destinationPortRange` | 🟠 High | Specific ports only |
| 4 | NSG flow logs | Separate flow log resource | 🟡 Medium | Enabled |

### 3.5 Verify All Findings (MANDATORY)

**Before classifying posture, run the verification checklist from the Verification Integrity Rules section:**

1. Re-read the ARM template JSON.
2. For every "✅ Applied" entry in your draft report, search for the exact property path and confirm the value.
3. For every network-related check, confirm whether a `publicIPAddress` resource exists and which ports are open.
4. For every encryption check, confirm whether the control is explicit (in template) or platform-default (Azure automatic).
5. Remove or downgrade any entry that fails verification.
6. Ensure no check uses misleading framing (see Rule 3).

**If you find an error during verification**: Fix it immediately. Do not present unverified findings to the user.

### 4. Classify Overall Security Posture & Gate Status

Based on the per-resource analysis, calculate an overall score AND the Security Gate status:

```markdown
Security Gate (BLOCKING):
- ALL 🔴 Critical checks MUST pass → if any fail, gate = 🔴 BLOCKED
- ALL 🟠 High checks MUST pass → if any fail, gate = 🔴 BLOCKED  
- If all Critical + High pass → gate = 🟢 PASSED
- 🟡 Medium and 🔵 Low do NOT block deployment

"Pass" means status is ✅ Applied or 🔄 Platform Default.
"Fail" means status is ⚠️ Not applied, ❌ Misconfigured, or ❓ Unknown.

Overall Posture (informational — does NOT control gating):
- **EXCELLENT** — All critical+high passed, > 75% medium passed
- **GOOD** — All critical+high passed, > 50% medium passed
- **ACCEPTABLE** — All critical passed, some high missing
- **NEEDS ATTENTION** — Some high-severity checks failed
- **NEEDS IMMEDIATE ATTENTION** — Critical checks failed (DO NOT deploy without fixing)
```

**The Security Gate is the authoritative deployment-blocking mechanism.** The posture label is informational only. A posture of "ACCEPTABLE" still results in `🔴 BLOCKED` if any High checks fail.

### 5. Generate Security Report

Produce a structured security assessment:

```markdown
# Security Best Practices Analysis

**Deployment ID:** {deployment-id}
**Analyzed:** {timestamp}
**Source:** Azure MCP bestpractices service
**Resources Analyzed:** {count}

## Overall Security Posture: {EXCELLENT|GOOD|ACCEPTABLE|NEEDS ATTENTION}

**Summary:**
- 🔴 Critical: {passed}/{total} passed
- 🟠 High: {passed}/{total} passed
- 🟡 Medium: {passed}/{total} passed
- 🔵 Low: {passed}/{total} passed

## Per-Resource Assessment

### {Resource Type}: {Resource Name}

| # | Recommendation | Severity | Status | Property | Evidence | Notes |
|---|---------------|----------|--------|----------|----------|-------|
| 1 | {check name} | {severity} | ✅ Applied | {exact property path} | {actual value from template} | {note} |
| 2 | {check name} | {severity} | 🔄 Platform Default | {property} | Not in template | {Azure provides this automatically} |
| 3 | {check name} | {severity} | ⚠️ Not applied | {property} | Absent | {recommendation} |

**Score: {applied}/{total}** ({percentage}%)

{Repeat for each resource}

## Recommendations

### Must Fix (before deployment)
{List any failed critical checks — these should block deployment}

### Should Fix (strongly recommended)
{List any failed high checks — warn user but don't block}

### Consider (best practice)
{List failed medium/low checks — informational}

## Environment-Specific Notes

**For production deployments:**
- Private endpoints should be configured for all data resources
- Network rules should default to Deny
- VNet integration recommended for compute resources
- Consider customer-managed keys for encryption

**For dev/staging:**
- Network rules can use Allow for easier development
- Private endpoints are optional
- Shared key access acceptable for development
```

### 6. Return Results with Gate Status

Return the security report to the calling agent (template generator) with two key outputs:

1. **Security Report** — Full per-resource assessment (saved to `security-analysis.md`)
2. **Security Gate Status** — `🟢 PASSED` or `🔴 BLOCKED` with list of blocking findings

**The gate status MUST be prominently displayed at the top of the report:**

```markdown
## Security Gate: 🟢 PASSED
All Critical and High security checks pass. Deployment may proceed.
```

or:

```markdown
## Security Gate: 🔴 BLOCKED
Deployment cannot proceed. The following checks must be resolved:

| # | Check | Severity | Resource | Status | Required Fix |
|---|-------|----------|----------|--------|--------------|
| 1 | {check} | 🔴 Critical | {resource} | ⚠️ Not applied | {fix} |
```

**Also save** the report to `.azure/deployments/$DEPLOYMENT_ID/security-analysis.md`.

**Save the gate result** to `.azure/deployments/$DEPLOYMENT_ID/security-gate.json`:
```json
{
  "gate": "PASSED",
  "blockingFindings": [],
  "criticalTotal": 4,
  "criticalPassed": 4,
  "highTotal": 6,
  "highPassed": 6,
  "timestamp": "2026-02-19T10:00:00Z"
}
```

## Severity Classification

| Severity | Icon | Meaning | Action |
|----------|------|---------|--------|
| **Critical** | 🔴 | Security vulnerability if missing | Must fix before deployment |
| **High** | 🟠 | Strongly recommended by Microsoft | Should fix, warn user |
| **Medium** | 🟡 | Best practice, may have trade-offs | Recommend, user decides |
| **Low** | 🔵 | Nice to have, optional | Informational only |

## Environment Sensitivity

Some checks are environment-dependent:

| Check | Dev | Staging | Prod |
|-------|-----|---------|------|
| Private endpoints | 🔵 Optional | 🟡 Recommended | 🟠 Required |
| Network firewall (Deny) | 🔵 Optional | 🟡 Recommended | 🟠 Required |
| VNet integration | 🔵 Optional | 🟡 Recommended | 🟠 Required |
| Customer-managed keys | 🔵 Optional | 🔵 Optional | 🟡 Recommended |
| IP restrictions | 🔵 Optional | 🟡 Recommended | 🟠 Required |
| Shared key access | 🟡 Acceptable | 🟡 Restricted | 🔴 Disabled |

When analyzing, adjust severity ratings based on the target environment from the requirements.

## Usage

**Invoked by template generator:**
```
/azure-security-analyzer

Input: ARM template resources and target environment
Output: Per-resource security assessment with severity ratings
```

**Manual invocation:**
```
User: /azure-security-analyzer

Agent: Provide the ARM template or resource configurations to analyze.

User: [pastes template or points to deployment]

Agent: Analyzing 3 resources against Azure best practices...

[Produces security report]
```

**Post-deployment audit:**
```
User: /azure-security-analyzer --deployment-id deploy-20260218-193500

Agent: Loading template from .azure/deployments/deploy-20260218-193500/template.json...

[Analyzes and produces report]
```

## Error Handling

If MCP bestpractices service is unavailable:
1. Fall back to the built-in security checklists defined in this skill
2. Note in the report: "Analysis based on built-in checklists (MCP bestpractices unavailable)"
3. Still produce a complete report — the checklists above are comprehensive

If a resource type is not in the checklists:
1. Query MCP bestpractices for the specific resource type
2. If no results, note: "No security checklist available for {resource-type}"
3. Apply generic checks: tags, diagnostic logging, encryption
