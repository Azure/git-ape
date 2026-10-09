<!-- markdownlint-disable -->

---
title: "Community skill scaffold template"
description: "Copy this file to .github/community-skills/<slug>/SKILL.md and replace every <!-- TODO --> marker."
---

<!--
  HOW TO USE THIS TEMPLATE
  1. Copy this file to `.github/community-skills/<your-slug>/SKILL.md`
     (rename, drop `.template`). Directory name must be kebab-case and
     must match the `name:` field below exactly.
  2. Remove this comment block and the `title:`/`description:` frontmatter
     above — a real SKILL.md uses `name:` + `description:` + `metadata:`
     frontmatter instead (see below).
  3. Fill in `metadata.author` — REQUIRED for community skills. This is how
     users know who built/maintains the skill. Use your GitHub handle,
     org name, or a contact email.
  4. If you maintain the canonical version of this skill in your own repo,
     set `metadata.source` to that repo's URL so users can track updates
     there. Omit it if this repo is the canonical home.
  5. Set `metadata.maturity` to `experimental` (default) or `stable` once
     you've used it in production for a while.
  6. Replace every <!-- TODO --> marker in the body. This skill goes through
     the same PR review and CI checks (structure validation, markdownlint,
     script lint if it has scripts) as a first-party skill.

  Required frontmatter for the real SKILL.md (replace the title/description
  block above):

  ---
  name: <your-slug>
  description: "One sentence describing what the skill does and when it fires. USE FOR: <trigger phrases>. DO NOT USE FOR: <out-of-scope cases>."
  license: MIT
  metadata:
    author: <your GitHub handle, org, or contact>
    source: <optional: URL of the repo where you maintain this skill>
    maturity: experimental
    version: "1.0.0"
  ---
-->

# <!-- TODO: Skill Display Name -->

> <!-- TODO: One-sentence value proposition. -->

## When to Use

<!-- TODO: Bullet list. Each bullet is a phrase a user would actually say. -->

* <!-- TODO -->
* <!-- TODO -->

## Procedure

<!-- TODO: Numbered, deterministic steps. A fresh model should be able to execute end-to-end with only this file (plus any scripts/references/ it links to) in context. -->

### 1. <!-- TODO: First step name -->

<!-- TODO: What to do, with which input, calling which tool. -->

### 2. <!-- TODO: Second step name -->

<!-- TODO -->

### 3. <!-- TODO: Final step name -->

<!-- TODO -->

## Outputs

<!-- TODO: The literal structure this skill is contracted to produce — table, JSON shape, or file path. -->

## Constraints

**Always:**

* <!-- TODO -->

**Never:**

* <!-- TODO -->

## Attribution

* **Author:** <!-- TODO: same value as `metadata.author` above -->
* **Source:** <!-- TODO: same value as `metadata.source`, or "This repository" -->
* **Support:** <!-- TODO: where users should file issues for this skill (your repo's issue tracker, not Azure/git-ape) -->

<!-- markdownlint-enable -->
