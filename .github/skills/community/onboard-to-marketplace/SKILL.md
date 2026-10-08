---
name: onboard-to-marketplace
description: "End-to-end onboarding flow for Azure Marketplace SaaS publication, from Partner Center readiness to final go-live checks. USE FOR: execution-focused walk-through of the full onboarding flow for a SaaS offer specifically. DO NOT USE FOR: comparing offer types (use marketplace-offer-types), general multi-offer-type onboarding (use marketplace-onboarding)."
license: MIT
metadata:
  author: dawright22
  source: https://github.com/dawright22/azure-saas-skills
  maturity: experimental
  version: "1.0.0"
---

# Onboard to Marketplace

> Execution-focused walk-through for moving a ready SaaS platform into a publishable Azure Marketplace offer.

## When to Use

* "walk me through onboarding my SaaS product to Marketplace, step by step"
* "run my publication onboarding flow"
* The platform is built and the user wants a concrete, ordered execution checklist (as opposed to decision guidance)

## Procedure

### 1. Check publisher and Partner Center readiness

Verify publisher account state and required role assignments.

### 2. Set up the offer

Configure listing, plans, pricing, and legal artifacts.

### 3. Prepare technical validation inputs

Confirm fulfillment API integration, landing page, and webhook endpoints are implemented
and reachable.

### 4. Run private audience testing

Validate the full purchase-to-fulfillment flow with a private audience before requesting
certification.

### 5. Complete the final launch checklist

Walk through the go-live checklist and hand off to operations.

## Outputs

* Marketplace onboarding checklist with blockers.
* Required artifact inventory for submission.
* Go-live readiness status by stage.

## Constraints

**Always:**

* Validate the purchase-to-fulfillment flow with a private audience before requesting certification.

**Never:**

* Treat this as a substitute for `marketplace-offer-types` decision guidance — this skill assumes the offer type is already chosen.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
