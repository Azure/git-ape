# Git-Ape Examples

This file keeps the longer usage examples out of the main README.

## Example 1: Deploy a Python Function App

```text
User: @git-ape deploy a Python function app

Agent: I'll help you deploy an Azure Function App through the guided workflow.

Stage 1: Requirements
- Region: East US
- Runtime: Python 3.11
- Plan: Consumption
- Monitoring: Application Insights enabled

Stage 2: Review
- Function App: func-api-dev-eastus
- Storage Account: stfuncapidev8k3m
- App Insights: appi-api-dev-eastus
- Security: HTTPS only, managed identity, TLS 1.2
- Cost estimate: about $0.40/month for a light workload

Agent: Confirm deployment.
User: yes

Stage 3: Deploy
- Resource group created
- Storage account created
- App Insights created
- Function App created

Stage 4: Validate
- Endpoint reachable
- HTTPS enforced
- Monitoring connected
```

## Example 2: Deploy a Web App with SQL Database

```text
User: @git-ape deploy a web app with SQL database

Agent: I will collect the app, plan, database, and connectivity requirements.

Review summary:
- App Service Plan: asp-webapp-dev-eastus
- Web App: app-webapp-dev-eastus
- SQL Server: sql-webapp-dev-eastus
- SQL Database: sqldb-webapp-dev
- Application Insights: appi-webapp-dev-eastus

Agent: Generated template, security review, and estimated cost.
User: proceed

Result:
- Resources deployed successfully
- Web app reachable
- Database connectivity validated
```

## Example 3: Run the Integration Tester

```text
User: /azure-integration-tester

Agent: Provide the deployment or resource details.

User: Test func-api-dev-eastus in rg-api-dev-eastus

Agent: Running checks...
- HTTPS endpoint accessible
- Response time within threshold
- Application Insights connected
- Managed identity present
```

## Example 4: Typical Workflow

```text
1. Configure Azure MCP and sign in with Azure CLI.
2. Ask @git-ape to deploy a resource or stack.
3. Review the generated template, security output, and cost estimate.
4. Confirm deployment.
5. Review the saved artifacts under .azure/deployments/.
```

## Related Docs

- [AZURE_MCP_SETUP.md](AZURE_MCP_SETUP.md)
- [ONBOARDING.md](ONBOARDING.md)
- [DEPLOYMENT_STATE.md](DEPLOYMENT_STATE.md)
- [DRIFT_DETECTION.md](DRIFT_DETECTION.md)