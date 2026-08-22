---
title: "Skill scaffold template"
description: "Copy this file to .github/skills/<slug>/SKILL.md and replace every <!-- TODO --> marker. Read the authoring framework spec at https://azure.github.io/git-ape/docs/authoring/framework first."
---

<!--
  HOW TO USE THIS TEMPLATE
  1. Copy this file to `.github/skills/<your-slug>/SKILL.md` (rename, drop `.template`).
  2. Remove this comment block and the `title:`/`description:` frontmatter above
     — a real SKILL.md uses `name:` + `description:` frontmatter instead (see below).
  3. Replace every <!-- TODO --> marker. Delete sections you genuinely do not need
     and document the omission under `## Stop conditions`.
  4. Add an eval at `.github/evals/<your-slug>/` and register it in `manifest.yaml`.
  5. Run `/skill-onboard <your-slug>` to smoke-test.

  Required frontmatter for the real SKILL.md (replace the title/description block above):

  ---
  name: <your-slug>
  description: "One-paragraph routing summary. End with USE FOR: <verbs/phrases>. DO NOT USE FOR: <out-of-scope verbs>. INVOKES: <tool names>."
  ---
-->

# <!-- TODO: Skill Display Name -->

## Purpose

<!-- TODO: One paragraph. What single, narrow job does this skill do? Why does it exist as its own skill instead of a section in another skill? -->

## When to use

<!-- TODO: Bullet list. Mirror the USE FOR clause from the description. Each bullet is a phrase a user would actually say. -->

* <!-- TODO -->
* <!-- TODO -->

## When NOT to use

<!-- TODO: Bullet list. Mirror DO NOT USE FOR. For each out-of-scope case, name the correct skill to route to. -->

* <!-- TODO: out-of-scope case → use `<other-skill>` instead. -->

## Procedure

<!-- TODO: Numbered, deterministic steps. A fresh model should be able to execute end-to-end with only this file in context. Use sub-steps only when necessary. -->

### 1. <!-- TODO: First step name -->

<!-- TODO: What to do, with which input, calling which tool. -->

### 2. <!-- TODO: Second step name -->

<!-- TODO -->

### 3. <!-- TODO: Final step name -->

<!-- TODO -->

## Authoritative sources

<!-- TODO: Table of every external source this skill relies on. Snapshot date is required for any source the skill claims is authoritative. -->

| Source | URL | Snapshot date |
|---|---|---|
| <!-- TODO: e.g. CAF abbreviations --> | <!-- TODO: full URL --> | <!-- TODO: YYYY-MM-DD --> |

## Inline canonical data

<!-- TODO: L1 layer. Put small, stable, high-traffic facts here as tables or short lists. Keep to roughly 20 facts. If it grows past that, move to references/. -->

<!-- Example shape — replace with real content:
| Key | Canonical value | Notes |
|---|---|---|
| foo | bar | …       |
-->

## References

<!-- TODO: L2 layer. List references files (relative paths). If this skill shares a corpus with another skill, point at `.github/references/<topic>/` instead of duplicating. Each referenced file MUST carry source/snapshot/refresh_command frontmatter. -->

* [references/<file>.md](references/<!-- TODO -->.md) — <!-- TODO: one-line description -->

## Tool mandates

<!-- TODO: L3 layer. List the tools the skill MUST call, the trigger condition for each call, and how the result must be cited in the output. -->

| Tool | When to call | How to cite the result |
|---|---|---|
| <!-- TODO: e.g. microsoft_docs_search --> | <!-- TODO: trigger condition --> | <!-- TODO: required citation format --> |

## Output schema

<!-- TODO: Declare the exact shape callers can rely on. JSON, table, or markdown sections — be explicit. Eval graders will assert against this shape. -->

```json
{
  "<!-- TODO: field -->": "<!-- TODO: type and meaning -->"
}
```

## Anti-patterns

<!-- TODO: Negative examples. What this skill must never do. One bullet per anti-pattern, with the reason. -->

* <!-- TODO: e.g. "Do not invent values when the source returns nothing — emit `unknown — out of corpus` instead." -->

## Stop conditions

<!-- TODO: Explicit escape hatches. When the skill cannot answer, what does it do? Refuse, hand off to which skill or agent, ask a clarifying question, or emit a sentinel value? -->

* <!-- TODO: trigger → action -->
