---
title: "Azure MCP Setup"
sidebar_label: "Azure Setup"
sidebar_position: 2
description: "Configure Azure MCP server for VS Code"
---

# Azure MCP Server Configuration

:::warning
EXPERIMENTAL ONLY: This setup is for development and sandbox testing.
Do **not** use this repository or its generated workflows for production Azure operations.
Review permissions and commands carefully before running them.
:::
This document explains how to configure the Azure MCP server to enable Azure deployment capabilities for the Git-Ape agent system.

## Prerequisites

1. **VS Code Insiders** (or VS Code with GitHub Copilot extension)
2. **GitHub Copilot subscription** (with access to Copilot Chat)
3. **Azure CLI** installed and configured
4. **Azure MCP Server extension** (should be installed automatically with Azure extensions)

## Extension Installation

The Azure MCP server is provided by the `ms-azuretools.vscode-azure-mcp-server` extension. It should be automatically available if you have Azure Tools for VS Code installed.

Verify installation:
```bash
code --list-extensions | grep azure-mcp
```

You should see: `ms-azuretools.vscode-azure-mcp-server`

## Configuration

### 1. VS Code Settings

Add the following to your VS Code settings (`.vscode/settings.json` or User Settings):

```json
{
  "azureMcp.serverMode": "namespace",
  "azureMcp.enabledServices": [
    "deploy",
    "bestpractices",
    "group",
    "subscription",
    "resourcehealth",
    "monitor",
    "functionapp",
    "storage",
    "sql",
    "cosmos",
    "bicepschema",
    "cloudarchitect"
  ],
  "azureMcp.readOnly": false
}
```

**Configuration Options:**

- **`serverMode`**: Controls how MCP tools are exposed
  - `"single"`: One tool that routes to 100+ internal commands
  - `"namespace"`: ~30 logical groups by service (recommended)
  - `"all"`: Every MCP tool exposed directly (100+ tools)

- **`enabledServices`**: Array of service namespaces to expose
  - Only specified services will be available to agents
  - Reduces tool clutter and improves agent focus

- **`readOnly`**: When `true`, prevents destructive operations
  - Set to `false` to allow deployments
  - Set to `true` for testing/validation only

### 2. Azure Authentication

Authenticate with Azure CLI:

```bash
# Login to Azure
az login

# Set default subscription (optional but recommended)
az account set --subscription "Your Subscription Name or ID"

# Verify authentication
az account show
```

The Azure MCP server uses your Azure CLI credentials automatically.

### 3. Environment Variables (Optional)

Create a `.env` file in your workspace root for default values:

```bash
# Azure Subscription
AZURE_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Default Region
AZURE_DEFAULT_REGION=eastus

# Default Resource Group (optional)
AZURE_DEFAULT_RESOURCE_GROUP=rg-git-ape-dev-eastus
```

## Available Azure MCP Services

The following services are used by the Git-Ape agents:

### Core Deployment Services

- **`deploy`** - ARM template deployment, what-if analysis, validation
- **`bestpractices`** - Security and configuration recommendations
- **`cloudarchitect`** - Architecture diagram generation

### Resource Management

- **`group`** - Resource group operations
- **`subscription`** - Subscription queries and management
- **`resourcehealth`** - Resource status and health monitoring
- **`monitor`** - Logging, metrics, and monitoring

### Compute Services

- **`functionapp`** - Azure Functions management
- **`aks`** - Azure Kubernetes Service (optional)
- **`acr`** - Azure Container Registry (optional)

### Data Services

- **`storage`** - Blob, Table, Queue, File storage
- **`sql`** - Azure SQL Database
- **`cosmos`** - Cosmos DB
- **`mysql`**, **`postgres`** - Database services (optional)

### Infrastructure

- **`bicepschema`** - Bicep/ARM template schemas
- **`keyvault`** - Secrets, keys, certificates

## Verification

After configuration, verify the MCP server is working:

1. Open VS Code
2. Open GitHub Copilot Chat
3. Type: `@git-ape`
4. You should see "Git-Ape" in the agent picker

To test Azure MCP tools are accessible:

```
In Copilot Chat:
"List available Azure subscriptions"

Expected: The agent should use Azure MCP tools to query subscriptions
```

## Troubleshooting

### Issue: "Unknown tool 'mcp_azure_mcp/*'"

**Cause:** Azure MCP server not loaded or not configured

**Solution:**
1. Verify extension is installed: `code --list-extensions | grep azure-mcp`
2. Reload VS Code window: `Cmd/Ctrl + Shift + P` → "Reload Window"
3. Check settings have `azureMcp.serverMode` configured

### Issue: Azure authentication fails

**Cause:** Azure CLI not authenticated or token expired

**Solution:**
```bash
# Re-authenticate
az login

# Verify
az account show

# If multiple subscriptions, set default
az account set --subscription "Your Subscription"
```

### Issue: "Permission denied" on deployments

**Cause:** Azure account lacks Contributor role on subscription/resource group

**Solution:**
1. Verify your role: `az role assignment list --assignee $(az account show --query user.name -o tsv)`
2. You need at least "Contributor" role for deployments
3. Contact your Azure administrator to grant appropriate permissions

### Issue: MCP tools are slow or unresponsive

**Cause:** Too many services enabled or network latency

**Solution:**
1. Reduce `enabledServices` to only what you need
2. Use `"namespace"` mode instead of `"all"`
3. Check Azure service health: https://status.azure.com

### Issue: Agent doesn't see Azure services

**Cause:** Services not in `enabledServices` list

**Solution:**
Add required services to `azureMcp.enabledServices` array in settings.json

## Security Considerations

### Credential Storage

- **Never commit** Azure credentials to version control
- Use `.env` for local development (add to `.gitignore`)
- In production/CI, use managed identities or Azure DevOps service connections

### Least Privilege

The agents require these minimum Azure permissions:

- **Requirements Gatherer**: `Reader` role
- **Template Generator**: `Reader` role
- **Resource Deployer**: `Contributor` role on target resource groups

Consider creating a custom role:

```json
{
  "Name": "Git-Ape Deployer",
  "Description": "Deploy Azure resources via Git-Ape agent",
  "Actions": [
    "Microsoft.Resources/deployments/*",
    "Microsoft.Resources/subscriptions/resourceGroups/*",
    "Microsoft.Web/sites/*",
    "Microsoft.Storage/storageAccounts/*",
    "Microsoft.Insights/components/*"
  ],
  "AssignableScopes": [
    "/subscriptions/{subscription-id}"
  ]
}
```

### Production Deployments

For production deployments:

1. Set `azureMcp.readOnly: false` only when deploying
2. Use approval gates (the agent requires user confirmation)
3. Enable Azure Policy to restrict resource types/regions
4. Use separate subscriptions for dev/staging/prod
5. Review ARM templates before confirming deployment

## Advanced Configuration

### Custom MCP Server Mode

If you want more control over which specific tools are available:

```json
{
  "azureMcp.serverMode": "all",
  "azureMcp.toolFilter": [
    "deploy_group_create",
    "deploy_group_what_if",
    "storage_account_create",
    "functionapp_create"
  ]
}
```

This exposes only specific tool commands instead of entire service namespaces.

### Multiple Azure Accounts

If you work with multiple Azure tenants/subscriptions:

```bash
# Login to different tenant
az login --tenant "tenant-id"

# Switch between subscriptions
az account set --subscription "subscription-1"
# Deploy resources...

az account set --subscription "subscription-2"
# Deploy to different subscription...
```

The agent will use whichever subscription is currently active in Azure CLI.

## Next Steps

After configuration:

1. Test the agent with a simple deployment: `@git-ape deploy a resource group`
2. Review the [project README](https://github.com/Azure/git-ape/blob/main/README.md) for example workflows
3. Customize workspace instructions in [`.github/copilot-instructions.md`](https://github.com/Azure/git-ape/blob/main/.github/copilot-instructions.md)
4. Add your organization's naming conventions and policies

## Resources

- [Azure MCP Server Documentation](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azure-mcp-server)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [GitHub Copilot Custom Agents](https://code.visualstudio.com/docs/copilot/customization/custom-agents)
- [ARM Template Reference](https://docs.microsoft.com/en-us/azure/templates/)
