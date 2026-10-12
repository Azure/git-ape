# Azure Sandbox Setup

> Prepare an Azure subscription for hands-on labs (Tracks 2-3).

Tracks 2 and 3 deploy real Azure resources. This guide helps you set up a sandbox environment that is safe for experimentation.

## Option 1: Azure Free Account

If you don't have an Azure subscription:

1. Go to [azure.microsoft.com/free](https://azure.microsoft.com/free/).
2. Sign up with a Microsoft account.
3. You get $200 credit for 30 days plus 12 months of free services.

> The workshop labs create low-cost resources (Consumption-tier Function Apps, Basic-tier databases). Estimated cost: under $5 for a full workshop session.

## Option 2: Existing Subscription (Dev/Sandbox)

Use a dev or sandbox subscription. Avoid production subscriptions.

**Verify your access level:**

```bash
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) \
  --subscription "Your Subscription Name" \
  --query "[].roleDefinitionName" -o tsv
```

**Minimum roles needed:**

| Lab | Required Role | Why |
|-----|--------------|-----|
| Track 2: Labs 1-5 | **Contributor** | Create and manage resources |
| Track 2: Lab 1 (onboarding) | **Owner** or **User Access Administrator** | Create RBAC role assignments and OIDC configuration |
| Track 3: Labs 1-6 | **Contributor** + **User Access Administrator** | Full CI/CD pipeline with RBAC assignments in ARM templates |

## Option 3: Instructor-Provided Sandbox

For instructor-led workshops, the facilitator may provide:

- A shared Azure subscription with pre-configured RBAC
- Per-attendee resource group quotas
- Pre-created service principals for OIDC labs

See the [Facilitator Guide](../FACILITATOR-GUIDE.md) for sandbox provisioning instructions.

## Set Your Subscription

After signing in:

```bash
# List available subscriptions
az account list --output table

# Set the subscription you want to use
az account set --subscription "Your Sandbox Subscription"

# Verify
az account show --query "{name:name, id:id, state:state}" -o table
```

## Resource Cleanup

Workshop labs create resources in clearly named resource groups (e.g., `rg-workshop-dev-eastus`). After the workshop:

```bash
# List workshop resource groups
az group list --query "[?starts_with(name, 'rg-')].{Name:name, Location:location}" -o table

# Delete a specific resource group
az group delete --name rg-workshop-dev-eastus --yes --no-wait
```

> **Track 3 Lab 6** covers the full destroy lifecycle using Git-Ape's teardown workflow. If you complete Track 3, your resources are cleaned up as part of the lab.

## Cost Expectations

| Resource | Estimated Monthly Cost | Workshop Duration Cost |
|----------|----------------------|----------------------|
| Function App (Consumption) | ~$0.40 | < $0.01 |
| Storage Account (LRS) | ~$0.50 | < $0.01 |
| App Service (B1) | ~$13.00 | ~$0.50 |
| SQL Database (Basic) | ~$5.00 | ~$0.20 |
| Application Insights | ~$2.30 | < $0.10 |

> Total estimated cost for completing all labs: **under $5**.
