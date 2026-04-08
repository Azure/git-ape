---
name: azure-naming-research
description: "Research Azure naming constraints and CAF abbreviations for a given resource type. Use when you need to look up the official CAF slug, naming rules (length, scope, valid characters), and derive validation/cleaning regex patterns for an Azure resource. Triggers on: CAF abbreviation lookup, Azure naming rules research, resource naming constraints."
---

# Azure Naming Research

## Procedure

### 1. Look up CAF abbreviation

Query the CAF abbreviations page for the official slug and resource provider namespace:

**URL**: `https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations`

Prefer Microsoft Docs MCP tools (`microsoft_docs_search`, `microsoft_docs_fetch`) when available.

Search by:
1. Terraform resource name without `azurerm_` prefix (e.g., "container app")
2. Resource provider namespace if known
3. Common name (e.g., "Container Apps")

Extract: **CAF abbreviation** (slug), **resource display name**, **resource provider namespace**.

If not found, the resource is out-of-doc — set `"out_of_doc": true` in the JSON entry and omit `official.slug` and `official.resource_provider_namespace`.

### 2. Look up Azure naming rules

Query the naming rules page for constraints:

**URL**: `https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules`

Find the section matching the resource provider namespace from step 1. Extract: **scope**, **length** (min-max), **valid characters**.

### 3. Derive field values

See [references/regex-patterns.md](references/regex-patterns.md) for the regex conversion tables.

- **scope** mapping: "globally unique"→`"global"`, "resource group"→`"resourceGroup"`, "within parent"→`"parent"`, "subscription"→`"subscription"`
- **dashes**: `true` if hyphens allowed
- **lowercase**: `true` if only lowercase letters allowed
- **validation_regex** and **regex**: Use the pattern tables in the reference file. Both MUST use escaped double quotes: `"\"pattern\""`

Never guess at constraints — mark as UNKNOWN if not verifiable.
