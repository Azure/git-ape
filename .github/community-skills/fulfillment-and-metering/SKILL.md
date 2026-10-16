---
name: fulfillment-and-metering
description: "Implements Azure Marketplace SaaS fulfillment APIs and metered billing event flows for transactable offers."
argument-hint: "Billing dimensions, entitlement model, meter events, and reconciliation process"
user-invocable: true
last_updated: "2026-06-12"
---

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
