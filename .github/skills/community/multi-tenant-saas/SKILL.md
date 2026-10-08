---
name: multi-tenant-saas
description: "Primary orchestration skill for building a multi-tenant Azure SaaS platform, integrating ISV landing zone guidance, SaaS Accelerator patterns, and marketplace publication workflows. USE FOR: starting a new multi-tenant SaaS build, routing work across landing-zone/tenancy/accelerator/marketplace skills. DO NOT USE FOR: single-tenant Azure deployments (use git-ape directly), post-launch operations only (use scale-and-sre)."
license: MIT
metadata:
  author: dawright22
  source: https://github.com/dawright22/azure-saas-skills
  maturity: stable
  version: "1.0.0"
---

# Multi-Tenant SaaS Orchestrator

> Top-level entrypoint for building a multi-tenant Azure SaaS platform end-to-end, from landing zone through marketplace publication.

## When to Use

* "build a multi-tenant SaaS platform on Azure"
* "help me take my product to Azure Marketplace as a SaaS offer"
* Starting a new ISV SaaS engagement and unsure which specialist skill to invoke first
* Need a staged plan spanning landing zone, platform build-out, and marketplace onboarding

## Procedure

### 1. Collect platform requirements

Gather tenant model, scale profile, compliance needs, target regions, and preferred offer
model (SaaS vs Azure Application vs other) from the user.

### 2. Apply authoritative multitenancy guidance

Use [Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview)
as the primary reference. For every architecture:

* Define tenants and the business-to-tenant mapping explicitly.
* Record the isolation model and trade-offs for compute, data, identity, messaging, and networking.
* Design tenant context propagation and authorization across every request and asynchronous message.
* Evaluate deployment stamps, tenant-to-stamp placement, scaling, and migration between stamps.
* Address noisy-neighbor controls, tenant-aware observability, metering, cost allocation, and operations.
* Automate the complete tenant lifecycle, including onboarding, configuration, movement, and offboarding.
* Avoid assuming all Azure services provide equivalent multitenancy or isolation guarantees.

### 3. Produce a staged execution plan

Map requirements to implementation tracks in this order:

1. Foundation and landing zone (`isv-landing-zone-foundation`)
2. Tenancy model selection (`tenant-isolation-models`)
3. SaaS platform build-out (`saas-accelerator-bootstrap`, `tenant-lifecycle-automation`, `deployment-blueprints`)
4. Security and compliance baseline (`security-and-compliance`)
5. Marketplace onboarding and publication (`marketplace-offer-types`, `fulfillment-and-metering`, `marketplace-onboarding`, `onboard-to-marketplace`)
6. Day-2 operations (`scale-and-sre`)

### 4. Route work to specialized skills

Invoke each specialist skill above in sequence, carrying forward decisions (tenancy model,
compliance scope, offer type) made in earlier stages.

## Outputs

* Target architecture with tenancy boundaries.
* Multitenancy decision record covering isolation, tenant context, deployment stamps, and tenant placement.
* Offer strategy (SaaS vs Azure app/VM/container alternatives).
* Marketplace readiness checklist with go-live gates.
* Day-2 operations and SRE control plan.

## Constraints

**Always:**

* Define the tenant model and business-to-tenant mapping before selecting Azure resources.
* Route to the relevant specialist skill rather than re-deriving its guidance inline.

**Never:**

* Assume a shared Azure resource provides tenant isolation by default without verifying per-service guarantees.
* Skip the security/compliance stage to save time — treat it as mandatory before marketplace onboarding.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
