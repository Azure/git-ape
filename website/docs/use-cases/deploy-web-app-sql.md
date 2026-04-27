---
title: "Deploy Web App + SQL"
sidebar_label: "Deploy Web App + SQL"
sidebar_position: 2
description: "Deploy a full-stack web application with SQL Database, Key Vault, and managed identities"
keywords: [web app, SQL, key vault, full-stack, app service, deployment]
---

# Deploy Web App + SQL Database

> **TL;DR** — Deploy a full-stack web application with Azure SQL, Key Vault for secrets, and managed identities for secure resource communication.

## Architecture

```mermaid
graph TD
    subgraph RG["rg-webapp-dev-eastus"]
        APP["app-portal-dev-eastus<br/>App Service (.NET)"]
        ASP["asp-portal-dev-eastus<br/>App Service Plan (B1)"]
        SQL["sql-portal-dev-eastus<br/>SQL Server"]
        SQLDB["sqldb-portal-dev<br/>SQL Database"]
        KV["kv-portal-dev-eus<br/>Key Vault"]
        AI["appi-portal-dev-eastus<br/>Application Insights"]
    end

    APP --> |"Managed Identity<br/>AAD-only auth"| SQLDB
    SQLDB --> |"Hosted on"| SQL
    APP --> |"@Microsoft.KeyVault(...)"| KV
    APP --> |"Telemetry"| AI
    APP --> |"Hosted on"| ASP
```

## Conversation

```
@git-ape deploy a .NET web app with SQL Database and Key Vault
         for the customer-portal project in dev, eastus
```

## Resource Configuration

| Resource | Key Settings |
|----------|-------------|
| App Service | HTTPS-only, TLS 1.2, managed identity enabled, FTP disabled |
| SQL Server | AAD-only auth (`azureADOnlyAuthentication: true`), no SQL auth |
| SQL Database | Standard S1, geo-backup enabled |
| Key Vault | RBAC authorization, soft-delete enabled, purge protection |
| App Insights | Connected via instrumentation key in Key Vault |

## Security Highlights

- **AAD-only SQL authentication** — no SQL username/password
- **Key Vault references** — app settings use `@Microsoft.KeyVault(SecretUri=...)` syntax
- **Managed identity chain** — App Service → SQL Database, App Service → Key Vault
- **RBAC roles auto-assigned**:
  - App Service → `SQL DB Contributor` on SQL Database
  - App Service → `Key Vault Secrets User` on Key Vault

## Related

- [Security Analysis Walkthrough](/docs/use-cases/security-analysis)
- [Cost Estimation](/docs/use-cases/cost-estimation)
- [For Engineers](/docs/personas/for-engineers)
