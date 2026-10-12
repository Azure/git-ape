# Lab 2: Deploy Web App + SQL Database

> 15 minutes | Azure required

Deploy a multi-resource architecture: Web App, SQL Database, Key Vault, and Application Insights — all connected with managed identities.

## Step 1: Start the Deployment

In Copilot Chat:

```text
@git-ape deploy a .NET web app with SQL database for the inventory-app project in dev, region eastus
```

## Step 2: Walk Through Requirements

The Requirements Gatherer asks for details. Suggested answers:

| Question | Answer |
|----------|--------|
| App Service Plan tier? | `B1` (Basic — suitable for dev) |
| SQL Database tier? | `Basic` (~$5/month) |
| Enable Key Vault? | `Yes` |
| Enable monitoring? | `Yes` |

## Step 3: Review the Template

The Template Generator produces a subscription-level ARM template. Look for:

### Resources Created

| Resource | CAF Name | Purpose |
|----------|----------|---------|
| Resource Group | `rg-inventoryapp-dev-eastus` | Container for all resources |
| App Service Plan | `asp-inventoryapp-dev-eastus` | Hosting plan for the web app |
| Web App | `app-inventoryapp-dev-eastus` | The .NET application |
| SQL Server | `sql-inventoryapp-dev-eastus` | Database server (AAD-only auth) |
| SQL Database | `sqldb-inventoryapp-dev` | Application database |
| Key Vault | `kv-inventoryapp-dev-eus` | Secrets management |
| Application Insights | `appi-inventoryapp-dev-eastus` | Monitoring and diagnostics |
| Managed Identity | `id-inventoryapp-dev-eastus` | Service-to-service auth |

### Security Features (Automatic)

Look for these in the security analysis:

- **AAD-only SQL auth** — no SQL passwords, Azure AD tokens only
- **Key Vault references** — app settings use `@Microsoft.KeyVault(...)` instead of inline secrets
- **Managed identity chain** — Web App → Key Vault → SQL (no connection strings)
- **HTTPS-only** — HTTP requests redirect to HTTPS
- **TLS 1.2** — minimum TLS version enforced
- **FTP disabled** — no FTP access to the web app

## Step 4: Review the Security Gate

The security analysis should show:

```
🟢 SECURITY GATE: PASSED

Critical: 0 ⚠️  |  High: 0 ⚠️  |  Medium: 0 ⚠️  |  Low: 0 ℹ️
```

All checks passed because Git-Ape applies security best practices by default.

## Step 5: Review the Cost Estimate

You'll see a cost breakdown:

| Resource | Estimated Monthly |
|----------|------------------|
| App Service Plan (B1) | ~$13.00 |
| SQL Database (Basic) | ~$5.00 |
| Key Vault | ~$0.03 |
| Application Insights | ~$2.30 |
| Storage | ~$0.50 |
| **Total** | **~$20.83/month** |

## Step 6: Deploy

Confirm the deployment:

```text
yes
```

Watch the Resource Deployer create each resource. This takes 2-5 minutes for a multi-resource deployment.

After deployment completes, the Integration Tester runs:

- Web app endpoint reachable
- HTTPS enforced
- SQL database connection healthy
- Application Insights connected

## What You Deployed

A complete web application stack with:

- **Zero connection strings** — all service-to-service auth uses managed identity
- **Zero passwords** — SQL uses AAD-only authentication
- **Zero secrets in code** — Key Vault references for any app settings that need secrets
- **Full monitoring** — Application Insights with auto-instrumentation

**Next:** [Lab 3 — Security Deep Dive](lab-03-security-deep-dive.md)


## Step 7: Run preflight what-if before confirming

Before typing `yes`, ask Git-Ape to run preflight:

```text
@git-ape run what-if for this deployment
```

The Azure deployment preflight (subscription-scope) returns a structured list of every resource that will be Created, Modified, or Deleted, plus the property-level changes. Read it carefully -- this is the last review surface before any Azure write happens.

> The template is **subscription-scope** with nested deployments using `inner` expressionEvaluationOptions. `reference()` calls inside nested templates include explicit API versions (per the deployment standards). You can verify by opening `.azure/deployments/<id>/template.json` and searching for `"scope": "inner"`.

## Step 8: Why every template change re-runs the gate

If you edit the template (even a one-line property change) and ask Git-Ape to re-deploy, the **full security analysis re-runs end-to-end** before the gate can pass again. There is no "pre-approved at version N" shortcut.

You will see this in action in Lab 3 when we deliberately break a security control.

## Common failure modes (before/during deploy)

| Symptom | Cause | Fix |
|---|---|---|
| `MissingSubscriptionRegistration` | Provider not registered for the sub | `az provider register --namespace Microsoft.Sql --wait` (plus Microsoft.Web, Microsoft.KeyVault) |
| `QuotaExceeded` for App Service Plans | Region quota at 100% | Re-run with different region |
| SQL deploy hangs > 5 minutes | SQL servers can take 4-6 minutes; nested deployment polls every 30s | Patient wait; check `az deployment sub show --name <id> --query "properties.provisioningState"` |
| Web App responds 403 after deploy | Managed identity not yet propagated to Key Vault | Wait 60s, retry |
| Tests fail: SQL connection refused | AAD-only auth + token still propagating | Wait 90s; verify with `az sql db show-connection-string` |

## Anti-patterns

- Do not add a SQL admin password to the parameters file -- the security gate blocks it. The override is logged.
- Do not skip the preflight -- the cost estimate is based on the template; preflight is based on what Azure ARM actually plans to do (the two can diverge if existing resources clash).
- Do not use `az deployment sub create` directly on the generated template -- bypasses the gate, the test step, and the state.json that destroy needs.

## Going further

- Template generator agent: `.github/agents/azure-template-generator.agent.md` (search for `inner scope` and `bestpractices`)
- Deployer agent: `.github/agents/azure-resource-deployer.agent.md`
- Security analyzer: `.github/skills/azure-security-analyzer/SKILL.md` (the evidence rule)
