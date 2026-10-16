---
name: tenant-isolation-models
description: "Designs and validates tenancy models (shared, pooled, siloed, hybrid) with security, cost, and scale trade-offs."
argument-hint: "Tenant count, data isolation requirements, noisy-neighbor tolerance, and regulatory constraints"
user-invocable: true
last_updated: "2026-08-17"
---

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
