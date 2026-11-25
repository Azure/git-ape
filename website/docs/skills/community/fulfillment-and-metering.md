---
title: "Fulfillment And Metering"
sidebar_label: "Fulfillment And Metering"
description: "Implements Azure Marketplace SaaS fulfillment APIs and metered billing event flows for transactable offers."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/community-skills/fulfillment-and-metering/SKILL.md -->


# Fulfillment And Metering

> Implements Azure Marketplace SaaS fulfillment APIs and metered billing event flows for transactable offers.

:::info[Third-party community skill]
This skill is reviewed through Azure/git-ape PRs and maintained by its listed author. It is not bundled or activated with core. See the [Skill Registry](../registry) and use `/git-ape-skills install fulfillment-and-metering` for explicit project or personal installation. Review is not a guarantee of safety.
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

Builds **live** marketplace transaction flows from subscription to usage reporting. No demo,
sandbox, simulator, or runtime fallback; mocks are test-only and unreachable from deployed
composition. Never ask for or store secrets, credentials, purchase tokens, or customer data.
Microsoft Learn is authoritative; a contract manifest is evidence only.

## Workflow

- **Landing page (LAND):** do not persist the purchase token; call Resolve server-side; correlate once (one-time use).
- **Lifecycle (LIFE):** verify before activation; use explicit state transitions; keep entitlement and plan state consistent.
- **Webhooks (WEB):** authenticated ingress; durable inbox with deduplication; verify with the Subscription API before mutating state; atomic processing; durable acknowledgement.
- **Data integrity (DATA-01 to 05)** and **security (SEC-01 to 07):** keep publisher identity separate from buyer identity, tokens server-side, timestamps in UTC.
- **Metering (MTR-01 to 08):** only when configured or requested; emit and reconcile usage events with retries and idempotency. Add a metering UI only when explicitly requested.
- Handle retries, idempotency, and audit logs; cover with TEST-01 to 08.

## Deliverables

- Fulfillment API integration checklist (LAND, LIFE, WEB).
- Meter dimensions and event schema (when metering applies).
- Financial reconciliation and exception handling process.
- Readiness label, exactly one of: `Scaffolding only`, `Implementation incomplete`, `Ready for publisher validation`, `Eligible for live release review`.

## References

- [SaaS fulfillment APIs v2](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/pc-saas-fulfillment-apis)
- [Subscription lifecycle](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/pc-saas-fulfillment-life-cycle)
- [Webhook](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/pc-saas-fulfillment-webhook)
- [Metered billing](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/saas-metered-billing)
- [Marketplace metering service APIs](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-metering-service-apis)
