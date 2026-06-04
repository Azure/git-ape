---
title: "Adr Generator"
sidebar_label: "Adr Generator"
description: "Generate and manage Architecture Decision Records (ADRs) for deployments. Auto-creates ADRs after successful deployment, maintains an index, and amends records when deployments are updated or destroyed."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/adr-generator/SKILL.md -->


# Adr Generator

> Generate and manage Architecture Decision Records (ADRs) for deployments. Auto-creates ADRs after successful deployment, maintains an index, and amends records when deployments are updated or destroyed.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/adr-generator/` |
| **Phase** | General |
| **User Invocable** | ✅ Yes |
| **Usage** | `/adr-generator Deployment ID to generate or amend an ADR for` |


## Documentation

# ADR Generator

Generate and manage Architecture Decision Records (ADRs) that document deployment decisions, trade-offs, and architecture choices.

## When to Use

- After a successful deployment (auto-triggered by deploy workflow)
- When a deployment is updated or redeployed
- When a deployment is destroyed (amend existing ADR)
- To rebuild the ADR index

## ADR Format

Each ADR follows a standard structure:

```markdown
# ADR-NNNN: Title

## Status
Accepted | Superseded | Deprecated

## Date
YYYY-MM-DD

## Deployment
- Deployment ID, project, environment, region, resource group

## Context
Why was this deployment needed? What requirements drove it?

## Decision
What was deployed? What configuration choices were made?

## Consequences
### Positive
### Negative
### Trade-offs

## Architecture
Reference to architecture diagram

## Amendments
Changes to the deployment over time
```

## Procedure

### 1. Generate ADR After Deployment

After a successful deployment, run:

```bash
.github/scripts/adr-manager.sh generate <deployment-id>
```

This will:
- Read deployment metadata, requirements, and WAF review
- Generate a numbered ADR in `.azure/adrs/`
- Link the ADR back to `metadata.json` via `adrFile` and `adrNumber` fields
- Update the ADR index

### 2. Amend ADR on Update or Destroy

When a deployment is updated or destroyed:

```bash
.github/scripts/adr-manager.sh amend <deployment-id> "Reason for change"
```

This will:
- Find the linked ADR from metadata
- Append an amendment entry with date, reason, and new status
- Update ADR status to "Superseded" if deployment was destroyed
- Update the ADR index

### 3. Rebuild Index

To regenerate the index from all existing ADRs:

```bash
.github/scripts/adr-manager.sh index
```

### 4. List ADRs

```bash
.github/scripts/adr-manager.sh list
```

## Directory Structure

```
.azure/adrs/
├── INDEX.md                              # Auto-maintained index
├── 0001-deploy-api-dev.md               # First ADR
├── 0002-deploy-webapp-prod.md           # Second ADR
└── ...
```

## Integration with Deployment Workflow

The ADR generation is integrated into:

1. **`git-ape-deploy.exampleyml`** — After successful deployment, generates an ADR and commits it alongside `state.json`
2. **`git-ape-destroy.exampleyml`** — Amends the ADR when a deployment is destroyed
3. **`metadata.json`** — Contains `adrFile` and `adrNumber` fields linking to the ADR

## Metadata Integration

After ADR generation, `metadata.json` is updated with:

```json
{
  "adrFile": ".azure/adrs/0001-deploy-api-dev.md",
  "adrNumber": 1
}
```

This allows agents and scripts to navigate from a deployment to its decision record.
