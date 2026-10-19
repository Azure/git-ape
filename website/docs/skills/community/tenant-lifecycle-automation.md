---
title: "Tenant Lifecycle Automation"
sidebar_label: "Tenant Lifecycle Automation"
description: "Implements automated tenant onboarding, provisioning, upgrade, suspension, and offboarding workflows."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/community-skills/tenant-lifecycle-automation/SKILL.md -->


# Tenant Lifecycle Automation

> Implements automated tenant onboarding, provisioning, upgrade, suspension, and offboarding workflows.

:::info[Third-party community skill]
This skill is reviewed through Azure/git-ape PRs and maintained by its listed author. It is not bundled or activated with core. See the [Skill Registry](../registry) and use `/git-ape-skills install tenant-lifecycle-automation` for explicit workspace installation. Review is not a guarantee of safety.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/community-skills/tenant-lifecycle-automation/` |
| **Author** | dawright22 |
| **Maturity** | experimental |
| **Available with Core** | ❌ No — explicit installation required |
| **Usage** | `/tenant-lifecycle-automation Provisioning SLA, onboarding approvals, data retention policy, and lifecycle states` |


## Documentation

# Tenant Lifecycle Automation

Defines lifecycle workflows that keep tenant operations consistent and auditable.

## Lifecycle coverage

1. Tenant signup and activation.
2. Plan/subscription assignment.
3. Resource provisioning and configuration.
4. Upgrade, downgrade, and pause/resume.
5. Offboarding, retention, and deletion.

Use the tenant lifecycle principles from [Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview).
Treat provisioning as an idempotent, observable workflow and include tenant placement,
configuration, entitlement, data residency, migration, and deprovisioning states.

## Deliverables

- Lifecycle state machine and event contracts.
- Automation responsibilities by service/component.
- Tenant placement and deployment-stamp movement workflow.
- Reconciliation process for detecting and repairing partial or drifted tenant state.
- Operational runbook for failed provisioning and retries.
