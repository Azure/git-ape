---
title: "Marketplace Configuration"
sidebar_label: "Marketplace"
description: "Git-Ape marketplace plugin configuration"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/plugin/marketplace.json -->


# Marketplace Configuration

The marketplace manifest configures how Git-Ape appears in the Copilot CLI plugin marketplace.

## Current Configuration

| Field | Value |
|-------|-------|
| **Name** | git-ape |
| **Owner** | Microsoft |
| **Version** | 0.0.1 |
| **Description** | Git-Ape — Intelligent Azure deployment agent and skill suite for GitHub Copilot. Onboard any repository with guided ARM template generation, security analysis, cost estimation, drift detection, and automated CI/CD pipelines. |

## Plugins

- **git-ape** v0.0.1: Intelligent Azure deployment agent system for GitHub Copilot. Provides guided, safe, and validated Azure resource deployments using ARM templates, with built-in security analysis, cost estimation, drift detection, and CI/CD pipeline integration.

## Full Source

```json
{
  "name": "git-ape",
  "owner": {
    "name": "Microsoft",
    "url": "https://github.com/Azure/git-ape"
  },
  "metadata": {
    "description": "Git-Ape — Intelligent Azure deployment agent and skill suite for GitHub Copilot. Onboard any repository with guided ARM template generation, security analysis, cost estimation, drift detection, and automated CI/CD pipelines.",
    "version": "0.0.1"
  },
  "plugins": [
    {
      "name": "git-ape",
      "description": "Intelligent Azure deployment agent system for GitHub Copilot. Provides guided, safe, and validated Azure resource deployments using ARM templates, with built-in security analysis, cost estimation, drift detection, and CI/CD pipeline integration.",
      "version": "0.0.1",
      "source": "."
    }
  ]
}
```
