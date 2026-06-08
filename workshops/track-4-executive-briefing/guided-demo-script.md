# Guided Demo Script

> 10 minutes | No Azure required (pre-record option available)

A pre-scripted demo for the executive briefing. The presenter deploys a Function App live, highlighting natural language input, security, cost, and architecture outputs.

## Before the Demo

### Setup Checklist

- [ ] Development environment open with Git-Ape configured (Codespaces, Dev Containers, or local VS Code)
- [ ] Azure subscription signed in (`az login`)
- [ ] Copilot Chat panel visible and responsive
- [ ] Font size increased for readability (Ctrl+= three times)
- [ ] Terminal visible at the bottom

### Backup Plan

If live demo fails (network, Azure outage, Copilot downtime):
- Switch to pre-recorded video of the same flow
- Or walk through screenshots of each stage

---

## Demo Script

### [0:00] Introduction (30 seconds)

**Say:**
> "I'm going to deploy Azure infrastructure from scratch. No templates, no configuration files, no CLI commands. Just a conversation."

### [0:30] Type the Request (30 seconds)

In Copilot Chat, type slowly so the audience can read:

```text
@git-ape deploy a Python function app with storage and monitoring
         for the demo-api project in dev, region eastus
```

**Say:**
> "One sentence. That's all the input I need to provide."

Press Enter.

### [1:00] Requirements Gathering (1 minute)

The agent asks 2-3 clarifying questions. Answer them:

| Agent Asks | You Say | Narrate |
|-----------|---------|---------|
| Runtime version? | Python 3.11 | "It asks me a few quick questions to fill in the details." |
| Hosting plan? | Consumption | "Consumption means pay-per-execution — no fixed monthly cost." |

### [2:00] Template Generation (1 minute)

The Template Generator produces the ARM template and outputs.

**Highlight the architecture diagram:**
> "It generated a complete architecture diagram showing every resource and how they connect. Four resources created from one sentence."

### [3:00] Security Analysis (2 minutes)

**This is the most important part of the demo.**

Point to the security analysis output:

> "This is the security gate. It checked 10+ security controls automatically."

Read the key findings:
> - "HTTPS-only: enabled. No unencrypted traffic."
> - "Managed identity: enabled. No passwords stored anywhere."
> - "Shared key access: disabled. Only Azure AD tokens can access the storage."
> - "TLS 1.2: enforced."

Point to the gate result:

> "SECURITY GATE: PASSED. If any Critical or High issue was found, this would say BLOCKED, and the deployment would stop. Security is not a suggestion — it's a gate."

### [5:00] Cost Estimate (1 minute)

Point to the cost breakdown:

> "Before I deploy anything, I can see exactly what this will cost. These are real prices from the Azure pricing API."

Read the total:

> "Total: about $3 per month for a dev Function App. No bill surprises."

### [6:00] Confirmation (30 seconds)

> "Now it asks me to confirm. Nothing deploys without my explicit approval."

Type `yes` and press Enter.

### [6:30] Deployment (2 minutes)

> "Watch as it creates each resource in Azure."

While deploying, narrate:
> "Resource group created. Storage account created with managed identity. Application Insights connected. Function App deployed."

### [8:30] Integration Tests (1 minute)

> "After deployment, it automatically tests everything. Endpoint reachable. HTTPS enforced. Monitoring connected."

### [9:30] Wrap Up (30 seconds)

> "In under 10 minutes, we went from a sentence to deployed, tested, secured infrastructure. The security analysis, cost estimate, and architecture diagram are all saved for audit."

> "Imagine every engineer on your team having this capability. No tickets. No waiting. No security gaps."

---

## Key Talking Points to Emphasize

| Moment | What to Highlight |
|--------|------------------|
| Security gate | "Deployment stops if security fails. Not a warning — a gate." |
| Cost estimate | "Real Azure prices. See what you pay before you deploy." |
| Managed identity | "No passwords. No connection strings. No secrets to rotate." |
| One sentence | "This is the entire input. Everything else is automated." |
| Confirmation gate | "Nothing deploys without explicit human approval." |

## Pre-Recording Option

To create a recorded version:
1. Run the demo in your development environment with screen recording
2. Use a clean subscription (no existing resources)
3. Edit out any wait times longer than 5 seconds
4. Add captions highlighting the key moments above
5. Target duration: 8-10 minutes
