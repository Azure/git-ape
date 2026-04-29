---
title: "Skills Overview"
sidebar_label: "Overview"
sidebar_position: 1
description: "Overview of all Git-Ape skills organized by deployment phase"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/ -->


# Skills Overview

Skills are focused capabilities invoked by agents at specific stages of the deployment workflow. Each skill handles one task.

## Pre-Deploy Skills

| Skill | Description | Invocable |
|-------|-------------|:---------:|
| [Azure Cost Estimator](./azure-cost-estimator) | Estimate monthly costs for Azure resources by querying the Azure Retail Prices API. Parses ARM templates to identify resources, SKUs, and regions, then looks up real retail pricing. Produces a per-resource cost breakdown with monthly totals. Use during template generation or when user asks about costs. | ✅ |
| [Azure Deployment Preflight](./azure-deployment-preflight) | Run preflight validation on ARM templates before deployment. Performs what-if analysis, permission checks, and generates a structured report with resource changes (create/modify/delete). Use before any deployment to preview changes and catch issues early. | ✅ |
| [Azure Naming Research](./azure-naming-research) | Research Azure naming constraints and CAF abbreviations for a given resource type. Use when you need to look up the official CAF slug, naming rules (length, scope, valid characters), and derive validation/cleaning regex patterns for an Azure resource. Triggers on: CAF abbreviation lookup, Azure naming rules research, resource naming constraints. | ✅ |
| [Azure Policy Advisor](./azure-policy-advisor) | Assess Azure Policy compliance for ARM template resources. Queries existing subscription assignments and unassigned custom/built-in definitions, cross-references with Microsoft Learn recommendations. Produces per-resource policy recommendations with implementation options. | ✅ |
| [Azure Resource Availability](./azure-resource-availability) | Query live Azure APIs to validate resource availability before template generation or deployment. Checks VM SKU restrictions, Kubernetes/runtime version support, API version compatibility, and subscription quota. Use during requirements gathering and preflight to catch deployment failures early. | ✅ |
| [Azure Role Selector](./azure-role-selector) | Recommend least-privilege Azure RBAC roles for deployed resources. Finds minimal built-in roles matching desired permissions or creates custom role definitions. Use during security analysis or when configuring access for service principals and managed identities. | ✅ |
| [Azure Security Analyzer](./azure-security-analyzer) | Analyze Azure resource configurations against security best practices using Azure MCP bestpractices service. Produces per-resource security assessment with severity ratings and recommendations. Use during template generation before deployment confirmation. | ✅ |
| [Prereq Check](./prereq-check) | Check that all required CLI tools are installed, meet minimum versions, and have active auth sessions. Shows platform-specific install commands for anything missing. | ✅ |

## Post-Deploy Skills

| Skill | Description | Invocable |
|-------|-------------|:---------:|
| [Azure Integration Tester](./azure-integration-tester) | Run post-deployment integration tests for Azure resources. Verify Function Apps, Storage Accounts, Databases, App Services are healthy and accessible. Use after successful Azure deployment. | ✅ |
| [Azure Resource Visualizer](./azure-resource-visualizer) | Analyze deployed Azure resource groups and generate detailed Mermaid architecture diagrams showing relationships between resources. Use for post-deployment visualization, understanding existing infrastructure, or documenting live Azure environments. | ✅ |

## Operations Skills

| Skill | Description | Invocable |
|-------|-------------|:---------:|
| [Azure Drift Detector](./azure-drift-detector) | Detect configuration drift between deployed Azure resources and stored deployment state. Compare actual Azure configuration against desired state in .azure/deployments/, identify differences, and guide user through reconciliation options. Use when checking for manual changes, policy remediations, or unauthorized modifications. | ✅ |
| [Azure Rest Api Reference](./azure-rest-api-reference) | Look up Azure REST API and ARM template reference documentation for any resource type. Returns exact property schemas, required fields, valid values, and latest stable API versions. Use BEFORE generating or modifying ARM templates to ensure correctness. No Azure connection required. | ✅ |
| [Git Ape Onboarding](./git-ape-onboarding) | Onboard a repository, Azure subscription(s), and user identity for Git-Ape CI/CD using a skill-driven CLI playbook. Use for first-time setup of OIDC, federated credentials, RBAC, GitHub environments, and required secrets. | ✅ |

## Skill Invocation in Deployment Flow

```mermaid
graph LR
    subgraph Pre["Pre-Deploy"]
        S1["/azure-cost-estimator\n/azure-deployment-preflight\n/azure-naming-research\n/azure-policy-advisor\n/azure-resource-availability\n/azure-role-selector\n/azure-security-analyzer\n/prereq-check"]
    end
    subgraph Post["Post-Deploy"]
        S2["/azure-integration-tester\n/azure-resource-visualizer"]
    end
    subgraph Ops["Operations"]
        S3["/azure-drift-detector\n/azure-rest-api-reference\n/git-ape-onboarding"]
    end
    Pre --> Post --> Ops

    classDef pre fill:#dbeafe,stroke:#1f6feb,stroke-width:1px,color:#0b3d91
    classDef post fill:#dcfce7,stroke:#15803d,stroke-width:1px,color:#14532d
    classDef ops fill:#ede9fe,stroke:#7c3aed,stroke-width:1px,color:#4c1d95
    class S1 pre
    class S2 post
    class S3 ops
```
