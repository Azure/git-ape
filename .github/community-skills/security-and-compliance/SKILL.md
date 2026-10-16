---
name: security-and-compliance
description: "Defines security architecture and compliance controls for multi-tenant SaaS, including identity, secrets, data protection, and auditability."
argument-hint: "Compliance frameworks, data residency requirements, tenant trust model, and encryption policy"
user-invocable: true
last_updated: "2026-08-17"
---

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
