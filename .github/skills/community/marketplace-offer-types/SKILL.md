---
name: marketplace-offer-types
description: "Provides offer-type decision guidance and implementation pathways for Azure Marketplace and related commercial offer models. USE FOR: choosing between SaaS, Azure Application, VM, container, or managed-services offer types. DO NOT USE FOR: executing the onboarding flow itself (use marketplace-onboarding or onboard-to-marketplace)."
license: MIT
metadata:
  author: dawright22
  source: https://github.com/dawright22/azure-saas-skills
  maturity: stable
  version: "1.0.0"
---

# Marketplace Offer Types

> Helps select and implement the right commercial offer path on Azure Marketplace.

## When to Use

* "should my product be a SaaS offer or an Azure Application on Marketplace"
* "compare offer types for my product"
* Deciding packaging/hosting/billing model before building fulfillment integration

## Procedure

### 1. Review covered offer types

* SaaS (transactable and license-based patterns)
* Azure Application (managed application and solution template paths)
* Virtual Machine offers
* Container offers
* Managed Services offer alignment (Azure Lighthouse-driven operations where relevant)

### 2. Build the fit matrix

Map the product's packaging preference, hosting model, billing model, and customer
procurement requirements against each offer type's constraints.

### 3. Determine technical packaging requirements

Identify the technical packaging requirements specific to the chosen offer type
(ARM template, container image, VM image, fulfillment API integration, etc.).

### 4. Assess publishing implications

Note validation, certification, and support-model implications of the chosen offer type.

## Outputs

* Offer-type fit matrix by product scenario.
* Technical packaging requirements by offer type.
* Publishing implications (validation, certification, support model).

## Constraints

**Always:**

* Match the offer type to the customer's actual procurement and billing requirements, not just technical convenience.

**Never:**

* Assume SaaS is the right offer type by default — Azure Application or Managed Services may fit better for infrastructure-heavy or white-glove products.

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/azure-saas-skills>
* **Support:** File issues at <https://github.com/dawright22/azure-saas-skills/issues>
