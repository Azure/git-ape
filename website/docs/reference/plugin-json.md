---
title: "plugin.json Reference"
sidebar_label: "plugin.json"
description: "Git-Ape plugin manifest (VS Code agent plugin and Copilot CLI plugin)"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: plugin.json -->


# plugin.json

The plugin manifest defines the Git-Ape plugin metadata. The same manifest is consumed by both the [VS Code agent plugin](https://code.visualstudio.com/docs/copilot/customization/agent-plugins) loader and the [GitHub Copilot CLI plugin](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference) loader — no separate config is required.

## Current Configuration

| Field | Value |
|-------|-------|
| **Name** | git-ape |
| **Version** | 0.3.0 |
| **Description** | Intelligent agent system for deploying any Azure workload through GitHub Copilot. Provides guided, safe, and validated deployments using ARM templates, with built-in security analysis, cost estimation, and CI/CD pipeline integration. |
| **Author** | Microsoft |
| **License** | MIT |
| **Agents Path** | `.github/agents/` |
| **Skills Path** | `.github/skills/` |

## Keywords

`azure` · `cloud` · `workloads` · `deployment` · `arm-templates` · `devops` · `security` · `cost-estimation` · `github-actions` · `copilot-agents`

## Full Source

```json
{
  "name": "git-ape",
  "description": "Intelligent agent system for deploying any Azure workload through GitHub Copilot. Provides guided, safe, and validated deployments using ARM templates, with built-in security analysis, cost estimation, and CI/CD pipeline integration.",
  "version": "0.3.0",
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
    "workloads",
    "deployment",
    "arm-templates",
    "devops",
    "security",
    "cost-estimation",
    "github-actions",
    "copilot-agents"
  ],
  "agents": ".github/agents/",
  "skills": ".github/skills/",
  "prompts": ".github/prompts/"
}
```
