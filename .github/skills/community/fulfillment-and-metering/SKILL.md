---
name: fulfillment-and-metering
description: "Implements Azure Marketplace SaaS fulfillment APIs and metered billing event flows for transactable offers. USE FOR: subscription/entitlement resolution, metering event schema and reconciliation design. DO NOT USE FOR: bootstrapping the accelerator itself (use saas-accelerator-bootstrap), publisher/Partner Center onboarding (use marketplace-onboarding)."
license: MIT
metadata:
  author: dawright22
  source: https://github.com/dawright22/azure-saas-skills
  maturity: experimental
  version: "1.0.0"
---

# Fulfillment and Metering

> Builds marketplace transaction flows from subscription resolution through usage reporting, with idempotent, auditable metering.

## When to Use

* "implement Azure Marketplace SaaS fulfillment APIs"
* "design metering events and billing dimensions for my offer"
* Handling marketplace purchase/subscription lifecycle events
* Designing reconciliation for metering/billing discrepancies

## Procedure

### 1. Resolve marketplace events

Handle marketplace purchase and subscription events (Resolve, Activate, Change, Reinstate,
Unsubscribe) from the Fulfillment API.

### 2. Track entitlement and plan state

Maintain entitlement and plan state transitions driven by fulfillment events.

### 3. Design meter dimensions and emit events

Define metering dimensions and the event schema, then emit metering events against the
Marketplace Metering API.

### 4. Handle retries, idempotency, and audit logging

Ensure every fulfillment and metering call is idempotent and retried safely; log every
transaction for financial audit.

### 5. Reconcile

Define the financial reconciliation process and exception handling for failed or
disputed metering events.

## Outputs

* Fulfillment API integration checklist.
* Meter dimensions and event schema.
* Financial reconciliation and exception handling process.

## Constraints

**Always:**

* Make fulfillment and metering API calls idempotent — marketplace webhooks can be delivered more than once.
* Log every fulfillment/metering transaction for audit and dispute resolution.

**Never:**

* Emit metering events without a reconciliation path for failures — billing discrepancies compound silently.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
