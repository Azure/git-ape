---
name: scale-and-sre
description: "Implements production scale, reliability, and observability patterns for multi-tenant SaaS platforms. USE FOR: SLO/alerting design, capacity/tenant-placement planning, DR, tenant-aware telemetry and cost attribution. DO NOT USE FOR: initial tenancy model selection (use tenant-isolation-models), lifecycle automation (use tenant-lifecycle-automation)."
license: MIT
metadata:
  author: dawright22
  source: https://github.com/dawright22/azure-saas-skills
  maturity: stable
  version: "1.0.0"
---

# Scale and SRE

> Applies day-2 engineering best practices for growth and stability on a multi-tenant SaaS platform.

## When to Use

* "design SLOs and alerting for my SaaS platform"
* "how do I prevent noisy-neighbor issues across tenants"
* Planning capacity, tenant placement, and scale-out thresholds
* Designing tenant-aware telemetry, usage, and cost attribution without leaking tenant data

## Procedure

### 1. Define horizontal scaling and partitioning strategy

Determine how the platform scales horizontally and how data/compute is partitioned.

### 2. Plan deployment-stamp capacity and tenant placement

Define deployment-stamp capacity, tenant placement, and scale-out thresholds, following
[Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview).

### 3. Design noisy-neighbor controls

Define detection, resource governance, throttling, and per-tenant quotas to prevent one
tenant from degrading others.

### 4. Design availability, backup, and DR

Define availability targets, backup policy, and disaster recovery procedures.

### 5. Design SLO/SLI and alerting

Define per-platform and, where appropriate, per-tenant service level objectives and the
alerting model backing them.

### 6. Design tenant-aware telemetry

Build telemetry, health, usage, and cost-attribution views that are tenant-aware without
leaking tenant data across boundaries.

### 7. Build incident response and dashboards

Define the incident response process and operational dashboards.

## Outputs

* SRE baseline for production operations.
* Capacity and resiliency validation checklist.
* Per-tenant observability, quota, metering, and cost-allocation model.
* Runbook set for common failure domains.

## Constraints

**Always:**

* Design per-tenant quotas and throttling before noisy-neighbor incidents occur, not after.
* Keep tenant-aware telemetry free of cross-tenant data leakage in dashboards, logs, and alerts.

**Never:**

* Treat platform-wide SLOs as sufficient without considering per-tenant fairness for larger or regulated tenants.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
