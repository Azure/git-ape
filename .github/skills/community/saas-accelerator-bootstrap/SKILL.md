---
name: saas-accelerator-bootstrap
description: "Bootstraps and customizes the Azure Commercial Marketplace SaaS Accelerator as a starting point for transactable SaaS offers. USE FOR: standing up fulfillment/billing scaffolding quickly using the official accelerator, deciding what to customize vs. keep as-is. DO NOT USE FOR: building fulfillment APIs from scratch (use fulfillment-and-metering), tenancy model decisions (use tenant-isolation-models)."
license: MIT
metadata:
  author: dawright22
  source: https://github.com/dawright22/azure-saas-skills
  maturity: experimental
  version: "1.0.0"
---

# SaaS Accelerator Bootstrap

> Uses the Commercial Marketplace SaaS Accelerator (Azure/Commercial-Marketplace-SaaS-Accelerator) as a foundation for a transactable SaaS offer.

## When to Use

* "bootstrap my SaaS offer with the Commercial Marketplace SaaS Accelerator"
* "what do I need to customize in the SaaS Accelerator for my product"
* Starting a transactable SaaS offer and want to avoid building fulfillment plumbing from scratch

## Procedure

### 1. Deploy accelerator components

Deploy the accelerator's baseline architecture and required backing services
(reference: <https://github.com/Azure/Commercial-Marketplace-SaaS-Accelerator>).

### 2. Configure marketplace integration points

Wire up landing pages and webhook endpoints the accelerator exposes for Partner Center
fulfillment events.

### 3. Establish extension boundaries

Identify exactly where product-specific code should be added versus what stays as
accelerator-provided scaffolding, to keep future accelerator upgrades low-friction.

### 4. Align data model and events

Map the accelerator's subscription/plan data model and events to this product's tenant
lifecycle and billing requirements.

### 5. Plan cutover to production

Define the path from the accelerator's sample flows to production-ready flows.

## Outputs

* Accelerator baseline architecture map.
* Customization backlog (must-have vs optional).
* Cutover plan from sample flows to production-ready flows.

## Constraints

**Always:**

* Keep product customizations in clearly separated extension points so accelerator updates remain mergeable.
* Validate webhook/landing-page endpoints against Partner Center's technical configuration requirements before go-live.

**Never:**

* Fork and heavily modify the accelerator's core fulfillment logic when an extension point would suffice.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
