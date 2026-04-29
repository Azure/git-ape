---
title: "Azure Rest Api Reference"
sidebar_label: "Azure Rest Api Reference"
description: "Look up Azure REST API and ARM template reference documentation for any resource type. Returns exact property schemas, required fields, valid values, and latest stable API versions. Use BEFORE generating or modifying ARM templates to ensure correctness. No Azure connection required."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/azure-rest-api-reference/SKILL.md -->


# Azure Rest Api Reference

> Look up Azure REST API and ARM template reference documentation for any resource type. Returns exact property schemas, required fields, valid values, and latest stable API versions. Use BEFORE generating or modifying ARM templates to ensure correctness. No Azure connection required.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/azure-rest-api-reference/` |
| **Phase** | Operations |
| **User Invocable** | ✅ Yes |
| **Usage** | `/azure-rest-api-reference Resource type (e.g., Microsoft.Web/sites, Microsoft.Storage/storageAccounts)` |


## Documentation

# Azure REST API Reference Lookup

Look up the official Azure REST API and ARM template reference for a resource type to get exact property definitions, required fields, valid values, and stable API versions — **before** generating or modifying templates.

## Why This Exists

ARM templates fail when properties are wrong, missing, or used with the wrong API version. The agent must never guess at property names, enum values, or required fields. This skill replaces guessing with lookup.

## When to Use

- **Before generating any ARM template resource** — look up the resource type to get correct properties
- **Before modifying a template to fix a deployment error** — look up what properties actually exist and what values are valid
- **When unsure about an API version** — find the latest stable version for a resource type
- **When a deployment fails with property-related errors** — verify the property exists in the schema

## Procedure

### Step 1: Identify the Resource Provider and Type

Parse the fully-qualified resource type. Examples:
- `Microsoft.Web/sites` → provider: `appservice`, operation: `web-apps`
- `Microsoft.Storage/storageAccounts` → provider: `storagerp`, operation: `storage-accounts`
- `Microsoft.Web/serverfarms` → provider: `appservice`, operation: `app-service-plans`
- `Microsoft.Insights/components` → provider: `applicationinsights`, operation: `components`
- `Microsoft.OperationalInsights/workspaces` → provider: `loganalytics`, operation: `workspaces`
- `Microsoft.ContainerApp/containerApps` → provider: `containerapps`, operation: `container-apps`

### Step 2: Fetch ARM Template Reference (Primary Source)

The ARM template reference provides the **exact schema** for template authoring — properties, types, required fields, and valid enum values.

**URL pattern:**
```
https://learn.microsoft.com/en-us/azure/templates/{resource-provider-lowercase}/{api-version}/{resource-type}
```

**Examples:**
```
https://learn.microsoft.com/en-us/azure/templates/microsoft.web/sites
https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts
https://learn.microsoft.com/en-us/azure/templates/microsoft.web/serverfarms
```

**Fetch using `curl`:**
```bash
# Fetch the ARM template reference page for the resource type
# Use the raw content URL to avoid HTML noise
curl -sL "https://learn.microsoft.com/en-us/azure/templates/microsoft.web/sites" \
  | sed -n '/<article/,/<\/article>/p' \
  | head -500
```

**If `curl` results are noisy, use the Azure REST API docs instead (Step 3).**

### Step 3: Fetch REST API Reference (Secondary Source)

The REST API reference provides operation-level details — request body schema, response format, required vs optional properties.

**URL pattern:**
```
https://learn.microsoft.com/en-us/rest/api/{service}/{operation}/{method}
```

**Examples for common create/update operations:**
```
https://learn.microsoft.com/en-us/rest/api/appservice/web-apps/create-or-update
https://learn.microsoft.com/en-us/rest/api/storagerp/storage-accounts/create
https://learn.microsoft.com/en-us/rest/api/appservice/app-service-plans/create-or-update
https://learn.microsoft.com/en-us/rest/api/resources/resource-groups/create-or-update
```

**Fetch using `curl`:**
```bash
curl -sL "https://learn.microsoft.com/en-us/rest/api/appservice/web-apps/create-or-update" \
  | sed -n '/Request Body/,/Responses/p' \
  | head -300
```

### Step 4: Fetch the Raw JSON Schema (Most Precise)

For exact property definitions, query the Azure resource schema directly:

**URL pattern:**
```
https://raw.githubusercontent.com/Azure/azure-resource-manager-schemas/main/schemas/{api-version}/{resource-provider}.json
```

**Or use the schema index to find available API versions:**
```bash
# Find all available API versions for a resource provider
curl -sL "https://raw.githubusercontent.com/Azure/azure-resource-manager-schemas/main/schemas/common/autogeneratedResources.json" \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
provider = sys.argv[1].lower()
for entry in data:
    if provider in entry.lower():
        print(entry)
" "Microsoft.Web"
```

**Get the actual property schema:**
```bash
# Get the schema for a specific resource type and API version
API_VERSION="2023-12-01"
curl -sL "https://raw.githubusercontent.com/Azure/azure-resource-manager-schemas/main/schemas/${API_VERSION}/Microsoft.Web.json" \
  | python3 -c "
import json, sys
schema = json.load(sys.stdin)
resource_type = sys.argv[1]
# Navigate to resource definition
for key, value in schema.get('resourceDefinitions', {}).items():
    if resource_type.lower() in key.lower():
        print(json.dumps(value, indent=2)[:3000])
" "sites"
```

### Step 5: Extract and Structure the Output

From the fetched documentation, extract:

```markdown
## Resource: {full-resource-type}

### API Version
- Latest stable: {version}
- Used in template: {version-from-template}
- Match: ✅ / ⚠️ Outdated

### Required Properties
| Property Path | Type | Description |
|---------------|------|-------------|
| properties.X  | string | ... |

### Security-Relevant Properties
| Property Path | Type | Recommended Value | Description |
|---------------|------|-------------------|-------------|
| properties.httpsOnly | bool | true | Enforce HTTPS |

### App Settings (if applicable)
| Setting Name | Purpose | Identity-Based Alternative |
|-------------|---------|---------------------------|
| AzureWebJobsStorage | Storage connection | AzureWebJobsStorage__accountName |

### Valid Enum Values (for constrained properties)
| Property | Valid Values |
|----------|-------------|
| properties.siteConfig.ftpsState | AllAllowed, Disabled, FtpsOnly |

### Common Mistakes
- {property commonly confused with another}
- {deprecated property still appearing in examples}
```

## Fallback: MCP Documentation Tools

If `curl` fetching is blocked or returns incomplete results, use MCP tools when available:

```
mcp_azure_mcp_documentation — search Azure documentation
```

Query: `"ARM template {resource-type} properties reference"`

## Output Rules

1. **Never guess at properties** — if a property cannot be found in the reference, say so
2. **Always include the API version** — mismatched API versions are a top cause of deployment failures
3. **Flag deprecated properties** — if a property exists but is marked deprecated, note the replacement
4. **Distinguish required vs optional** — required properties that are missing will cause deployment failures
5. **Note identity-based alternatives** — for any property that accepts connection strings or keys, note the managed-identity-based equivalent

## Provider-to-REST-API Mapping

Quick reference for common resource types:

| Resource Provider | REST API Service | Create Operation |
|-------------------|-----------------|-----------------|
| Microsoft.Web/sites | appservice | web-apps/create-or-update |
| Microsoft.Web/serverfarms | appservice | app-service-plans/create-or-update |
| Microsoft.Storage/storageAccounts | storagerp | storage-accounts/create |
| Microsoft.Insights/components | applicationinsights | components/create-or-update |
| Microsoft.OperationalInsights/workspaces | loganalytics | workspaces/create-or-update |
| Microsoft.Sql/servers | sql | servers/create-or-update |
| Microsoft.Sql/servers/databases | sql | databases/create-or-update |
| Microsoft.DocumentDB/databaseAccounts | cosmos-db | database-accounts/create-or-update |
| Microsoft.KeyVault/vaults | keyvault | vaults/create-or-update |
| Microsoft.ContainerApp/containerApps | containerapps | container-apps/create-or-update |
| Microsoft.App/managedEnvironments | containerapps | managed-environments/create-or-update |
| Microsoft.Network/virtualNetworks | virtualnetwork | virtual-networks/create-or-update |
| Microsoft.Compute/virtualMachines | compute | virtual-machines/create-or-update |
| Microsoft.Authorization/roleAssignments | authorization | role-assignments/create |
