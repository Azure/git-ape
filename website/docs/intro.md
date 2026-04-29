---
title: "Introduction"
sidebar_label: "Introduction"
sidebar_position: 1
description: "Git-Ape — Intelligent Azure deployment agent system for GitHub Copilot"
slug: /intro
---

# Git-Ape

:::warning
**EXPERIMENTAL PROJECT:** Git-Ape is in active development and is not production-ready. Use it for local development, demos, sandbox subscriptions, and learning only.
:::

Git-Ape is a **platform engineering framework** built on GitHub Copilot. It provides a structured, multi-agent system for planning, validating, and deploying Azure infrastructure — with security gates, cost analysis, and CI/CD pipeline integration built in.

It is the implementation of the thesis Microsoft published in [Platform Engineering for the Agentic AI Era](https://devblogs.microsoft.com/all-things-azure/platform-engineering-for-the-agentic-ai-era/) — agents and policy replacing module catalogues as the platform team's primary deliverable. See the **[Vision & Manifesto](./vision)** for the full thinking.

## What it does

- **Gather deployment requirements** through guided conversations
- **Generate ARM templates** and supporting deployment artifacts
- **Run security, preflight, and cost checks** before deployment
- **Deploy and validate** with post-deployment health checks
- **Manage lifecycle** with drift detection and teardown workflows

## How it works

Git-Ape enforces compliance at three layers — generation, plan, and runtime — so non-compliant code never reaches your subscription. See [Vision & Manifesto → Three layers of enforcement](./vision#how-it-works--three-layers-of-enforcement).

## Deployment Flow

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontSize':'13px','lineColor':'#64748b','textColor':'#1e293b','primaryTextColor':'#0f172a','edgeLabelBackground':'#f8fafc','tertiaryColor':'#f1f5f9'}}}%%
graph TD
    U["User prompt:<br/>deploy a Python function app"]
    U --> S1
    S1["Stage 1: Requirements<br/>Gather inputs, validate naming & SKUs"]
    S1 --> S2
    S2["Stage 2: Template & Analysis<br/>Generate ARM + security + cost"]
    S2 --> GATE
    GATE{{"Security Gate"}}
    GATE -- "BLOCKED" --> FIX["Fix & retry"]
    FIX --> S2
    GATE -- "PASSED" --> CONFIRM
    CONFIRM{{"User Confirmation"}}
    CONFIRM --> S3
    S3["Stage 3: Deploy"]
    S3 --> S4
    S4["Stage 4: Validate & Test"]

    classDef user fill:#e0e7ff,stroke:#4338ca,stroke-width:2px,color:#1e1b4b
    classDef stage fill:#dbeafe,stroke:#1f6feb,stroke-width:1px,color:#0b3d91
    classDef gate fill:#fde68a,stroke:#b45309,stroke-width:2px,color:#7c2d12
    classDef fix fill:#fecaca,stroke:#b91c1c,stroke-width:1px,color:#7f1d1d
    classDef deploy fill:#dcfce7,stroke:#15803d,stroke-width:2px,color:#14532d

    class U user
    class S1,S2 stage
    class GATE,CONFIRM gate
    class FIX fix
    class S3,S4 deploy
```

## Execution Modes

Git-Ape works in two modes:

- **Interactive (VS Code)** — Talk to `@git-ape` in Copilot Chat, authenticate via `az login`, approve each step in real time.
- **Headless (Coding Agent)** — Copilot Coding Agent picks up a GitHub Issue, generates templates on a branch, opens a PR, and CI/CD workflows handle the rest.

## Quick Start

```bash
# Install the plugin
copilot plugin marketplace add Azure/git-ape
copilot plugin install Azure/git-ape

# Check prerequisites
# In Copilot Chat: /prereq-check

# Deploy something
# In Copilot Chat: @git-ape deploy a Python function app
```

## Next Steps

- [Vision & Manifesto](./vision) — why Git-Ape exists and how it relates to module-first platforms
- [Installation & Prerequisites](./getting-started/installation)
- [Azure MCP Setup](./getting-started/azure-setup)

### Who Is This For?

- [Executives & CxOs](./personas/for-executives) — governance, cost visibility, compliance
- [Engineering Leads](./personas/for-engineering-leads) — self-service, architecture standards
- [DevOps Engineers](./personas/for-devops) — CI/CD pipelines, OIDC, drift detection
- [Platform Engineers](./personas/for-platform-engineering) — guardrails, naming, policy
- [Individual Engineers](./personas/for-engineers) — quick start, skill cheatsheet

### Popular Use Cases

- [Deploy anything](./use-cases/deploy-anything)
- [Security Analysis](./use-cases/security-analysis)
- [CI/CD Pipeline](./use-cases/cicd-pipeline)
- [Headless / Coding Agent Mode](./use-cases/headless-mode)

### Deep Dives

- [Agents Overview](./agents/overview)
- [Skills Overview](./skills/overview)
- [CI/CD Workflows](./workflows/overview)
