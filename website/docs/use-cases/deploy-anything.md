---
title: "Deploy anything"
sidebar_label: "Deploy anything"
sidebar_position: 1
description: "Git-Ape deploys any Azure workload from natural-language intent — or from a reference architecture you provide"
keywords: [deploy, web app, sql, container apps, reference architecture, intent, ARM]
---

# Deploy anything

> **TL;DR** — Tell `@git-ape` what you want, in plain language. Or hand it a reference architecture link, diagram, or screenshot. Either way, it generates a CAF-compliant ARM template with security, cost, and policy enforced before deployment.

Git-Ape is **workload-agnostic**. If Azure Resource Manager can deploy it, the agent can generate it — using the live Azure REST API specs at generation time, not last year's module catalogue.

## Three ways to describe what you want

```mermaid
flowchart LR
    A["Natural-language intent<br/><i>'Deploy a .NET web app with SQL'</i>"] --> AGENT
    B["Reference architecture URL<br/><i>learn.microsoft.com/architecture/...</i>"] --> AGENT
    C["Diagram or screenshot<br/><i>your hand-drawn whiteboard</i>"] --> AGENT
    AGENT["<b>@git-ape</b><br/>reasons over live Azure API specs<br/>+ your security & naming policy"] --> OUT["ARM template<br/>+ security gate<br/>+ cost estimate<br/>+ deployment trace"]

    classDef input fill:#dbeafe,stroke:#1f6feb,color:#0b3d91
    classDef agent fill:#dcfce7,stroke:#15803d,stroke-width:2px,color:#14532d
    classDef out fill:#fde68a,stroke:#b45309,color:#7c2d12
    class A,B,C input
    class AGENT agent
    class OUT out
```

| Input | Example prompt |
|---|---|
| **Plain intent** | `@git-ape deploy a .NET web app with SQL Database for the customer portal in dev` |
| **Reference architecture** | `@git-ape implement this reference architecture: https://learn.microsoft.com/azure/architecture/reference-architectures/...` |
| **Diagram or picture** | Attach a PNG or markdown with mermaid, then: `@git-ape deploy what's in this diagram for the payments-api project` |

The agent reads the input, asks clarifying questions only when needed (region, environment, project name), and produces a full deployment plan you can review before approval.

---

## Example 1 — Web app with SQL Database

A common full-stack pattern: App Service with managed identity to SQL Database, secrets in Key Vault.

```mermaid
graph TD
    subgraph RG["rg-portal-dev-eastus"]
        APP["app-portal-dev-eastus<br/>App Service (.NET)"]
        ASP["asp-portal-dev-eastus<br/>App Service Plan (B1)"]
        SQL["sql-portal-dev-eastus<br/>SQL Server"]
        SQLDB["sqldb-portal-dev<br/>SQL Database"]
        KV["kv-portal-dev-eus<br/>Key Vault"]
        AI["appi-portal-dev-eastus<br/>App Insights"]
    end

    APP --> |"Managed identity<br/>AAD-only auth"| SQLDB
    SQLDB --> |"Hosted on"| SQL
    APP --> |"@Microsoft.KeyVault(...)"| KV
    APP --> |"Telemetry"| AI
    APP --> |"Hosted on"| ASP

    classDef compute fill:#dbeafe,stroke:#1f6feb,color:#0b3d91
    classDef data fill:#dcfce7,stroke:#15803d,color:#14532d
    classDef secret fill:#fde68a,stroke:#b45309,color:#7c2d12
    classDef obs fill:#ede9fe,stroke:#7c3aed,color:#4c1d95
    class APP,ASP compute
    class SQL,SQLDB data
    class KV secret
    class AI obs
```

**Prompt:**

```text
@git-ape deploy a .NET web app with SQL Database and Key Vault
         for the customer-portal project in dev, eastus
```

**What you get:**

| Resource | Key settings enforced automatically |
|---|---|
| App Service | HTTPS-only, TLS 1.2, managed identity, FTP disabled |
| SQL Server | `azureADOnlyAuthentication: true` — no SQL username/password |
| SQL Database | Standard S1, geo-backup enabled |
| Key Vault | RBAC authorization, soft-delete + purge protection |
| RBAC | App Service → `SQL DB Contributor`, App Service → `Key Vault Secrets User` |

---

## Example 2 — Container Apps

A containerised microservice with auto-scaling, private registry, and centralised logging.

```mermaid
graph TD
    subgraph RG["rg-payments-dev-eastus"]
        CA["ca-payments-dev-eastus<br/>Container App"]
        CAE["cae-payments-dev-eastus<br/>Container Apps Environment"]
        ACR["crpaymentsdev<br/>Container Registry"]
        LOG["log-payments-dev-eastus<br/>Log Analytics"]
    end

    CA --> |"Pull images<br/>(AcrPull role)"| ACR
    CA --> |"Hosted in"| CAE
    CAE --> |"App logs"| LOG

    classDef compute fill:#dbeafe,stroke:#1f6feb,color:#0b3d91
    classDef registry fill:#fde68a,stroke:#b45309,color:#7c2d12
    classDef obs fill:#ede9fe,stroke:#7c3aed,color:#4c1d95
    class CA,CAE compute
    class ACR registry
    class LOG obs
```

**Prompt:**

```text
@git-ape deploy a Container App with Registry and Log Analytics
         for the payments-api project in dev, eastus
```

**What you get:**

| Resource | Key settings enforced automatically |
|---|---|
| Container App | Min replicas: 0, max: 10, scale on HTTP concurrency |
| Container Apps Environment | Connected to Log Analytics workspace |
| Container Registry | Admin user disabled, managed identity pull only |
| RBAC | Container App → `AcrPull` on registry |
| Log Analytics | 30-day retention |

---

## Use a reference architecture as the source of truth

The Git-Ape [Vision](/docs/vision) describes a future state where governed documents — reference architectures, ADRs, security baselines — become the **ledger** that drives deployments. The agent's job is to compile those documents into compliant infrastructure.

You can do this today:

1. **Point the agent at a published Azure reference architecture URL.** The agent fetches it, identifies the resources, and produces an ARM template that matches.
2. **Attach a diagram or screenshot of an internal architecture pattern.** The agent reads the boxes and arrows and proposes a deployment.
3. **Reference an Architecture Decision Record (ADR) in your repo.** The agent treats the ADR as authoritative and validates the generated template against it.

```text
@git-ape deploy this reference architecture for the order-api project, dev:
https://learn.microsoft.com/azure/architecture/reference-architectures/...
```

Whatever you use as input, the agent produces the same artifacts: a CAF-compliant ARM template, a security analysis, a cost estimate, and a deployment trace under [`.azure/deployments/`](/docs/deployment/state) — your auditable evidence of intent → plan → outcome.

---

## What happens after you approve

```mermaid
flowchart LR
    REQ["Requirements<br/>gathered"] --> GEN["Template<br/>generated"]
    GEN --> SEC["Security gate<br/>(blocking)"]
    SEC --> COST["Cost estimate<br/>shown"]
    COST --> APPROVE{"You approve?"}
    APPROVE -->|"yes"| DEPLOY["az deployment<br/>sub create"]
    APPROVE -->|"no"| EXIT["Iterate or stop"]
    DEPLOY --> TEST["Integration<br/>tests"]
    TEST --> STATE["state.json<br/>committed"]

    classDef gate fill:#fde68a,stroke:#b45309,color:#7c2d12
    classDef deploy fill:#dcfce7,stroke:#15803d,color:#14532d
    class SEC,APPROVE gate
    class DEPLOY,TEST,STATE deploy
```

See the full lifecycle in [State Management](/docs/deployment/state) and [CI/CD Pipeline](/docs/use-cases/cicd-pipeline).

---

## Related

- [Vision & Manifesto](/docs/vision) — why agents over modules
- [Security Analysis](/docs/use-cases/security-analysis) — what the security gate checks
- [Cost Estimation](/docs/use-cases/cost-estimation) — how pricing is computed
- [Skills overview](/docs/skills/overview) — every capability the agent invokes
