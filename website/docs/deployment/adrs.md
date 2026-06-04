---
title: "Architecture Decision Records"
sidebar_label: "ADRs"
sidebar_position: 3
description: "How Git-Ape auto-generates and tracks Architecture Decision Records"
---

# Architecture Decision Records (ADRs)

:::warning
EXPERIMENTAL ONLY: ADR generation formats, templates, and lifecycle behavior may change at any time.
Do **not** rely on this feature for production governance or audit compliance.
:::

Git-Ape automatically generates Architecture Decision Records after each successful deployment, creating a governing ledger of infrastructure decisions.

## Overview

ADRs document:
- **What** was deployed (resources, configuration)
- **Why** it was deployed (requirements, context)
- **Trade-offs** accepted (from WAF review)
- **Architecture** (diagram reference)
- **Evolution** over time (amendments when updated or destroyed)

## Directory Structure

```
.azure/adrs/
├── INDEX.md                           # Auto-maintained index
├── 0001-deploy-api-dev.md            # First deployment ADR
├── 0002-deploy-webapp-prod.md        # Second deployment ADR
└── ...
```

## ADR Template

Each ADR follows a consistent format:

```markdown
# ADR-NNNN: Title

## Status
Accepted | Superseded | Deprecated

## Date
YYYY-MM-DD

## Deployment
- Deployment ID, project, environment, region, resource group, user

## Context
Why was this deployment needed? What requirements drove it?

## Decision
What was deployed? Configuration choices and rationale.

## Consequences
### Positive
### Negative
### Trade-offs

## Architecture
Reference to architecture diagram

## Amendments
Changes over time (updates, scaling, destruction)
```

## Lifecycle

### Generation

ADRs are generated automatically after a successful deployment:
1. The deploy workflow calls `adr-manager.sh generate <deployment-id>`
2. The script reads `metadata.json`, `requirements.json`, and `waf-review.md`
3. A numbered ADR is created in `.azure/adrs/`
4. The deployment's `metadata.json` is updated with `adrFile` and `adrNumber` fields
5. The `INDEX.md` is rebuilt

### Amendment

When a deployment is updated or destroyed:
1. The workflow calls `adr-manager.sh amend <deployment-id> "reason"`
2. The linked ADR is found via `metadata.json`
3. An amendment entry is appended with date, reason, and new status
4. If destroyed, the ADR status changes to "Superseded"
5. The index is updated

### Index Maintenance

The `INDEX.md` file is automatically regenerated whenever an ADR is created or amended. It provides a table listing all ADRs with their number, title, status, date, and linked deployment.

## Integration with Deployments

Each deployment's `metadata.json` contains:

```json
{
  "adrFile": ".azure/adrs/0001-deploy-api-dev.md",
  "adrNumber": 1
}
```

This bidirectional link allows navigation from deployment → ADR and from ADR → deployment.

## CLI Usage

The ADR manager script supports manual operations:

```bash
# Generate ADR for a deployment
.github/scripts/adr-manager.sh generate deploy-20260218-143022

# Amend ADR when deployment changes
.github/scripts/adr-manager.sh amend deploy-20260218-143022 "Scaled to production SKU"

# Rebuild the index
.github/scripts/adr-manager.sh index

# List all ADRs
.github/scripts/adr-manager.sh list
```

## Status Values

| Status | Meaning |
|--------|---------|
| **Accepted** | Active deployment, decision in effect |
| **Superseded** | Deployment destroyed or replaced |
| **Deprecated** | Decision no longer recommended |
