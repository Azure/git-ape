---
title: "Azure Role Selector"
sidebar_label: "Azure Role Selector"
description: "Recommend least-privilege Azure RBAC roles for deployed resources. Finds minimal built-in roles matching desired permissions or creates custom role definitions. Use during security analysis or when configuring access for service principals and managed identities."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/azure-role-selector/SKILL.md -->


# Azure Role Selector

> Recommend least-privilege Azure RBAC roles for deployed resources. Finds minimal built-in roles matching desired permissions or creates custom role definitions. Use during security analysis or when configuring access for service principals and managed identities.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/azure-role-selector/` |
| **Phase** | Pre-Deploy |
| **User Invocable** | ✅ Yes |
| **Usage** | `/azure-role-selector Describe the permissions needed (e.g., 'read storage blobs', 'deploy to app service')` |


## Documentation

# Azure Role Selector

Recommend the most appropriate Azure RBAC roles following the principle of least privilege. Find minimal built-in roles or define custom roles when needed.

Adapted from [github/awesome-copilot](https://github.com/github/awesome-copilot) `azure-role-selector` skill.

## When to Use

- When deploying resources that need RBAC assignments
- When configuring managed identity access between resources
- When setting up service principals for CI/CD pipelines
- During security analysis to verify correct role assignments
- When user asks "what role do I need for X?"

## Procedure

### 1. Understand Required Permissions

Ask the user what actions they need to perform:

```markdown
What permissions do you need? Examples:
- "Read and write blobs in a storage account"
- "Deploy code to a Function App"
- "Read secrets from Key Vault"
- "Manage SQL databases"
- "Full access to a resource group"
```

### 2. Search for Built-In Roles

Use Azure MCP documentation tools to find matching built-in roles:

```bash
# List relevant built-in roles
az role definition list \
  --query "[?contains(roleName, '{keyword}')].{Name:roleName, Description:description, Id:name}" \
  --output table

# Get detailed permissions for a role
az role definition list \
  --name "{role-name}" \
  --output json
```

Cross-reference with Microsoft Docs for the latest role definitions.

### 3. Recommend Least-Privilege Role

Present the recommended role(s) in order of least privilege:

```markdown
## Role Recommendation

**Desired:** Read and write blobs in storage account starnwkdhk

### Recommended Role (Least Privilege)
| Property | Value |
|----------|-------|
| **Role** | Storage Blob Data Contributor |
| **ID** | ba92f5b4-2d11-453d-a403-e96b0029c9fe |
| **Scope** | Storage Account level |
| **Permissions** | Read, write, delete blobs and containers |

### Alternatives (More Permissive)
| Role | Extra Permissions | Use When |
|------|-------------------|----------|
| Storage Account Contributor | Full account management | Need to manage account settings too |
| Contributor | Full resource management | Need broad access (not recommended) |

### ⚠️ Avoid These (Over-Privileged)
- **Owner** — Grants RBAC management, not needed for data access
- **Contributor** at subscription level — Too broad for storage-only needs
```

### 4. Generate Assignment Commands

Provide ready-to-use commands:

**Azure CLI:**
```bash
# Assign role to managed identity
az role assignment create \
  --assignee {principal-id} \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}

# Assign role to service principal
az role assignment create \
  --assignee {app-id} \
  --role "Storage Blob Data Contributor" \
  --scope {resource-id}
```

**ARM Template (for inclusion in deployment):**
```json
{
  "type": "Microsoft.Authorization/roleAssignments",
  "apiVersion": "2022-04-01",
  "name": "[guid(resourceId('Microsoft.Storage/storageAccounts', '{name}'), '{principal-id}', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')]",
  "scope": "[resourceId('Microsoft.Storage/storageAccounts', '{name}')]",
  "properties": {
    "roleDefinitionId": "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')]",
    "principalId": "{principal-id}",
    "principalType": "ServicePrincipal"
  }
}
```

### 5. Custom Role (If No Built-In Matches)

If no built-in role matches the exact permissions needed:

```bash
# Create custom role definition
az role definition create --role-definition '{
  "Name": "Custom Storage Reader Writer",
  "Description": "Can read and write blobs but not delete",
  "Actions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write"
  ],
  "NotActions": [],
  "DataActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write"
  ],
  "NotDataActions": [],
  "AssignableScopes": ["/subscriptions/{sub-id}"]
}'
```

## Common Role Mappings

| Resource | Action | Recommended Role |
|----------|--------|------------------|
| Storage | Read/write blobs | Storage Blob Data Contributor |
| Storage | Read blobs only | Storage Blob Data Reader |
| Key Vault | Read secrets | Key Vault Secrets User |
| Key Vault | Manage secrets | Key Vault Secrets Officer |
| SQL Database | Read data | SQL DB Contributor |
| Function App | Deploy code | Website Contributor |
| App Service | Deploy code | Website Contributor |
| Cosmos DB | Read/write data | Cosmos DB Account Reader Role |
| Resource Group | Full management | Contributor (scoped to RG) |
| Monitoring | Read metrics | Monitoring Reader |

## Integration with Git-Ape

When the template generator creates resources with managed identities, invoke this skill to:
1. Identify what roles the managed identity needs
2. Add role assignment resources to the ARM template
3. Follow least-privilege principle automatically
