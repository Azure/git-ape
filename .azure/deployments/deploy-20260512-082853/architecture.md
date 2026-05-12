# Architecture: Python Function App (`deploy-20260512-082853`)

## Resource Topology

```mermaid
graph TD
    subgraph "Subscription-Level Deployment"
        RG["📦 rg-pyapi-dev-eastus<br/>Resource Group"]
    end

    subgraph RG_CONTENTS ["rg-pyapi-dev-eastus"]
        LOG["📊 log-pyapi-dev-eastus<br/>Log Analytics Workspace<br/>PerGB2018 / 30d retention"]
        APPI["🔍 appi-pyapi-dev-eastus<br/>Application Insights<br/>Web / Workspace-based"]
        ST["💾 stpyapidev{unique}<br/>Storage Account<br/>StorageV2 / Standard_LRS<br/>No shared key access"]
        ASP["⚙️ asp-pyapi-dev-eastus<br/>App Service Plan<br/>Linux / Y1 Consumption"]
        FUNC["⚡ func-pyapi-dev-eastus<br/>Function App<br/>Python 3.11 / Functions v4<br/>System Managed Identity"]
    end

    RG --> LOG
    RG --> ST
    LOG --> APPI
    APPI --> FUNC
    ST --> FUNC
    ASP --> FUNC

    FUNC -->|"🔑 Storage Blob Data Owner"| ST
    FUNC -->|"🔑 Storage Account Contributor"| ST
    FUNC -->|"📡 Connection String"| APPI

    style RG fill:#e1f5fe
    style FUNC fill:#fff3e0
    style ST fill:#e8f5e9
    style APPI fill:#fce4ec
    style LOG fill:#f3e5f5
    style ASP fill:#fff8e1
```

## Resource Inventory

| # | Resource | Type | SKU | Region |
|---|----------|------|-----|--------|
| 1 | `rg-pyapi-dev-eastus` | Resource Group | — | East US |
| 2 | `log-pyapi-dev-eastus` | Log Analytics Workspace | PerGB2018 | East US |
| 3 | `appi-pyapi-dev-eastus` | Application Insights | Workspace-based | East US |
| 4 | `stpyapidev{unique}` | Storage Account | Standard_LRS | East US |
| 5 | `asp-pyapi-dev-eastus` | App Service Plan | Y1 (Consumption) | East US |
| 6 | `func-pyapi-dev-eastus` | Function App | Python 3.11 / v4 | East US |

## Data Flow

1. **HTTP requests** → Function App (HTTPS-only, TLS 1.2+)
2. **Function App** → Storage Account (identity-based, RBAC — no connection strings)
3. **Function App** → App Insights (telemetry via connection string)
4. **App Insights** → Log Analytics (workspace-linked)
