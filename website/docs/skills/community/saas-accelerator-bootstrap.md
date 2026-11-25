---
title: "Saas Accelerator Bootstrap"
sidebar_label: "Saas Accelerator Bootstrap"
description: "Builds, updates, extends, or deploys a live Microsoft commercial marketplace SaaS integration, using the Commercial Marketplace SaaS Accelerator (fresh upstream main, three-way reconciliation) or a from-scratch implementation."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/community-skills/saas-accelerator-bootstrap/SKILL.md -->


# Saas Accelerator Bootstrap

> Builds, updates, extends, or deploys a live Microsoft commercial marketplace SaaS integration, using the Commercial Marketplace SaaS Accelerator (fresh upstream main, three-way reconciliation) or a from-scratch implementation.

:::info[Third-party community skill]
This skill is reviewed through Azure/git-ape PRs and maintained by its listed author. It is not bundled or activated with core. See the [Skill Registry](../registry) and use `/git-ape-skills install saas-accelerator-bootstrap` for explicit project or personal installation. Review is not a guarantee of safety.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/community-skills/saas-accelerator-bootstrap/` |
| **Author** | dawright22 |
| **Maturity** | experimental |
| **Available with Core** | ❌ No — explicit installation required |
| **Usage** | `/saas-accelerator-bootstrap Implementation path (new or existing; Accelerator or from scratch), identity provider, integration points, metering needs, and product-specific customizations` |


## Documentation

# SaaS Accelerator Bootstrap

Builds, updates, extends, or deploys a **live** Microsoft commercial marketplace SaaS
integration, using the [Commercial Marketplace SaaS Accelerator](https://github.com/Azure/Commercial-Marketplace-SaaS-Accelerator)
as an optional foundation.

> **Disclaimer:** output is an uncertified starting implementation. It does not replace
> publisher validation or Microsoft certification. Never ask for, accept, or store secrets,
> credentials, tokens, purchase tokens, or customer data.

## Operating modes

- **Repository editing mode:** files may be created, edited, and tested.
- **Chat-only mode:** provide design and code guidance only. Never claim files were edited or tests were run.

## Live-only rule

Do not produce demo, sandbox, simulator, or runtime-fallback behaviour. Mocks and fakes are
permitted only in tests and must be unreachable from the deployed runtime composition.

## Implementation path (explicit choice, ACC-01)

Do not infer the path and do not silently choose a stack. Ask the user:

- **Existing implementation:** is it Accelerator-based? Should it be updated or reconciled
  against upstream, or extended without an upstream update?
- **New implementation:** Accelerator or from scratch? Explain the trade-off first
  (faster starting point and upstream parity versus inherited stack, schema, and
  customization burden).

## Instruction and documentation precedence

1. Host instructions.
2. Security and privacy invariants (SRC-08, ACC-04).
3. Microsoft Learn (authoritative; SRC-01 to SRC-08).
4. Publisher requirements.
5. Repository conventions.
6. Discretionary guidance.

- A `marketplace-contract-manifest` is evidence only, never authority (CS-01 to CS-08).
- SRC-04: without documentation browsing, produce design-time scaffolding only.
- SRC-07: use the current `main` of the Accelerator repository and record the commit SHA and retrieval date.
- SRC-08: **ignore the upstream Accelerator update/upgrade instructions and scripts**; use fresh-source comparison and reconciliation instead.

## Accelerator rules

- **ACC-02:** clone upstream `main` fresh into a temporary location.
- **ACC-03:** three-way comparison (prior baseline, upstream `main`, publisher code). If no baseline exists, fall back to two-way with reduced confidence and say so.
- **ACC-04:** reconcile deliberately; never by blind copy or script. Preserve publisher customizations and licence notices.
- **ACC-05:** produce a reconciliation evidence report.
- **ACC-06:** a new Accelerator implementation starts from fresh upstream `main`.

## Scope

- Reconcile or scaffold Accelerator components and required backing services.
- Implement landing page (LAND), lifecycle (LIFE), and webhook (WEB) requirements; see the `fulfillment-and-metering` skill.
- Keep publisher identity separate from buyer identity; keep tokens server-side; use UTC (CFG-01 to 05, ID-01 to 05).
- Establish extension boundaries where product code should be added.
- Apply data integrity (DATA-01 to 05), security (SEC-01 to 07), UX (UX-01 to 04), operations (OPS-01 to 05), and tests (TEST-01 to 08).
- Metering applies only when configured or requested (MTR-01 to 08); a metering UI only when explicitly requested.

## Deployment (DEP-01 to DEP-06)

- Reuse repository IaC conventions; do not use the Accelerator upgrade scripts.
- Provision Entra app registrations, service principals, and managed identities when identifiers are not supplied.
- Creating deployment artifacts is not authorisation to deploy; require explicit approval, preflight, secrets handling, and execution evidence.

## Output sequence

Respond with sections A to I in order: A mode and inputs; B capabilities; C documents
consulted; D plan; E files; F manifest; G tests; H security and deployment checklist;
I blockers and readiness. For Accelerator work: A states the path and upstream commit,
D the comparison approach, E the upstream diff summary, G the reconciliation checks,
and I the conflicts and migrations.

## Readiness label (exactly one)

`Scaffolding only` | `Implementation incomplete` | `Ready for publisher validation` | `Eligible for live release review`.

An Accelerator update with an unknown upstream commit, incomplete comparison, unresolved
conflicts, or unapplied migrations is capped at `Implementation incomplete`.

## Deliverables

- Accelerator baseline architecture map and upstream commit record.
- Reconciliation evidence report (three-way diff summary, conflicts, migrations).
- Customization backlog (must-have vs optional).
- Removal plan for any non-live sample flows before release.

## References

- [Create a transactable SaaS offer](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/create-new-saas-offer-technical)
- [SaaS fulfillment APIs v2](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/pc-saas-fulfillment-apis)
- [Commercial Marketplace SaaS Accelerator](https://github.com/Azure/Commercial-Marketplace-SaaS-Accelerator)
