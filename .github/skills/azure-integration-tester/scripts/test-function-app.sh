#!/bin/bash
# Test Azure Function App health and accessibility
# Usage: ./test-function-app.sh --url <function-url> --resource-group <rg> --name <function-name>

set -e

# Default values
TIMEOUT=30
RETRY_COUNT=3
RETRY_DELAY=10
THRESHOLD_MS=3000

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --url)
      FUNCTION_URL="$2"
      shift 2
      ;;
    --resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --name)
      FUNCTION_NAME="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --retry)
      RETRY_COUNT="$2"
      shift 2
      ;;
    --delay)
      RETRY_DELAY="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$FUNCTION_URL" ]; then
  echo -e "${RED}Error: --url is required${NC}"
  exit 1
fi

echo "========================================="
echo "Azure Function App Integration Test"
echo "========================================="
echo "URL: $FUNCTION_URL"
echo "Resource Group: ${RESOURCE_GROUP:-N/A}"
echo "Function Name: ${FUNCTION_NAME:-N/A}"
echo ""

PASSED=0
FAILED=0
WARNINGS=0

# Test 1: HTTPS endpoint accessibility
echo -n "Test 1: HTTPS endpoint accessible... "
for i in $(seq 1 $RETRY_COUNT); do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$FUNCTION_URL" || echo "000")
  
  if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 401 ] || [ "$HTTP_STATUS" -eq 404 ]; then
    # 200 = OK, 401 = Auth required (expected), 404 = No default route (expected)
    echo -e "${GREEN}✓ PASSED${NC} (HTTP $HTTP_STATUS)"
    PASSED=$((PASSED + 1))
    break
  elif [ $i -lt $RETRY_COUNT ]; then
    echo -n "retrying ($i/$RETRY_COUNT)... "
    sleep $RETRY_DELAY
  else
    echo -e "${RED}✗ FAILED${NC} (HTTP $HTTP_STATUS)"
    FAILED=$((FAILED + 1))
  fi
done

# Test 2: Response time check
echo -n "Test 2: Response time under threshold... "
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time $TIMEOUT "$FUNCTION_URL" 2>/dev/null || echo "999")
RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc -l | cut -d'.' -f1)

if [ "$RESPONSE_MS" -lt "$THRESHOLD_MS" ]; then
  echo -e "${GREEN}✓ PASSED${NC} (${RESPONSE_MS}ms)"
  PASSED=$((PASSED + 1))
else
  echo -e "${YELLOW}⚠ WARNING${NC} (${RESPONSE_MS}ms exceeds ${THRESHOLD_MS}ms threshold)"
  WARNINGS=$((WARNINGS + 1))
fi

# Test 3: HTTPS enforcement (reject HTTP)
echo -n "Test 3: HTTPS enforcement... "
HTTP_URL=$(echo "$FUNCTION_URL" | sed 's/https:/http:/')
HTTP_REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$HTTP_URL" 2>/dev/null || echo "000")

if [ "$HTTP_REDIRECT" -eq 301 ] || [ "$HTTP_REDIRECT" -eq 302 ] || [ "$HTTP_REDIRECT" -eq 307 ] || [ "$HTTP_REDIRECT" -eq 000 ]; then
  echo -e "${GREEN}✓ PASSED${NC} (HTTP redirects or blocked)"
  PASSED=$((PASSED + 1))
else
  echo -e "${YELLOW}⚠ WARNING${NC} (HTTP not redirected, status: $HTTP_REDIRECT)"
  WARNINGS=$((WARNINGS + 1))
fi

# Test 4: Health endpoint check (if Azure CLI available and resource details provided)
if command -v az >/dev/null 2>&1 && [ -n "$RESOURCE_GROUP" ] && [ -n "$FUNCTION_NAME" ]; then
  echo -n "Test 4: Function App status... "
  
  APP_STATE=$(az functionapp show \
    --name "$FUNCTION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "state" \
    --output tsv 2>/dev/null || echo "Unknown")
  
  if [ "$APP_STATE" = "Running" ]; then
    echo -e "${GREEN}✓ PASSED${NC} (State: $APP_STATE)"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗ FAILED${NC} (State: $APP_STATE)"
    FAILED=$((FAILED + 1))
  fi
  
  # Test 5: Application Insights connection
  echo -n "Test 5: Application Insights configured... "
  
  APPINSIGHTS_KEY=$(az functionapp config appsettings list \
    --name "$FUNCTION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?name=='APPINSIGHTS_INSTRUMENTATIONKEY'].value" \
    --output tsv 2>/dev/null || echo "")
  
  if [ -n "$APPINSIGHTS_KEY" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${YELLOW}⚠ WARNING${NC} (Application Insights not configured)"
    WARNINGS=$((WARNINGS + 1))
  fi
  
  # Test 6: HTTPS-only setting
  echo -n "Test 6: HTTPS-only enforcement (config)... "
  
  HTTPS_ONLY=$(az functionapp show \
    --name "$FUNCTION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "httpsOnly" \
    --output tsv 2>/dev/null || echo "false")
  
  if [ "$HTTPS_ONLY" = "true" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗ FAILED${NC} (HTTPS-only not enforced)"
    FAILED=$((FAILED + 1))
  fi
else
  echo "Tests 4-6: Skipped (Azure CLI not available or resource details not provided)"
fi

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}Overall Status: HEALTHY ✓${NC}"
  exit 0
else
  echo -e "${RED}Overall Status: UNHEALTHY ✗${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "1. Wait 2-3 minutes for Function App to fully start"
  echo "2. Check logs: az webapp log tail --name $FUNCTION_NAME --resource-group $RESOURCE_GROUP"
  echo "3. Verify in Azure Portal: https://portal.azure.com"
  exit 1
fi
