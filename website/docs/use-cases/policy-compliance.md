---
title: "Policy Compliance"
sidebar_label: "Policy Compliance"
sidebar_position: 7
description: "Assess ARM templates against Azure Policy before deployment — find gaps, get recommendations"
keywords: [azure policy, compliance, governance, CIS, NIST, policy advisor]
---

# Policy Compliance

> **TL;DR** — The `@azure-policy-advisor` agent checks your ARM template against subscription policies and recommends additional policies. Advisory only — it surfaces findings without blocking.

## How It Works

```mermaid
graph TD
    TEMPLATE["ARM Template"] --> SCAN["Policy Advisor<br/>scans resources"]
    SCAN --> ASSIGNED["Check against<br/>assigned policies"]
    SCAN --> UNASSIGNED["Recommend<br/>unassigned policies"]
    ASSIGNED --> PART1["Part 1: Template<br/>Improvements"]
    UNASSIGNED --> PART2["Part 2: Subscription<br/>Policy Assignments"]
    PART1 --> REPORT["policy-assessment.md"]
    PART2 --> REPORT

    classDef input fill:#dbeafe,stroke:#1f6feb,stroke-width:1px,color:#0b3d91
    classDef scan fill:#ede9fe,stroke:#7c3aed,stroke-width:1px,color:#4c1d95
    classDef policy fill:#fef3c7,stroke:#92400e,stroke-width:1px,color:#78350f
    classDef out fill:#dcfce7,stroke:#15803d,stroke-width:2px,color:#14532d
    class TEMPLATE input
    class SCAN scan
    class ASSIGNED,UNASSIGNED,PART1,PART2 policy
    class REPORT out
```

## Invoke It

```
@azure-policy-advisor assess my template
```

## Report Structure

### Part 1: Template Improvements

Issues found in the ARM template that conflict with assigned policies:

| Resource | Policy | Effect | Status |
|----------|--------|--------|--------|
| Storage Account | Require HTTPS | Deny | ✅ Compliant |
| Function App | Require managed identity | Audit | ⚠️ Not configured |
| SQL Server | Require AAD-only auth | Deny | ✅ Compliant |

### Part 2: Recommended Policy Assignments

Policies from Microsoft Learn best practices that are not yet assigned to your subscription:

| Category | Policy | Effect | Recommendation |
|----------|--------|--------|---------------|
| Storage | Require TLS 1.2 | Deny | Assign to prevent legacy TLS |
| Compute | Require HTTPS-only | Deny | Assign to enforce encryption |
| Monitoring | Require diagnostic settings | AuditIfNotExists | Assign for visibility |

## Compliance Frameworks

Git-Ape supports assessment against:

- **CIS Azure Foundations v3.0**
- **NIST SP 800-53 Rev 5**
- **General Azure best practices** (default)

## Related

- [Skills: Azure Policy Advisor](/docs/skills/azure-policy-advisor)
- [Agents: Azure Policy Advisor](/docs/agents/azure-policy-advisor)
- [Security Analysis](/docs/use-cases/security-analysis)
- [For Platform Engineering](/docs/personas/for-platform-engineering)
