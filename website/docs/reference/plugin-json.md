---
title: "plugin.json Reference"
sidebar_label: "plugin.json"
description: "Git-Ape Copilot CLI plugin manifest"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: plugin.json -->


# plugin.json

The plugin manifest defines the Git-Ape Copilot CLI plugin metadata.

## Current Configuration

| Field | Value |
|-------|-------|
| **Name** | git-ape |
| **Version** | 0.0.1 |
| **Description** | Intelligent Azure deployment agent system for GitHub Copilot. Provides guided, safe, and validated Azure resource deployments using ARM templates, with built-in security analysis, cost estimation, and CI/CD pipeline integration. |
| **Author** | Microsoft |
| **License** | MIT |
| **Agents Path** | `.github/agents/` |
| **Skills Path** | `.github/skills/` |

## Keywords

`azure` · `cloud` · `infrastructure` · `arm-templates` · `deployment` · `devops` · `iac` · `security` · `cost-estimation` · `github-actions`

## Full Source

```json
{
  "name": "git-ape",
  "description": "Intelligent Azure deployment agent system for GitHub Copilot. Provides guided, safe, and validated Azure resource deployments using ARM templates, with built-in security analysis, cost estimation, and CI/CD pipeline integration.",
  "version": "0.0.1",
  "author": {
    "name": "Microsoft",
    "url": "https://github.com/Azure/git-ape"
  },
  "homepage": "https://github.com/Azure/git-ape",
  "repository": "https://github.com/Azure/git-ape",
  "license": "MIT",
  "keywords": [
    "azure",
    "cloud",
    "infrastructure",
    "arm-templates",
    "deployment",
    "devops",
    "iac",
    "security",
    "cost-estimation",
    "github-actions"
  ],
  "agents": ".github/agents/",
  "skills": ".github/skills/"
}
```
