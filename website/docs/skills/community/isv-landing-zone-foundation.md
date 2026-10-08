---
title: "Isv Landing Zone Foundation"
sidebar_label: "Isv Landing Zone Foundation"
description: "Builds the Azure ISV landing zone baseline for identity, networking, governance, security, and environment separation. USE FOR: standing up the first Azure environment for an ISV SaaS product, defining subscription/management-group layout. DO NOT USE FOR: tenancy model selection (use tenant-isolation-models), marketplace publication (use marketplace-onboarding)."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/community/isv-landing-zone-foundation/SKILL.md -->


# Isv Landing Zone Foundation

> Builds the Azure ISV landing zone baseline for identity, networking, governance, security, and environment separation. USE FOR: standing up the first Azure environment for an ISV SaaS product, defining subscription/management-group layout. DO NOT USE FOR: tenancy model selection (use tenant-isolation-models), marketplace publication (use marketplace-onboarding).

:::info[Third-party community skill]
This skill is contributed and maintained by the community, not by the Git-Ape maintainers. See the [Skill Registry](../registry) for provenance details.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/community/isv-landing-zone-foundation/` |
| **Author** | dawright22 |
| **Maturity** | stable |
| **Source** | [https://github.com/dawright22/azure-saas-skills](https://github.com/dawright22/azure-saas-skills) |
| **User Invocable** | ✅ Yes |
| **Usage** | `/isv-landing-zone-foundation` |


## Documentation

# ISV Landing Zone Foundation

> Implements the Azure Cloud Adoption Framework ISV landing zone baseline: identity, networking, governance, security, and environment separation.

## When to Use

* "set up the Azure landing zone for my SaaS product"
* "what subscription/management-group layout should an ISV use"
* Defining the foundation before any workload resources are deployed
* Establishing environment promotion (dev/test/prod) boundaries

## Procedure

### 1. Design management group and subscription layout

Define the platform vs. workload subscription split, following CAF ISV landing zone guidance.

### 2. Design connectivity and isolation

Establish network topology (hub-spoke or Virtual WAN) sized for multi-tenant SaaS, with
explicit isolation boundaries between environments and, where applicable, between tenants.

### 3. Define identity and RBAC

Apply least-privilege RBAC patterns for platform operations, service identities, and
break-glass access.

### 4. Apply governance controls

Define Azure Policy, tagging standards, and baseline monitoring/security services
(Defender for Cloud, diagnostic settings) applied consistently across environments.

### 5. Define environment promotion model

Document how resources and configuration move from dev through test to prod.

## Outputs

* Landing zone decision record.
* Foundation IaC checklist and deployment order.
* Environment promotion model for dev/test/prod.

## Constraints

**Always:**

* Treat the landing zone as the foundation every other skill in this plugin builds on — complete it first.
* Apply least-privilege RBAC and policy-as-code from the start rather than retrofitting later.

**Never:**

* Mix platform-management and workload resources in the same subscription.
* Skip environment separation to save setup time.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
