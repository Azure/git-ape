---
title: "Tenant Isolation Models"
sidebar_label: "Tenant Isolation Models"
description: "Designs and validates tenancy models (shared, pooled, siloed, hybrid) with security, cost, and scale trade-offs. USE FOR: choosing an isolation model per architecture layer (compute/data/identity/messaging/networking), compliance-driven isolation decisions. DO NOT USE FOR: landing zone setup (use isv-landing-zone-foundation), lifecycle automation (use tenant-lifecycle-automation)."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/community/tenant-isolation-models/SKILL.md -->


# Tenant Isolation Models

> Designs and validates tenancy models (shared, pooled, siloed, hybrid) with security, cost, and scale trade-offs. USE FOR: choosing an isolation model per architecture layer (compute/data/identity/messaging/networking), compliance-driven isolation decisions. DO NOT USE FOR: landing zone setup (use isv-landing-zone-foundation), lifecycle automation (use tenant-lifecycle-automation).

:::info[Third-party community skill]
This skill is contributed and maintained by the community, not by the Git-Ape maintainers. See the [Skill Registry](../registry) for provenance details.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/community/tenant-isolation-models/` |
| **Author** | dawright22 |
| **Maturity** | stable |
| **Source** | [https://github.com/dawright22/azure-saas-skills](https://github.com/dawright22/azure-saas-skills) |
| **User Invocable** | ✅ Yes |
| **Usage** | `/tenant-isolation-models` |


## Documentation

# Tenant Isolation Models

> Selects the right multitenancy isolation pattern for the product and compliance profile, independently per architecture layer.

## When to Use

* "should my SaaS product be multi-tenant shared, pooled, or siloed"
* "what tenant isolation model fits our compliance requirements"
* Comparing resource sharing vs isolation trade-offs for compute, data, identity, messaging, or networking
* Planning tenant placement or migration between deployment stamps

## Procedure

### 1. Define the tenant

Start with the product's definition of a tenant and map customers, users, subscriptions,
business units, and environments to explicit tenant boundaries, following
[Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview).

### 2. Evaluate model options per layer

Independently assess for compute, data, identity, messaging, and networking:

* Shared infrastructure / shared data
* Shared infrastructure / isolated data
* Pooled resources per segment
* Silo model per tenant
* Hybrid progression model

### 3. Run the required analysis

* Assess security boundaries, regulatory constraints, performance isolation, noisy-neighbor risk, scale limits, cost, and operational complexity.
* Define how tenant context is established, validated, propagated, and logged for synchronous and asynchronous flows.
* Identify service-specific multitenancy constraints — do not assume a shared resource provides tenant isolation by default.
* Define tenant placement and migration criteria when deployment stamps or mixed tenancy models are used.

### 4. Record the decision

Document the chosen model per layer with rationale, and the migration path as tenant
scale and compliance requirements grow.

## Outputs

* Chosen tenancy model with rationale.
* Isolation control map (identity, network, data, compute).
* Tenant-context trust and propagation model.
* Tenant placement, capacity, and migration policy.
* Migration path as tenant scale and compliance requirements grow.

## Constraints

**Always:**

* Evaluate isolation independently per architecture layer — a product can mix shared and siloed layers.
* Define tenant-context validation and propagation explicitly; never trust an unvalidated tenant identifier.

**Never:**

* Assume a shared Azure service provides tenant isolation guarantees without checking that service's specific multitenancy documentation.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
