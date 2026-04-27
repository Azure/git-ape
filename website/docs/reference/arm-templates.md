---
title: "ARM Template Conventions"
sidebar_label: "ARM Templates"
sidebar_position: 3
description: "ARM template standards and conventions used by Git-Ape"
---

# ARM Template Conventions

Git-Ape follows these conventions when generating and validating ARM templates.

## Naming Conventions

All resources follow the Cloud Adoption Framework (CAF) naming pattern:

```
{resource-type-abbreviation}-{project}-{environment}-{region}[-{instance}]
```

| Resource | CAF Prefix | Example |
|----------|-----------|---------|
| Resource Group | `rg` | `rg-webapp-prod-eastus` |
| Function App | `func` | `func-api-dev-westus2` |
| Storage Account | `st` | `stwebappdev8k3m` |
| App Service Plan | `asp` | `asp-webapp-prod-eastus` |
| Web App | `app` | `app-webapp-prod-eastus` |
| SQL Server | `sql` | `sql-webapp-prod-eastus` |
| Cosmos DB | `cosmos` | `cosmos-webapp-prod-eastus` |
| Key Vault | `kv` | `kv-webapp-prod-eus` |
| Container App | `ca` | `ca-api-prod-eastus` |

Use `/azure-naming-research` to look up constraints for any resource type.

## Template Structure

Every generated template includes:

- **Parameters section** for configurable values
- **Outputs section** returning resource IDs and endpoints
- **Standard tags** on all resources:

```json
{
  "Environment": "dev|staging|prod",
  "Project": "project-name",
  "ManagedBy": "git-ape-agent",
  "CreatedDate": "YYYY-MM-DD"
}
```

## Security Baseline

- HTTPS-only for all web-facing resources
- Managed identities (never connection strings or shared keys)
- `allowSharedKeyAccess: false` on storage accounts
- RBAC role assignments in templates
- AAD-only auth for SQL databases
- FTP disabled on App Services / Function Apps
- Minimum TLS 1.2 on all resources
- Key Vault references for secrets

## Default Regions

| Priority | Region |
|----------|--------|
| Primary | East US |
| Secondary | West US 2 |
| Europe | West Europe |

## API Version Lookup

Always use `/azure-rest-api-reference` to look up the correct API version before writing or modifying ARM template resources.
