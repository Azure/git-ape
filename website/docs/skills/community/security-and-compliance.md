---
title: "Security And Compliance"
sidebar_label: "Security And Compliance"
description: "Defines security architecture and compliance controls for multi-tenant SaaS, including identity, secrets, data protection, and auditability."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/community-skills/security-and-compliance/SKILL.md -->


# Security And Compliance

> Defines security architecture and compliance controls for multi-tenant SaaS, including identity, secrets, data protection, and auditability.

:::info[Third-party community skill]
This skill is reviewed through Azure/git-ape PRs and maintained by its listed author. It is not bundled or activated with core. See the [Skill Registry](../registry) and use `/git-ape-skills install security-and-compliance` for explicit project or personal installation. Review is not a guarantee of safety.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/community-skills/security-and-compliance/` |
| **Author** | dawright22 |
| **Maturity** | experimental |
| **Available with Core** | ❌ No — explicit installation required |
| **Usage** | `/security-and-compliance Compliance frameworks, data residency requirements, tenant trust model, and encryption policy` |


## Documentation

# Security and Compliance

Builds the security baseline required for marketplace-scale SaaS operations.

## Coverage

- Entra ID tenant strategy and service identity model.
- Tenant identity mapping and trusted tenant-context propagation.
- Authorization at every tenant-scoped resource and data access boundary.
- Secret/certificate lifecycle management.
- Data encryption, key ownership, and retention policy.
- Cross-tenant access prevention and automated isolation testing.
- Audit logging and compliance evidence mapping.

Apply the security and isolation principles in [Architect multitenant solutions on Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/overview).
Do not trust a tenant identifier supplied by a client without deriving or validating it
against authenticated identity and authorization data. Explicitly test horizontal
privilege escalation and cross-tenant data access in APIs, background jobs, caches,
search indexes, logs, and administrative tooling.

## Deliverables

- Security controls matrix by architecture component.
- Tenant-context threat model and cross-tenant isolation test plan.
- Compliance implementation checklist.
- Risk register with remediation priorities.
