---
name: tenant-lifecycle-automation
description: "Implements automated tenant onboarding, provisioning, upgrade, suspension, and offboarding workflows."
argument-hint: "Provisioning SLA, onboarding approvals, data retention policy, and lifecycle states"
user-invocable: true
last_updated: "2026-08-17"
---

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
