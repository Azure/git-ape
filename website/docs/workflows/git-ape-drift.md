---
title: "Git-Ape: Drift (source)"
sidebar_label: "Drift (source)"
description: "Agentic workflow source: Continuous drift detection and remediation"
---

<!-- HAND-CURATED — NOT auto-generated. Sibling page `git-ape-drift-lock.md` is
     auto-generated from the compiled `.lock.yml`. This page documents the
     agentic workflow source (`.md`) authored with GitHub Agentic Workflows. -->

# Git-Ape: Drift

**Workflow source:** `.github/skills/git-ape-onboarding/templates/workflows/git-ape-drift.md`
**Compiled lock:** `.github/skills/git-ape-onboarding/templates/workflows/git-ape-drift.lock.yml` ([generated page](./git-ape-drift-lock))

:::info[Scaffolded by `/git-ape-onboarding`]
This workflow is **shipped as a template** under `.github/skills/git-ape-onboarding/templates/workflows/` and copied into your repository's `.github/workflows/` by the [`/git-ape-onboarding`](/docs/skills/git-ape-onboarding) flow. It does **not** run in the git-ape repo itself.
:::

:::info Agentic Workflow
This is a [GitHub Agentic Workflow](https://github.github.com/gh-aw/) — an AI-driven workflow authored in Markdown rather than traditional YAML. The AI agent reasons about drift, classifies changes, and creates PRs for human review.
:::

## Triggers

- **`schedule`** — Daily around 06:00 UTC
- **`workflow_dispatch`** — Manual trigger

## Permissions

- `contents: read`
- `issues: read`
- `pull-requests: read`

## What It Does

The drift workflow implements continuous drift remediation as described in the [Platform Engineering for the Agentic AI Era](https://devblogs.microsoft.com/all-things-azure/platform-engineering-for-the-agentic-ai-era/) manifesto.

### 1. Discovery

Scans `.azure/deployments/` for all active deployments (`state.json` with `"status": "succeeded"`, excluding destroyed deployments).

### 2. Detection

For each active deployment, the agent:
- Reads the stored ARM template (`template.json`) as the desired state
- Queries Azure for current resource configuration via `az resource show`
- Compares properties and identifies differences

### 3. Classification

Each drifted property is classified by severity:

| Severity | Examples | Action |
|----------|----------|--------|
| 🔴 **Critical** | HTTPS disabled, firewall removed, auth changes, TLS downgrade | Issue + two PRs |
| 🟡 **Warning** | SKU changes, tag modifications, runtime version changes | Two PRs |
| 🔵 **Info** | Description changes, Azure Policy-added tags | Logged only |

### 4. Anti-Flapping

To prevent alert fatigue and churn:

- **Debounce** — No duplicate alerts for the same drift within 24 hours
- **Cooldown** — Skip resources with recently merged remediation PRs
- **Persistence threshold** — Only alert on drift persisting for 2+ consecutive checks

### 5. Remediation PRs

For each drifted deployment, the agent creates **two draft PRs**:

| PR | Purpose | Changes |
|----|---------|---------|
| **Revert** | Restore Azure to match IaC | Contains `az` commands to revert Azure state |
| **Adopt** | Update IaC to match Azure | Updates `template.json` to reflect current Azure config |

The human reviewer chooses which PR to merge (or closes both if neither is appropriate).

For Critical drift, a GitHub issue is also created with `priority:critical` and `security` labels.

## Safe Outputs

| Output | Configuration |
|--------|--------------|
| `create-issue` | Prefix: `[drift]`, labels: `drift, security`, max: 5, auto-close older |
| `create-pull-request` | Prefix: `[drift-remediation]`, labels: `drift, automated-remediation`, draft: true, max: 10 |

## Tools

| Tool | Purpose |
|------|---------|
| `bash` | Azure CLI queries, JSON processing with jq |
| `edit` | Read/modify deployment files |
| `cache-memory` | Anti-flapping state and drift history |

## Configuration

### Enabling the Workflow

The workflow is scaffolded into your repository by `/git-ape-onboarding`. To recompile after editing the agentic source:

1. Install the `gh-aw` CLI extension:
   ```bash
   gh extension install github/gh-aw
   ```

2. Compile the workflow:
   ```bash
   gh aw compile
   ```

3. Commit and push both `.github/workflows/git-ape-drift.md` and the generated `.github/workflows/git-ape-drift.lock.yml`

4. Configure required secrets for your chosen AI engine (see [Authentication](https://github.github.com/gh-aw/reference/auth/))

### Customizing the Schedule

Edit the `on.schedule` field in the frontmatter:
```yaml
on:
  schedule: daily around 06:00   # Default
  # schedule: "0 */6 * * *"      # Every 6 hours
  # schedule: weekly on monday   # Weekly
```

### Azure Authentication

The workflow needs Azure CLI access to query resource state. Configure OIDC credentials as described in the [onboarding guide](../getting-started/onboarding).

## Related

- [Continuous Drift Remediation (compiled workflow)](./git-ape-drift-lock) — auto-generated reference for the `.lock.yml`
- [Azure Drift Detector skill](../skills/azure-drift-detector) — the skill that powers the agent's reasoning
- [Drift Detection use case](../use-cases/drift-detection) — high-level overview
- [Drift Detection deployment guide](../deployment/drift-detection) — operator playbook
