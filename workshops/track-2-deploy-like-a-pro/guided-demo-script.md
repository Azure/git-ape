# Guided Demo Script — Track 2: Deploy Like a Pro

> 20 minutes facilitator-led | Azure sandbox + GitHub OIDC-onboarded repo required | Audience: practising engineers

The Track 2 demo extends Track 1's "first deploy" experience to a real multi-resource workload (Web App + SQL Database + Key Vault) and shows the security gate doing its job — by deliberately breaking a template and watching the gate block deployment until fixed. This is the moment that sells Git-Ape to engineering teams.

## Before the Demo

### Setup Checklist

- [ ] Sandbox subscription with no name conflicts on `app-payments-dev-eastus`, `sql-payments-dev-eastus`, `kv-payments-dev-eus`
- [ ] Repo already onboarded via Git-Ape Onboarding (OIDC federated credential, RBAC roles assigned)
- [ ] `az login` complete; `az account show` shows the sandbox
- [ ] Copilot Chat panel visible and signed in
- [ ] Two browser tabs open: GitHub repo PR page, Azure portal (signed into sandbox)
- [ ] Editor font size bumped
- [ ] Terminal cleared

### Backup Plan

If live deploy fails:

- Pre-recorded video at `workshops/shared/recordings/track-2-demo.mp4`
- Or use a pre-deployed sandbox stack and walk through its `state.json`, `security-assessment.md`, and `cost-estimate.md`

---

## Demo Script

### [0:00] The Track 2 promise (45 seconds)

**Say:**
> "In Track 1 we deployed a single Function App. That's a great start, but real systems are multi-resource: web tiers, databases, key vaults, role assignments. They also have real security constraints — and that's where most IaC pipelines silently fail. Today I'm going to deploy a Web App with a SQL database, watch the security gate catch a misconfiguration on purpose, fix it, and then deploy clean — all without leaving Copilot Chat."

### [0:45] Multi-resource request (1 minute)

In Copilot Chat:

```text
@git-ape deploy a Python web app with an Azure SQL database
and a key vault for the payments project, dev environment, eastus.
Use managed identity from the web app to read secrets and connect to SQL.
```

**Narrate:**
> "Three resources, one identity, one sentence. Notice I'm specifying the security pattern up front — managed identity, no connection strings. The agent will hold me to that."

### [1:45] Requirements + Architecture (2 minutes)

Walk through the agent's clarifying questions:

| Agent asks | You answer | Narrate |
|------------|------------|---------|
| App runtime? | `Python 3.11` | "Same defaults as Track 1." |
| SQL tier? | `Basic` | "Sandbox tier — Lab 2 covers picking the right tier." |
| AAD-only auth on SQL? | `yes` | "This is the key decision — no SQL logins allowed." |

Open the generated `architecture.md`. The Mermaid diagram shows:

- App Service Plan → Web App
- Web App → Key Vault (managed identity, Get/List secrets)
- Web App → SQL Server (AAD-only, identity-based)
- SQL Server → SQL Database

**Say:**
> "Look at the arrows. Every line is an identity-based connection. No `connectionStrings`. No `WEBSITE_*` secrets. The diagram and the template are the same source of truth."

### [3:45] First security analysis — PASS (2 minutes)

The Security Analyzer prints the per-resource report.

Scroll through and read three callouts:

- "AAD-only auth on SQL: ✅ Applied (azureADOnlyAuthentication = true)"
- "Shared key access on storage: ✅ Applied (allowSharedKeyAccess = false)"
- "Key Vault soft-delete: ✅ Applied"

**Headline:**
> "🟢 SECURITY GATE: PASSED — 18 controls verified across 4 resources. Now watch what happens when I break one."

### [5:45] Break the template on purpose (3 minutes)

Open `.azure/deployments/<id>/template.json` in a split editor. Find the SQL server resource. Use Find & Replace to flip:

```diff
-  "azureADOnlyAuthentication": true,
+  "azureADOnlyAuthentication": false,
```

Save.

In Copilot Chat:

```text
@git-ape re-run security analysis
```

**Watch the output change:**

- "❌ SQL AAD-only authentication: NOT APPLIED — Critical severity"
- "🔴 SECURITY GATE: BLOCKED"

**The key teaching moment** — pause and let the room read it:
> "I changed exactly one property. The gate caught it. It will not let me deploy until I fix it or explicitly override with the phrase 'I accept the security risk' — and that override is logged."

**Anti-pattern callout:**
> "In a normal team, this kind of regression slips into a PR, passes review because it's a one-line change, and gets caught six months later in a pentest. Here it's caught at PR-open time, by the Plan workflow, with a comment posted on the PR explaining exactly which property and why."

### [8:45] Fix it back and re-validate (1 minute)

Revert the change (`azureADOnlyAuthentication: true`). Re-run:

```text
@git-ape re-run security analysis
```

Gate is back to 🟢 PASSED.

**Say:**
> "Fix the property, re-run, gate passes. The full security analysis is re-run end-to-end — no pre-approval, no shortcuts. That's a rule of the platform, not a habit."

### [9:45] Cost estimate (1 minute)

Show the cost breakdown:

- Web App (Basic B1): ~$13/month
- SQL Database (Basic): ~$5/month
- Key Vault: ~$0.03/secret/month
- **Total: ~$18.50/month dev environment**

**Say:**
> "Before I touch Azure, I know the bill. Production-tier estimates are in Lab 4."

### [10:45] Confirm and deploy (4 minutes)

Type `yes`. The deployment runs as a Deployment Stack.

**Narrate during the ~3-minute deploy:**

- "Stack created — this is the unit of lifecycle."
- "SQL server with AAD admin assigned."
- "Database provisioned at Basic tier."
- "Web App created. Managed identity assigned and granted Key Vault Secrets User."
- "RBAC role assignments completed across resources."

### [14:45] Integration tests (2 minutes)

The tester runs:

- ✅ Web App responds on HTTPS (302 → login redirect, expected)
- ✅ Managed identity can read Key Vault test secret
- ✅ Managed identity authenticates to SQL (queries `SELECT @@VERSION`)
- ✅ SQL refuses connection without AAD token (negative test)

**Say:**
> "Look at that last one — it's a *negative* test. The agent verified the security control actually blocks unauthorised access. Not just that the property is set, but that it works."

### [16:45] State and the GitHub flow (2 minutes)

Open the GitHub repo PR tab. Show:

- `.azure/deployments/<id>/state.json` — committed by the deploy workflow
- The PR comment posted by `git-ape-deploy.yml` confirming the deployment
- The deployment stack visible in Azure portal

**Say:**
> "Every artefact is in Git. The template, the state, the assessment, the cost report — auditable. If I want to change something next week, I open a PR, the Plan workflow re-validates, the Deploy workflow re-applies the stack idempotently."

### [18:45] Wrap-up (1 minute)

**Closing line:**
> "Twenty minutes ago we had a project name. We now have a Web App, a SQL database, a Key Vault — all wired with managed identity, all behind a security gate that actively blocks regressions, all cost-known, all in Git. In Labs 1 through 5 you're going to do this against your own sandbox. Lab 3 is where you'll deliberately break the template and watch the gate fire. Questions before we start the labs?"

---

## Key Talking Points to Emphasize

| Moment | What to highlight |
|--------|------------------|
| Identity-based wiring | "Three resources connected by identity. Zero secrets in the template." |
| Security gate BLOCKED | "Real enforcement. Not a linter. The deploy stops." |
| Re-run after fix | "Full re-run, not pre-approval. Rule of the platform." |
| Negative integration tests | "Verifies the control works, not just that the property is set." |
| Deployment Stack | "One unit of lifecycle. One delete removes everything." |
| Everything in Git | "PR-driven. Auditable. Reviewable. Reversible." |

---

## Common Audience Questions

| Question | Answer |
|----------|--------|
| "What if I genuinely need a SQL login?" | "Use the override: type 'I accept the security risk' with a justification. It's logged, never silent. Lab 3 walks the override path." |
| "Can the gate be customised per team?" | "Yes — Track 3 covers Policy Advisor and adding org-specific checks." |
| "What about secrets the app actually needs (e.g., third-party API key)?" | "Key Vault reference syntax in app settings: `@Microsoft.KeyVault(...)`. The agent generates this — never inline secrets." |
| "How does this integrate with our existing CI?" | "Three GitHub Actions workflows: Plan on PR, Deploy on merge, Destroy on metadata change. Track 3 covers it in depth." |
| "What happens if Plan fails on a colleague's PR?" | "The PR comment shows the gate output. Their PR is blocked until they fix it. No deploy from a failed plan." |

---

## Pre-Recording Option

1. Record against a clean sandbox subscription
2. Use the same payments project name for consistency
3. Edit out waits >5 seconds
4. Chapter markers at: 1:45 (request), 5:45 (break it), 8:45 (fix it), 10:45 (deploy), 14:45 (tests)
5. Target final duration: 14–16 minutes
6. Save to `workshops/shared/recordings/track-2-demo.mp4`
