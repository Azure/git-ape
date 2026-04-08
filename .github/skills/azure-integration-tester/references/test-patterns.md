# Azure Integration Test Patterns

Common patterns for testing Azure resources after deployment.

## Health Endpoint Patterns

### Function Apps

Azure Functions expose a built-in admin health endpoint:

```bash
# System health endpoint (requires admin key)
GET https://{function-app}.azurewebsites.net/admin/host/status

# Custom health endpoint (recommended)
GET https://{function-app}.azurewebsites.net/api/health
```

**Custom Health Endpoint Example (Python):**

```python
import azure.functions as func

def main(req: func.HttpRequest) -> func.HttpResponse:
    # Check dependencies (database, storage, etc.)
    health_checks = {
        "status": "healthy",
        "checks": {
            "storage": check_storage_connection(),
            "database": check_database_connection()
        }
    }
    
    if all(health_checks["checks"].values()):
        return func.HttpResponse(
            json.dumps(health_checks),
            mimetype="application/json",
            status_code=200
        )
    else:
        return func.HttpResponse(
            json.dumps(health_checks),
            mimetype="application/json",
            status_code=503
        )
```

### App Services

```bash
# Default endpoint
GET https://{app-service}.azurewebsites.net/

# Health probe (if configured)
GET https://{app-service}.azurewebsites.net/health
```

## Retry Logic

Transient failures are common immediately after deployment. Implement retry with exponential backoff:

```bash
#!/bin/bash
MAX_RETRIES=5
RETRY_DELAY=5

for i in $(seq 1 $MAX_RETRIES); do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT")
  
  if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "Success!"
    exit 0
  fi
  
  if [ $i -lt $MAX_RETRIES ]; then
    WAIT_TIME=$((RETRY_DELAY * i))
    echo "Retry $i/$MAX_RETRIES in ${WAIT_TIME}s..."
    sleep $WAIT_TIME
  fi
done

echo "Failed after $MAX_RETRIES attempts"
exit 1
```

## Connection String Handling

**Never hardcode connection strings in tests.** Retrieve them securely:

### Storage Account Connection String

```bash
# Get connection string from Azure
CONNECTION_STRING=$(az storage account show-connection-string \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query "connectionString" \
  --output tsv)

# Use in test
az storage blob list \
  --connection-string "$CONNECTION_STRING" \
  --container-name "test"
```

### SQL Database Connection String

```bash
# Get connection string (without password)
CONNECTION_STRING=$(az sql db show-connection-string \
  --client ado.net \
  --name "$DATABASE_NAME" \
  --server "$SERVER_NAME")

# Replace placeholders
CONNECTION_STRING=$(echo $CONNECTION_STRING | sed "s/<username>/$USERNAME/" | sed "s/<password>/$PASSWORD/")
```

## Managed Identity Authentication

For resources using managed identity, authenticate tests appropriately:

```bash
# Get access token using managed identity
ACCESS_TOKEN=$(az account get-access-token \
  --resource https://storage.azure.com/ \
  --query "accessToken" \
  --output tsv)

# Use token in API call
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER}"
```

## Error Diagnostics

### Common Deployment Errors

**Error: "Resource not found" immediately after deployment**
- **Cause:** DNS propagation delay or resource still initializing
- **Solution:** Wait 30-60 seconds and retry
- **Test:** Query Azure Resource Graph to verify resource exists

**Error: "Connection refused" or timeout**
- **Cause:** Firewall rules, NSG blocking access, or resource not started
- **Solution:** Check firewall rules allow client IP
- **Test:** `az network nsg rule list` or check App Service IP restrictions

**Error: "401 Unauthorized" on Function App**
- **Cause:** Function requires authentication (expected)
- **Solution:** Not an error if auth is configured; test with auth token
- **Test:** Retrieve function key and include in request

**Error: "404 Not Found" on Function App**
- **Cause:** No default route configured (expected for HTTP-triggered functions)
- **Solution:** Test specific function route: `/api/{function-name}`
- **Test:** List functions: `az functionapp function list`

### Health Check Response Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | Healthy | ✅ Pass test |
| 401 | Auth required | ⚠️ Expected if auth enabled |
| 404 | No default route | ⚠️ Test specific endpoints |
| 500 | Internal error | ❌ Check logs, may be starting up |
| 502 | Bad Gateway | ❌ App crashed or not started |
| 503 | Service Unavailable | ⚠️ Warning, may be cold start |

## Azure CLI Query Patterns

### Check Resource Status

```bash
# Generic resource status
az resource show \
  --ids "/subscriptions/{sub}/resourceGroups/{rg}/providers/{provider}/{type}/{name}" \
  --query "{Name:name, Status:properties.provisioningState, Location:location}"

# Function App specific
az functionapp show \
  --name "$FUNCTION_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "{State:state, OutboundIPs:possibleOutboundIpAddresses, Hostname:defaultHostName}"
```

### List Recent Deployments

```bash
# Check deployment history
az deployment group list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?properties.timestamp >= '$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')'].{Name:name, Status:properties.provisioningState, Time:properties.timestamp}" \
  --output table
```

### Get Resource Logs

```bash
# Function App logs
az webapp log tail \
  --name "$FUNCTION_NAME" \
  --resource-group "$RESOURCE_GROUP"

# Deployment logs
az webapp log deployment show \
  --name "$FUNCTION_NAME" \
  --resource-group "$RESOURCE_GROUP"
```

## Performance Baselines

Set realistic thresholds for response times:

| Resource Type | Expected Response Time | Threshold Warning |
|---------------|------------------------|-------------------|
| Function App (Warm) | < 500ms | < 3000ms |
| Function App (Cold Start) | < 5s | < 15s |
| App Service | < 200ms | < 2000ms |
| Storage Blob Read | < 100ms | < 1000ms |
| SQL Database Query | < 50ms | < 500ms |
| Cosmos DB Query | < 10ms | < 100ms |

## Security Verification Checklist

After deployment, verify these security settings:

- [ ] HTTPS-only enforcement enabled
- [ ] TLS 1.2 or higher required
- [ ] Public access disabled (unless required)
- [ ] Managed identity configured (if applicable)
- [ ] Diagnostic logging enabled
- [ ] No hardcoded secrets in app settings
- [ ] Firewall rules restrict access appropriately
- [ ] Resource tags applied for governance

## Example: Complete Function App Test

```bash
#!/bin/bash
FUNCTION_URL="https://func-api-dev-eastus.azurewebsites.net"
FUNCTION_NAME="func-api-dev-eastus"
RESOURCE_GROUP="rg-webapp-dev-eastus"

echo "Testing Function App: $FUNCTION_NAME"

# 1. Check deployment status
DEPLOY_STATUS=$(az functionapp show \
  --name "$FUNCTION_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "state" -o tsv)

if [ "$DEPLOY_STATUS" != "Running" ]; then
  echo "❌ Function App not running (State: $DEPLOY_STATUS)"
  exit 1
fi

# 2. Test endpoint with retries
for i in {1..5}; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$FUNCTION_URL")
  
  if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 404 ]; then
    echo "✅ Endpoint accessible (HTTP $HTTP_CODE)"
    break
  fi
  
  if [ $i -eq 5 ]; then
    echo "❌ Endpoint not accessible after 5 retries"
    exit 1
  fi
  
  sleep 10
done

# 3. Verify HTTPS enforcement
HTTPS_ONLY=$(az functionapp show \
  --name "$FUNCTION_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "httpsOnly" -o tsv)

if [ "$HTTPS_ONLY" == "true" ]; then
  echo "✅ HTTPS-only enforced"
else
  echo "❌ HTTPS-only NOT enforced"
  exit 1
fi

# 4. Check Application Insights
APPINSIGHTS=$(az functionapp config appsettings list \
  --name "$FUNCTION_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?name=='APPINSIGHTS_INSTRUMENTATIONKEY'].value" -o tsv)

if [ -n "$APPINSIGHTS" ]; then
  echo "✅ Application Insights configured"
else
  echo "⚠️ Application Insights not configured"
fi

echo "✅ All tests passed!"
```

## Summary

**Best Practices:**
1. Always use retry logic for HTTP tests (cold starts, DNS propagation)
2. Retrieve credentials securely via Azure CLI, never hardcode
3. Test security configurations, not just functionality
4. Set realistic performance thresholds based on resource type
5. Provide clear error diagnostics to help debug failures
6. Clean up any test resources (containers, blobs, etc.)
7. Use managed identity authentication in tests when possible
