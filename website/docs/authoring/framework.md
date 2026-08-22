---
title: "Authoring framework for skills, agents, prompts, and instructions"
sidebar_label: "Framework spec"
sidebar_position: 2
description: "The contract every skill and agent in this repo follows: anatomy templates, grounding policy, eval-as-contract enforcement, and the closed-loop authoring lifecycle."
---

## Purpose

This is the framework spec for every prompt-engineering artifact in `.github/`. It is generic — domain examples are illustrative, the rules apply to any skill or agent regardless of domain.

The skill format conforms to the **Agent Skills open standard** at [agentskills.io](https://agentskills.io/) [\[1\]](#refs). This document extends that standard with three repo-specific contracts: a third grounding layer for live tool calls, an eval-as-contract policy enforced in CI, and an agent file format for VS Code Copilot custom agents.

Read this once before adding a new skill, agent, prompt, or shared reference. Every file under `.github/skills/**`, `.github/agents/**`, `.github/prompts/**`, `.github/instructions/**`, and `.github/references/**` MUST conform to the contracts below.

## TL;DR

Four primitives. One grounding policy. One lifecycle. The eval suite enforces the contract; the skill author does not "train" anything.

```text
PROMPT (.prompt.md)         user-invokable command, triggers a workflow
   │
   ▼
AGENT (.agent.md)           persona + workflow + curated skill set
   │
   ▼
SKILL (SKILL.md)            one narrow procedure + tool mandates + sources
   │
   ▼
REFERENCES (references/*)   authoritative snapshots, schemas, regex tables

CROSS-CUTTING: INSTRUCTIONS (.instructions.md, applyTo: glob) — repo-wide policy.
```

Decision rule:

* **Skill** — *"how do I do X step by step, with what sources?"*
* **Agent** — *"who am I, what is my workflow, which skills do I own?"*
* **Prompt** — *"the user's verb that boots a workflow"*
* **Instructions** — *"rules that apply regardless of which skill or agent fired"*

## The four primitives

### Skill

Atomic, reusable procedure. One job, well grounded. Follows `templates/SKILL.template.md`.

A skill is a directory containing a `SKILL.md` with YAML frontmatter (required: `name`, `description`) plus optional `scripts/`, `references/`, and `assets/` subdirectories — the canonical layout defined by the Agent Skills spec [\[1\]](#refs)[\[2\]](#refs).

Lives at `.github/skills/<slug>/SKILL.md`. Discovered by the runtime via `plugin.json` and by the eval harness via `.github/evals/manifest.yaml`.

### Agent

Thin orchestrator. Owns a persona, a workflow, and a curated list of skills. Follows `templates/AGENT.template.md`.

Lives at `.github/agents/<name>.agent.md`. Calls skills for domain knowledge. Carries no how-to detail of its own; if an agent file is becoming long, extract the procedural content into one or more skills.

### Prompt

User-invokable verb. Boots a workflow with arguments. Often delegates to an agent via `agent:` frontmatter.

Lives at `.github/prompts/<name>.prompt.md`.

### Instructions

Cross-cutting policy applied by glob. Used for conventions that span many files (commit style, markdown linting, naming standards).

Lives at `.github/instructions/<name>.instructions.md`. Required frontmatter: `description` and `applyTo`.

## The grounding contract

This is the centerpiece. Every skill obeys it. Every agent inherits it from its skills.

### Progressive disclosure, plus a third layer

The Agent Skills standard defines a three-stage **progressive disclosure** model: Discovery (metadata only), Activation (full `SKILL.md` body), and Execution (bundled scripts and reference files loaded on demand) [\[1\]](#refs)[\[2\]](#refs). This framework adopts that model verbatim and adds an L3 layer for live tool-mediated fetches when freshness matters.

| Layer | Agent Skills stage [\[1\]](#refs) | Where it lives | When it is used | Cost |
|---|---|---|---|---|
| **L1 — Inline canon** | Activation (SKILL.md body) | `SKILL.md` body, up to roughly 20 facts | Hot path; common, stable answers | 0 tool calls |
| **L2 — References corpus** | Execution (bundled files) | `references/*.md` next to the skill, or shared `.github/references/<canon>/` | When L1 misses | 1 file read |
| **L3 — Live fetch** *(framework extension)* | n/a (not in baseline spec) | MCP tool (`microsoft_docs_*`, etc.), `curl`, REST API | When L2 misses or freshness is required | 1 or more tool calls |

The upstream spec recommends keeping `SKILL.md` under roughly 500 lines and 5,000 tokens [\[1\]](#refs)[\[6\]](#refs) — only the core instructions the agent needs on every run. When a skill legitimately needs more, move detail to L2 references and tell the agent *when* to load each file: `Read references/api-errors.md if the API returns a non-200 status code` is more useful than a bare `see references/ for details`. That conditional load instruction is what makes progressive disclosure work in practice.

### Citation policy (cite-or-fail)

Every factual claim in a skill's output MUST cite one of:

1. A snapshot date from an L1 or L2 source.
2. A live URL from an L3 fetch result.
3. The literal token `unknown — out of corpus`.

Skills never recite from model memory without grounding. Where memory-only answers are explicitly acceptable, the SKILL.md says so under a `## Stop conditions` section.

### Snapshot refresh policy

Each L2 file carries this header block:

```yaml
---
source: <canonical URL>
snapshot: YYYY-MM-DD
refresh_command: <one-line shell command to regenerate>
---
```

A repo-level `scripts/refresh-snapshots.sh` (or per-canon script) re-fetches and diffs. `waza check` (or the equivalent quality gate) flags snapshots older than a per-canon threshold.

### Shared references convention

When two or more skills consume the same canon, the canon moves up to `.github/references/<topic>/`. Skills reference it by relative path. Never copy-paste a snapshot table between skills.

```text
.github/references/
├── README.md            ← framework conventions for shared canon
├── azure-caf/
│   ├── abbreviations.md
│   └── naming-rules.md
└── ...
```

## The skill anatomy contract

The following sections are the recommended structure for `SKILL.md`, in this order. The full scaffold lives at `templates/SKILL.template.md` — copy it when authoring a new skill. **Anatomy is documentation, not a runtime gate**: the eval (`eval.yaml`) is what graders run against, and it is where the load-bearing checks live.

The Agent Skills spec only requires `name` and `description` in frontmatter [\[1\]](#refs). This framework keeps those two fields and adds repo-specific anatomy sections below — none of these sections are part of the open standard; they exist to make our skills self-contained and eval-gradable.

| Section | Purpose |
|---|---|
| Frontmatter `name`, `description` | Routing metadata (per Agent Skills spec [\[1\]](#refs)). `description` ends with `USE FOR:`, `DO NOT USE FOR:`, `INVOKES:` clauses. |
| `## Purpose` | One paragraph; why this skill exists. |
| `## When to use` | Bullets mirroring `USE FOR`. |
| `## When NOT to use` | Bullets mirroring `DO NOT USE FOR`. |
| `## Procedure` | Numbered, deterministic steps. |
| `## Authoritative sources` | Table: source name, URL, snapshot date. |
| `## Inline canonical data` | L1 content — small, stable facts. |
| `## References` | Pointers to L2 files (relative paths). |
| `## Tool mandates` | L3 — required tool calls and how to cite their results. |
| `## Output schema` | JSON shape or markdown sections callers can rely on. |
| `## Anti-patterns` | Negative examples. |
| `## Stop conditions` | When to escalate, refuse, or ask the user. |

Two checks decide whether a SKILL.md is framework-compliant:

1. **Self-contained.** A fresh model with only this file in context can execute the procedure without guessing. This mirrors Anthropic's "think from Claude's perspective" guidance [\[2\]](#refs): the `name` and `description` are the trigger surface; the body is the operational manual.
2. **Auditable.** Every claim in its output traces back to a source listed under `## Authoritative sources` — inline, references, or a tool result.

## The agent anatomy contract

The following sections are the recommended structure for `.agent.md`. The full scaffold lives at `templates/AGENT.template.md` — copy it when authoring a new agent. **Anatomy is documentation, not a runtime gate**: the eval (`eval.yaml`) is what graders run against. Agents are thin (domain knowledge belongs in the skills they call), so the load-bearing minimums are the frontmatter (`name`, `description`, `tools`) and a `## Workflow` section the eval can anchor task prompts against.

| Section | Purpose |
|---|---|
| Frontmatter `name`, `description`, `argumentHint`, `tools` | Routing metadata + tool whitelist. |
| `## Identity (non-negotiable)` | Persona lock-in. The agent never identifies as anything else, including on off-topic prompts. |
| `## Mission` | One sentence. |
| `## Skills I own` | Ordered list of skills with load priority. |
| `## Workflow` | Phases with explicit hand-offs to skills. |
| `## State management` | Where session state lives; recovery rules. |
| `## Interaction contract` | Question cadence; headless mode hook (CI-safe). |
| `## Non-goals` | Refusal redirect script for off-topic prompts. |
| `## Hand-off contracts` | Inputs and outputs when calling other agents. |

Rule of thumb: agents are thin. Domain knowledge belongs in the skills they call. If an agent file grows fat with how-to detail, that detail is mis-located — extract it into a skill.

## Authoring practices

Anatomy is necessary but not sufficient. These are the editorial principles every skill in this repo applies. They come from the official Agent Skills authoring guide [\[6\]](#refs) and Anthropic's design rationale [\[2\]](#refs).

### Ground every skill in real expertise

Skills extracted from a hands-on agent session (with corrections you made along the way) and skills synthesized from project artifacts (runbooks, schemas, code-review comments, PR history) consistently outperform skills generated cold from generic best-practices articles [\[6\]](#refs). Two viable paths:

* **Extract from a hands-on task.** Run the task with an agent, note the corrections you made, then distil the reusable pattern into a skill.
* **Synthesize from existing project artifacts.** Feed internal documentation, schemas, runbooks, and the version-control history (especially patches and fixes) into an LLM as source material — not generic references.

Generic skills with no project-specific context produce vague procedures (`handle errors appropriately`) and are the most common first-author failure mode [\[6\]](#refs).

### Spend context wisely

Once a skill activates, its full `SKILL.md` body loads into the agent's context window alongside conversation history, system context, and other active skills. Every token competes for attention.

* **Add what the agent lacks; omit what it knows.** Skip explanations of well-known concepts (what a PDF is, how HTTP works). Jump to the project-specific decision (which library, which flag, which gotcha).
* **Design coherent units.** A skill is like a function: encapsulate one job that composes with others. Too narrow → multiple skills load for one task; too broad → activation precision suffers.
* **Aim for moderate detail.** Concise stepwise guidance plus one worked example outperforms exhaustive enumeration. Trust the agent's own judgment for routine edge cases.

### Calibrate control to fragility

Not every instruction needs the same prescriptiveness. Match specificity to how fragile the task is [\[6\]](#refs).

* **Give freedom where multiple approaches work.** Code review, analysis, design — describe what to look for, explain *why*, let the model choose how.
* **Be prescriptive where operations are fragile.** Database migrations, destructive ops, a specific deploy sequence — give the exact command and forbid variation.
* **Provide defaults, not menus.** When several tools could work, pick one and mention alternatives as escape hatches. Avoid `you can use A, B, C, or D` lists.
* **Favor procedures over declarations.** Teach the agent how to approach a class of problems, not the answer to one instance.

### Reusable patterns

Pick the ones that fit; not every skill needs all of them [\[6\]](#refs).

| Pattern | When to use |
|---|---|
| **Gotchas section** | Concrete corrections to mistakes the agent will make without being told (soft deletes, field-name aliases, misleading health endpoints). Add a gotcha every time you have to correct the agent. |
| **Output templates** | When the caller expects a specific format. Pattern-matching against a concrete structure beats describing the format in prose. Inline if short; in `assets/` if long. |
| **Checklists** | Multi-step workflows with dependencies. Helps the agent track progress and skip nothing. |
| **Validation loops** | Do the work → run a validator → fix → repeat until validation passes. The validator can be a script, a checklist, or a reference document. |
| **Plan-validate-execute** | For batch or destructive ops: emit an intermediate plan as structured data, validate it against a source of truth, only then execute. |
| **Bundled scripts** | When trace analysis shows the agent reinventing the same logic across runs — extract it into `scripts/` once. See the next section. |

### Refine with real execution

Even a single execute-then-revise pass noticeably improves quality; complex skills often need several iterations [\[6\]](#refs). Read execution *traces*, not just final outputs — if the agent wastes time on unproductive steps, the cause is usually a vague instruction, an instruction that doesn't apply, or too many options without a default. The eval-as-contract section below codifies the systematic iteration loop.

## Bundled scripts contract

When a skill bundles executables in `scripts/`, those scripts MUST be designed for agentic invocation. These rules come from the upstream Using Scripts guide [\[7\]](#refs).

| Rule | Why |
|---|---|
| **Non-interactive — hard requirement.** | Agents run in non-TTY shells. Any script that blocks on `read`, password prompt, or confirmation menu hangs the run indefinitely. Accept input via flags, env vars, or stdin only. |
| **Implement `--help` with a usage line, flag list, and at least one example.** | `--help` is the primary surface through which the agent learns the interface. Keep it concise — it enters the context window. |
| **Write actionable error messages.** | An opaque `Error: invalid input` wastes a turn. Say what went wrong, what was expected, and what to try (e.g., `Error: --format must be one of: json, csv, table. Received: "xml"`). |
| **Use structured output (JSON / CSV / TSV) by default.** | Composable with `jq`, `cut`, `awk`. Send data to stdout, diagnostics and progress to stderr. |
| **Document distinct exit codes.** | The agent reads exit codes to decide next steps. Reserve `0` for success, distinct non-zero codes for invocation errors vs. domain failures, and document each code in `--help`. |
| **Be idempotent.** | The harness may retry. `Create if not exists` is safer than `create and fail on duplicate`. |
| **Offer `--dry-run` for destructive or stateful ops.** | Lets the agent preview the effect before committing. |
| **Predictable output size.** | Many agent harnesses truncate tool output beyond 10–30K characters [\[7\]](#refs). Default to a summary; support `--offset` / pagination for full results; or require `--output FILE` for large dumps. |
| **Pin versions for one-off command invocations.** | When `SKILL.md` instructs `uvx ruff@0.8.0 …` or `npx eslint@9.0.0 …`, pin the version so behaviour stays stable over time [\[7\]](#refs). |
| **Declare inline dependencies for self-contained scripts.** | Python: PEP 723 inline metadata, run with `uv run`. Deno, Bun, Ruby, and Go all have analogous patterns [\[7\]](#refs). No separate `requirements.txt` for skill-local scripts. |
| **List bundled scripts in `SKILL.md` and tell the agent when to call them.** | A `## Available scripts` block followed by procedural references (`bash scripts/validate.sh "$INPUT"`) is more discoverable than naming the file once, buried in prose. |

Reference paths in `SKILL.md` are relative to the skill directory root — the agent runs commands from there.

## Eval-as-contract

Each layer of the framework has a matching grader family. The eval enforces the framework; the framework does not enforce itself. This aligns with Anthropic's "start with evaluation" guidance for skill authors [\[2\]](#refs): identify capability gaps via representative tasks, then build skills to address them.

Grader types in the table below are from the waza harness [\[3\]](#refs).

| Property | Grader type [\[3\]](#refs) | Failure means |
|---|---|---|
| Trigger precision (positive + negative) | `type: trigger` | Description block is wrong (USE FOR / DO NOT USE FOR). |
| Tool mandates (L3) | `behavior` / `tool_constraint` with `expect_tools` | Skill did not call the required tool. |
| Citation policy | `prompt` judge + regex on output | Answer claims fact without source. |
| Content correctness | `prompt` judge with PASS criteria | Canonical value missing or wrong. |
| Schema compliance | `json_schema` / `program` / regex | Output does not match declared `## Output schema`. |
| Refusal cleanliness | `prompt` + regex with refusal markers | Off-topic produced an answer instead of redirect. |
| Budget | `behavior` with `max_tool_calls`, `max_duration_ms` | Skill ran away or thrashed. |
| Persona-lock (agents) | `prompt` + regex | Agent identified as a generic assistant. |

Hard-won grader rules from this repo:

* Prompt graders are **binary**. The waza prompt grader gives the judge LLM exactly two tools: `set_waza_grade_pass` (score `1.0`) and `set_waza_grade_fail` (score `0.0`) [\[3\]](#refs). Do not write 1-to-5 rubrics — the judge collapses them to 0 or 1.
* Prompt graders require `continue_session: true` or the judge has no view of the agent's output [\[3\]](#refs).
* LLM-as-judge is reliable but biased. Strong judges agree with humans about 80% of the time but exhibit position, verbosity, and self-enhancement biases [\[4\]](#refs) — mitigate by pairing prompt graders with deterministic graders (`text`, `file`, `json_schema`).
* Eval-level `skill_invocation` graders with aspirational `required_skills` fire on every task and produce deterministic 0.0 noise. Scope content graders to positive tasks only.

Shared grader blocks live at `.github/evals/_lib/graders/*.yaml` (when created). Per-skill evals `extends:` them rather than copy-pasting.

### Test case design and iteration

Graders only check what you thought to assert. Test-case design is the other half — taken from the upstream evaluation guide [\[8\]](#refs).

* **Start with 2–3 cases.** Don't over-invest before you've seen your first round of results. Expand later. Each case is a realistic prompt + a human-readable expected output + (optional) input files.
* **Vary prompt phrasing.** Some cases should be casual (`hey can you clean up this csv`), others precise (`Parse the CSV at data/input.csv, drop rows where column B is null, …`). Cover at least one edge case (malformed input, ambiguous request, refusal).
* **Compare with-skill against without-skill (baseline).** A skill that doesn't beat the no-skill baseline is not adding value. When iterating on an existing skill, snapshot the previous version and use it as the baseline.
* **Write assertions only after seeing the first outputs.** Good assertions are specific, observable, and programmatically verifiable (`Both axes are labeled`, `The output is valid JSON`, `The report includes at least 3 recommendations`). Weak assertions are vague (`looks good`) or too brittle (`exactly the phrase 'Total Revenue: $X'`).
* **Use scripts for mechanical checks, LLM judges for narrative quality.** Scripts are reliable and reusable across iterations; LLM judges complement them for organization, formatting, and overall usability.
* **Capture timing and tokens.** A skill that improves quality but triples token usage is a different trade-off than one that's both better and cheaper. Track `total_tokens` and `duration_ms` per run; the waza harness records both [\[3\]](#refs).
* **Analyse patterns, not just averages.** Remove assertions that always pass in both configurations (no signal). Investigate assertions that always fail in both (broken assertion, too-hard task, or wrong check). Focus iteration effort on assertions that pass with the skill and fail without — that is where the skill is adding value.
* **High variance ≠ bad skill.** If the same case passes sometimes and fails others, either the assertion is sensitive to model randomness or the skill's instructions are ambiguous enough that the model interprets them differently each run. Add an example or tighten the wording.
* **Keep a human in the review loop.** Assertion grading and pattern analysis only catch what you thought to write assertions for. A reviewer catches issues you didn't anticipate.

The iteration loop itself: run → grade → review → propose changes (give failed assertions, human feedback, and execution transcripts to an LLM) → apply → re-run [\[8\]](#refs). Stop when feedback is consistently empty or improvements plateau. In this repo, `/skill-improve` automates the run-grade-propose-re-run cycle on top of the waza harness.

## The authoring lifecycle

Four commands per surface (skills and agents), same pattern: onboard → bench → improve → promote. See the [Prompts](./prompts) catalogue for full argument lists and cost notes.

```text
        ┌──────────────────┐
        │  /skill-onboard  │  scaffold SKILL + eval + manifest entry;
        │  scaffold + smoke│  runs quality check + smoke trial on 1 model
        └────────┬─────────┘
                 │ pass smoke?
        ┌────────▼─────────┐
        │  /skill-bench    │  run across N models (pilot tier);
        │  multi-model     │  identify winning model + weak tasks
        └────────┬─────────┘
                 │ score >= threshold?
        ┌────────▼─────────┐
        │  /skill-improve  │  read failures, propose SKILL edits,
        │  failure-driven  │  verify with re-run; baseline-vs-after diff
        └────────┬─────────┘
                 │ regression-free?
        ┌────────▼─────────┐
        │  /skill-promote  │  move from pilot tier to expanded tier;
        │  tier gate       │  requires evidence (improvement + bench)
        └────────┬─────────┘
                 │ live
        ┌────────▼─────────┐
        │  nightly trend   │  trend report; alert on regression
        │  workflow        │
        └──────────────────┘
```

The same four commands exist for agents (`/agent-onboard`, `/agent-bench`, `/agent-improve`, `/agent-promote`). Agents add one extra phase: persona-lock verification — the eval asserts the agent identifies as itself, never as "GitHub Copilot CLI" or "software engineering assistant."

## Repository layout

```text
.github/
├── copilot-instructions.md ← workspace-wide rules
├── templates/
│   ├── SKILL.template.md   ← skill scaffold (use as starting point)
│   └── AGENT.template.md   ← agent scaffold
├── skills/<slug>/
│   ├── SKILL.md
│   └── references/*.md     ← skill-local L2 corpus
├── agents/<name>.agent.md
├── prompts/<name>.prompt.md
├── instructions/*.instructions.md
├── references/             ← shared L2 corpus across skills
│   └── <topic>/*.md
├── evals/
│   ├── manifest.yaml       ← tier registration
│   ├── _lib/graders/       ← shared grader blocks
│   └── <slug>/
│       ├── eval.yaml
│       └── tasks/
│           ├── positive-*.yaml
│           └── negative-*.yaml
└── workflows/
    ├── waza-evals.yml      ← PR-blocking grading
    └── waza-trends.yml     ← nightly trend
```

## Authoring checklist

Before opening a PR that adds or modifies a skill or agent:

* [ ] File starts from the matching template under `.github/templates/`.
* [ ] Frontmatter `description` includes `USE FOR:`, `DO NOT USE FOR:`, `INVOKES:` (skills) or persona + tools (agents).
* [ ] Recommended sections from the anatomy guidance above are present where they add value (anatomy is documentation, not a runtime gate — the eval is what graders run against).
* [ ] Every factual claim traces to L1 inline, an L2 file, or a mandated L3 tool call.
* [ ] L2 files (if any) carry the `source` + `snapshot` + `refresh_command` header.
* [ ] At least one positive task and one negative task exist in the eval; prompt phrasing is varied (casual + precise) and at least one edge case is covered.
* [ ] Assertions are specific, observable, and programmatically verifiable; vague or brittle assertions removed.
* [ ] A without-skill (or previous-version) baseline run exists for comparison.
* [ ] Tool-use and citation graders are configured.
* [ ] `SKILL.md` body stays within roughly 500 lines / 5,000 tokens; overflow lives in L2 with explicit *when-to-load* instructions.
* [ ] Any bundled `scripts/*` are non-interactive, support `--help`, document distinct exit codes, and produce structured output (data to stdout, diagnostics to stderr).
* [ ] A `## Available scripts` block in `SKILL.md` lists every bundled script with a one-line summary.
* [ ] Manifest entry added to `.github/evals/manifest.yaml`.
* [ ] Smoke trial ran cleanly on the configured smoke model.
* [ ] If a shared canon was duplicated, it has been hoisted to `.github/references/<topic>/`.

## What is intentionally out of scope

* **Model fine-tuning.** Skills are not training data; they are runtime context. There is no weight-level "training" step in this framework. This matches the Agent Skills design: skills extend agent capabilities at runtime via files and folders, not via model weights [\[2\]](#refs).
* **Vector search / RAG infrastructure.** The L2 layer is a curated, dated snapshot — a human-readable corpus, not an embedding index.
* **Multi-tenant skill packaging.** Sharing skills across repos is handled by the host platform (plugin manifest), not by this framework.

## Security note

Skills can include instructions and executable code, so a malicious skill is a real attack surface — install only from trusted sources, and audit unfamiliar skills before use [\[2\]](#refs). When this repo accepts a skill contribution, the review must cover bundled scripts, network endpoints, and any tool mandates that could exfiltrate data.

## Versioning

This spec is v0.1. Breaking changes (renaming required sections, changing the anatomy contracts) bump the minor version and require a migration note pinned at the top of this file.

<a id="refs"></a>

## References

Snapshot dates reflect the date each source was last verified against upstream.

1. **Agent Skills open standard.** Agent Skills Overview. <https://agentskills.io/> — defines the SKILL.md folder format, the required `name` + `description` frontmatter, and the three-stage progressive disclosure model (Discovery, Activation, Execution). Snapshot: 2026-05-21.
2. **Zhang B., Lazuka K., Murag M.** "Equipping agents for the real world with Agent Skills." Anthropic Engineering, Oct 16 2025. <https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills> — origin article for the Agent Skills design; defines progressive disclosure, best practices ("start with evaluation," "structure for scale," "think from Claude's perspective," "iterate with Claude"), and security guidance. Snapshot: 2026-05-21.
3. **Microsoft waza.** "Graders" — Validators and Graders reference. <https://microsoft.github.io/waza/guides/graders/> — defines the grader taxonomy (`text`, `file`, `diff`, `json_schema`, `prompt`, `behavior`, `action_sequence`, `skill_invocation`, `tool_constraint`, `tool_calls`, `program`, `trigger`), the binary `set_waza_grade_pass` / `set_waza_grade_fail` contract for prompt graders, and the `continue_session: true` mechanism. Snapshot: 2026-05-21.
4. **Zheng L. et al.** "Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena." NeurIPS 2023 Datasets and Benchmarks. arXiv:2306.05685. <https://arxiv.org/abs/2306.05685> — establishes that strong LLM judges reach ~80% agreement with humans (matching inter-human agreement) but exhibit position, verbosity, and self-enhancement biases that mixed grading layers must mitigate. Snapshot: 2026-05-21.
5. **anthropics/skills.** Reference skill repository. <https://github.com/anthropics/skills> — canonical SKILL.md examples (document-skills, example-skills) and the upstream `template/` scaffold. Snapshot: 2026-05-21.
6. **Agent Skills.** "Best practices for skill creators." <https://agentskills.io/skill-creation/best-practices> — upstream editorial guide; defines *start from real expertise*, *spend context wisely* (≤500 lines / ≤5,000 tokens), *calibrate control to fragility*, and the reusable patterns (gotchas, templates, checklists, validation loops, plan-validate-execute, bundling scripts). Snapshot: 2026-05-21.
7. **Agent Skills.** "Using scripts in skills." <https://agentskills.io/skill-creation/using-scripts> — design rules for bundled scripts: non-interactive, `--help`, structured output, meaningful exit codes, idempotency, `--dry-run`, predictable output size, inline-dependency declarations (PEP 723 et al.), and pinned versions for one-off commands. Snapshot: 2026-05-21.
8. **Agent Skills.** "Evaluating skill output quality." <https://agentskills.io/skill-creation/evaluating-skills> — eval-driven iteration: test cases (`evals/evals.json`), with-skill vs. without-skill baseline, assertion design, grading (LLM judge + scripts), aggregation (`benchmark.json`), pattern analysis, human review, and the iteration loop. Snapshot: 2026-05-21.
