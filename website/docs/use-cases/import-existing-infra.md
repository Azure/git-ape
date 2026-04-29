---
title: "Import Existing Infrastructure"
sidebar_label: "Import Existing Infra"
sidebar_position: 9
description: "Reverse-engineer deployed Azure resources into ARM templates for Git-Ape management"
keywords: [import, export, existing resources, reverse engineer, IaC, migration]
---

# Import Existing Infrastructure

> **TL;DR** — Use `@azure-iac-exporter` to reverse-engineer live Azure resources into ARM templates. Bring existing infrastructure under Git-Ape management.

## Workflow

```mermaid
graph TD
    LIVE["Live Azure Resources"] --> EXPORT["@azure-iac-exporter<br/>export rg-legacy-prod"]
    EXPORT --> ANALYZE["Analyze 12 resources<br/>via Resource Graph"]
    ANALYZE --> TEMPLATE["ARM Template<br/>generated"]
    TEMPLATE --> REVIEW["You review<br/>& adjust"]
    REVIEW --> COMMIT["Commit to<br/>.azure/deployments/"]
    COMMIT --> MANAGED["Now managed<br/>by Git-Ape"]

    classDef azure fill:#dcfce7,stroke:#15803d,stroke-width:1px,color:#14532d
    classDef agent fill:#ede9fe,stroke:#7c3aed,stroke-width:1px,color:#4c1d95
    classDef artifact fill:#fef3c7,stroke:#92400e,stroke-width:1px,color:#78350f
    classDef user fill:#e0e7ff,stroke:#4338ca,stroke-width:1px,color:#1e1b4b
    classDef done fill:#dbeafe,stroke:#1f6feb,stroke-width:2px,color:#0b3d91
    class LIVE azure
    class EXPORT,ANALYZE agent
    class TEMPLATE,COMMIT artifact
    class REVIEW user
    class MANAGED done
```

## Invoke It

```
@azure-iac-exporter export rg-legacy-app-prod
```

## What Happens

1. **Resource discovery** — queries Azure Resource Graph for all resources in the resource group
2. **Template generation** — creates an ARM template with parameters for each resource
3. **State capture** — generates `state.json` with current deployment state
4. **Security assessment** — runs the security analyzer on the exported template
5. **Gap identification** — flags resources missing best practices (e.g., no managed identity)

## Output Structure

```
.azure/deployments/legacy-app-prod/
├── template.json         # Generated ARM template
├── parameters.json       # Extracted parameter values
├── metadata.json         # Deployment metadata
├── state.json           # Current state snapshot
└── architecture.md      # Auto-generated diagram
```

## Common Scenarios

| Scenario | Command |
|----------|---------|
| Import a resource group | `@azure-iac-exporter export rg-myapp-prod` |
| Import specific resources | `@azure-iac-exporter export rg-myapp-prod --filter "Microsoft.Web/*"` |
| Generate only Bicep | `@azure-iac-generator` (after export) |

## After Import

Once imported, the resources are managed like any other Git-Ape deployment:

- **Drift detection** catches future manual changes
- **Security analysis** identifies gaps to remediate
- **CI/CD workflows** handle future updates via PR → Plan → Deploy

## Related

- [Agents: Azure IaC Exporter](/docs/agents/azure-iac-exporter)
- [Drift Detection](/docs/use-cases/drift-detection)
- [CI/CD Pipeline](/docs/use-cases/cicd-pipeline)
