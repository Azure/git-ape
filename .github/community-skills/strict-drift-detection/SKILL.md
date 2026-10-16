---
name: strict-drift-detection
description: "Deep, baseline-based configuration drift detection for Git-Ape deployments. Recursively diffs the FULL resolved Azure resource state (every nested property, array-aware) against a captured baseline, instead of a curated per-resource-type property list. Complements git-ape's azure-drift-detector. Use when the standard drift check is not catching nested/unexpected property changes, for compliance-grade drift audits, or before production deployments."
license: MIT
metadata:
  author: dawright22
  source: https://github.com/dawright22/strict-drift-detection
  maturity: experimental
  version: "1.0.0"
  argument-hint: "Deployment ID, optional --refresh-baseline, optional --output-format markdown|json|github"
  user-invocable: true
---

# Strict Drift Detection

## Overview

Git-Ape's built-in `azure-drift-detector` skill compares a short, hardcoded list of properties per resource type (e.g. `httpsOnly`, `minimumTlsVersion`, tags) against `requirements.json`. That catches common security regressions quickly, but it misses:

- Nested configuration (`siteConfig.appSettings`, `networkAcls`, `encryption.*`, `identity.*`, etc.)
- Any resource type that isn't explicitly coded into the detector
- Changes to array-valued properties (firewall rules, app settings) where only *some* entries changed
- Anything not already captured in `requirements.json`, which reflects intent, not the actual resolved ARM state

**`strict-drift-detection` is a companion skill, not a replacement.** Run the standard `azure-drift-detector` first for a fast, human-readable summary of high-value security properties; run `strict-drift-detection` for a full, compliance-grade recursive diff of everything else.

**Triggers:**
- User asks: "do a deep drift check", "strict drift", "check every property", "full configuration audit"
- Standard `azure-drift-detector` reports "no drift" but the user suspects something changed elsewhere
- Pre-production deployment gate requiring full configuration verification
- Scheduled compliance audits

## How It Differs From `azure-drift-detector`

| | `azure-drift-detector` (git-ape) | `strict-drift-detection` (this skill) |
|---|---|---|
| Comparison source | `requirements.json` (intent) | Captured baseline snapshot of actual `az resource show` output |
| Properties checked | Hardcoded list per resource type (httpsOnly, TLS, tags, ...) | Every leaf property, recursively, for any resource type |
| Arrays | Not diffed | Array-aware: objects matched by `name`/`id`/`key`, not index, so reordering doesn't false-positive |
| New resource types | Reports "no drift" unless explicitly coded | Automatically covered — generic diff works on any JSON shape |
| Severity classification | Inline in bash | External `drift-rules.json` — add a pattern, no code change |
| Noise control | None | `ignore-properties.json` strips volatile/computed fields (etag, provisioningState, endpoints, timestamps) |
| First-run behavior | N/A | Captures a baseline snapshot (no diff) if one doesn't exist yet |

## Procedure

### 0. Confirm Before Running (REQUIRED)

Never run this skill silently. Before any capture or diff, ask the user (use the `ask_user` tool if available) whether a strict check is needed, and wait for the answer:

- State why it was suggested (e.g. standard `azure-drift-detector` reported no drift, pre-production gate, compliance audit).
- Offer: **Run strict check** / **Run standard `azure-drift-detector` only** / **Skip**.
- If the user has not explicitly asked for a deep/strict check, default to recommending the standard detector first.
- Do not capture or refresh baselines (`--refresh-baseline`) without separate explicit confirmation, since it overwrites the existing baseline.

Only continue to step 1 if the user chooses **Run strict check**.

### 1. Identify Target Deployment

Same as `azure-drift-detector` — resolve `$DEPLOYMENT_ID` and confirm `.azure/deployments/$DEPLOYMENT_ID/metadata.json` exists. This skill reads the same `metadata.json` resource list (`managedResources[]` or legacy `resources[]`), so no extra setup is needed if git-ape already manages the deployment.

### 2. Establish or Refresh Baseline

On the first run for a resource, there is no prior captured state, so the script snapshots the live `az resource show` output as the baseline and skips diffing for that resource this run:

```bash
.github/skills/strict-drift-detection/scripts/strict-detect-drift.sh \
  --deployment-id "$DEPLOYMENT_ID"
```

Baselines are stored at:
```
.azure/deployments/$DEPLOYMENT_ID/drift-analysis/strict-baseline/<resource-name>.json
```

To intentionally reset the baseline (e.g. after accepting drift, or after a verified manual change), force a recapture:

```bash
.github/skills/strict-drift-detection/scripts/strict-detect-drift.sh \
  --deployment-id "$DEPLOYMENT_ID" \
  --refresh-baseline
```

### 3. Run the Deep Diff

On subsequent runs, every resource is diffed against its baseline using a recursive `jq` walk (`scripts/deep-diff.jq`):

1. Both baseline and current JSON are normalized: arrays of objects are re-keyed by an identifying field (`name`, `id`, or `key` — see `array-keys.json`) instead of compared positionally.
2. Every leaf path is flattened (e.g. `properties.siteConfig.appSettings.FUNCTIONS_WORKER_RUNTIME`).
3. Paths matching `ignore-properties.json` (volatile/computed fields) are dropped.
4. Remaining paths are compared value-by-value; differences are classified `added`, `removed`, or `changed`.
5. Each diff is assigned a severity via `drift-rules.json` (first matching regex pattern wins; a catch-all `.*` defaults to `info`).

### 4. Review the Report

```bash
cat .azure/deployments/$DEPLOYMENT_ID/drift-analysis/strict-drift-report.md
```

```markdown
# Strict Drift Detection Report

**Deployment:** deploy-20260218-143022
**Mode:** full recursive property diff (baseline-based, array-aware)
**Resources Analyzed:** 5

## Summary
- Critical Drift: 2 properties
- Warning Drift: 3 properties
- Info Drift: 1 property
- No Drift: 2 resource(s)

---

### func-api-dev-eastus (Microsoft.Web/sites)

**CRITICAL** `properties.networkAcls.ipRules` (changed)
- Baseline: `{"203.0.113.0/24":{...}}`
- Current: `{}`
- Impact: Network access rules changed - security boundary affected

**WARNING** `properties.siteConfig.appSettings.WEBSITE_RUN_FROM_PACKAGE` (added)
- Baseline: `null`
- Current: `"1"`
- Impact: Application setting changed - may affect runtime behavior
```

Machine-readable output is saved to `drift-analysis/strict-drift-details.json`.

### 5. Reconcile

Use the same reconciliation playbook as `azure-drift-detector` (Accept / Revert / Selective / Mark as Known Drift). Because this skill is baseline-driven:

- **Accept:** re-run with `--refresh-baseline` after confirming the new state is correct. This updates the baseline so the accepted change stops showing as drift.
- **Revert:** redeploy via the normal git-ape `azure-resource-deployer` flow, then re-run this skill to confirm the live state matches the baseline again.
- **Mark as known drift:** not yet automated here — for now, note it in the shared `drift-analysis/known-drift.json` used by `azure-drift-detector`; both skills write to the same `drift-analysis/` directory per deployment.

## Configuration

| File | Purpose |
|---|---|
| `scripts/ignore-properties.json` | Regex patterns (matched against dotted path) excluded from diffing. Extend this for noisy, resource-specific computed fields. |
| `scripts/drift-rules.json` | Ordered list of `{pattern, severity, impact}`. First match wins. Always ends with a `.*` catch-all so unmatched properties still surface as `info` rather than being silently dropped. |
| `scripts/array-keys.json` | Candidate key fields (in priority order) used to re-key arrays-of-objects before diffing, so reordering doesn't produce false positives. |

## Usage with Multiple Deployments

```bash
for d in .azure/deployments/*/; do
  DEPLOYMENT_ID=$(basename "$d")
  .github/skills/strict-drift-detection/scripts/strict-detect-drift.sh \
    --deployment-id "$DEPLOYMENT_ID" --output-format github
done
```

Exit codes match `azure-drift-detector` for CI compatibility: `2` = critical drift, `1` = warning drift, `0` = clean.

## Output Format

```
.azure/deployments/{deployment-id}/drift-analysis/
├── strict-baseline/
│   └── <resource-name>.json       # Captured full resource snapshot
├── strict-drift-report.md         # Human-readable deep-diff report
└── strict-drift-details.json      # Machine-readable diff (all paths, severities)
```

## Related Skills

- **azure-drift-detector** (git-ape) — fast, curated security-property check; run this first
- **azure-integration-tester** (git-ape) — verify resource health after reconciliation
- **azure-security-analyzer** (git-ape) — re-validate security posture after accepting/reverting drift
