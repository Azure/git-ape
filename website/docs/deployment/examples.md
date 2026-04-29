---
title: "Examples"
sidebar_label: "Examples"
sidebar_position: 3
description: "End-to-end Git-Ape usage examples"
---

# Examples

These walkthroughs show what a typical Git-Ape session looks like from start to finish. Each example follows the four-stage deployment flow: **Requirements → Review → Deploy → Validate**.

## Deploy a Python Function App

The most common starting point. You describe what you want in plain language; Git-Ape handles the rest.

```text
User: @git-ape deploy a Python function app

Agent: I'll help you deploy an Azure Function App through the guided workflow.

Stage 1 — Requirements
  Region: East US
  Runtime: Python 3.11
  Plan: Consumption (serverless)
  Monitoring: Application Insights enabled

Stage 2 — Review
  Function App:      func-api-dev-eastus
  Storage Account:   stfuncapidev8k3m
  App Insights:      appi-api-dev-eastus
  Security:          HTTPS only, managed identity, TLS 1.2
  Estimated cost:    ~$0.40/month (light workload)

Agent: Confirm deployment?
User: yes

Stage 3 — Deploy
  ✓ Resource group created
  ✓ Storage account created
  ✓ App Insights created
  ✓ Function App created

Stage 4 — Validate
  ✓ Endpoint reachable
  ✓ HTTPS enforced
  ✓ Monitoring connected
```

**What happened behind the scenes:** Git-Ape's Requirements Gatherer collected your intent, the Template Generator produced an ARM template, the Security Analyzer ran a blocking security gate, and the Resource Deployer executed the deployment. All artifacts are saved to `.azure/deployments/deploy-YYYYMMDD-HHMMSS/`.

## Deploy a Web App with SQL Database

Multi-resource deployments work the same way. Git-Ape generates a single ARM template with all resources and their dependencies.

```text
User: @git-ape deploy a web app with SQL database

Agent: I will collect the app, plan, database, and connectivity requirements.

Review summary:
  App Service Plan:   asp-webapp-dev-eastus
  Web App:            app-webapp-dev-eastus
  SQL Server:         sql-webapp-dev-eastus
  SQL Database:       sqldb-webapp-dev
  App Insights:       appi-webapp-dev-eastus

Agent: Generated template, security review, and estimated cost.
User: proceed

Result:
  ✓ Resources deployed successfully
  ✓ Web app reachable
  ✓ Database connectivity validated
```

## Run post-deployment tests

After a deployment, you can verify everything is healthy:

```text
User: /azure-integration-tester

Agent: Provide the deployment or resource details.

User: Test func-api-dev-eastus in rg-api-dev-eastus

Agent: Running checks...
  ✓ HTTPS endpoint accessible
  ✓ Response time within threshold
  ✓ Application Insights connected
  ✓ Managed identity present
```

## Typical end-to-end workflow

Here is the recommended sequence for a new deployment:

1. **Configure Azure MCP** and sign in with `az login` — see [Azure Setup](../getting-started/azure-setup).
2. **Ask Git-Ape** to deploy: `@git-ape deploy a ...`.
3. **Review** the generated ARM template, security analysis, and cost estimate.
4. **Confirm** the deployment.
5. **Check artifacts** saved under `.azure/deployments/` — see [State Management](./state).

## Related pages

- [Azure Setup](../getting-started/azure-setup) — Connect Git-Ape to your Azure subscription.
- [Onboarding](../getting-started/onboarding) — Set up CI/CD pipelines.
- [State Management](./state) — How deployment artifacts are stored.
