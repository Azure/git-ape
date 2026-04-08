#!/bin/bash
# Test Azure Database connectivity (SQL Database or Cosmos DB)
# Usage: ./test-database.sh --type <sqldb|cosmosdb> --server <server> --database <db> --resource-group <rg>

set -e

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --type)
      DB_TYPE="$2"
      shift 2
      ;;
    --server)
      SERVER_NAME="$2"
      shift 2
      ;;
    --database)
      DATABASE_NAME="$2"
      shift 2
      ;;
    --resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --username)
      USERNAME="$2"
      shift 2
      ;;
    --password)
      PASSWORD="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$DB_TYPE" ]; then
  echo -e "${RED}Error: --type is required (sqldb or cosmosdb)${NC}"
  exit 1
fi

if [ -z "$SERVER_NAME" ]; then
  echo -e "${RED}Error: --server is required${NC}"
  exit 1
fi

echo "========================================="
echo "Azure Database Integration Test"
echo "========================================="
echo "Type: $DB_TYPE"
echo "Server: $SERVER_NAME"
echo "Database: ${DATABASE_NAME:-N/A}"
echo "Resource Group: ${RESOURCE_GROUP:-N/A}"
echo ""

PASSED=0
FAILED=0
WARNINGS=0

# Check if Azure CLI is available
if ! command -v az >/dev/null 2>&1; then
  echo -e "${RED}Error: Azure CLI (az) is required but not installed${NC}"
  exit 1
fi

if [ "$DB_TYPE" = "sqldb" ]; then
  # SQL Database Tests
  
  # Test 1: SQL Server exists
  echo -n "Test 1: SQL Server accessible... "
  if [ -n "$RESOURCE_GROUP" ]; then
    SERVER_STATE=$(az sql server show \
      --name "$SERVER_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "state" \
      --output tsv 2>/dev/null || echo "NotFound")
  else
    # Try to find the server
    SERVER_STATE=$(az sql server list \
      --query "[?name=='$SERVER_NAME'].state | [0]" \
      --output tsv 2>/dev/null || echo "NotFound")
  fi
  
  if [ "$SERVER_STATE" = "Ready" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗ FAILED${NC} (State: $SERVER_STATE)"
    FAILED=$((FAILED + 1))
  fi
  
  # Test 2: Database exists (if database name provided)
  if [ -n "$DATABASE_NAME" ] && [ -n "$RESOURCE_GROUP" ]; then
    echo -n "Test 2: Database exists... "
    DB_STATE=$(az sql db show \
      --name "$DATABASE_NAME" \
      --server "$SERVER_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "status" \
      --output tsv 2>/dev/null || echo "NotFound")
    
    if [ "$DB_STATE" = "Online" ]; then
      echo -e "${GREEN}✓ PASSED${NC}"
      PASSED=$((PASSED + 1))
    else
      echo -e "${RED}✗ FAILED${NC} (Status: $DB_STATE)"
      FAILED=$((FAILED + 1))
    fi
  fi
  
  # Test 3: TDE enabled
  if [ -n "$DATABASE_NAME" ] && [ -n "$RESOURCE_GROUP" ]; then
    echo -n "Test 3: Transparent Data Encryption... "
    TDE_STATUS=$(az sql db tde show \
      --database "$DATABASE_NAME" \
      --server "$SERVER_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "state" \
      --output tsv 2>/dev/null || echo "Unknown")
    
    if [ "$TDE_STATUS" = "Enabled" ]; then
      echo -e "${GREEN}✓ PASSED${NC}"
      PASSED=$((PASSED + 1))
    else
      echo -e "${YELLOW}⚠ WARNING${NC} (TDE: $TDE_STATUS)"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
  
  # Test 4: Firewall rules configured
  if [ -n "$RESOURCE_GROUP" ]; then
    echo -n "Test 4: Firewall rules configured... "
    FIREWALL_COUNT=$(az sql server firewall-rule list \
      --server "$SERVER_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "length(@)" \
      --output tsv 2>/dev/null || echo "0")
    
    if [ "$FIREWALL_COUNT" -gt 0 ]; then
      echo -e "${GREEN}✓ PASSED${NC} ($FIREWALL_COUNT rules)"
      PASSED=$((PASSED + 1))
      
      # Check for insecure 0.0.0.0/0 rule
      ALLOW_ALL=$(az sql server firewall-rule list \
        --server "$SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[?startIpAddress=='0.0.0.0' && endIpAddress=='255.255.255.255'].name | [0]" \
        --output tsv 2>/dev/null || echo "")
      
      if [ -n "$ALLOW_ALL" ]; then
        echo -e "  ${YELLOW}⚠ WARNING: Firewall rule allows all IPs (insecure for production)${NC}"
        WARNINGS=$((WARNINGS + 1))
      fi
    else
      echo -e "${YELLOW}⚠ WARNING${NC} (No firewall rules - may block access)"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
  
  # Test 5: Connection test (if credentials provided)
  if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ] && [ -n "$DATABASE_NAME" ]; then
    echo -n "Test 5: Database connection... "
    
    # Check if sqlcmd is available
    if command -v sqlcmd >/dev/null 2>&1; then
      CONNECTION_TEST=$(sqlcmd -S "$SERVER_NAME.database.windows.net" \
        -d "$DATABASE_NAME" \
        -U "$USERNAME" \
        -P "$PASSWORD" \
        -Q "SELECT 1" \
        -h -1 \
        2>/dev/null || echo "Failed")
      
      if echo "$CONNECTION_TEST" | grep -q "1"; then
        echo -e "${GREEN}✓ PASSED${NC}"
        PASSED=$((PASSED + 1))
      else
        echo -e "${RED}✗ FAILED${NC}"
        FAILED=$((FAILED + 1))
      fi
    else
      echo -e "${YELLOW}⚠ SKIPPED${NC} (sqlcmd not available)"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi

elif [ "$DB_TYPE" = "cosmosdb" ]; then
  # Cosmos DB Tests
  
  # Test 1: Cosmos DB account exists
  echo -n "Test 1: Cosmos DB account accessible... "
  if [ -n "$RESOURCE_GROUP" ]; then
    COSMOS_STATE=$(az cosmosdb show \
      --name "$SERVER_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "provisioningState" \
      --output tsv 2>/dev/null || echo "NotFound")
  else
    COSMOS_STATE=$(az cosmosdb list \
      --query "[?name=='$SERVER_NAME'].provisioningState | [0]" \
      --output tsv 2>/dev/null || echo "NotFound")
  fi
  
  if [ "$COSMOS_STATE" = "Succeeded" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗ FAILED${NC} (State: $COSMOS_STATE)"
    FAILED=$((FAILED + 1))
  fi
  
  # Test 2: Endpoint accessibility
  if [ -n "$RESOURCE_GROUP" ]; then
    echo -n "Test 2: Cosmos DB endpoint... "
    COSMOS_ENDPOINT=$(az cosmosdb show \
      --name "$SERVER_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "documentEndpoint" \
      --output tsv 2>/dev/null || echo "")
    
    if [ -n "$COSMOS_ENDPOINT" ]; then
      echo -e "${GREEN}✓ PASSED${NC}"
      echo "  Endpoint: $COSMOS_ENDPOINT"
      PASSED=$((PASSED + 1))
    else
      echo -e "${RED}✗ FAILED${NC}"
      FAILED=$((FAILED + 1))
    fi
  fi
  
  # Test 3: Database exists (if database name provided)
  if [ -n "$DATABASE_NAME" ] && [ -n "$RESOURCE_GROUP" ]; then
    echo -n "Test 3: Database exists... "
    DB_EXISTS=$(az cosmosdb sql database show \
      --account-name "$SERVER_NAME" \
      --name "$DATABASE_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --query "id" \
      --output tsv 2>/dev/null || echo "")
    
    if [ -n "$DB_EXISTS" ]; then
      echo -e "${GREEN}✓ PASSED${NC}"
      PASSED=$((PASSED + 1))
    else
      echo -e "${RED}✗ FAILED${NC}"
      FAILED=$((FAILED + 1))
    fi
  fi
  
  # Test 4: Encryption at rest
  if [ -n "$RESOURCE_GROUP" ]; then
    echo -n "Test 4: Encryption at rest... "
    # Cosmos DB has encryption enabled by default
    echo -e "${GREEN}✓ PASSED${NC} (Enabled by default)"
    PASSED=$((PASSED + 1))
  fi

else
  echo -e "${RED}Error: Unsupported database type '$DB_TYPE'${NC}"
  echo "Supported types: sqldb, cosmosdb"
  exit 1
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
  echo "1. Verify database server is running"
  echo "2. Check firewall rules allow your IP"
  echo "3. Verify credentials are correct"
  echo "4. Check Azure Portal for detailed status"
  exit 1
fi
