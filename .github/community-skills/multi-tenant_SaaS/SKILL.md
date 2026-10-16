---
name: multi-tenant_SaaS
description: "Primary orchestration skill for building a multi-tenant Azure SaaS platform, integrating ISV landing zone guidance, SaaS Accelerator patterns, and marketplace publication workflows."
argument-hint: "SaaS product type, target tenants, regions, compliance needs, and preferred offer model"
user-invocable: true
last_updated: "2026-08-17"
---

# Multi-Tenant SaaS Orchestrator

Use this skill as the top-level entrypoint: `/git-ape:multi-tenant_SaaS`.

## What this skill does

1. Collects platform requirements (tenant model, scale profile, compliance, regions).
2. Maps requirements to ISV landing zone and SaaS Accelerator implementation tracks.
3. Produces a staged execution plan:
   - Foundation and landing zone
   - SaaS platform build-out
   - Marketplace onboarding and publication
4. Routes work to specialized skills in this plugin.

## Authoritative multitenancy guidance

Use [Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview)
as the primary Azure Architecture Center reference for multitenancy decisions. Apply its
principles across the specialist skills rather than treating multitenancy as only a data
isolation concern.

For every architecture:

- Define tenants and the business-to-tenant mapping explicitly.
- Record the isolation model and trade-offs for compute, data, identity, messaging, and networking.
- Design tenant context propagation and authorization across every request and asynchronous message.
- Evaluate deployment stamps, tenant-to-stamp placement, scaling, and migration between stamps.
- Address noisy-neighbor controls, tenant-aware observability, metering, cost allocation, and operations.
- Automate the complete tenant lifecycle, including onboarding, configuration, movement, and offboarding.
- Avoid assumptions that all Azure services provide equivalent multitenancy or isolation guarantees.

## Required outputs

- Target architecture with tenancy boundaries.
- Multitenancy decision record covering isolation, tenant context, deployment stamps, and tenant placement.
- Offer strategy (SaaS vs Azure app/VM/container alternatives).
- Marketplace readiness checklist with go-live gates.
- Day-2 operations and SRE control plan.
