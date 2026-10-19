---
title: "Fulfillment And Metering"
sidebar_label: "Fulfillment And Metering"
description: "Implements Azure Marketplace SaaS fulfillment APIs and metered billing event flows for transactable offers."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/community-skills/fulfillment-and-metering/SKILL.md -->


# Fulfillment And Metering

> Implements Azure Marketplace SaaS fulfillment APIs and metered billing event flows for transactable offers.

:::info[Third-party community skill]
This skill is reviewed through Azure/git-ape PRs and maintained by its listed author. It is not bundled or activated with core. See the [Skill Registry](../registry) and use `/git-ape-skills install fulfillment-and-metering` for explicit workspace installation. Review is not a guarantee of safety.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/community-skills/fulfillment-and-metering/` |
| **Author** | dawright22 |
| **Maturity** | experimental |
| **Available with Core** | ❌ No — explicit installation required |
| **Usage** | `/fulfillment-and-metering Billing dimensions, entitlement model, meter events, and reconciliation process` |


## Documentation

# Fulfillment and Metering

Builds marketplace transaction flows from subscription to usage reporting.

## Workflow

- Resolve marketplace purchase/subscription events.
- Track entitlement and plan state changes.
- Emit and reconcile metering events.
- Handle retries, idempotency, and audit logs.

## Deliverables

- Fulfillment API integration checklist.
- Meter dimensions and event schema.
- Financial reconciliation and exception handling process.
