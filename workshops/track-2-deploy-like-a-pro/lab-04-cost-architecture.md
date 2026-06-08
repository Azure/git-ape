# Lab 4: Cost Estimation and Architecture Review

> 10 minutes | Uses artifacts from Lab 2

Estimate costs with real Azure pricing and get an AI architecture review.

## Part A: Cost Estimation (5 minutes)

### Step 1: Run the Cost Estimator

In Copilot Chat:

```text
/azure-cost-estimator
```

Point it at your deployment from Lab 2.

### Step 2: Read the Cost Breakdown

You'll see a per-resource estimate using the Azure Retail Prices API:

| Resource | SKU | Monthly Cost |
|----------|-----|-------------|
| App Service Plan | B1 | $13.14 |
| SQL Database | Basic (5 DTU) | $4.99 |
| Key Vault | Standard | $0.03 |
| Application Insights | Pay-as-you-go | $2.30 |
| Storage Account | Standard LRS | $0.50 |
| **Total** | | **~$20.96** |

> These are real retail prices from `prices.azure.com`, not guesses.

### Step 3: Compare Dev vs Prod

Ask about production sizing:

```text
What would this cost if I used Standard tier App Service and S1 SQL Database instead?
```

You'll see a comparison showing how costs change with production-grade SKUs.

> **Key insight:** Git-Ape uses Basic/Consumption tiers for dev by default. You control the upgrade path.

## Part B: Architecture Review (5 minutes)

### Step 4: Invoke the Principal Architect

In Copilot Chat:

```text
@azure-principal-architect review my last deployment
```

### Step 5: Read the WAF Assessment

The Principal Architect evaluates your deployment against the Well-Architected Framework's 5 pillars:

**1. Security**
- Managed identity chain (Web App → Key Vault → SQL)
- AAD-only SQL authentication
- HTTPS-only with TLS 1.2

**2. Reliability**
- Single region deployment (acceptable for dev)
- No redundancy configured (expected for B1 tier)
- Application Insights for health monitoring

**3. Performance Efficiency**
- B1 App Service plan (1 core, 1.75 GB RAM)
- Basic SQL (5 DTU)
- Adequate for dev workloads

**4. Cost Optimization**
- Dev-appropriate SKUs selected
- Consumption-based monitoring
- No over-provisioning detected

**5. Operational Excellence**
- Application Insights configured
- Deployment managed through IaC
- Audit trail maintained

### Step 6: Understand Trade-offs

The architect may note:
- "For production, consider Standard tier with auto-scaling"
- "Add a secondary region for disaster recovery"
- "Enable diagnostic logs on SQL Server"

These are recommendations, not blockers. The security gate handles blocking concerns.

## What You Learned

| Concept | What It Means |
|---------|--------------|
| **Real pricing** | Cost estimates use the Azure Retail Prices API — same source as the Azure pricing calculator |
| **Per-resource breakdown** | You see exactly what each resource costs, not just a total |
| **Dev vs Prod comparison** | Easily compare SKU tiers to plan your upgrade path |
| **WAF 5 pillars** | Architecture quality assessed across Security, Reliability, Performance, Cost, Operations |
| **Recommendations vs blockers** | Architecture review is advisory. Security gate is blocking. |

**Next:** [Lab 5 — Drift Detection](lab-05-drift-detection.md)

## Step 6: Architect questions you should expect

The Principal Architect agent asks clarifying questions before recommendations:

- SLA target (99.9 / 99.95 / 99.99)?
- RTO / RPO requirements?
- Monthly budget ceiling?
- Compliance frameworks in scope (CIS / SOC2 / HIPAA)?
- Expected scale (peak requests/sec, data volume, users)?

Skipping these means the agent assumes; you may get recommendations that overshoot or undershoot.

## Step 7: A trade-off example (dev vs prod)

- Dev (current): B1 App Service (~$13), Basic SQL (~$5), single region, public endpoints. ~$20/mo.
- Prod recommendation: S1 or P1V3 App Service (~$73-146), S0 SQL (~$15) + geo-replica (~$30), Front Door (~$35), private endpoints + Bastion (~$40). ~$200-300/mo.

The agent surfaces deltas honestly; it does not push the most expensive option.

## Step 8: Cost estimate caveats

- Prices are pay-as-you-go list rates from the Azure Retail Prices API on the day the estimate ran.
- Reserved Instance / Savings Plan / EA discounts are NOT reflected.
- The estimate persists at .azure/deployments/<id>/cost-estimate.json. Track 3 PR comments read this file; if missing, the PR plan shows $0.00.

## Going further

- Cost-estimator skill: .github/skills/azure-cost-estimator/SKILL.md
- Principal architect agent: .github/agents/azure-principal-architect.agent.md
