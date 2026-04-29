---
title: "Azure MCP Setup"
sidebar_label: "Azure Setup"
sidebar_position: 2
description: "Connect Git-Ape to Azure through the Azure MCP server"
---

# Azure MCP setup

This page walks you through connecting Git-Ape to your Azure subscription so it can query resources, generate templates, and deploy infrastructure.

:::warning
EXPERIMENTAL ONLY — This setup is for development and sandbox testing. Do **not** use this project for production Azure operations. Review permissions and commands carefully before running them.
:::

## Before you start

You need three things:

1. **VS Code** (Stable or Insiders) with GitHub Copilot enabled.
2. **Azure CLI** installed and authenticated (`az login`).
3. **Azure MCP Server extension** — ships with Azure Tools for VS Code. Verify with:

   ```bash
   code --list-extensions | grep azure-mcp
   ```

   You should see `ms-azuretools.vscode-azure-mcp-server`. If not, install [Azure Tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack) from the marketplace.

## Step 1: Sign in to Azure

```bash
az login
az account set --subscription "Your Subscription Name or ID"   # optional but recommended
az account show                                                 # verify
```

Git-Ape uses your Azure CLI credentials automatically — there is nothing else to configure for authentication.

## Step 2: Configure the MCP server

Add these settings to your VS Code configuration (`.vscode/settings.json` or User Settings):

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

:::tip[Which server mode should I choose?]
- **`namespace`** (recommended) — Groups tools by Azure service (~30 tool groups). Gives agents enough context without overwhelming them.
- **`single`** — One tool that routes to 100+ internal commands. Use this only if your organization limits tool count.
- **`all`** — Exposes every individual MCP tool (100+). Can slow down agent responses.
:::

### Which services do I need?

The list above covers the most common Git-Ape scenarios. Here is what each service does:

| Service | What it enables | When to add it |
|---------|----------------|----------------|
| `deploy` | ARM template deployment, what-if, validation | **Always** — core deployment |
| `bestpractices` | Security and configuration recommendations | **Always** — security analysis |
| `group` | Resource group operations | **Always** — resource management |
| `subscription` | Subscription queries | **Always** — subscription discovery |
| `functionapp` | Azure Functions management | Deploying Function Apps |
| `storage` | Storage account operations | Most deployments (Functions, web apps) |
| `sql`, `cosmos` | Database operations | Deploying databases |
| `keyvault` | Key Vault access | Templates using Key Vault references |
| `aks`, `acr` | Kubernetes and container registry | Container workloads |

Start with the recommended list. You can add or remove services at any time.

## Step 3: Verify the connection

1. Reload VS Code (`Cmd+Shift+P` → **Developer: Reload Window**).
2. Open Copilot Chat and type:

   ```text
   @git-ape list my Azure subscriptions
   ```

   The agent should use Azure MCP tools and return your subscription details.

If it works, you are ready to deploy. Try:

```text
@git-ape deploy a Python function app in East US
```

## Troubleshooting

<details>
<summary><strong>"Unknown tool 'mcp_azure_mcp/…'"</strong></summary>

The Azure MCP server is not loaded. Fix:

1. Verify the extension is installed: `code --list-extensions | grep azure-mcp`
2. Reload the VS Code window.
3. Check that `azureMcp.serverMode` is set in your settings.

</details>

<details>
<summary><strong>Azure authentication fails</strong></summary>

Your Azure CLI session has expired. Fix:

```bash
az login
az account show   # confirm you are signed in
```

If you have multiple subscriptions, set the default: `az account set --subscription "..."`.

</details>

<details>
<summary><strong>"Permission denied" on deployments</strong></summary>

Your Azure account lacks permissions. You need at least **Contributor** on the target resource group or subscription.

```bash
az role assignment list --assignee "$(az account show --query user.name -o tsv)" -o table
```

Contact your Azure administrator if roles are missing.

</details>

<details>
<summary><strong>MCP tools are slow or unresponsive</strong></summary>

1. Switch to `"namespace"` mode if you are using `"all"`.
2. Reduce the `enabledServices` list to only what you need.
3. Check [Azure service health](https://status.azure.com).

</details>

## Security best practices

- **Never commit** Azure credentials to version control. Use `.env` files (add to `.gitignore`) for local defaults.
- Git-Ape always asks for confirmation before deploying. Review the generated ARM template and cost estimate before approving.
- For production use, consider creating a least-privilege custom role scoped to the resource types you deploy.

## What's next?

- **[Onboarding](./onboarding)** — Set up OIDC, RBAC, and GitHub environments for CI/CD pipelines.
- **[Deploy anything](/docs/use-cases/deploy-anything)** — Walk through your first deployment.
