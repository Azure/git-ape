---
title: "Azure Deployment Preflight"
sidebar_label: "Azure Deployment Preflight"
description: "Run preflight validation on ARM templates before deployment. Performs what-if analysis, permission checks, and generates a structured report with resource changes (create/modify/delete). Use before any deployment to preview changes and catch issues early."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/azure-deployment-preflight/SKILL.md -->


# Azure Deployment Preflight

> Run preflight validation on ARM templates before deployment. Performs what-if analysis, permission checks, and generates a structured report with resource changes (create/modify/delete). Use before any deployment to preview changes and catch issues early.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/azure-deployment-preflight/` |
| **Phase** | Pre-Deploy |
| **User Invocable** | ✅ Yes |
| **Usage** | `/azure-deployment-preflight ARM template path or deployment ID` |


## Documentation

# Azure Deployment Preflight Validation

Validate ARM template deployments before execution by running what-if analysis, checking permissions, and generating a structured preflight report.

Adapted from [github/awesome-copilot](https://github.com/github/awesome-copilot) `azure-deployment-preflight` skill.

## When to Use

- Before deploying infrastructure to Azure
- To preview what changes a deployment will make
- To verify permissions are sufficient for deployment
- As part of the template generation workflow (invoked by template generator)

## Procedure

### Step 1: Locate Template Files

Find the ARM template and parameters to validate:

```bash
# From deployment artifacts
DEPLOYMENT_ID="deploy-20260218-193500"
TEMPLATE=".azure/deployments/$DEPLOYMENT_ID/template.json"
PARAMETERS=".azure/deployments/$DEPLOYMENT_ID/parameters.json"

# Or from user-provided path
TEMPLATE="path/to/template.json"
```

Verify files exist before proceeding.

### Step 1.5: Resource Availability Gate

**Invoke `/azure-resource-availability` skill** to validate all resources in the template before running what-if.

This catches issues that `az deployment sub validate` and what-if do NOT catch — such as:
- VM SKU restrictions per subscription/region
- Deprecated or LTS-only service versions (e.g., Kubernetes)
- API version incompatibilities (fields that don't exist in the chosen version)
- Quota limits that would be exceeded

```bash
# Parse template for resources to check
# For each resource: extract type, apiVersion, SKU, service version, region
# Pass to /azure-resource-availability
```

**Gate behavior:**
- ✅ PASSED → continue to Step 2
- ⚠️ WARNINGS → continue but include warnings in preflight report
- ❌ BLOCKED → STOP. Report blocking issues with alternatives. Do not proceed to what-if.

Save the availability report to `.azure/deployments/$DEPLOYMENT_ID/availability-report.md`.

### Step 2: Validate Template Syntax

Check the ARM template is valid JSON and follows schema:

```bash
# Validate template syntax
az deployment sub validate \
  --location {location} \
  --template-file "$TEMPLATE" \
  --parameters @"$PARAMETERS" \
  --output json 2>&1
```

**What to capture:**
- Syntax errors with details
- Schema validation warnings
- Parameter validation issues

### Step 3: Run What-If Analysis

Run what-if to preview resource changes without deploying:

```bash
# For subscription-level deployments (Git-Ape default)
az deployment sub what-if \
  --location {location} \
  --template-file "$TEMPLATE" \
  --parameters @"$PARAMETERS" \
  --result-format FullResourcePayloads \
  --output json 2>&1
```

**Fallback:** If permission errors occur, retry without RBAC validation:

```bash
az deployment sub what-if \
  --location {location} \
  --template-file "$TEMPLATE" \
  --parameters @"$PARAMETERS" \
  --result-format FullResourcePayloads \
  --no-prompt \
  --output json 2>&1
```

Note the fallback in the report.

### Step 4: Parse What-If Results

Categorize resource changes from the what-if output:

| Change Type | Symbol | Meaning |
|-------------|--------|---------|
| **Create** | ➕ | New resource will be created |
| **Delete** | ➖ | Resource will be deleted |
| **Modify** | ✏️ | Resource properties will change |
| **NoChange** | ✅ | Resource unchanged |
| **Ignore** | ⏭️ | Resource not analyzed |
| **Deploy** | 🚀 | Resource will be deployed (changes unknown) |

For modified resources, capture the specific property changes:
```
Resource: Microsoft.Storage/storageAccounts/starnwkdhk
  ~ properties.minimumTlsVersion: "TLS1_0" → "TLS1_2"
  ~ tags.Environment: "staging" → "dev"
```

### Step 5: Generate Preflight Report

Create a structured report saved to `.azure/deployments/$DEPLOYMENT_ID/preflight-report.md`:

```markdown
# Preflight Validation Report

**Deployment ID:** {deployment-id}
**Validated:** {timestamp}
**Template:** {template-path}
**Scope:** Subscription-level

## Summary

| Check | Status |
|-------|--------|
| Template Syntax | ✅ Valid |
| Schema Compliance | ✅ Valid |
| What-If Analysis | ✅ Completed |
| Permission Check | ✅ Sufficient |

## What-If Results

### Resources to Create ({count})
| Resource Type | Name | Location |
|---------------|------|----------|
| Microsoft.Resources/resourceGroups | rg-xxx | eastus |
| Microsoft.Storage/storageAccounts | stxxx | eastus |

### Resources to Modify ({count})
| Resource | Property | Current | New |
|----------|----------|---------|-----|
| stxxx | minimumTlsVersion | TLS1_0 | TLS1_2 |

### Resources to Delete ({count})
{list or "None"}

### Resources Unchanged ({count})
{count resources with no changes}

## Issues Found

### Errors
{any blocking errors}

### Warnings
{any non-blocking warnings}

## Recommendations
- {actionable suggestions}
```

### Step 6: Return Results

Return the preflight report to the calling agent. If any **errors** were found, recommend the user address them before deploying.

**Save report** to `.azure/deployments/$DEPLOYMENT_ID/preflight-report.md`.

## Error Handling

| Error Type | Action |
|------------|--------|
| Not logged in | Note in report, suggest `az login` |
| Permission denied | Fall back to no-RBAC validation, note in report |
| Template syntax error | Include all errors, mark as blocking |
| Resource group not found | Note in report (RG may be created by template) |
| API version issues | Note in report, suggest updating |

**Key principle:** Continue validation even when errors occur. Capture all issues in the final report.

## Integration

**Called by template generator** after generating ARM template:
```
Template Generator → /azure-deployment-preflight → Preflight Report → User Confirmation
```

**Manual invocation:**
```
User: /azure-deployment-preflight --deployment-id deploy-20260218-193500

Agent: Running preflight validation...
[Validates template, runs what-if, generates report]
```
