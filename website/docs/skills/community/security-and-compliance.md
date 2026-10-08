---
title: "Security And Compliance"
sidebar_label: "Security And Compliance"
description: "Defines security architecture and compliance controls for multi-tenant SaaS, including identity, secrets, data protection, and auditability. USE FOR: cross-tenant isolation threat modeling, compliance control mapping, secret/key lifecycle design. DO NOT USE FOR: tenancy model selection itself (use tenant-isolation-models), landing zone governance baseline (use isv-landing-zone-foundation)."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/community/security-and-compliance/SKILL.md -->


# Security And Compliance

> Defines security architecture and compliance controls for multi-tenant SaaS, including identity, secrets, data protection, and auditability. USE FOR: cross-tenant isolation threat modeling, compliance control mapping, secret/key lifecycle design. DO NOT USE FOR: tenancy model selection itself (use tenant-isolation-models), landing zone governance baseline (use isv-landing-zone-foundation).

:::info[Third-party community skill]
This skill is contributed and maintained by the community, not by the Git-Ape maintainers. See the [Skill Registry](../registry) for provenance details.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/community/security-and-compliance/` |
| **Author** | dawright22 |
| **Maturity** | stable |
| **Source** | [https://github.com/dawright22/azure-saas-skills](https://github.com/dawright22/azure-saas-skills) |
| **User Invocable** | ✅ Yes |
| **Usage** | `/security-and-compliance` |


## Documentation

# Security and Compliance

> Builds the security baseline required for marketplace-scale, multi-tenant SaaS operations.

## When to Use

* "design the security and compliance baseline for my multi-tenant SaaS product"
* "how do we prevent cross-tenant data access"
* Mapping compliance frameworks to concrete architecture controls
* Designing secret/certificate lifecycle and encryption/key ownership policy

## Procedure

### 1. Define identity strategy

Define the Microsoft Entra ID tenant strategy and service identity model, and the tenant
identity mapping with trusted tenant-context propagation.

### 2. Define authorization boundaries

Require authorization checks at every tenant-scoped resource and data access boundary.

### 3. Design secret and key management

Define secret/certificate lifecycle management, data encryption, key ownership, and
retention policy.

### 4. Model cross-tenant threats

Apply the security and isolation principles in
[Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview).
Do not trust a tenant identifier supplied by a client without deriving or validating it
against authenticated identity and authorization data. Explicitly test horizontal
privilege escalation and cross-tenant data access in APIs, background jobs, caches, search
indexes, logs, and administrative tooling.

### 5. Map compliance evidence

Build an audit logging strategy and map architecture controls to each required compliance
framework's evidence requirements.

## Outputs

* Security controls matrix by architecture component.
* Tenant-context threat model and cross-tenant isolation test plan.
* Compliance implementation checklist.
* Risk register with remediation priorities.

## Constraints

**Always:**

* Derive or validate tenant identifiers against authenticated identity data — never trust a client-supplied tenant ID directly.
* Explicitly test for horizontal privilege escalation across APIs, background jobs, caches, search indexes, logs, and admin tooling.

**Never:**

* Treat encryption-at-rest platform defaults as sufficient evidence of a compliance control without checking the framework's specific requirement.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
