---
title: "Shared references corpus"
description: "L2 grounding corpus shared across skills. Conventions, snapshot format, and refresh procedure."
---

## What this directory is

The **L2 grounding layer** of the [authoring framework](https://azure.github.io/git-ape/docs/authoring/framework#the-grounding-contract).

Each subdirectory under `.github/references/` is a curated, dated snapshot of an authoritative external source — Microsoft Learn pages, OpenAPI specs, regex tables, JSON schemas, vendor docs.

Skills consume this corpus by relative path. The corpus is human-readable markdown by design; this is not an embedding index, not a vector store, and not RAG infrastructure.

## When a reference belongs here vs. inside a skill

| Situation | Location |
|---|---|
| Used by one skill, unlikely to be shared | `.github/skills/<slug>/references/` (skill-local) |
| Used by two or more skills, or likely to be | `.github/references/<topic>/` (shared, here) |
| Skill-internal regex tables, prompt fragments, output schemas | `.github/skills/<slug>/references/` (skill-local) |
| Canonical vendor doc snapshot (CAF abbreviations, RBAC roles, API versions, etc.) | `.github/references/<topic>/` (shared, here) |

When in doubt, start skill-local. Hoist to shared the first time a second skill needs the same canon — do not copy-paste.

## Snapshot file format

Every reference file MUST start with this frontmatter:

```yaml
---
source: <canonical URL of the upstream source>
snapshot: YYYY-MM-DD
refresh_command: <one-line shell command that regenerates this file>
---
```

* **`source`** — the canonical upstream URL. Used by graders to verify citations.
* **`snapshot`** — the date the content was last verified against upstream. Used by the staleness check.
* **`refresh_command`** — exact command to re-fetch and regenerate. Should be idempotent; should fail loudly if the upstream shape changed.

After the frontmatter, the body is normal markdown. Prefer tables, lists, and structured sections over prose — skills consume this content programmatically.

## Directory layout

```text
.github/references/
├── README.md             ← this file
└── <topic>/
    ├── <file>.md         ← snapshot file (with source/snapshot/refresh_command frontmatter)
    └── <file>.md
```

A `<topic>` directory is a coherent corpus. Examples (illustrative; create them on demand, do not pre-stub):

* `azure-caf/` — Cloud Adoption Framework abbreviations and naming rules
* `azure-rbac/` — built-in role definitions snapshot
* `openssf-scorecard/` — Scorecard check definitions

## Refresh procedure

1. Pick a reference file you suspect is stale (or that the staleness check flagged).
2. Run the file's `refresh_command`.
3. Inspect the diff. If the upstream shape changed (new columns, removed entries, schema break), the refresh command should fail and surface the diff — do not silently overwrite.
4. Update the `snapshot:` date.
5. Run the skill's eval suite to catch any regression caused by content drift.
6. Commit the snapshot update separately from any skill changes that depend on it.

## Staleness thresholds

Per-canon thresholds live next to the topic's files (in a `_meta.yaml` or similar) once the corpus has more than one snapshot. Default if unset: **90 days**. The quality gate (`waza check` or equivalent) flags older snapshots.

## What does NOT belong here

* **Generated artifacts.** If a file can be regenerated deterministically from another file, regenerate at runtime; do not snapshot the derivative.
* **Skill-internal scaffolding.** Output schemas, prompt fragments, and grader rubrics are skill-local.
* **Secrets, tokens, or credentials.** Snapshots are public source content only.
* **Large binary data.** Tables, lists, structured markdown only. If a corpus needs binary data, that is a sign it should be fetched live (L3), not snapshotted (L2).

## Adding a new topic

1. Create `.github/references/<topic>/`.
2. Add the first snapshot file with the required frontmatter.
3. Update the skill that consumes it to point at the shared path instead of any skill-local copy.
4. Delete the skill-local copy if one existed.
5. Add a one-line entry to the directory layout above so future authors can find it.
