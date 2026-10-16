---
name: aws-cost-estimator
description: "Estimate monthly costs for AWS resources using the AWS Pricing API. Parses CloudFormation templates to identify resources, service types, and regions, then looks up real AWS retail pricing. Produces a per-resource cost breakdown with monthly totals. Use during template generation or when user asks about costs."
argument-hint: "CloudFormation template JSON/YAML or list of AWS resources with instance types and region"
user-invocable: true
last_updated: "2026-04-15"
---

# AWS Cost Estimator

Estimate monthly costs for AWS resources using the **AWS Pricing API** — a REST API that returns real AWS retail pricing data.

## When to Use

- During CloudFormation template generation to show cost estimates before deployment
- When user asks "how much will this cost?" or "estimate costs"
- To compare cost of different instance types or service tiers
- To validate budget constraints before deployment

## API Reference

**Endpoint:** `https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/{SERVICE}/current/index.json`

**Alternative (Bulk Price List API):**
```
GET https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonEC2/current/{region}/index.json
```

**Key facts:**
- No authentication required for public pricing pages
- Prices are in USD by default
- Use the AWS Pricing Calculator for complex scenarios: https://calculator.aws/
- Always note the retrieval date in estimates

## Procedure

### 1. Parse CloudFormation Template Resources

Extract from the CloudFormation template:
- Resource type (`AWS::EC2::Instance`, `AWS::RDS::DBInstance`, etc.)
- Instance/class size (e.g., `t3.micro`, `db.t3.medium`)
- Region (from template parameter or default)
- Storage sizes and types
- Any quantity-affecting properties

### 2. Map Resource Types to Pricing

Use the AWS Pricing API or well-known current rates for common services.

**Query pattern using AWS CLI:**
```bash
# Get pricing for EC2 instances
aws pricing get-products \
  --service-code AmazonEC2 \
  --filters \
    "Type=TERM_MATCH,Field=instanceType,Value=t3.micro" \
    "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
    "Type=TERM_MATCH,Field=location,Value=US East (N. Virginia)" \
    "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
    "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
    "Type=TERM_MATCH,Field=capacityStatus,Value=Used" \
  --region us-east-1 \
  --query 'PriceList[0]' --output text | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
for term in data['terms']['OnDemand'].values():
    for price_dim in term['priceDimensions'].values():
        print(f\"{price_dim['description']}: \${price_dim['pricePerUnit']['USD']}/hr\")
"
```

### Resource Type Mapping

#### EC2 Instances (`AWS::EC2::Instance`)

**Service code:** `AmazonEC2`

| CloudFormation Property | Pricing Filter |
|------------------------|---------------|
| `Properties.InstanceType` | `instanceType` |
| `Properties.ImageId` (OS detection) | `operatingSystem`: Linux or Windows |

**Unit:** Per hour → multiply by **730** for monthly estimate.

**Common instance pricing (us-east-1, Linux, On-Demand):**
| Instance | vCPU | RAM | Est. $/month |
|----------|------|-----|-------------|
| t3.micro | 2 | 1 GB | ~$7.59 |
| t3.small | 2 | 2 GB | ~$15.18 |
| t3.medium | 2 | 4 GB | ~$30.37 |
| t3.large | 2 | 8 GB | ~$60.74 |
| m6i.large | 2 | 8 GB | ~$69.35 |
| c6i.large | 2 | 4 GB | ~$61.20 |

#### EBS Volumes (`AWS::EC2::Volume`)

**Service code:** `AmazonEC2`

| Volume Type | CloudFormation `VolumeType` | Approximate Cost |
|-------------|---------------------------|-----------------|
| gp3 | `gp3` | ~$0.08/GB/month |
| gp2 | `gp2` | ~$0.10/GB/month |
| io1 | `io1` | ~$0.125/GB/month + $0.065/IOPS/month |
| st1 | `st1` | ~$0.045/GB/month |

#### S3 Buckets (`AWS::S3::Bucket`)

**Service code:** `AmazonS3`

- Standard storage: ~$0.023/GB/month
- Intelligent-Tiering (frequent): ~$0.023/GB/month
- Standard-IA: ~$0.0125/GB/month
- Glacier Instant: ~$0.004/GB/month
- PUT/POST requests: ~$0.005/1,000 requests
- GET requests: ~$0.0004/1,000 requests

*Note: No fixed monthly cost — estimate based on expected data volume.*

#### RDS Instances (`AWS::RDS::DBInstance`)

**Service code:** `AmazonRDS`

| DB Instance Class | Engine | Est. $/month (Multi-AZ) |
|-------------------|--------|------------------------|
| db.t3.micro | MySQL/PostgreSQL | ~$28 (Multi-AZ ~$57) |
| db.t3.medium | MySQL/PostgreSQL | ~$57 (Multi-AZ ~$115) |
| db.m6g.large | MySQL/PostgreSQL | ~$138 (Multi-AZ ~$277) |
| db.r6g.large | MySQL/PostgreSQL | ~$182 (Multi-AZ ~$365) |

Plus: Storage at ~$0.115/GB/month (gp2) or ~$0.115/GB/month (gp3 base)

#### Lambda Functions (`AWS::Lambda::Function`)

**Service code:** `AWSLambda`

**Consumption plan pricing:**
- First 1M requests/month: **FREE**
- Additional requests: $0.20 per 1M requests
- First 400,000 GB-seconds/month: **FREE**
- Additional GB-seconds: $0.0000166667 per GB-second

**Example (128 MB, 500ms avg, 1M invocations/month):**
- Compute: 1M × 0.5s × 0.125 GB × $0.0000166667 = ~$1.04
- Requests: $0.20
- **Total: ~$1.24/month** (first 1M invocations included)

#### DynamoDB Tables (`AWS::DynamoDB::Table`)

**Service code:** `AmazonDynamoDB`

- **On-Demand**: $1.25 per million write request units, $0.25 per million read request units
- **Provisioned**: $0.00065/WCU/hour, $0.00013/RCU/hour
- Storage: $0.25/GB/month
- PITR: $0.20/GB/month

#### ECS/Fargate Tasks (`AWS::ECS::TaskDefinition`)

**Service code:** `AmazonECS`

- vCPU: $0.04048/vCPU/hour
- Memory: $0.004445/GB/hour

**Example (0.5 vCPU, 1 GB, running 730 hours/month):**
- vCPU: 0.5 × $0.04048 × 730 = ~$14.78
- Memory: 1 × $0.004445 × 730 = ~$3.24
- **Total: ~$18.02/month**

#### EKS Clusters (`AWS::EKS::Cluster`)

- Control plane: **$0.10/hour** = ~$73/month (fixed)
- Worker nodes (EC2): priced as EC2 instances separately

#### Secrets Manager (`AWS::SecretsManager::Secret`)

- $0.40/secret/month
- $0.05 per 10,000 API calls

#### CloudWatch Logs

- Ingestion: $0.50/GB
- Storage: $0.03/GB/month
- Insights queries: $0.005/GB scanned

### 3. Calculate Monthly Costs

Apply the correct multiplier:

| Unit | Monthly Multiplier | Notes |
|------|-------------------|-------|
| Per hour | × 730 | 365 days × 24 hours ÷ 12 months |
| Per GB/month | × estimated GB | Use actual or default estimate |
| Per month | × 1 | Already monthly |
| Per request | × estimated volume | Estimate based on workload |

### 4. Handle Free Tier

Note any AWS Free Tier allowances (first 12 months or always free):

| Service | Free Tier |
|---------|-----------|
| Lambda | 1M requests + 400K GB-s/month (always free) |
| DynamoDB | 25 GB storage + 25 WCU + 25 RCU (always free) |
| S3 | 5 GB Standard storage (12 months) |
| EC2 | 750 hours t2.micro/t3.micro (12 months) |
| RDS | 750 hours db.t2.micro/db.t3.micro (12 months) |
| CloudWatch | 10 custom metrics + 5 GB logs (always free) |

### 5. Present Cost Estimate

Format the output as a clear cost breakdown:

```markdown
### 💰 Estimated Monthly Cost

| # | Resource | Type | SKU/Tier | Est. Monthly |
|---|----------|------|----------|-------------|
| 1 | MyWebServer | EC2 Instance | t3.medium (Linux) | $30.37 |
| 2 | MyWebServer OS Disk | EBS Volume | 20 GB gp3 | $1.60 |
| 3 | MyDatabase | RDS PostgreSQL | db.t3.medium Multi-AZ | $115.00 |
| 4 | MyDatabase Storage | RDS Storage | 100 GB gp3 | $11.50 |
| 5 | MyBucket | S3 Storage | Standard ~50 GB | $1.15 |
| 6 | MyFunction | Lambda | ~1M invocations | $0.20 |
| | | | **Total** | **$159.82/mo** |

**Notes:**
- Prices are AWS retail (pay-as-you-go) in USD for us-east-1
- Actual costs may vary with Reserved Instances, Savings Plans, or enterprise agreements
- Data transfer costs not included (first 100 GB/month outbound: $0.09/GB)
- Estimates based on 24/7 operation (730 hours/month)
- Prices current as of 2026-04-15 — verify at https://calculator.aws/

**Cost Optimization Opportunities:**
- 💡 EC2 1-Year Reserved Instance: ~40% savings on compute
- 💡 EC2 3-Year Reserved Instance: ~60% savings on compute
- 💡 RDS Reserved Instance (1-year): ~40% savings on database
- 💡 Use Savings Plans for flexible commitment discounts
```

### 6. Save Cost Estimate

Save the estimate to deployment artifacts:

**File:** `.aws/deployments/{deployment-id}/cost-estimate.json`

```json
{
  "estimatedAt": "2026-04-15T00:00:00Z",
  "currency": "USD",
  "region": "us-east-1",
  "monthlyTotal": 159.82,
  "resources": [
    {
      "name": "MyWebServer",
      "type": "AWS::EC2::Instance",
      "sku": "t3.medium",
      "unitPrice": 0.0416,
      "unitOfMeasure": "1 Hour",
      "monthlyEstimate": 30.37
    }
  ],
  "notes": [
    "Retail pay-as-you-go pricing",
    "Data transfer not included"
  ],
  "source": "AWS Pricing API",
  "sourceUrl": "https://pricing.us-east-1.amazonaws.com"
}
```

## Error Handling

**If a price cannot be determined:**
- Show `❓ Price not found` with the resource type and instance size
- Link to the AWS Pricing Calculator: https://calculator.aws/
- Never fabricate a price — show `Unknown` and provide the manual lookup URL

**If the API is unreachable:**
- Fall back to a note: "Cost estimation unavailable — verify at https://calculator.aws/"
- Use the well-known rates table above for common resource types as a fallback estimate

## Constraints

- **DO NOT** fabricate or guess prices — use the pricing table above or query the API
- **DO NOT** use hardcoded prices without noting they may be outdated
- **ALWAYS** show the pricing date so users know how current the estimate is
- **ALWAYS** note that actual costs may differ from retail pricing (Reserved Instances, Savings Plans, EDP)
- **ALWAYS** note that data transfer costs are not included in the estimate

## References

- [AWS Pricing Calculator](https://calculator.aws/)
- [AWS Pricing API](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/price-changes.html)
- [EC2 Pricing](https://aws.amazon.com/ec2/pricing/)
- [RDS Pricing](https://aws.amazon.com/rds/pricing/)
- [Lambda Pricing](https://aws.amazon.com/lambda/pricing/)
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)
- [Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
