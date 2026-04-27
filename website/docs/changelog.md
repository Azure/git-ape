---
title: "Changelog"
sidebar_label: "Changelog"
sidebar_position: 99
description: "Git-Ape release notes and changelog"
---

# Changelog

## v0.0.1 (Current)

Initial experimental release.

### Agents
- Git-Ape (main orchestrator)
- Azure Requirements Gatherer
- Azure Template Generator
- Azure Resource Deployer
- Azure Principal Architect
- Azure IaC Exporter
- Azure Policy Advisor
- Git-Ape Onboarding

### Skills
- 13 skills covering pre-deploy, post-deploy, and operations phases

### CI/CD Workflows
- `git-ape-plan.yml` — Validate & preview on PR
- `git-ape-deploy.yml` — Deploy on merge or `/deploy` command
- `git-ape-destroy.yml` — Tear down on merge with destroy-requested status
- `git-ape-verify.yml` — Manual setup verification
