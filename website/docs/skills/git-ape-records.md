---
title: "Git Ape Records"
sidebar_label: "Git Ape Records"
description: "Run Git-Ape's native Bash producer to save draft ADRP Intent, create and validate structured execution traces, and emit immutable AERP Evidence. USE FOR: save deployment intent; create intent.json; record a declared workflow path; validate transition receipts; emit portable evidence; fingerprint native records without ISEE. DO NOT USE FOR: ratifying Intent, authoring ASRP Structure, independently verifying Evidence, or deploying Azure resources."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/git-ape-records/SKILL.md -->


# Git Ape Records

> Run Git-Ape's native Bash producer to save draft ADRP Intent, create and validate structured execution traces, and emit immutable AERP Evidence. USE FOR: save deployment intent; create intent.json; record a declared workflow path; validate transition receipts; emit portable evidence; fingerprint native records without ISEE. DO NOT USE FOR: ratifying Intent, authoring ASRP Structure, independently verifying Evidence, or deploying Azure resources.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/git-ape-records/` |
| **Phase** | General |
| **User Invocable** | ✅ Yes |
| **Usage** | `/git-ape-records` |


## Documentation

# Git-Ape Records

## When to Use

Use this skill when the user asks to save/capture Git-Ape Intent from
`requirements.json`, capture or validate a structured execution trace, or emit
portable Evidence after `state.json` and `tests.json` exist. It requires no
ISEE profile CLI.

## Ownership

- Git-Ape may create **draft** ADRP records. It must not mark them ratified.
- Git-Ape may create fingerprinted AERP bundles from facts it produced.
- Git-Ape may record workflow-owned execution events and validate them against
  a declared graph. A passing trace does not establish authority or prove that
  referenced Evidence is true.
- ADRP remains authoritative for validation, authority, and ratification.
- ASRP remains authoritative for governed Structure and execution manifests.
- AERP remains authoritative for independent validation and verification.

The distinction is lifecycle status, not file portability.

## Procedure

### Capture Intent

After `requirements.json` or onboarding intent input is complete:

```bash
bash .github/git-ape/records/git-ape-records.sh intent \
  --source .azure/deployments/<id>/requirements.json \
  --output .azure/deployments/<id>/intent.json \
  --status-output .azure/deployments/<id>/intent-status.json
```

The output is an `ape-decision-record/v1` record with `status: draft` and
`ratification: null`. Inferred or incomplete material is listed in `gaps`.

If the source or producer is missing, stop and name the missing path. If a
draft already exists, do not overwrite it without explicit review.

### Capture and Validate Execution

Use the scaffolded graph at
`.github/git-ape/records/graphs/git-ape-deploy-v1.json`. Build a JSON array of
explicit node and transition events, then run:

```bash
bash .github/git-ape/records/git-ape-records.sh trace \
  --graph .azure/deployments/<id>/execution-graphs/<invocation>.json \
  --events <events.json> \
  --output .azure/deployments/<id>/traces/<invocation>.json \
  --validation-output .azure/deployments/<id>/trace-validations/<invocation>.json \
  --invocation-id <invocation> \
  --workflow git-ape-deploy \
  --identity "<workflow-identity>" \
  --outcome succeeded
```

The validator checks graph-byte binding, declared nodes and transitions,
required transition receipts, node-transition-node event ordering, path
continuity, and required successful nodes. CI archives the exact graph bytes
under `execution-graphs/<invocation>.json` so older traces remain verifiable
after the canonical graph evolves.
Failed executions may terminate at the failed node; they remain valid Evidence
of an unsuccessful attempt.

Prefer workflow-owned trace reconstruction from actual step outcomes. An
agent-written trace is not independent proof of the same agent's behavior.
Trace files are immutable per invocation.

### Emit Evidence

After `state.json`, `metadata.json`, and test results have been written:

```bash
bash .github/git-ape/records/git-ape-records.sh evidence \
  --deployment-dir .azure/deployments/<id> \
  --output .azure/deployments/<id>/evidence/bundles/<invocation>.json \
  --status-output .azure/deployments/<id>/evidence-status.json \
  --identity "<human-or-workflow-identity>" \
  --target "<Azure-stack-or-scope>" \
  --decision .azure/deployments/<id>/intent.json
```

The bundle is `aerp-evidence-bundle/v1`, contains SHA-256 artifact digests,
and records `status: generated` in the Git-Ape status file.

If `state.json` or `tests.json` is missing, stop. Never substitute a
success-shaped Evidence record.

### Optional Governance

When profile tooling is available:

```bash
adrp validate --target <intent>             # draft validation
aerp validate <bundle>
aerp verify <bundle> --artifact-root <deployment-dir>
```

Only ADRP ratification may change Intent to `ratified`. Only a successful
independent AERP validation and verification step may change Evidence status
from `generated` to `verified`.

## Safety

- Never fabricate authority, alternatives, accepted risks, or verification.
- Never report a draft Intent as ratified.
- Never report generated Evidence as independently verified.
- Never modify `state.json`; it remains Git-Ape's runtime lifecycle state.
- Never silently discard captured Intent because optional tooling is missing.
- Never treat trace conformance as proof that a referenced control was
  effective or that the trace is independently verified.
