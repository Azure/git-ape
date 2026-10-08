---
title: "Tenant Lifecycle Automation"
sidebar_label: "Tenant Lifecycle Automation"
description: "Implements automated tenant onboarding, provisioning, upgrade, suspension, and offboarding workflows. USE FOR: designing idempotent tenant state machines, reconciliation of partial/drifted tenant state. DO NOT USE FOR: initial tenancy model selection (use tenant-isolation-models), marketplace fulfillment events specifically (use fulfillment-and-metering)."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/community/tenant-lifecycle-automation/SKILL.md -->


# Tenant Lifecycle Automation

> Implements automated tenant onboarding, provisioning, upgrade, suspension, and offboarding workflows. USE FOR: designing idempotent tenant state machines, reconciliation of partial/drifted tenant state. DO NOT USE FOR: initial tenancy model selection (use tenant-isolation-models), marketplace fulfillment events specifically (use fulfillment-and-metering).

:::info[Third-party community skill]
This skill is contributed and maintained by the community, not by the Git-Ape maintainers. See the [Skill Registry](../registry) for provenance details.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/community/tenant-lifecycle-automation/` |
| **Author** | dawright22 |
| **Maturity** | experimental |
| **Source** | [https://github.com/dawright22/azure-saas-skills](https://github.com/dawright22/azure-saas-skills) |
| **User Invocable** | ✅ Yes |
| **Usage** | `/tenant-lifecycle-automation` |


## Documentation

# Tenant Lifecycle Automation

> Defines automated, idempotent tenant lifecycle workflows — onboarding, provisioning, upgrade, suspension, and offboarding — that stay consistent and auditable.

## When to Use

* "automate tenant onboarding/provisioning for my SaaS platform"
* "what happens when a tenant upgrades, downgrades, or is deleted"
* Designing reconciliation for tenants stuck in a partial or drifted state
* Defining deployment-stamp tenant placement and movement workflows

## Procedure

### 1. Map lifecycle coverage

Cover, at minimum:

1. Tenant signup and activation.
2. Plan/subscription assignment.
3. Resource provisioning and configuration.
4. Upgrade, downgrade, and pause/resume.
5. Offboarding, retention, and deletion.

### 2. Apply multitenancy lifecycle principles

Use the tenant lifecycle principles from
[Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview).
Treat provisioning as an idempotent, observable workflow, and include tenant placement,
configuration, entitlement, data residency, migration, and deprovisioning states.

### 3. Define the state machine and events

Design the lifecycle state machine and the event contracts each stage emits/consumes.

### 4. Assign automation responsibilities

Map each lifecycle stage to the service/component responsible for executing it.

### 5. Define reconciliation and runbooks

Define a reconciliation process for detecting and repairing partial or drifted tenant
state, plus an operational runbook for failed provisioning and retries.

## Outputs

* Lifecycle state machine and event contracts.
* Automation responsibilities by service/component.
* Tenant placement and deployment-stamp movement workflow.
* Reconciliation process for detecting and repairing partial or drifted tenant state.
* Operational runbook for failed provisioning and retries.

## Constraints

**Always:**

* Make every provisioning/deprovisioning operation idempotent and safely retryable.
* Include a reconciliation path for tenants left in a partial state by a failed operation.

**Never:**

* Treat tenant deletion as a single irreversible step without a retention/grace-period policy.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
