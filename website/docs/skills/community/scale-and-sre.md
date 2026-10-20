---
title: "Scale And Sre"
sidebar_label: "Scale And Sre"
description: "Implements production scale, reliability, and observability patterns for multi-tenant SaaS platforms."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/community-skills/scale-and-sre/SKILL.md -->


# Scale And Sre

> Implements production scale, reliability, and observability patterns for multi-tenant SaaS platforms.

:::info[Third-party community skill]
This skill is reviewed through Azure/git-ape PRs and maintained by its listed author. It is not bundled or activated with core. See the [Skill Registry](../registry) and use `/git-ape-skills install scale-and-sre` for explicit project or personal installation. Review is not a guarantee of safety.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/community-skills/scale-and-sre/` |
| **Author** | dawright22 |
| **Maturity** | experimental |
| **Available with Core** | ❌ No — explicit installation required |
| **Usage** | `/scale-and-sre SLO targets, peak concurrency, DR objectives, and telemetry tooling preferences` |


## Documentation

# Scale and SRE

Applies day-2 engineering best practices for growth and stability.

## Focus areas

- Horizontal scaling and partitioning strategy.
- Deployment-stamp capacity, tenant placement, and scale-out thresholds.
- Noisy-neighbor detection, resource governance, throttling, and per-tenant quotas.
- Availability, backup, and disaster recovery.
- SLO/SLI design and alerting model.
- Tenant-aware telemetry, health, usage, and cost attribution without leaking tenant data.
- Incident response and operational dashboards.

Use [Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview)
to assess shared-resource limits, tenant density, blast radius, fairness, and operational
automation. Define both platform-wide and tenant-level service objectives where appropriate.

## Deliverables

- SRE baseline for production operations.
- Capacity and resiliency validation checklist.
- Per-tenant observability, quota, metering, and cost-allocation model.
- Runbook set for common failure domains.
