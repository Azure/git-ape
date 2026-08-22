---
title: "Authoring Skills"
sidebar_label: "Skills"
sidebar_position: 3
description: "How to add a new skill: directory layout, SKILL.md frontmatter, structure, and registration."
---

# Authoring Skills

A **skill** is a focused, callable capability with a documented procedure. Skills are the atomic unit Git-Ape composes into agent workflows. Each skill is a directory under [`.github/skills/`](https://github.com/Azure/git-ape/tree/main/.github/skills) containing one `SKILL.md` file (plus optional helper files).

## Quick start

```bash
SKILL=my-new-skill
mkdir -p .github/skills/"$SKILL"
$EDITOR .github/skills/"$SKILL"/SKILL.md
```

Then write the frontmatter and body following the template below. No further registration is needed — `plugin.json` declares `"skills": ".github/skills/"` and Copilot auto-discovers every subdirectory containing a `SKILL.md`.

> **Optimize your skill from the start.** Don't ship a `SKILL.md` blind — use the prompts listed in [Prompts](./prompts) to evaluate and harden it as you write:
>
> - [`/skill-onboard`](./prompts#skill-onboard) — scaffolds `.github/evals/<skill>/` with positive and negative tasks and runs a smoke trial so you see how the skill behaves before you commit it.
> - [`/skill-bench`](./prompts#skill-bench) — benchmarks the skill across models so you know which ones it works on.
> - [`/skill-improve`](./prompts#skill-improve) — diagnoses failing tasks and proposes targeted edits to your `SKILL.md`.
> - [`/skill-promote`](./prompts#skill-promote) — locks the skill in once it's stable.
>
> Run `/skill-onboard` as soon as your first draft is readable — even rough drafts surface gaps faster through evals than through re-reads.

## File layout

```
.github/skills/my-new-skill/
├── SKILL.md             # Required: frontmatter + procedure
├── scripts/             # Optional: helper scripts the skill shells out to
└── templates/           # Optional: text/config templates referenced by the skill
```

The directory name **must** match the `name:` field in frontmatter.

## SKILL.md template

```markdown
---
name: my-new-skill
description: "One sentence describing what the skill does and when it should fire. WHEN: trigger phrase 1, trigger phrase 2, trigger phrase 3. DO NOT USE FOR: scope boundary 1, scope boundary 2."
argument-hint: "Free-text hint shown to users when they invoke the skill"
user-invocable: true
license: MIT
metadata:
  author: Git-Ape
  version: "1.0.0"
---

# Display Title

One paragraph describing what the skill does and the value it delivers.

## Quick Reference

| Property | Value |
|----------|-------|
| Best for | One-line summary of the primary use case |
| MCP tools | Tool names, or `None — runs locally via shell` |
| CLI | Primary commands, e.g. `az policy assignment list` |
| Related skills | Sibling skills to call before/after |
| Side effects | `Read-only`, or list what gets created / modified |

## When to Use

- Bullet describing trigger condition 1 (user's voice)
- Bullet describing trigger condition 2
- Bullet describing trigger condition 3

## Rules

1. Numbered, blocking constraints the agent must follow.
2. Use `⛔` or `❌` prefixes for hard rules and reference them later when steps depend on them.

## Steps

| # | Action | Reference |
|---|--------|-----------|
| 1 | **Verify Prerequisites** — what to check first | inline |
| 2 | **Do the Thing** — short imperative | [references/foo.md](references/foo.md) |
| 3 | **Report Results** — produce the output contract | See [Outputs](#outputs) |

### Step 1: Verify Prerequisites

```bash
command -v az >/dev/null || { echo "az not found"; exit 1; }
```

### Step 2: Do the Thing

Describe the action. Use fenced code blocks for any shell or API calls so they can be reused verbatim. Push long examples into `references/*.md` to stay under the token budget.

### Step 3: Report Results

Link to the **Outputs** section.

## Outputs

Show the literal structure the skill is contracted to produce — table, JSON shape, or file path. Eval graders score against this contract, so make it concrete.

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `<exact error text>` | Why it happens | What to run |

## Constraints

**Always:**

- ✅ Concrete do-this behavior

**Never:**

- ❌ Concrete don't-do-this behavior

## Next

What the user (or agent) should invoke after a successful run. Use a clickable chip:

> Next: **@Some Agent** — or run `/some-skill` to continue.

`@AgentName` and `/skill-name` render as clickable chips in VS Code Copilot Chat.
```

## Frontmatter reference

| Field | Required | Purpose |
|-------|:--------:|---------|
| `name` | ✅ | Kebab-case skill identifier. Must match directory name. |
| `description` | ✅ | Used by the Copilot router. Encode trigger phrases with `USE FOR:` and scope boundaries with `DO NOT USE FOR:` — specific verbs and nouns improve routing precision. (`WHEN:` is also accepted but `USE FOR:` matches the wider skill ecosystem.) |
| `argument-hint` | ⚪ | Free-text hint displayed in the prompt picker. |
| `user-invocable` | ⚪ | Defaults to `true`. Set `false` for skills that only run as a sub-step of an agent and should not be surfaced standalone. |
| `license` | ⚪ | Recommended `MIT` for skills shipped with this repo — keeps redistribution rights explicit. |
| `metadata.author` | ⚪ | Free-text author or team name (e.g. `Git-Ape`, `Microsoft`). |
| `metadata.version` | ⚪ | Semver string. Bump on every behavior change — eval suites and CI can pin to a version. |

## Anatomy of a good skill

Look at [`prereq-check/SKILL.md`](https://github.com/Azure/git-ape/blob/main/.github/skills/prereq-check/SKILL.md) for the canonical reference. The twelve principles below are the patterns Git-Ape skills follow — they are distilled from the Microsoft `azure-skills` package and apply to every skill in `.github/skills/`.

### Twelve principles

1. **Frontmatter is metadata, not decoration.** Add `license`, `metadata.author`, and `metadata.version` so skills are versionable and reproducible. Encode trigger boundaries in `description` with `USE FOR:` and `DO NOT USE FOR:` markers — vague descriptions hurt router precision.
2. **Open with a `## Quick Reference` table.** One scannable block (`Best for`, `MCP tools`, `CLI`, `Related skills`, `Side effects`) before any prose. Cuts time-to-orient for both the model and a human reviewer.
3. **`## When to Use` is the trigger contract.** Concrete, user-voice bullets. The router and eval graders both grade against this list.
4. **Hard-block guardrails as callouts.** Use `> **⛔ STOP**` / `> **⚠️ MANDATORY**` blockquotes for non-negotiables; numbered `## Rules` for everything else.
5. **Steps as a table, body as expansion.** A `# | Action | Reference` table at the top, then per-step detail underneath. Lets the agent skim and dispatch without re-reading the whole body.
6. **MCP-first, CLI-fallback.** Every Azure-touching skill lists MCP tools in a table with an explicit CLI fallback when MCP is not enabled. Discover before you act — never assume names or schemas.
7. **Explicit `## Outputs` contract.** What files, tables, or JSON the skill is contracted to produce. Eval graders score against this.
8. **`## Error Handling` table.** Rows of `Error | Cause | Fix` for the top failure modes. Cheap, high-signal documentation.
9. **`## Constraints` as Always / Never sections.** Explicit do/don't lists at the bottom catch drift. Use `**Always:**` and `**Never:**` headers — polarity is already conveyed, so do **not** prefix each bullet with ✅/❌ (each emoji costs 1-3 tokens and adds no information). Reserve emoji semantics for *status output* only: ⛔ blocking, ⚠️ warn, ❌ misconfigured, ✅ applied, 🔄 platform default, ❔ unknown.
10. **Cross-skill chains are explicit — emit a handoff chip.** Document `A → B → C` flows and end with a `## Next` pointer. VS Code Copilot Chat renders `@AgentName` mentions and `/skill-name` slash commands as clickable chips — the closest thing to a button in the chat surface. Always include at least one in `## Next` (e.g. `Next: **@Git-Ape Onboarding** — or run /git-ape-onboarding`) so the user can dispatch the follow-up with one click. Add `⛔ MANDATORY NEXT STEP` when the hand-off is required.
11. **Push depth into `references/`.** Keep `SKILL.md` close to the 1,300-token budget; long CLI examples, schema tables, and provider-specific patterns belong in `references/*.md` linked from the steps table. Bash one-shots can live in `scripts/`.
12. **No persona language.** Skills read like runbooks. Persona-lock belongs in the `.agent.md` that calls the skill, not in the skill itself.

## Token budget

`waza` runs a token audit on every skill. The thresholds live in [`.waza.yaml`](https://github.com/Azure/git-ape/blob/main/.waza.yaml):

```yaml
tokens:
  warningThreshold: 1000   # warn above this
  fallbackLimit: 1300      # hard fail above this (waza tokens compare --strict)
```

Run `waza tokens count .github/skills/my-new-skill/SKILL.md` while iterating to keep the skill within budget. The [`/skill-improve`](./prompts#skill-improve) prompt automates the audit + edit loop and shows a before/after delta.

## Local validation

Before opening a PR, run:

```bash
# Lint frontmatter and structure
waza check .github/skills/my-new-skill

# (Optional) Estimate token count
waza tokens count .github/skills/my-new-skill

# If you also wrote an eval suite (see "Eval suites"):
waza run .github/evals/my-new-skill/eval.yaml --no-cache
```

`waza check` validates the skill against the [agentskills.io](https://agentskills.io) frontmatter spec.

## CI integration

Adding the skill file is enough to ship it as a runtime capability. To opt the skill into the [PR-time eval matrix](./evals#how-ci-picks-up-your-eval), add a row to [`.github/evals/manifest.yaml`](https://github.com/Azure/git-ape/blob/main/.github/evals/manifest.yaml) **and** create `.github/evals/my-new-skill/eval.yaml`. The matrix runs the suite against every model in the selected tier on each PR that touches relevant files.

## Common pitfalls

- **Vague `description:` text** — the trigger grader will catch this. Specific verbs/nouns improve routing.
- **Directory name doesn't match `name:`** — `waza check` will flag it but the plugin loader silently skips the skill in some clients. Always match exactly.
- **Skill embeds persona** — move "you are X" framing into an `.agent.md` and have the agent call the skill. Skills should read like runbooks, not personas.
- **No output contract** — the `behavior` grader needs something concrete to verify. Document the literal output shape.

## Read next

- [Eval suites](./evals) — score the skill across models
- [Prompts](./prompts#skill-improve) — local audit + edit loop
- [Authoring agents](./agents) — wrap the skill in a persona
