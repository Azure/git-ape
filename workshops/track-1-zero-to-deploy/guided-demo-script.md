# Guided Demo Script — Track 1: Zero to Deploy

> 15 minutes facilitator-led | Azure sandbox required | Audience: developers new to IaC

A live, narrated walkthrough that gives the audience their first end-to-end Git-Ape experience: from one sentence to a deployed, monitored, secured Azure Function App. Attendees will repeat the same flow in Labs 2 and 3 right after.

## Before the Demo

### Setup Checklist

- [ ] Codespace (or Dev Container / local VS Code) is open, fully built, and the Git-Ape extension is loaded
- [ ] `az login` has been run; `az account show` shows the workshop sandbox subscription
- [ ] GitHub Copilot Chat panel is visible, signed in, and responsive
- [ ] Editor font size bumped (Cmd/Ctrl + `=` three times) so back-row attendees can read
- [ ] Terminal panel visible at the bottom, cleared
- [ ] A fresh resource-group name ready (e.g., `rg-demoapi-dev-eastus`) — do not reuse a prior demo's RG
- [ ] `.azure/deployments/` is empty (delete any leftovers from a dry run)

### Backup Plan

If live Azure deploy fails (network, quota, Copilot downtime):
- Pre-recorded screen capture of the same flow lives at `workshops/shared/recordings/track-1-demo.mp4` (record once before workshop)
- Or skip the deploy step and walk through artefacts already generated in `.azure/deployments/<id>/`

---

## Demo Script

### [0:00] Set the scene (45 seconds)

**Say:**
> "In the next 15 minutes I'm going to deploy a real Function App into a real Azure subscription, with monitoring, identity-based storage, and a security gate — and I'm going to do it without writing a single line of Bicep, ARM JSON, or YAML. The only input I'll provide is one sentence in plain English. Watch what happens."

### [0:45] Type the request (1 minute)

In Copilot Chat, type slowly so attendees can read along:

```text
@git-ape deploy a Python function app with storage and monitoring
for the demoapi project, dev environment, eastus region
```

**Narrate as you type:**
> "Four things I'm telling it: what to deploy (function app), the platform (Python), the project name, and where. Everything else is going to be filled in by the agent."

Press Enter.

### [1:45] Requirements gathering (2 minutes)

The Requirements Gatherer asks 2–3 clarifying questions. Answer them out loud:

| Agent asks | You answer | Narrate |
|------------|------------|---------|
| Python runtime version? | `3.11` | "It picks the latest LTS by default — I'll confirm." |
| Hosting plan? | `Consumption` | "Consumption means pay-per-execution, $0 when idle." |
| Subscription? | (sandbox) | "It validated my login and is showing only subs I can deploy to." |

**Pause here.** Ask the room:
> "Notice it didn't ask me anything I wouldn't already know as a developer. No 'what API version of Microsoft.Web/sites' — that's the agent's job."

### [3:45] Template generation (2 minutes)

The Template Generator produces:
- `.azure/deployments/<id>/template.json`
- `.azure/deployments/<id>/parameters.json`
- `.azure/deployments/<id>/architecture.md` (with Mermaid diagram)

**Open `architecture.md`** in a split editor. The Mermaid diagram renders four resources: Storage Account, App Service Plan, Function App, Application Insights — wired correctly.

**Say:**
> "Four resources, generated from one sentence, with every connection drawn for me. CAF-compliant naming. Tags applied. Managed identity wired in. I haven't touched a template file."

Briefly scroll the `template.json` so they see actual ARM JSON.

### [5:45] Security analysis — the wow moment (3 minutes)

The Security Analyzer agent runs automatically and prints a per-resource report.

**Read the headline aloud:**
> "🟢 SECURITY GATE: PASSED — 12 checks applied across 4 resources."

**Highlight three findings** by clicking each in the chat output:
- "HTTPS only: enabled — no clear-text traffic possible."
- "Managed identity: enabled — no storage keys anywhere in the template."
- "TLS 1.2 minimum: enforced."

**The key teaching moment:**
> "This is not advice. This is a gate. If any Critical or High check had failed, the agent would refuse to deploy until I fixed it. Security is not optional."

Pause for questions. (This is where beginners often raise their hand — encourage it.)

### [8:45] Cost estimate (1 minute)

Scroll to the Cost Estimator output.

**Say:**
> "Before I deploy, I see exactly what this costs — real prices from the Azure Retail Pricing API."

Read the total:
> "About $3.20 per month for a Consumption Function App at idle. No bill surprises."

### [9:45] Confirmation gate (30 seconds)

The agent prints the deployment intent and waits.

**Narrate:**
> "It tells me what it's about to do and asks for explicit approval. Nothing deploys without my 'yes'."

Type `yes`.

### [10:15] Deployment (3 minutes)

The Azure Resource Deployer runs `az stack sub create --action-on-unmanage deleteAll`.

**While it runs (~2 min), narrate:**
- "Resource group created."
- "Storage account created — note the auto-generated unique suffix."
- "App Service Plan created."
- "Application Insights created and linked."
- "Function App deployed. Identity assigned. Storage RBAC role bound."

**While waiting, point out:**
> "This is one Azure Deployment Stack — one unit of lifecycle. When I want to tear it down later, one command deletes every resource managed by the stack, no orphans."

### [13:15] Integration tests (1 minute)

The Integration Tester runs and prints results:
- ✅ Function App responds on HTTPS
- ✅ Storage account reachable via managed identity
- ✅ Application Insights receiving telemetry
- ✅ HTTPS-only enforced (HTTP returns 301)

**Say:**
> "The agent didn't just deploy it — it verified it. Health-checked. Smoke-tested. Done."

### [14:15] Wrap-up (45 seconds)

Switch to the Azure portal to show the resources actually exist (this lands the point).

**Closing line:**
> "Fifteen minutes ago we had an empty subscription. Now we have a fully deployed, security-gated, cost-known, integration-tested Function App. And in 30 minutes any one of you will be doing this same flow in Lab 2 against your own sandbox. Questions?"

---

## Key Talking Points to Emphasize

| Moment | What to highlight |
|--------|------------------|
| One sentence input | "Everything else is generated. You're the architect, not the typist." |
| Architecture diagram | "Generated, not drawn. The same source of truth as the deploy." |
| Security gate | "Not a suggestion — a gate. Deployment stops on Critical/High." |
| Managed identity | "Zero passwords. Zero connection strings. Zero rotation work." |
| Cost estimate | "Pre-deploy. Real Azure prices. No surprises." |
| Confirmation gate | "Human-in-the-loop on every deploy. No silent infrastructure." |
| Integration tests | "Self-verifying. The agent proves the deployment works." |

---

## Common Audience Questions (and short answers)

| Question | Answer |
|----------|--------|
| "What if I want to change a resource later?" | "Edit the template, re-run `@git-ape deploy`. The stack updates idempotently — Lab 3 covers this." |
| "How do I delete this?" | "PR that flips `metadata.json` status to `destroy-requested`. The `git-ape-destroy` workflow handles it. We cover teardown in Lab 3 and Track 3." |
| "Can I override the agent's choices?" | "Yes — every step takes user input. The agent suggests, you decide." |
| "What if my org needs Policy X?" | "Policy Advisor (Track 2/3) checks Azure Policy compliance and flags gaps." |

---

## Pre-Recording Option

If you want a recorded version as backup or for asynchronous viewing:

1. Run this exact script against a fresh sandbox subscription
2. Edit out any single wait longer than 5 seconds
3. Add chapter markers at: 1:45 (request), 5:45 (security gate), 10:15 (deploy), 13:15 (tests)
4. Target final duration: 8–10 minutes
5. Save to `workshops/shared/recordings/track-1-demo.mp4`
