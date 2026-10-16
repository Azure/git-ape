---
title: "Tenant Isolation Models"
sidebar_label: "Tenant Isolation Models"
description: "Designs and validates tenancy models (shared, pooled, siloed, hybrid) with security, cost, and scale trade-offs."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/community-skills/tenant-isolation-models/SKILL.md -->


# Tenant Isolation Models

> Designs and validates tenancy models (shared, pooled, siloed, hybrid) with security, cost, and scale trade-offs.

:::info[Third-party community skill]
This skill is reviewed through Azure/git-ape PRs and maintained by its listed author. It is not bundled or activated with core. See the [Skill Registry](../registry) and use `/git-ape-skills install tenant-isolation-models` for explicit workspace installation. Review is not a guarantee of safety.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/community-skills/tenant-isolation-models/` |
| **Author** | dawright22 |
| **Maturity** | experimental |
| **Available with Core** | ❌ No — explicit installation required |
| **Usage** | `/tenant-isolation-models Tenant count, data isolation requirements, noisy-neighbor tolerance, and regulatory constraints` |


## Documentation

# Tenant Isolation Models

Selects the right multitenancy pattern for the product and compliance profile.

Follow the principles in [Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview).
Begin with the product's definition of a tenant and map customers, users, subscriptions,
business units, and environments to tenant boundaries before selecting Azure resources.

## Model options

- Shared infrastructure / shared data
- Shared infrastructure / isolated data
- Pooled resources per segment
- Silo model per tenant
- Hybrid progression model

## Required analysis

- Compare resource sharing and isolation independently for compute, data, identity, messaging, and networking.
- Assess security boundaries, regulatory constraints, performance isolation, noisy-neighbor risk, scale limits, cost, and operational complexity.
- Define how tenant context is established, validated, propagated, and logged for synchronous and asynchronous flows.
- Identify service-specific multitenancy constraints; do not assume a shared resource provides tenant isolation by default.
- Define tenant placement and migration criteria when deployment stamps or mixed tenancy models are used.

## Deliverables

- Chosen tenancy model with rationale.
- Isolation control map (identity, network, data, compute).
- Tenant-context trust and propagation model.
- Tenant placement, capacity, and migration policy.
- Migration path as tenant scale and compliance requirements grow.
