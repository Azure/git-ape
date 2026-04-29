---
title: "Azure Integration Tester"
sidebar_label: "Azure Integration Tester"
description: "Run post-deployment integration tests for Azure resources. Verify Function Apps, Storage Accounts, Databases, App Services are healthy and accessible. Use after successful Azure deployment."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/azure-integration-tester/SKILL.md -->


# Azure Integration Tester

> Run post-deployment integration tests for Azure resources. Verify Function Apps, Storage Accounts, Databases, App Services are healthy and accessible. Use after successful Azure deployment.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/azure-integration-tester/` |
| **Phase** | Post-Deploy |
| **User Invocable** | ✅ Yes |
| **Usage** | `/azure-integration-tester Deployment outputs (resource IDs and endpoints)` |


## Documentation

# Azure Integration Tester

Run comprehensive integration tests on deployed Azure resources to verify they are functional, accessible, and properly configured.

## When to Use

- After successful ARM template deployment
- To verify resource health and endpoints
- Before handing off deployment to user
- For troubleshooting deployment issues

## Procedure

### 1. Identify Deployed Resources

Parse deployment outputs to identify resource types:
- Function Apps → HTTP endpoint tests
- Storage Accounts → Connectivity and blob operations
- SQL Databases / Cosmos DB → Connection tests
- App Services → HTTP endpoint tests
- Application Insights → Telemetry verification

### 2. Run Resource-Specific Tests

**For Function Apps:**

Execute [test-function-app.sh](https://github.com/Azure/git-ape/blob/main/.github/skills/azure-integration-tester/scripts/test-function-app.sh):
```bash
./scripts/test-function-app.sh \
  --url "https://func-api-dev-eastus.azurewebsites.net" \
  --resource-group "rg-webapp-dev-eastus" \
  --name "func-api-dev-eastus"
```

Tests performed:
- ✓ HTTP endpoint accessibility (GET /)
- ✓ Health endpoint (/api/health or /admin/host/status)
- ✓ Response time under threshold
- ✓ HTTPS enforcement (reject HTTP)
- ✓ CORS configuration
- ✓ Application Insights connectivity

**For Storage Accounts:**

Execute [test-storage.sh](https://github.com/Azure/git-ape/blob/main/.github/skills/azure-integration-tester/scripts/test-storage.sh):
```bash
./scripts/test-storage.sh \
  --account-name "stwebappdev8k3m" \
  --resource-group "rg-webapp-dev-eastus"
```

Tests performed:
- ✓ Account accessibility
- ✓ Blob service available
- ✓ Create/read/delete test blob
- ✓ HTTPS-only enforcement
- ✓ Firewall rules (if configured)
- ✓ Minimum TLS version

**For Databases:**

Execute [test-database.sh](https://github.com/Azure/git-ape/blob/main/.github/skills/azure-integration-tester/scripts/test-database.sh):
```bash
./scripts/test-database.sh \
  --type "sqldb" \
  --server "sql-webapp-dev-eastus.database.windows.net" \
  --database "mydb" \
  --resource-group "rg-webapp-dev-eastus"
```

Tests performed:
- ✓ Server reachability
- ✓ Database exists
- ✓ Connection successful (using managed identity if configured)
- ✓ Basic query execution (SELECT 1)
- ✓ Firewall rules allow access
- ✓ Encryption enabled

### 3. Verify Security Configurations

Check that security best practices are applied:

```bash
# HTTPS-only enforcement
az resource show --ids {resource-id} --query "properties.httpsOnly"

# Managed identity enabled
az resource show --ids {resource-id} --query "identity.type"

# TLS version
az resource show --ids {resource-id} --query "properties.minTlsVersion"

# Diagnostic logs enabled
az monitor diagnostic-settings list --resource {resource-id}
```

### 4. Generate Test Report

Output a comprehensive test report:

```markdown
## Integration Test Report

**Deployment ID:** {deployment-id}
**Tested:** {timestamp}
**Duration:** {test-duration}

### Test Results

#### Function App: func-api-dev-eastus
- ✅ HTTP endpoint accessible (200 OK)
- ✅ Response time: 245ms (threshold: 3000ms)
- ✅ HTTPS enforcement verified
- ✅ Application Insights connected
- ⚠️  No custom health endpoint found (using default)

#### Storage Account: stwebappdev8k3m
- ✅ Blob service accessible
- ✅ Test blob created/read/deleted successfully
- ✅ HTTPS-only enforced
- ✅ TLS 1.2 minimum version set

#### Security Configuration
- ✅ All resources use HTTPS-only
- ✅ Managed identities configured
- ✅ Diagnostic logging enabled
- ✅ Resource tags applied correctly

### Summary

**Total Tests:** 12
**Passed:** 11 ✅
**Warnings:** 1 ⚠️
**Failed:** 0 ❌

**Overall Status:** HEALTHY ✅

### Recommendations

1. Consider adding custom health endpoint to Function App for better monitoring
2. Configure Application Insights alerts for failures
3. Enable auto-scaling if expecting variable load

### Next Steps

Your Azure resources are deployed and verified. You can now:
1. Deploy your application code to the Function App
2. Configure any application-specific settings
3. Set up CI/CD pipelines for automated deployments
4. Monitor resources in Azure Portal

**Azure Portal Links:**
- Function App: https://portal.azure.com/#@{tenant}/resource{function-app-id}
- Resource Group: https://portal.azure.com/#@{tenant}/resource{rg-id}
```

## Test Scripts

All test scripts are located in the `./scripts/` directory:

- [test-function-app.sh](https://github.com/Azure/git-ape/blob/main/.github/skills/azure-integration-tester/scripts/test-function-app.sh) - Function App health checks
- [test-storage.sh](https://github.com/Azure/git-ape/blob/main/.github/skills/azure-integration-tester/scripts/test-storage.sh) - Storage Account connectivity
- [test-database.sh](https://github.com/Azure/git-ape/blob/main/.github/skills/azure-integration-tester/scripts/test-database.sh) - Database connection tests

## Common Test Patterns

See [test-patterns.md](https://github.com/Azure/git-ape/blob/main/.github/skills/azure-integration-tester/references/test-patterns.md) for detailed test patterns including:
- Retry logic for transient failures
- Health endpoint formats
- Connection string handling
- Managed identity authentication
- Error diagnostics

## Error Handling

If tests fail, provide diagnostic information:

```markdown
❌ **Test Failed: Function App Endpoint**

**Error:** Connection refused
**Endpoint:** https://func-api-dev-eastus.azurewebsites.net

**Possible Causes:**
1. Function App still starting up (can take 2-3 minutes after deployment)
2. Network security group blocking access
3. Function App in stopped state

**Troubleshooting:**
1. Wait 2 minutes and retry
2. Check Function App status: `az functionapp show --name {name} --resource-group {rg} --query "state"`
3. View logs: `az webapp log tail --name {name} --resource-group {rg}`

**Retry Command:**
./scripts/test-function-app.sh --url {url} --retry 3 --delay 30
```

## Skipping Tests

Some tests may not apply:
- Resource Groups have no endpoints to test
- Some resources may be private (no public access)

In these cases, output:
```markdown
ℹ️ **Integration Tests: N/A**

No testable endpoints for Resource Group deployments.
Verified resource creation via Azure Resource Graph instead.
```

## Usage Examples

**After Function App deployment:**
```
@git-ape deploy a python function app
[... deployment completes ...]
/azure-integration-tester {deployment-outputs}
```

**Manual invocation:**
```
/azure-integration-tester
Please provide deployment outputs or resource details:
- Function App URL: https://func-api-dev-eastus.azurewebsites.net
- Resource Group: rg-webapp-dev-eastus
- Storage Account: stwebappdev8k3m
```

## Output Format

Always provide:
1. Detailed test results for each resource
2. Pass/fail status with diagnostics
3. Security configuration verification
4. Performance metrics (response times)
5. Overall health summary
6. Recommendations for improvements
7. Next steps for the user
8. Azure Portal links for monitoring
