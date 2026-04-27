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

## What It Does

- **Gather deployment requirements** through guided conversations
- **Generate ARM templates** and supporting deployment artifacts
- **Run security, preflight, and cost checks** before deployment
- **Deploy and validate** with post-deployment health checks
- **Manage lifecycle** with drift detection and teardown workflows

## Deployment Flow

```mermaid
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

- [Installation & Prerequisites](./getting-started/installation)
- [Azure MCP Setup](./getting-started/azure-setup)

### Who Is This For?

- [Executives & CxOs](./personas/for-executives) — governance, cost visibility, compliance
- [Engineering Leads](./personas/for-engineering-leads) — self-service, architecture standards
- [DevOps Engineers](./personas/for-devops) — CI/CD pipelines, OIDC, drift detection
- [Platform Engineers](./personas/for-platform-engineering) — guardrails, naming, policy
- [Individual Engineers](./personas/for-engineers) — quick start, skill cheatsheet

### Popular Use Cases

- [Deploy a Function App](./use-cases/deploy-function-app)
- [Security Analysis](./use-cases/security-analysis)
- [CI/CD Pipeline](./use-cases/cicd-pipeline)
- [Headless / Coding Agent Mode](./use-cases/headless-mode)

### Deep Dives

- [Agents Overview](./agents/overview)
- [Skills Overview](./skills/overview)
- [CI/CD Workflows](./workflows/overview)
