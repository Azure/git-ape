---
title: "Azure Resource Availability"
sidebar_label: "Azure Resource Availability"
description: "Query live Azure APIs to validate resource availability before template generation or deployment. Checks VM SKU restrictions, Kubernetes/runtime version support, API version compatibility, and subscription quota. Use during requirements gathering and preflight to catch deployment failures early."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/azure-resource-availability/SKILL.md -->


# Azure Resource Availability

> Query live Azure APIs to validate resource availability before template generation or deployment. Checks VM SKU restrictions, Kubernetes/runtime version support, API version compatibility, and subscription quota. Use during requirements gathering and preflight to catch deployment failures early.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/azure-resource-availability/` |
| **Phase** | Pre-Deploy |
| **User Invocable** | ✅ Yes |
| **Usage** | `/azure-resource-availability Resource type, region, and SKU/version to validate` |


## Documentation

# Azure Resource Availability

Validate that Azure resources, SKUs, service versions, and API versions are available in the target subscription and region **before** generating templates or deploying.

## When to Use

- **Requirements Gathering** — After collecting region + resource type, validate availability before finalizing
- **Template Generation** — When selecting API versions and resource properties, verify they exist
- **Preflight** — As a blocking gate before what-if analysis
- **Deployment Retry** — After a deployment failure, diagnose availability issues

## Procedure

### Step 1: Parse Resources to Validate

Extract the resource list from one of these sources (in priority order):

1. **ARM template** — Parse `template.json` for resource types, API versions, SKUs, and service versions
2. **Requirements document** — Parse `requirements.json` for requested resources
3. **User input** — Resource type, region, and version/SKU provided directly

For each resource, extract:
- Resource type (e.g., `Microsoft.ContainerService/managedClusters`)
- Target region
- API version used in the template
- SKU or VM size (if applicable)
- Service version (e.g., Kubernetes version, runtime version)

### Step 2: Check VM/Compute SKU Availability

For any resource that uses a VM SKU (AKS node pools, App Service Plans, VMs):

```bash
# Check if the SKU is available and unrestricted in the target region
az vm list-skus \
  --location {region} \
  --resource-type virtualMachines \
  --size {sku_name} \
  --output json 2>&1 | \
  jq '[.[] | select(.restrictions | length == 0)] | length'
```

**Interpret results:**
- Count > 0 → SKU is available
- Count = 0 → SKU is restricted or doesn't exist in this region

**If unavailable**, find alternatives:

```bash
# Find similar unrestricted SKUs in the same family
# Example: if Standard_B2s is restricted, find other 2-vCPU options
az vm list-skus \
  --location {region} \
  --resource-type virtualMachines \
  --output json 2>&1 | \
  jq -r '[.[] | select((.restrictions | length == 0) and (.capabilities[] | select(.name == "vCPUs" and .value == "2"))) | .name] | unique | .[:5] | .[]'
```

### Step 3: Check Service Version Availability

#### Kubernetes (AKS)

```bash
# Get supported non-preview Kubernetes versions
az aks get-versions \
  --location {region} \
  --output json 2>&1 | \
  jq -r '[.values[] | select(.isPreview != true)] | sort_by(.version) | .[].version'
```

**Check:** Is the requested version in the list?
- If not, report which versions ARE available
- Flag if the version exists but is preview-only or LTS-only

#### Function App / App Service Runtimes

```bash
# Linux runtimes
az functionapp list-runtimes --os-type linux --output json 2>&1 | \
  jq -r '.[] | "\(.runtime): \(.version)"'

# Web App runtimes
az webapp list-runtimes --os-type linux --output json 2>&1
```

**Check:** Is the requested runtime + version available?

#### Container Apps

```bash
# Check if Container Apps is available in the region
az provider show \
  --namespace Microsoft.App \
  --query "resourceTypes[?resourceType=='containerApps'].locations" \
  --output json 2>&1
```

### Step 4: Check API Version Compatibility

For each resource type in the template, verify the API version is valid:

```bash
# Get available API versions for a resource type
az provider show \
  --namespace {namespace} \
  --query "resourceTypes[?resourceType=='{resourceType}'].apiVersions" \
  --output json 2>&1
```

**Example:** For `Microsoft.ContainerService/managedClusters`:
```bash
az provider show \
  --namespace Microsoft.ContainerService \
  --query "resourceTypes[?resourceType=='managedClusters'].apiVersions" \
  --output json 2>&1
```

**Validation rules:**
1. The API version used in the template MUST appear in the list
2. Prefer the latest **stable** (non-preview) version
3. If the template uses a preview API version, flag it as a warning
4. Report if a newer stable version is available

**Recommend the latest stable API version:**
```bash
# Get the latest non-preview API version
az provider show \
  --namespace {namespace} \
  --query "resourceTypes[?resourceType=='{resourceType}'].apiVersions" \
  --output json 2>&1 | \
  jq -r '.[][] | select(test("preview") | not)' | head -1
```

### Step 5: Check Subscription Quota

For compute resources, verify the subscription has available quota:

```bash
# Check vCPU quota usage in the target region
az vm list-usage \
  --location {region} \
  --output json 2>&1 | \
  jq '.[] | select(.name.value | test("cores|vCPU"; "i")) | {name: .name.localizedValue, current: .currentValue, limit: .limit, available: (.limit - .currentValue)}'
```

**Check:** Will the deployment exceed quota limits?
- Calculate total vCPUs needed (node count × vCPUs per VM)
- Compare against available quota
- Flag if available quota < required

### Step 6: Check Resource Provider Registration

```bash
# Verify the resource provider is registered in the subscription
az provider show \
  --namespace {namespace} \
  --query "registrationState" \
  --output tsv 2>&1
```

**If not registered:** Flag as blocking — the deployment will fail. Include the registration command:
```bash
az provider register --namespace {namespace}
```

### Step 7: Generate Availability Report

Produce a structured report with pass/fail/warning for each check.

**Save to:** `.azure/deployments/{deployment-id}/availability-report.md` (if deployment context exists)

```markdown
# Resource Availability Report

**Region:** {region}
**Subscription:** {subscription-name} (`{subscription-id}`)
**Checked:** {ISO 8601 timestamp}

## Summary

| Check | Status | Details |
|-------|--------|---------|
| VM SKU: {sku} in {region} | ✅ Available / ❌ Restricted | {details} |
| K8s Version: {version} | ✅ Supported / ❌ Unsupported | {alternatives} |
| API Version: {api-version} | ✅ Valid / ⚠️ Outdated / ❌ Invalid | Latest stable: {latest} |
| Quota: vCPUs | ✅ Sufficient / ⚠️ Low / ❌ Exceeded | {current}/{limit} |
| Provider: {namespace} | ✅ Registered / ❌ Not registered | {command} |

## Availability Gate

**🟢 PASSED** — All checks passed. Safe to proceed with template generation/deployment.
**🟡 WARNINGS** — Non-blocking issues found. Review before proceeding.
**🔴 BLOCKED** — Blocking issues found. Must resolve before proceeding.

## Blocking Issues
{List of issues that prevent deployment}

## Warnings
{List of non-blocking issues}

## Recommendations
{Suggested alternatives for any failed checks}
```

### Step 8: Return Structured Results

Return the report to the calling agent/skill with:
- Overall gate status: `PASSED`, `WARNINGS`, or `BLOCKED`
- Per-resource availability details
- Recommended alternatives for any failures

**JSON output** (for programmatic consumption by other agents):

```json
{
  "gate": "PASSED|WARNINGS|BLOCKED",
  "region": "{region}",
  "timestamp": "{ISO 8601}",
  "checks": [
    {
      "type": "vm-sku",
      "resource": "{resource-name}",
      "requested": "{sku}",
      "status": "available|restricted|unavailable",
      "alternatives": ["{alt1}", "{alt2}"]
    },
    {
      "type": "service-version",
      "resource": "{resource-name}",
      "requested": "{version}",
      "status": "supported|lts-only|preview-only|unsupported",
      "supported": ["{v1}", "{v2}", "{v3}"]
    },
    {
      "type": "api-version",
      "resource": "{resource-type}",
      "requested": "{api-version}",
      "status": "valid|outdated|invalid",
      "latestStable": "{latest}",
      "available": ["{v1}", "{v2}"]
    },
    {
      "type": "quota",
      "metric": "vCPUs",
      "required": 2,
      "available": 48,
      "limit": 50,
      "status": "sufficient|low|exceeded"
    },
    {
      "type": "provider-registration",
      "namespace": "{namespace}",
      "status": "registered|not-registered"
    }
  ]
}
```

## Error Handling

| Error | Action |
|-------|--------|
| Not logged in to Azure | Note in report; in interactive mode suggest `az login`; in headless mode fail |
| Region not found | Report as blocking; suggest default regions (East US, West Europe) |
| Provider namespace unknown | Report as warning; may be a typo in the resource type |
| Command timeout | Retry once; if still fails, report as "unable to verify" with ❓ |
| Empty results | Treat as "unavailable" — the SKU/version likely doesn't exist |

## Integration Points

### Called by Requirements Gatherer (early validation)
```
User provides region + resource type + SKU/version
→ /azure-resource-availability checks all three
→ If BLOCKED: present alternatives before finalizing requirements
→ If PASSED: proceed to template generation
```

### Called by Template Generator (API version selection)
```
Before selecting API version for a resource type
→ /azure-resource-availability checks latest stable API version
→ Generator uses the returned version instead of hardcoding
```

### Called by Preflight (blocking gate)
```
After template is generated, before what-if
→ /azure-resource-availability parses template for all resources
→ Validates SKUs, versions, API versions, quota
→ If BLOCKED: fail preflight with actionable report
→ If PASSED: proceed to what-if analysis
```

### Called by Deploy Workflow (freshness check)
```
Before deploying a template (especially if generated days ago)
→ /azure-resource-availability re-checks all versions
→ If any version has been deprecated since generation: warn
```
