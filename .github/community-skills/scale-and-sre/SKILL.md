---
name: scale-and-sre
description: "Implements production scale, reliability, and observability patterns for multi-tenant SaaS platforms."
argument-hint: "SLO targets, peak concurrency, DR objectives, and telemetry tooling preferences"
user-invocable: true
last_updated: "2026-08-17"
---

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
