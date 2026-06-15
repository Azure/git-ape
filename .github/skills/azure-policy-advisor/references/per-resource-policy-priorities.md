---
source: https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies
snapshot: 2026-06-04
refresh_command: "echo 'Manual: cross-check each list against the built-in-policies page; update if categories change. The severity assignments (🔴🟠🟡🔵) are skill-author judgement, not a Microsoft taxonomy.'"
---

# Per-resource-type policy priorities

Concrete, ranked recommendations for the most common Azure resource types. Used by `azure-policy-advisor` Step 5 (Classify and Prioritize Recommendations).

**Severity legend** (from `SKILL.md`, kept here for self-containment):

| Tier | Effect (Audit mode) | Effect (Deny mode) | Meaning |
|------|--------------------|--------------------|---------|
| 🔴 **Critical** | Audit | Deny | Prevents insecure deployments — never ship without it |
| 🟠 **High** | Audit | Deny | Strong security posture — required for production |
| 🟡 **Medium** | Audit | Audit | Visibility and tracking |
| 🔵 **Low** | AuditIfNotExists | DeployIfNotExists | Auto-remediation / observability |

## Storage Accounts

1. 🔴 Require secure transfer (HTTPS)
2. 🔴 Disable public blob access
3. 🟠 Disable shared key access
4. 🟠 Require minimum TLS 1.2
5. 🟡 Require private endpoints (production)
6. 🟡 Enable soft delete for blobs and containers
7. 🔵 Deploy diagnostic settings

## App Service / Function Apps

1. 🔴 Require HTTPS only
2. 🔴 Require managed identity
3. 🟠 Require minimum TLS 1.2
4. 🟠 Disable FTP / require FTPS only
5. 🟡 Disable public network access (production)
6. 🔵 Enable resource logs

## SQL Servers / Databases

1. 🔴 Require AAD-only authentication
2. 🔴 Enable transparent data encryption
3. 🟠 Enable auditing
4. 🟠 Enable Advanced Threat Protection
5. 🟡 Require private endpoints (production)
6. 🔵 Deploy diagnostic settings

## Key Vault

1. 🔴 Enable RBAC authorization
2. 🔴 Enable soft delete and purge protection
3. 🟠 Disable public network access (production)
4. 🟡 Require private endpoints
5. 🔵 Deploy diagnostic settings for audit events

## Compute / VMs

1. 🔴 Require managed disks
2. 🟠 Require managed identity
3. 🟡 Restrict allowed VM SKUs
4. 🟡 Require approved extensions only
5. 🔵 Deploy monitoring agent

## AKS / Kubernetes

1. 🔴 Require managed identity
2. 🔴 Disable local accounts
3. 🟠 Require Azure Policy add-on
4. 🟠 Require network policy
5. 🟡 Require authorized IP ranges for API server
6. 🔵 Enable Container Insights

## Networking

1. 🟠 Require NSG flow logs
2. 🟡 Enable Network Watcher
3. 🟡 Restrict allowed locations
4. 🔵 Deploy DDoS protection (production)

## General / Cross-cutting

1. 🟡 Require tags on resources (ManagedBy, Environment, Project)
2. 🟡 Restrict allowed locations
3. 🔵 Require resource group tags inheritance

## When a resource type is not listed

Fall back to `microsoft_docs_search` with the query template `Azure Policy built-in {resource-type-category}` (see Step 4 of `SKILL.md`). The pattern: identify the top 2-3 security-critical controls (🔴), 1-2 hardening controls (🟠), 1-2 visibility controls (🟡), and 1 observability control (🔵). Cross-check definition IDs live before emitting recommendations.
