# Lab 2: First Deploy

> 15 minutes | No Azure required (review-only path available)

Deploy an Azure Function App using a single sentence in Copilot Chat.

> **What this teaches you:** how Git-Ape moves from one English sentence to a production-shape ARM template, an actionable security gate, and an honest pre-deploy cost estimate — all without you writing a line of infra-as-code.

## Step 0: Confirm where you are deploying

Before any agent runs, check the subscription you are signed into so you know exactly where this lands:

```bash
az account show --query "{subscription:name, id:id, tenant:tenantId}" -o table
```

If this isn't the sandbox you intend to use:

```bash
az account list -o table
az account set --subscription "Workshop Sandbox"
```

> If you don't have an Azure CLI session, you can still complete the review-only path below — Git-Ape generates the template and reports without deploying.

## Step 1: Start the conversation

In Copilot Chat, type:

```text
@git-ape deploy a Python function app for hello-world in dev, region eastus
```

Press Enter and watch what happens.

## Step 2: Follow the requirements gathering

Git-Ape's **Requirements Gatherer** activates. It will:

1. **Echo your subscription/tenant** so you confirm the target before anything happens
2. **Ask 2-3 clarifying questions** to fill in details your sentence left out

| Question | Answer | Why it matters |
|---|---|---|
| Runtime version? | `Python 3.11` | LTS, matches Azure Functions Premium support |
| Hosting plan? | `Consumption` | Pay-per-execution, $0 at idle |
| Enable monitoring? | `yes` | Application Insights gets wired in via managed identity |
| Project name confirmation? | `hello-world` | Drives CAF naming for every resource |

> **Tip:** If the agent skips a question, your prompt already supplied enough info — it used a sensible default rather than re-asking.

Progress indicator:

```
██████░░░░ Stage 1: Requirements gathered ✓
```

## Step 3: Resource availability gate

Before generating any template, the agent runs an **availability check**:

- Is the region open for your subscription?
- Is the Python 3.11 runtime supported in that region?
- Are the resource providers (`Microsoft.Web`, `Microsoft.Storage`, `Microsoft.Insights`) registered?
- Are the proposed CAF names available (Function Apps and Storage have global uniqueness)?

If any check fails, the agent stops here with a specific fix — usually `az provider register --namespace <X> --wait` or "pick a different region". This is the most common place an attendee's first run can halt; it's by design.

## Step 4: Review the generated template

The **Template Generator** produces an ARM template plus three companion docs (architecture, security, cost). All three are shown inline; the actual files land in `.azure/deployments/<id>/`.

### Architecture diagram

A Mermaid diagram showing every resource and its connections:

```
Resource Group
├── Function App (func-helloworld-dev-eastus)
│   ├── Managed Identity (system-assigned)
│   └── App Settings (identity-based storage connection)
├── Storage Account (sthelloworlddev<unique>)
├── App Service Plan (Consumption Y1)
└── Application Insights (appi-helloworld-dev-eastus)
```

> **CAF naming**: every resource follows `<type>-<project>-<env>-<region>`. Globally unique names (Storage, Function App) get a random suffix via ARM's `uniqueString()`.

### Security gate

A per-resource report ending in a single gate verdict:

```
🟢 SECURITY GATE: PASSED — 12 checks applied across 4 resources

✅ HTTPS only: Enabled (Microsoft.Web/sites/properties/httpsOnly = true)
✅ Min TLS: 1.2 enforced
✅ FTP state: Disabled
✅ Managed identity: System-assigned (no secrets)
✅ Storage shared key access: Disabled
✅ Storage → Function App: identity-based connection
```

Notice each finding cites the **exact ARM property path** — that's how Git-Ape proves a finding rather than asserting it. The gate **blocks deployment** on any unresolved Critical or High. You'll deliberately break this in Track 2 Lab 3 to see BLOCKED in action.

### Cost estimate

Real prices fetched from the Azure Retail Prices API for your region:

```
Resource                   | Monthly cost
---------------------------|-------------
Function App (Consumption) | $0.00 at idle, pay-per-execution
Storage Account (LRS)      | $0.50
Application Insights       | $2.30
---------------------------|-------------
Total                      | ~$2.80/month
```

> **Caveat:** these are pay-as-you-go list prices in the target region. Reserved instances, EA discounts, or savings plans are not reflected. For workshop labs, expect the actual bill to be under $1 because resources only exist for the workshop session.

## Step 5: Confirm or review

Git-Ape shows the deployment intent and waits:

```
Ready to deploy?
  Target: subscription "Workshop Sandbox"
  Resource group: rg-helloworld-dev-eastus (will be created)
  Resources: 4
  Estimated monthly: ~$2.80
```

### If you have Azure access

Type `yes`. The Resource Deployer runs `az stack sub create --action-on-unmanage deleteAll`. Deploy takes ~90 seconds.

After deploy, an integration tester runs and reports HTTPS / managed-identity / App Insights checks plus a negative test for HTTP-to-HTTPS redirect.

**Verify it landed independently** (not just chat):

```bash
az stack sub show --name <deployment-id> --query "{state:provisioningState, resources:length(resources)}" -o table
```

### If you don't have Azure access (review-only path)

Type `no`. You have already seen the key outputs above — Git-Ape generated the template, security analysis, and cost estimate without touching Azure. The artifacts are saved to `.azure/deployments/<id>/` and a teammate with access can deploy them later via Track 3's PR-driven workflow.

## Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| Agent errors before first question | az not logged in | `az login` then set subscription |
| MissingSubscriptionRegistration | Provider not registered | `az provider register --namespace Microsoft.Web --wait` |
| SECURITY GATE BLOCKED | Sandbox Azure Policy conflict | Read finding; fix or override-with-justification |
| SKU/quota error | Sandbox region constraint | Re-run with different region |
| Tests fail after deploy | Role propagation 60-90s | Wait 90s and retry |

## Anti-patterns

- Do not deploy `template.json` via raw `az deployment` — bypasses the security gate.
- Do not edit `parameters.json` to skip managed identity — gate catches it on re-run.
- Do not delete `.azure/deployments/<id>/` to start over — it is the audit trail.

## Going further

Stage agents: `.github/agents/azure-{requirements-gatherer,template-generator,resource-deployer}.agent.md`. Security playbook: `.github/skills/azure-security-analyzer/SKILL.md`.

**Next:** [Lab 3 — Explore Results](lab-03-explore-results.md)
