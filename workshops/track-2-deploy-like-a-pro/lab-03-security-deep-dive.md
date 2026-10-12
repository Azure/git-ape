# Lab 3: Security Deep Dive

> 10 minutes | Uses artifacts from Lab 2

Deliberately introduce a security issue, see the security gate block deployment, then fix it.

## Why This Lab Matters

The security gate isn't just a report — it's a **blocking control**. This lab shows you what happens when security fails.

## Step 1: Run the Security Analyzer

Invoke the security analyzer on your deployment:

```text
/azure-security-analyzer
```

Point it at the template from Lab 2. You should see all green:

```
🟢 SECURITY GATE: PASSED
```

## Step 2: Break the Security

Ask Git-Ape to modify the template and enable shared key access on the storage account:

```text
@git-ape update the storage account in my last deployment to enable shared key access
```

> **Why is this bad?** Shared key access means anyone with the storage account key can read/write all data. Managed identity is the secure alternative — it uses Azure AD tokens that are scoped, rotated automatically, and auditable.

## Step 3: See the Gate Block

Run the security analyzer again:

```text
/azure-security-analyzer
```

Now you should see:

```
🔴 SECURITY GATE: BLOCKED

Critical: 0  |  High: 1 ⚠️  |  Medium: 0  |  Low: 0

HIGH: Storage Account — allowSharedKeyAccess is true
  → Set allowSharedKeyAccess to false when all consumers use managed identity
  → Impact: Shared keys can be extracted and used to access all data
```

**The deployment is blocked.** Git-Ape will not deploy this template until the High-severity finding is resolved.

## Step 4: Fix the Issue

Ask Git-Ape to fix it:

```text
@git-ape fix the security issue — disable shared key access on the storage account
```

Git-Ape updates the template: `"allowSharedKeyAccess": false`.

## Step 5: Re-Run the Gate

```text
/azure-security-analyzer
```

```
🟢 SECURITY GATE: PASSED

Critical: 0  |  High: 0  |  Medium: 0  |  Low: 0
```

Deployment can now proceed.

## What You Learned

| Concept | What It Means |
|---------|--------------|
| **Blocking gate** | Deployment physically stops when Critical/High issues exist |
| **Severity levels** | Critical > High > Medium > Low. Only Critical and High block deployment. |
| **Shared key access** | A common misconfiguration. Managed identity is the secure alternative. |
| **Fix-and-rerun** | The gate loops: find issue → fix → re-analyze → pass or block again |
| **No security regression** | Git-Ape never weakens security to fix a deployment error |

> **Key takeaway:** Security is not optional. It's enforced at deployment time, every time.

**Next:** [Lab 4 — Cost & Architecture Review](lab-04-cost-architecture.md)

## Step 6: Read a finding (evidence-based)

Every finding cites the exact ARM property path:

HIGH: Storage Account -- allowSharedKeyAccess is true
  ARM property: Microsoft.Storage/storageAccounts/properties/allowSharedKeyAccess
  Rationale: Shared keys can be extracted to access all data
  Fix: Set to false; ensure all consumers use managed identity

The property path IS the evidence. If a finding lacks one, treat as assertion not proof.

States: Applied (explicit secure), Platform Default (Azure default), Not applied (insecure or unset). Only Applied counts as intent.

## Step 7: Three remediation paths

- Auto-fix: ask Git-Ape; full gate re-runs end-to-end.
- Manual fix: edit template.json, re-invoke analyzer.
- Override: type 'I accept the security risk' with rationale -- logged OVERRIDDEN.

Every template change re-runs the gate.

## Step 8: HTTPS/TLS second example

Ask Git-Ape to allow HTTP and downgrade TLS to 1.0. Re-run analyzer; expect two new Critical findings. Fix both, re-run, back to PASSED. The gate covers HTTPS, TLS, FTP, managed identity, Key Vault references, RBAC, shared keys, and more.

## Going further

- Skill: .github/skills/azure-security-analyzer/SKILL.md
- Template generator integration: .github/agents/azure-template-generator.agent.md
