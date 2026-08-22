---
title: "Prompts"
sidebar_label: "Prompts"
sidebar_position: 6
description: "The onboard / bench / improve / promote prompts you use to scaffold, evaluate, and harden your skills and agents from creation onward."
---

# Prompts

Prompts are short, parametric commands shipped under [`.github/prompts/`](https://github.com/Azure/git-ape/tree/main/.github/prompts) that wrap the authoring loop: scaffolding eval suites at creation, cross-model benchmarking, iterative quality improvement, and readiness assessment for promotion.

**Use them while authoring, not after.** They exist so that every skill and agent you write is grounded in measurable evals from the first commit. Drafting a `SKILL.md` or `.agent.md` without running `/skill-onboard` or `/agent-onboard` is shipping blind — the prompts are how you turn a rough draft into something a model can reliably execute.

## When to use which

| Goal | Prompt |
|------|--------|
| "This skill has no eval suite yet — scaffold one." | [`/skill-onboard`](#skill-onboard) |
| "This agent has no eval suite yet — scaffold one." | [`/agent-onboard`](#agent-onboard) |
| "Which model handles this skill best?" | [`/skill-bench`](#skill-bench) |
| "Which model handles this agent best?" | [`/agent-bench`](#agent-bench) |
| "This skill scored low — help me fix it." | [`/skill-improve`](#skill-improve) |
| "This agent scored low — help me fix it." | [`/agent-improve`](#agent-improve) |
| "Is this skill ready for the `pilot` tier?" | [`/skill-promote`](#skill-promote) |
| "Is this agent production-ready?" | [`/agent-promote`](#agent-promote) |

> **Cost notice:** every prompt invokes `waza run` one or more times. Each leg consumes premium model requests. Bench and promote prompts run across multiple models (default four); improve loops can run up to three rounds. Plan your quota before invoking.

## File format

All prompts share the same shape:

```markdown
---
agent: 'agent'
description: 'One-sentence description'
argument-hint: '[paramA=...] [paramB=...]'
---

# Prompt body

Procedural steps the prompt's wrapping agent will execute,
typically a sequence of `bash` blocks and decision points.
```

The `agent: 'agent'` value pins execution to VS Code's generic chat agent (no specific persona). Add or edit prompt files directly under `.github/prompts/`; no further registration is needed.

## skill-onboard

**Description.** Stage 0 of the eval lifecycle — bootstrap a brand-new eval suite for a skill that currently has none. Scaffolds `eval.yaml` + positive / negative / off-topic task files, patches them to repo conventions (hybrid graders, concrete prompts, schema headers), registers the skill at the `expanded` tier in `manifest.yaml`, and runs a single-model smoke trial to confirm the suite is wired correctly.

**Arguments.** `[skillName=...] [positiveTasks={2|3|4}] [negativeTasks={1|2}] [smokeModel=claude-sonnet-4.6]`

**Interactivity.** **Interactive.** Pauses for approval before appending to `manifest.yaml` and before running the smoke trial.

**Output.** A new `.github/evals/<skill>/` directory containing `eval.yaml`, positive tasks, a trigger-only negative task, and an off-topic refusal task, plus a `{ name: <skill>, tier: expanded }` entry in `manifest.yaml`. The smoke trial prints per-task pass / fail and aggregate score.

**Out of scope.** Does **not** edit `SKILL.md` (use [`/skill-improve`](#skill-improve) for that) and does **not** promote the skill to the `pilot` tier (use [`/skill-promote`](#skill-promote) after the skill has matured in `expanded`).

**Cost.** ≈ 5–8 premium requests per invocation: 1 for the `waza suggest --apply` scaffold + `1 × len(tasks)` for the smoke trial (default 4) plus per-task LLM-judge calls.

**Use when.** You've authored or refactored a `SKILL.md` that has no companion eval suite and you want a guarded path from zero to a working `expanded`-tier entry without hand-writing every task YAML.

## agent-onboard

**Description.** Stage 0 of the agent eval lifecycle — bootstrap a brand-new eval suite for a custom agent that currently has no evaluation. Scaffolds `.github/evals/agents/<agent>/` with `eval.yaml`, a mirror copy of the `.agent.md` (waza walks the directory under `skill_directories: ["."]`), positive and negative tasks, and an off-topic task with a `clean_refusal` grader that asserts the agent identifies itself and redirects to its specialty. Runs a single-model smoke trial. No edits to the canonical `.agent.md` or to `manifest.yaml` (agent evals are auto-discovered from the filesystem).

**Arguments.** `[agentName=...] [positiveTasks={2|3|4}] [negativeTasks={1|2}] [smokeModel=claude-sonnet-4.6]`

**Interactivity.** **Interactive.** Pauses for approval before writing the eval directory and before running the smoke trial.

**Output.** A new `.github/evals/agents/<agent>/` directory with `eval.yaml`, a mirrored `<agent>.agent.md`, positive tasks (hybrid `trigger` + `answer_quality` graders), a trigger-only negative task, and an off-topic refusal task. The smoke trial prints per-task pass / fail and an aggregate score.

**Out of scope.** Does **not** edit the canonical `.github/agents/<agent>.agent.md` (use [`/agent-improve`](#agent-improve) for that), does **not** run readiness checks (use [`/agent-promote`](#agent-promote) after the agent has matured), and does **not** touch `manifest.yaml`.

**Cost.** ≈ 6–9 premium requests per invocation: `1 × len(tasks)` for the smoke trial (default 4) plus per-task LLM-judge calls.

**Use when.** You've authored or refactored an `.agent.md` that has no companion eval suite and you want a guarded path from zero to a working agent eval directory.

## skill-bench

**Description.** Cross-model benchmark for a single skill: runs `waza` eval once per model, captures results, compares with `waza compare`, and prints a one-line winner summary.

**Arguments.** `[skillName=...] [models=claude-sonnet-4.6,gpt-5.4,gpt-5-codex,claude-opus-4.6]`

**Interactivity.** Non-interactive once `skillName` is supplied. Prompts for the name if omitted.

**Output.** A `waza compare` table (per-model aggregate score, success rate, latency, premium requests) plus a one-line winner.

**Use when.** You want to know which model handles a skill best — for example, before promoting a skill or after editing the SKILL.md substantially.

## agent-bench

**Description.** Same as `skill-bench` but targets a custom agent (under `.github/evals/agents/<name>/`).

**Arguments.** `[agentName=...] [models=claude-sonnet-4.6,gpt-5.4,gpt-5-codex,claude-opus-4.6]`

**Use when.** Sweeping the model field for an agent. Pair with `/agent-promote` once the winner is clear.

## skill-improve

**Description.** Local feedback loop for a single skill: baseline → audit → propose edits → apply (with approval) → re-rank via `waza compare`. Optionally loops up to 3 rounds for deeper refinement.

**Arguments.** `[skillName=...] [iterations={1|2|3}] [rescoreQuality={true|false}]`

**Interactivity.** **Interactive.** After each proposed edit you approve, reject, or amend.

**Output.** A per-round diff plus updated comparison table. The skill file is modified in place when you approve.

**Use when.** A skill scored below the pilot promotion bar and you want a guided revision loop instead of hand-editing.

## agent-improve

**Description.** Same as `skill-improve`, applied to `.github/agents/<name>.agent.md`. Also re-syncs the eval-directory mirror (`.github/evals/agents/<name>/<name>.agent.md`) after every approved edit.

**Arguments.** `[agentName=...] [iterations={1|2|3}] [rescoreQuality={true|false}]`

**Use when.** An agent's persona-lock leaks, off-topic refusals are weak, or trigger precision is below threshold.

## skill-promote

**Description.** Assess whether a skill in the `expanded` eval tier is ready to graduate to `pilot` (full 4-model fan-out). Runs the eval suite, checks against numeric promotion criteria, and prints a graduation report.

**Arguments.** `[skillName=...]`

**Output.** A `PROMOTE` / `BLOCK` verdict with the specific criterion that gated the decision (e.g. `success_rate < 0.85 on gpt-5.4`). When `PROMOTE`, it suggests the `manifest.yaml` patch.

**Use when.** A skill has been stable in `expanded` for a few PRs and you're considering moving it to `pilot`.

## agent-promote

**Description.** Assess whether a custom agent is production-ready: runs the eval suite across pilot-tier models, checks against numeric readiness criteria, and prints a graduation report.

**Arguments.** `[agentName=...] [models=claude-sonnet-4.6,gpt-5.4,gpt-5-codex,claude-opus-4.6]`

**Output.** A readiness verdict per criterion (persona-lock, off-topic refusal rate, trigger precision, budget compliance, answer-quality threshold) and an overall `GO` / `NO-GO`.

**Use when.** Before flipping an agent's `user-invocable: true` for the first time, or before announcing it to users.

## Read next

- [Eval suites](./evals) — what the prompts actually run
- [Authoring skills](./skills) — content the improve loop edits and the onboard prompt consumes as-is
- [Authoring agents](./agents) — agent surface specifics
