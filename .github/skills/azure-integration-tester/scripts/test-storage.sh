#!/bin/bash
# Test Azure Storage Account connectivity and operations
# Usage: ./test-storage.sh --account-name <storage-account> --resource-group <rg>

set -e

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --account-name)
      STORAGE_ACCOUNT="$2"
      shift 2
      ;;
    --resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --container)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$STORAGE_ACCOUNT" ]; then
  echo -e "${RED}Error: --account-name is required${NC}"
  exit 1
fi

# Default container name for testing
CONTAINER_NAME=${CONTAINER_NAME:-"integration-test-$(date +%s)"}
TEST_BLOB="test-blob-$(date +%s).txt"
TEST_CONTENT="Azure Storage Integration Test - $(date)"

echo "========================================="
echo "Azure Storage Account Integration Test"
echo "========================================="
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Resource Group: ${RESOURCE_GROUP:-N/A}"
echo "Test Container: $CONTAINER_NAME"
echo ""

PASSED=0
FAILED=0
WARNINGS=0

# Check if Azure CLI is available
if ! command -v az >/dev/null 2>&1; then
  echo -e "${RED}Error: Azure CLI (az) is required but not installed${NC}"
  exit 1
fi

# Test 1: Storage account exists and is accessible
echo -n "Test 1: Storage account accessible... "
if [ -n "$RESOURCE_GROUP" ]; then
  ACCOUNT_STATUS=$(az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --query "provisioningState" \
    --output tsv 2>/dev/null || echo "NotFound")
else
  ACCOUNT_STATUS=$(az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --query "provisioningState" \
    --output tsv 2>/dev/null || echo "NotFound")
fi

if [ "$ACCOUNT_STATUS" = "Succeeded" ]; then
  echo -e "${GREEN}✓ PASSED${NC}"
  PASSED=$((PASSED + 1))
else
  echo -e "${RED}✗ FAILED${NC} (Status: $ACCOUNT_STATUS)"
  FAILED=$((FAILED + 1))
  exit 1
fi

# Get storage account key for subsequent tests
echo -n "Test 2: Retrieving storage account key... "
if [ -n "$RESOURCE_GROUP" ]; then
  STORAGE_KEY=$(az storage account keys list \
    --account-name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].value" \
    --output tsv 2>/dev/null)
else
  STORAGE_KEY=$(az storage account keys list \
    --account-name "$STORAGE_ACCOUNT" \
    --query "[0].value" \
    --output tsv 2>/dev/null)
fi

if [ -n "$STORAGE_KEY" ]; then
  echo -e "${GREEN}✓ PASSED${NC}"
  PASSED=$((PASSED + 1))
else
  echo -e "${RED}✗ FAILED${NC} (Could not retrieve key)"
  FAILED=$((FAILED + 1))
  exit 1
fi

# Test 3: HTTPS-only enforcement
echo -n "Test 3: HTTPS-only enforcement... "
if [ -n "$RESOURCE_GROUP" ]; then
  HTTPS_ONLY=$(az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --query "enableHttpsTrafficOnly" \
    --output tsv 2>/dev/null)
else
  HTTPS_ONLY=$(az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --query "enableHttpsTrafficOnly" \
    --output tsv 2>/dev/null)
fi

if [ "$HTTPS_ONLY" = "true" ]; then
  echo -e "${GREEN}✓ PASSED${NC}"
  PASSED=$((PASSED + 1))
else
  echo -e "${RED}✗ FAILED${NC} (HTTPS-only not enforced)"
  FAILED=$((FAILED + 1))
fi

# Test 4: Minimum TLS version
echo -n "Test 4: Minimum TLS version... "
if [ -n "$RESOURCE_GROUP" ]; then
  TLS_VERSION=$(az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --query "minimumTlsVersion" \
    --output tsv 2>/dev/null || echo "Unknown")
else
  TLS_VERSION=$(az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --query "minimumTlsVersion" \
    --output tsv 2>/dev/null || echo "Unknown")
fi

if [ "$TLS_VERSION" = "TLS1_2" ] || [ "$TLS_VERSION" = "TLS1_3" ]; then
  echo -e "${GREEN}✓ PASSED${NC} (TLS $TLS_VERSION)"
  PASSED=$((PASSED + 1))
else
  echo -e "${YELLOW}⚠ WARNING${NC} (TLS version: $TLS_VERSION)"
  WARNINGS=$((WARNINGS + 1))
fi

# Test 5: Create test container
echo -n "Test 5: Create test container... "
CREATE_RESULT=$(az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --output tsv 2>/dev/null || echo "false")

if [ "$CREATE_RESULT" = "true" ] || [ "$CREATE_RESULT" = "True" ]; then
  echo -e "${GREEN}✓ PASSED${NC}"
  PASSED=$((PASSED + 1))
  CLEANUP_CONTAINER=true
else
  echo -e "${RED}✗ FAILED${NC}"
  FAILED=$((FAILED + 1))
  CLEANUP_CONTAINER=false
fi

# Test 6: Upload test blob
if [ "$CLEANUP_CONTAINER" = true ]; then
  echo -n "Test 6: Upload blob... "
  echo "$TEST_CONTENT" > "/tmp/$TEST_BLOB"
  
  UPLOAD_RESULT=$(az storage blob upload \
    --file "/tmp/$TEST_BLOB" \
    --container-name "$CONTAINER_NAME" \
    --name "$TEST_BLOB" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --output tsv 2>/dev/null || echo "false")
  
  if echo "$UPLOAD_RESULT" | grep -q "True\|true\|Uploaded"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED=$((FAILED + 1))
  fi
  
  # Test 7: Download and verify blob
  echo -n "Test 7: Download and verify blob... "
  az storage blob download \
    --container-name "$CONTAINER_NAME" \
    --name "$TEST_BLOB" \
    --file "/tmp/$TEST_BLOB.downloaded" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --output none 2>/dev/null
  
  DOWNLOADED_CONTENT=$(cat "/tmp/$TEST_BLOB.downloaded" 2>/dev/null || echo "")
  
  if [ "$DOWNLOADED_CONTENT" = "$TEST_CONTENT" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗ FAILED${NC} (Content mismatch)"
    FAILED=$((FAILED + 1))
  fi
  
  # Test 8: Delete test blob
  echo -n "Test 8: Delete blob... "
  az storage blob delete \
    --container-name "$CONTAINER_NAME" \
    --name "$TEST_BLOB" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --output none 2>/dev/null
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED=$((FAILED + 1))
  fi
  
  # Cleanup
  echo -n "Cleanup: Deleting test container... "
  az storage container delete \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --output none 2>/dev/null
  echo "Done"
  
  # Cleanup temp files
  rm -f "/tmp/$TEST_BLOB" "/tmp/$TEST_BLOB.downloaded" 2>/dev/null
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
  echo "1. Verify network access (firewall rules, VNet restrictions)"
  echo "2. Check storage account status in Azure Portal"
  echo "3. Verify permissions and access keys"
  exit 1
fi
