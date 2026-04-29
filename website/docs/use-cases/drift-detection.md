---
title: "Drift Detection"
sidebar_label: "Drift Detection"
sidebar_position: 8
description: "Detect configuration drift between deployed Azure resources and stored deployment state"
keywords: [drift detection, configuration drift, reconciliation, state management]
---

# Drift Detection

> **TL;DR** — Git-Ape compares your deployed Azure resources against the stored template state and identifies manual changes, policy remediations, or unauthorized modifications.

## How Drift Detection Works

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontSize':'13px','actorBkg':'#dbeafe','actorBorder':'#1f6feb','actorTextColor':'#0b3d91','signalColor':'#475569','signalTextColor':'#0f172a','noteBkgColor':'#fef3c7','noteBorderColor':'#b45309','noteTextColor':'#7c2d12'}}}%%
sequenceDiagram
    participant User
    participant GitApe as Git-Ape
    participant Repo as state.json
    participant Azure as Azure Resource Manager

    User->>GitApe: Check drift for deployment X
    GitApe->>Repo: Read stored state
    GitApe->>Azure: Query live resource config
    GitApe->>GitApe: Compare stored vs. live
    GitApe->>User: Drift report + reconciliation options
```

## Invoke Drift Detection

```
@git-ape check drift for the order-api deployment
```

## Example Drift Report

```
🔍 Drift Report — rg-orderapi-dev-eastus

  Resources Scanned: 6
  Drift Items Found: 2

  1. Storage Account (storderapidev8k3m)
     Property: networkAcls.defaultAction
     Template: "Allow"  →  Live: "Deny"
     Cause: Likely Azure Policy remediation
     Options: [Update template] [Revert resource] [Accept drift]

  2. Function App (func-orderapi-dev-eastus)
     Property: siteConfig.appSettings
     Template: 5 settings  →  Live: 7 settings
     Added: WEBSITE_RUN_FROM_PACKAGE, FUNCTIONS_EXTENSION_VERSION
     Cause: Likely manual portal change
     Options: [Update template] [Revert resource] [Accept drift]
```

## Reconciliation Options

| Option | What It Does |
|--------|-------------|
| **Update template** | Modifies the ARM template to match live state. Commits change to repo. |
| **Revert resource** | Redeploys the stored template to reset the resource to desired state. |
| **Accept drift** | Acknowledges the change. Updates `state.json` to match live state. |

## When to Run

- **Scheduled audits** — weekly drift checks for production environments
- **Post-incident** — after a production issue to find manual fixes that need to be codified
- **Before redeployment** — ensure the stored template reflects actual state
- **Compliance reviews** — prove infrastructure matches approved templates

## Related

- [Skills: Azure Drift Detector](/docs/skills/azure-drift-detector)
- [Deployment State](/docs/deployment/state)
- [For DevOps](/docs/personas/for-devops)
