---
name: deployment-blueprints
description: "Provides implementation blueprints and deployment sequencing for Azure SaaS reference topologies."
argument-hint: "Preferred IaC tool, target topology, deployment environments, and release cadence"
user-invocable: true
last_updated: "2026-08-17"
---

# Deployment Blueprints

Turns architecture decisions into executable deployment tracks.

## Blueprint tracks

- Single-region starter SaaS topology.
- Multi-region production topology.
- Shared services + per-tenant workload topology.
- Deployment-stamp topology with a global control plane and tenant placement strategy.
- Reference CI/CD promotion model.

## Multitenant deployment requirements

Apply the deployment-stamp guidance from [Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview):

- Define stamp boundaries, capacity limits, tenant allocation, and scale-out triggers.
- Separate global routing and tenant-placement metadata from stamp-local workload resources.
- Support controlled tenant movement between stamps, including data migration and routing changes.
- Use repeatable IaC and versioned configuration so stamps remain consistent while supporting safe upgrades.
- Define blast radius, rollback, and regional evacuation behavior.

## Deliverables

- Deployment sequence and dependency graph.
- Environment-specific parameter model.
- Stamp topology, tenant placement algorithm, and migration procedure when stamps are used.
- Release and rollback strategy guidance.
