---
title: "Azure Cost Estimator"
sidebar_label: "Azure Cost Estimator"
description: "Estimate monthly costs for Azure resources by querying the Azure Retail Prices API. Parses ARM templates to identify resources, SKUs, and regions, then looks up real retail pricing. Produces a per-resource cost breakdown with monthly totals. Use during template generation or when user asks about costs."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/azure-cost-estimator/SKILL.md -->


# Azure Cost Estimator

> Estimate monthly costs for Azure resources by querying the Azure Retail Prices API. Parses ARM templates to identify resources, SKUs, and regions, then looks up real retail pricing. Produces a per-resource cost breakdown with monthly totals. Use during template generation or when user asks about costs.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/azure-cost-estimator/` |
| **Phase** | Pre-Deploy |
| **User Invocable** | ✅ Yes |
| **Usage** | `/azure-cost-estimator ARM template JSON or list of resources with SKUs and region` |


## Documentation

# Azure Cost Estimator

Estimate monthly costs for Azure resources using the **Azure Retail Prices API** — a free, unauthenticated REST API that returns real Microsoft retail pricing.

## When to Use

- During template generation (Stage 2) to show cost estimates before deployment
- When user asks "how much will this cost?" or "estimate costs"
- To compare cost of different SKU options
- To validate budget constraints before deployment

## API Reference

**Endpoint:** `https://prices.azure.com/api/retail/prices`

**Key facts:**
- No authentication required
- OData `$filter` for targeted queries
- Filter values are **case-sensitive** (e.g., `'Virtual Machines'` not `'virtual machines'`)
- Returns max 1,000 records per page (use `NextPageLink` for pagination)
- Currency defaults to USD; override with `currencyCode='EUR'` etc.
- Always filter for `priceType eq 'Consumption'` and `isPrimaryMeterRegion eq true` unless looking for reservations

**Filterable fields:** `armRegionName`, `serviceName`, `armSkuName`, `meterName`, `productName`, `skuName`, `serviceFamily`, `priceType`

## Procedure

### 1. Parse ARM Template Resources

Extract from the ARM template:
- Resource type (`Microsoft.Compute/virtualMachines`, `Microsoft.Storage/storageAccounts`, etc.)
- SKU/size (e.g., `Standard_B1ls`, `Standard_LRS`)
- Region (`armRegionName` value, e.g., `southeastasia`, `eastus`)
- Any quantity-affecting properties (disk size, number of instances, reserved capacity)

### 2. Map Resource Types to Pricing API Queries

Use the mapping table below to construct the correct API filter for each resource type. Run each query using `curl` in the terminal.

**Query pattern:**
```bash
curl -s "https://prices.azure.com/api/retail/prices?\$filter=<FILTER>" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('Items', []):
    print(f\"{item['meterName']:30s} {item['retailPrice']:>10.6f} {item['unitOfMeasure']:15s} {item['productName']}\")
"
```

### Resource Type Mapping

#### Virtual Machines (`Microsoft.Compute/virtualMachines`)

```
serviceName eq 'Virtual Machines'
and armRegionName eq '{region}'
and armSkuName eq '{vmSize}'
and priceType eq 'Consumption'
and contains(productName, 'Linux')      # or 'Windows' based on osProfile
```

Pick the result where `meterName` matches the SKU base name (e.g., `B1ls` for `Standard_B1ls`).
**Unit:** `1 Hour` → multiply by **730** for monthly estimate.

**OS detection from ARM template:**
- `osProfile.linuxConfiguration` present → Linux
- `osProfile.windowsConfiguration` present → Windows

#### Managed Disks (`Microsoft.Compute/disks` or implicit VM OS disk)

```
serviceName eq 'Storage'
and armRegionName eq '{region}'
and meterName eq '{diskTier} LRS Disk'    # e.g., 'P4 LRS Disk', 'S4 LRS Disk'
and priceType eq 'Consumption'
```

**Disk tier mapping** (from `diskSizeGB` or `sku.name`):
| ARM `sku.name` | Prefix | Sizes |
|----------------|--------|-------|
| Premium_LRS | P | P4 (32GB), P6 (64GB), P10 (128GB), P15 (256GB), P20 (512GB), P30 (1TB) |
| StandardSSD_LRS | E | E4, E6, E10, E15, E20, E30 |
| Standard_LRS | S | S4, S6, S10, S15, S20, S30 |

If VM uses `osDisk.managedDisk.storageAccountType` → use that to determine the tier.
**Unit:** `1/Month` → use directly.

#### Storage Accounts (`Microsoft.Storage/storageAccounts`)

```
serviceName eq 'Storage'
and armRegionName eq '{region}'
and skuName eq '{redundancy}'            # e.g., 'Standard LRS', 'Standard GRS'
and meterName eq 'LRS Data Stored'       # or 'GRS Data Stored'
and productName eq 'Blob Storage'
and priceType eq 'Consumption'
```

**Unit:** `1 GB/Month` → estimate based on expected storage. Use **10 GB** as default if unknown.
Also add transaction costs: search for `meterName eq 'Write Operations'` (per 10,000 ops).

#### Function Apps (`Microsoft.Web/sites` with `kind: functionapp`)

**Consumption plan:**
```
serviceName eq 'Functions'
and armRegionName eq '{region}'
and priceType eq 'Consumption'
```

Key meters:
- `Execution Time` — per GB-s ($0.000016/GB-s, first 400,000 GB-s/month free)
- `Total Executions` — per execution ($0.20/million, first 1M/month free)

**Dedicated plan:** Price the App Service Plan instead (see below).

#### App Service Plans (`Microsoft.Web/serverfarms`)

```
serviceName eq 'Azure App Service'
and armRegionName eq '{region}'
and armSkuName eq '{skuName}'            # e.g., 'B1', 'S1', 'P1v3'
and priceType eq 'Consumption'
```

**Unit:** `1 Hour` → multiply by **730** for monthly.

#### SQL Database (`Microsoft.Sql/servers/databases`)

**DTU model:**
```
serviceName eq 'SQL Database'
and armRegionName eq '{region}'
and meterName eq '{tier} DTUs'           # e.g., 'Basic DTUs', 'S1 DTUs'
and priceType eq 'Consumption'
```

**vCore model:**
```
serviceName eq 'SQL Database'
and armRegionName eq '{region}'
and skuName eq '{tier}'
and priceType eq 'Consumption'
```

#### Cosmos DB (`Microsoft.DocumentDB/databaseAccounts`)

```
serviceName eq 'Azure Cosmos DB'
and armRegionName eq '{region}'
and meterName eq '100 RU/s'             # or 'Autoscale - 100 RU/s'
and priceType eq 'Consumption'
```

**Unit:** `1 Hour` per 100 RU/s → multiply by **730** × (provisioned RU/s ÷ 100).
Storage: search `meterName eq '1 GB Data Stored'`.

#### Public IP (`Microsoft.Network/publicIPAddresses`)

```
serviceName eq 'Virtual Network'
and armRegionName eq '{region}'
and meterName eq 'Static Public IP'      # or 'Dynamic Public IP' or 'Basic IPv4 Static Public IP Address'
and priceType eq 'Consumption'
```

**Unit:** `1 Hour` → multiply by **730**.

#### Application Insights (`Microsoft.Insights/components`)

```
serviceName eq 'Azure Monitor'
and armRegionName eq '{region}'
and meterName eq 'Data Ingestion'
and priceType eq 'Consumption'
```

**Unit:** `1 GB` — first 5 GB/month free. Estimate **1 GB/month** for dev, **5-10 GB** for prod.

#### Key Vault (`Microsoft.KeyVault/vaults`)

```
serviceName eq 'Key Vault'
and armRegionName eq '{region}'
and priceType eq 'Consumption'
```

Key meters: `Operations` (per 10,000), `Certificate Renewals`, `HSM Key Operations`.
Typically **< $1/month** for dev workloads.

#### Log Analytics Workspace (`Microsoft.OperationalInsights/workspaces`)

```
serviceName eq 'Azure Monitor'
and armRegionName eq '{region}'
and meterName eq 'Pay-as-you-go Data Ingestion'
and priceType eq 'Consumption'
```

**Unit:** `1 GB` — first 5 GB/day free on pay-as-you-go tier.

#### Network Security Group / Virtual Network / NIC

These resources are **free** — no pricing API query needed. Note this in the output:
```
Network Security Group     $0.00/month   (no charge)
Virtual Network            $0.00/month   (no charge)
Network Interface          $0.00/month   (no charge)
```

### 3. Query the API

For each resource, run the constructed query. Use `curl` with proper URL encoding:

```bash
curl -s "https://prices.azure.com/api/retail/prices?\$filter=serviceName%20eq%20%27Virtual%20Machines%27%20and%20armRegionName%20eq%20%27southeastasia%27%20and%20armSkuName%20eq%20%27Standard_B1ls%27%20and%20priceType%20eq%20%27Consumption%27" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('Items', []):
    if item.get('isPrimaryMeterRegion'):
        print(json.dumps({
            'meter': item['meterName'],
            'price': item['retailPrice'],
            'unit': item['unitOfMeasure'],
            'product': item['productName'],
            'sku': item.get('armSkuName', ''),
            'type': item['type']
        }, indent=2))
"
```

### 4. Calculate Monthly Costs

Apply the correct multiplier based on `unitOfMeasure`:

| Unit | Monthly Multiplier | Notes |
|------|-------------------|-------|
| `1 Hour` | × 730 | 365.25 days × 24 hours ÷ 12 months |
| `1 GB/Month` | × estimated GB | Use actual or default estimate |
| `1/Month` | × 1 | Already monthly |
| `100/Month` | × quantity ÷ 100 | Per 100 units/month |
| `1 GB` | × estimated GB | Ingestion-based |
| `10K` | × estimated ops ÷ 10000 | Transaction-based |

### 5. Handle Free Tiers and Included Quantities

Note any free tier allowances in the output:

| Service | Free Allowance |
|---------|---------------|
| Functions (Consumption) | 1M executions + 400K GB-s/month |
| Application Insights | 5 GB ingestion/month |
| Log Analytics | 5 GB/day ingestion |
| Cosmos DB (Serverless) | No minimum, pay per RU |
| Bandwidth | First 5 GB outbound/month |

If the estimated usage falls within the free tier, show `$0.00` with a note.

### 6. Present Cost Estimate

Format the output as a clear cost breakdown:

```markdown
### 💰 Estimated Monthly Cost

| # | Resource | SKU/Tier | Meter | Unit Price | Monthly Est. |
|---|----------|----------|-------|-----------|-------------|
| 1 | vm-linuxvm-dev-sea | Standard_B1ls | B1ls (Linux) | $0.0052/hr | $3.80 |
| 2 | OS Disk (30GB) | Standard_LRS | S4 LRS Disk | $1.54/mo | $1.54 |
| 3 | pip-linuxvm-dev-sea | Basic Static | Static IP | $0.0036/hr | $2.63 |
| 4 | NSG, VNet, NIC | — | — | — | $0.00 |
| | | | | **Total** | **$7.97/mo** |

**Notes:**
- Prices are Microsoft retail (pay-as-you-go) in USD
- Actual costs may vary with reserved instances, savings plans, or enterprise agreements
- Bandwidth egress is not included (first 5 GB/month free)
- Prices retrieved from [Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices) on {date}

**Cost optimization options:**
- 💡 1-Year Reserved Instance: ~{X}% savings
- 💡 3-Year Reserved Instance: ~{Y}% savings
- 💡 Spot Instance: ~{Z}% savings (interruptible)
```

### 7. Save Cost Estimate

Save the estimate to the deployment artifacts:

**File:** `.azure/deployments/{deployment-id}/cost-estimate.json`

```json
{
  "estimatedAt": "2026-02-19T10:00:00Z",
  "currency": "USD",
  "region": "southeastasia",
  "monthlyTotal": 7.97,
  "resources": [
    {
      "name": "vm-linuxvm-dev-southeastasia",
      "type": "Microsoft.Compute/virtualMachines",
      "sku": "Standard_B1ls",
      "meter": "B1ls",
      "unitPrice": 0.0052,
      "unitOfMeasure": "1 Hour",
      "monthlyEstimate": 3.80
    }
  ],
  "notes": [
    "Retail pay-as-you-go pricing",
    "Bandwidth egress not included"
  ],
  "source": "Azure Retail Prices API",
  "sourceUrl": "https://prices.azure.com/api/retail/prices"
}
```

## Error Handling

**If a price is not found for a resource:**
- Try broader filters (remove `armSkuName`, search by `productName` with `contains()`)
- Try alternate `serviceName` values (e.g., `'Azure App Service'` vs `'App Service'`)
- If still not found: show `❓ Price not found` with the query used, so the user can verify manually
- Never fabricate a price — show `Unknown` and link to the Azure Pricing Calculator

**If the API is unreachable:**
- Fall back to a note: "Cost estimation unavailable — API unreachable. Check manually at https://azure.microsoft.com/pricing/calculator/"

## Constraints

- **DO NOT** fabricate or guess prices — all prices must come from the API response
- **DO NOT** use hardcoded prices — always query the API for current rates
- **DO NOT** forget to filter for `isPrimaryMeterRegion eq true` to avoid duplicate results
- **DO NOT** mix up `serviceName` values — they are case-sensitive (e.g., `'Virtual Machines'` not `'virtual machines'`)
- **ALWAYS** show the pricing date so users know how current the estimate is
- **ALWAYS** note that actual costs may differ from retail pricing (EA, CSP, savings plans)
