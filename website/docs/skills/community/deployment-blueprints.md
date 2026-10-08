---
title: "Deployment Blueprints"
sidebar_label: "Deployment Blueprints"
description: "Provides implementation blueprints and deployment sequencing for Azure SaaS reference topologies. USE FOR: choosing single-region vs multi-region vs deployment-stamp topology, defining deployment sequencing and rollback strategy. DO NOT USE FOR: tenancy model selection itself (use tenant-isolation-models), day-2 scale/SRE operations (use scale-and-sre)."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/community/deployment-blueprints/SKILL.md -->


# Deployment Blueprints

> Provides implementation blueprints and deployment sequencing for Azure SaaS reference topologies. USE FOR: choosing single-region vs multi-region vs deployment-stamp topology, defining deployment sequencing and rollback strategy. DO NOT USE FOR: tenancy model selection itself (use tenant-isolation-models), day-2 scale/SRE operations (use scale-and-sre).

:::info[Third-party community skill]
This skill is contributed and maintained by the community, not by the Git-Ape maintainers. See the [Skill Registry](../registry) for provenance details.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/community/deployment-blueprints/` |
| **Author** | dawright22 |
| **Maturity** | experimental |
| **Source** | [https://github.com/dawright22/azure-saas-skills](https://github.com/dawright22/azure-saas-skills) |
| **User Invocable** | ✅ Yes |
| **Usage** | `/deployment-blueprints` |


## Documentation

# Deployment Blueprints

> Turns multi-tenant SaaS architecture decisions into executable, sequenced deployment tracks.

## When to Use

* "what deployment topology fits my multi-tenant SaaS product"
* "design a deployment-stamp topology with tenant placement"
* Defining IaC deployment sequencing and environment-specific parameters
* Planning rollback and regional evacuation behavior

## Procedure

### 1. Select a blueprint track

Choose from:

* Single-region starter SaaS topology.
* Multi-region production topology.
* Shared services + per-tenant workload topology.
* Deployment-stamp topology with a global control plane and tenant placement strategy.
* Reference CI/CD promotion model.

### 2. Apply multitenant deployment requirements

Apply the deployment-stamp guidance from
[Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview):

* Define stamp boundaries, capacity limits, tenant allocation, and scale-out triggers.
* Separate global routing and tenant-placement metadata from stamp-local workload resources.
* Support controlled tenant movement between stamps, including data migration and routing changes.
* Use repeatable IaC and versioned configuration so stamps remain consistent while supporting safe upgrades.
* Define blast radius, rollback, and regional evacuation behavior.

### 3. Define sequencing and parameters

Document the deployment sequence, dependency graph, and environment-specific parameter
model.

### 4. Define release and rollback strategy

Document the release process and rollback strategy for each topology track.

## Outputs

* Deployment sequence and dependency graph.
* Environment-specific parameter model.
* Stamp topology, tenant placement algorithm, and migration procedure when stamps are used.
* Release and rollback strategy guidance.

## Constraints

**Always:**

* Separate global routing/tenant-placement metadata from stamp-local workload resources in stamp topologies.
* Define blast radius and rollback behavior before the first production deployment, not after an incident.

**Never:**

* Hand-deploy stamp instances outside of repeatable, versioned IaC — stamps must stay consistent to support safe upgrades.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
