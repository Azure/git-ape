---
title: "Strict Drift Detection"
sidebar_label: "Strict Drift Detection"
description: "Deep, baseline-based configuration drift detection that recursively diffs the FULL resolved Azure resource state (every nested property, array-aware) against a captured baseline, instead of a curated per-resource-type property list. USE FOR: compliance-grade drift audits, catching nested/unexpected property changes that azure-drift-detector's curated checks miss, pre-production configuration verification. DO NOT USE FOR: replacing azure-drift-detector's fast security-property summary — run that first; reconciliation/redeployment (use azure-resource-deployer); resource health checks (use azure-integration-tester)."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/community/strict-drift-detection/SKILL.md -->


# Strict Drift Detection

> Deep, baseline-based configuration drift detection that recursively diffs the FULL resolved Azure resource state (every nested property, array-aware) against a captured baseline, instead of a curated per-resource-type property list. USE FOR: compliance-grade drift audits, catching nested/unexpected property changes that azure-drift-detector's curated checks miss, pre-production configuration verification. DO NOT USE FOR: replacing azure-drift-detector's fast security-property summary — run that first; reconciliation/redeployment (use azure-resource-deployer); resource health checks (use azure-integration-tester).

:::info[Third-party community skill]
This skill is contributed and maintained by the community, not by the Git-Ape maintainers. See the [Skill Registry](../registry) for provenance details.
:::

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/community/strict-drift-detection/` |
| **Author** | dawright22 |
| **Maturity** | experimental |
| **Source** | [https://github.com/dawright22/strict-drift-detection](https://github.com/dawright22/strict-drift-detection) |
| **User Invocable** | ✅ Yes |
| **Usage** | `/strict-drift-detection` |


## Documentation

# Strict Drift Detection

> Deep, baseline-based recursive diff of the full resolved Azure resource state — catches drift anywhere in the JSON tree, not just a curated property list.

Git-Ape's built-in `azure-drift-detector` skill compares a short, hardcoded
list of properties per resource type (e.g. `httpsOnly`, `minimumTlsVersion`,
tags) against `requirements.json`. That catches common security regressions
quickly, but it misses nested configuration
(`siteConfig.appSettings`, `networkAcls`, `encryption.*`, `identity.*`), any
resource type not explicitly coded into the detector, and partial array
changes (e.g. one firewall rule added among several). This skill is a
**companion**, not a replacement: run `azure-drift-detector` first for the
fast summary, then run this skill for a full, compliance-grade diff of
everything else.

## When to Use

* "do a deep drift check" / "strict drift" / "check every property"
* "azure-drift-detector says no drift but I think something changed"
* Pre-production deployment gate requiring full configuration verification
* Scheduled compliance audits across all managed resources
* A resource type not covered by `azure-drift-detector`'s hardcoded checks needs drift coverage

## Procedure

### 1. Identify the target deployment

Resolve `$DEPLOYMENT_ID` and confirm
`.azure/deployments/$DEPLOYMENT_ID/metadata.json` exists (this is the same
file git-ape's `azure-resource-deployer` and `azure-drift-detector` already
produce/consume — no extra setup required). The script reads either the
extended `managedResources[]` schema or the legacy `resources[]` schema.

### 2. Establish or refresh the baseline

Run the detection script:

```bash
.github/skills/community/strict-drift-detection/scripts/strict-detect-drift.sh \
  --deployment-id "$DEPLOYMENT_ID"
```

On the **first run** for any resource, there is no prior captured state, so
the script snapshots the live `az resource show` output as the baseline
(saved to `drift-analysis/strict-baseline/<resource-name>.json`) and skips
diffing that resource for this run.

To intentionally reset a baseline (e.g. after accepting drift, or after a
verified manual change), force a recapture:

```bash
.github/skills/community/strict-drift-detection/scripts/strict-detect-drift.sh \
  --deployment-id "$DEPLOYMENT_ID" --refresh-baseline
```

### 3. Run the deep diff

On subsequent runs, every resource is diffed against its baseline via a
recursive `jq` walk (`scripts/deep-diff.jq`):

1. Both baseline and current JSON are normalized — arrays of objects are
   re-keyed by an identifying field (`name`, `id`, or `key`, see
   `scripts/array-keys.json`) instead of compared positionally, so
   reordering does not produce false positives.
2. Every leaf path is flattened (e.g.
   `properties.siteConfig.appSettings.FUNCTIONS_WORKER_RUNTIME`).
3. Paths matching `scripts/ignore-properties.json` (volatile/computed
   fields: etags, timestamps, endpoints) are dropped.
4. Remaining paths are compared value-by-value; differences are classified
   `added`, `removed`, or `changed`.
5. Each diff is assigned a severity via `scripts/drift-rules.json` (first
   matching regex pattern wins; a catch-all `.*` defaults to `info` so
   unmatched properties still surface rather than being silently dropped).

### 4. Review and reconcile

```bash
cat .azure/deployments/$DEPLOYMENT_ID/drift-analysis/strict-drift-report.md
```

Use the same reconciliation playbook as `azure-drift-detector`
(Accept / Revert / Selective / Mark as known drift):

* **Accept:** re-run with `--refresh-baseline` after confirming the new
  state is correct — this updates the baseline so the accepted change
  stops showing as drift.
* **Revert:** redeploy via the normal git-ape `azure-resource-deployer`
  flow, then re-run this skill to confirm the live state matches the
  baseline again.
* **Mark as known drift:** note it in the shared
  `drift-analysis/known-drift.json` used by `azure-drift-detector` — both
  skills write into the same `drift-analysis/` directory per deployment.

## Outputs

```
.azure/deployments/{deployment-id}/drift-analysis/
├── strict-baseline/
│   └── <resource-name>.json       # Captured full resource snapshot
├── strict-drift-report.md         # Human-readable deep-diff report
└── strict-drift-details.json      # Machine-readable diff (all paths, severities)
```

Exit codes match `azure-drift-detector` for CI compatibility: `2` =
critical drift, `1` = warning drift, `0` = clean.

## Constraints

**Always:**

* Run `azure-drift-detector` first — this skill supplements it, it does not
  replace the fast security-property summary.
* Treat the first run for any resource as a baseline capture, not a drift
  result — there is nothing to compare against yet.
* Extend `drift-rules.json` / `ignore-properties.json` rather than
  hand-editing the diff logic when a new noisy or security-sensitive
  property is discovered.

**Never:**

* Auto-reconcile drift without user confirmation — always present the
  report and let the user choose Accept/Revert/Selective/Known-drift.
* Assume a "no drift" result means the resource is secure — this skill only
  reports *differences from a previously captured baseline*, not
  compliance with any external standard (pair with `azure-security-analyzer`
  / `azure-policy-advisor` for that).

## Attribution

* **Author:** dawright22
* **Source:** <https://github.com/dawright22/strict-drift-detection>
* **Support:** File issues at <https://github.com/dawright22/strict-drift-detection/issues>
