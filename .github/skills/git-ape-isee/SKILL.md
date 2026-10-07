---
name: git-ape-isee
description: "Adopt and govern existing Git-Ape records after ISEE is installed. USE FOR: adopt existing standalone intent and evidence; run adopt-existing.sh; create isee-bindings.json; require ratified ADRP Intent; bind ASRP Structure; verify existing AERP Evidence; enforce exact approved artifact bytes. DO NOT USE FOR: saving requirements.json as draft Intent, basic Evidence emission, installing ISEE, or Azure deployment execution."
metadata:
  argument-hint: "discover or preflight plus a Git-Ape deployment ID"
  user-invocable: true
---

# Git-Ape ISEE Governance

## When to Use

Use this skill when the user explicitly asks to adopt an existing Git-Ape
deployment into ISEE, create governance bindings, or enforce optional/required
ISEE governance.
Git-Ape's native `/git-ape-records` skill remains responsible for producing
portable draft Intent and generated Evidence whether this skill is present or
not.

## Boundary

```text
Git-Ape records → portable producer output
ADRP             → Intent authority and ratification
ASRP             → governed Structure, gates, and execution manifest
AERP             → independent Evidence validation and verification
```

The ISEE suite is an optional user experience. Profile CLIs are optional in
`optional` governance and mandatory in `required` governance. Never install
them silently during a deployment workflow.

## Procedure

### Discover

1. Inspect `.azure/deployments/<id>/isee-bindings.json`.
2. If absent and ISEE is not required, report `standalone`.
3. If present, report governance mode, Intent and Structure bindings, gates,
   Evidence duties, and profile CLI availability.

### Preflight

Run:

```bash
.github/skills/git-ape-isee/scripts/verify-bindings.sh \
  --deployment-id <id>
```

In an onboarded repository use:

```bash
.github/git-ape/isee/verify-bindings.sh --deployment-id <id>
```

The verifier always checks native canonical fingerprints and exact artifact
digests. When profile CLIs are available it also performs authoritative
profile validation. Required governance blocks if tooling, authority,
fingerprints, gates, manifests, or approved bytes do not match.

### Evidence

Git-Ape emits the AERP bundle first. If `aerp` is installed, validate and
verify that existing bundle. Do not regenerate it through a second adapter.
Promote `evidence-status.json` from `generated` to `verified` only after both
commands succeed.

### Adopt Existing Git-Ape Records

After installing ISEE into a repository that already onboarded or deployed
with standalone Git-Ape, run:

```bash
.github/git-ape/isee/adopt-existing.sh \
  --deployment-id <id> \
  --mode optional
```

From the Git-Ape plugin checkout, run:

```bash
.github/skills/git-ape-isee/scripts/adopt-existing.sh \
  --deployment-id <id> \
  --mode optional
```

The adoption command:

- validates the existing ADRP record when `adrp` is installed;
- validates and artifact-verifies every existing AERP bundle when `aerp` is
  installed;
- creates `isee-bindings.json` from exact existing fingerprints and artifact
  digests;
- writes `isee-adoption.json` as a human-readable machine record;
- promotes only successfully verified Evidence;
- never installs tooling, regenerates records, or ratifies Intent.

If the deployment ID is supplied, run the command directly. Stop on missing
records, stale artifacts, failed profile validation, or failed verification;
report the exact failing file and do not refresh fingerprints automatically.

For required governance, first ratify the Intent with ADRP and then bind the
ratified record explicitly:

```bash
.github/git-ape/isee/adopt-existing.sh \
  --deployment-id <id> \
  --mode required \
  --intent .github/ape-decisions/<ratified-record>.json
```

Required adoption runs `adrp validate --target <intent> --require-ratified`;
schema-valid drafts are rejected. It also requires `aerp validate` and
`aerp verify --artifact-root <deployment-dir>` for existing Evidence bundles.

## Safety

- Do not make standalone Git-Ape depend on this skill.
- Do not silently install ADRP, ASRP, AERP, Ape Context, or the ISEE suite.
- Do not silently refresh fingerprints after artifacts change.
- Do not mark draft Intent as ratified.
- Do not mark native Evidence as independently verified without AERP.
- Do not modify `state.json` or automatically roll back Azure on Evidence failure.
