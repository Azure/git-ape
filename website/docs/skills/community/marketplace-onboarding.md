---
title: "Marketplace Onboarding"
sidebar_label: "Marketplace Onboarding"
description: "Guides onboarding to Azure Marketplace: publisher setup, technical configuration, validation, and launch readiness. USE FOR: Partner Center publisher setup, offer metadata/plans/pricing, certification prep. DO NOT USE FOR: choosing the offer type (use marketplace-offer-types), fulfillment API implementation (use fulfillment-and-metering)."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/community/marketplace-onboarding/SKILL.md -->


# Marketplace Onboarding

> Guides onboarding to Azure Marketplace: publisher setup, technical configuration, validation, and launch readiness. USE FOR: Partner Center publisher setup, offer metadata/plans/pricing, certification prep. DO NOT USE FOR: choosing the offer type (use marketplace-offer-types), fulfillment API implementation (use fulfillment-and-metering).

:::info[Third-party community skill]
This skill is contributed and maintained by the community, not by the Git-Ape maintainers. See the [Skill Registry](../registry) for provenance details.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/community/marketplace-onboarding/` |
| **Author** | dawright22 |
| **Maturity** | stable |
| **Source** | [https://github.com/dawright22/azure-saas-skills](https://github.com/dawright22/azure-saas-skills) |
| **User Invocable** | ✅ Yes |
| **Usage** | `/marketplace-onboarding` |


## Documentation

# Marketplace Onboarding

> Transforms a built SaaS platform into a publishable Azure Marketplace offer.

## When to Use

* "onboard my SaaS platform to Azure Marketplace"
* "what do I need in Partner Center before I can publish"
* Preparing offer metadata, pricing, and legal artifacts for submission
* Running certification and go-live readiness checks

## Procedure

### 1. Confirm Partner Center readiness

Verify publisher profile, legal entities, and role assignments are in place.

### 2. Configure the offer

Define offer metadata, plans, pricing, and required legal artifacts.

### 3. Prepare for technical validation and certification

Confirm fulfillment, landing page, and webhook integrations are ready for Microsoft's
technical validation and certification process.

### 4. Run private preview

Move through private audience testing before requesting go-live.

### 5. Execute go-live

Complete the go-live motion and confirm the offer is publicly listed.

## Outputs

* End-to-end onboarding checklist.
* Submission-quality artifact inventory.
* Launch gate report with blocking/non-blocking findings.

## Constraints

**Always:**

* Complete private preview testing before requesting go-live.
* Track blocking vs non-blocking findings separately so launch isn't delayed by non-blockers.

**Never:**

* Submit for certification without first validating fulfillment/webhook endpoints end-to-end.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
