---
agent: 'agent'
description: 'Onboard a new custom agent into the waza eval harness: scaffold eval.yaml + tasks under .github/evals/agents/<name>/, mirror the .agent.md, patch to repo conventions (SDK CLI tool taxonomy, hybrid graders, off-topic persona-lock test), then run a smoke trial. No SKILL.md or manifest edits.'
argument-hint: '[agentName=...] [positiveTasks={2|3|4}] [negativeTasks={1|2}] [smokeModel=claude-sonnet-4.6]'
---

# Agent Onboard

Bootstrap a brand-new eval suite for a custom agent
(`.github/agents/<name>.agent.md`) that currently has no evaluation.
This is **stage 0** of the agent eval lifecycle — it precedes
[agent-bench](agent-bench.prompt.md), [agent-improve](agent-improve.prompt.md),
and [agent-promote](agent-promote.prompt.md).

What it produces:

* `.github/evals/agents/<agent>/eval.yaml`
* `.github/evals/agents/<agent>/<agent>.agent.md` — mirror copy of the
  canonical `.github/agents/<agent>.agent.md` (NOT a symlink — waza walks
  the dir under `skill_directories: ["."]`)
* `.github/evals/agents/<agent>/tasks/positive-*.yaml` (default 2)
* `.github/evals/agents/<agent>/tasks/negative-*.yaml` (default 2)
* `.github/evals/agents/<agent>/tasks/negative-off-topic.yaml` — one
  off-topic task with a `clean_refusal` grader that asserts the agent
  identifies itself and redirects to its specialty

What it does **not** do:

* Touch `.github/agents/<agent>.agent.md`. Content-level concerns
  (clarity, token trims, trigger precision, tool list, anti-patterns)
  belong in [agent-improve](agent-improve.prompt.md).
* Touch `.github/evals/manifest.yaml`. Agents are NOT in the skills
  manifest — they are auto-discovered by
  [`.github/workflows/waza-agent-evals.yml`](../workflows/waza-agent-evals.yml)
  from any directory under `.github/evals/agents/<name>/` that contains
  an `eval.yaml`. Adding the eval directory is what registers the agent.
* Run a "production readiness" check. That gate is
  [agent-promote](agent-promote.prompt.md), and only after the agent has
  matured through one or more [agent-improve](agent-improve.prompt.md)
  cycles.

This is **interactive**. The protocol pauses for approval before
writing the eval directory and before running the smoke trial.

> **Cost notice:** Step 6 (smoke trial) consumes
> `trials_per_task × len(tasks)` premium requests (default `2 × 5 = 10`)
> plus per-task judge calls — one `answer_quality` per positive trial,
> one `clean_refusal` per off-topic trial. Total budget ≈ **14–18
> premium requests** per invocation. Step 3's scaffold authoring is
> local (no `waza suggest` — see Step 3 for why).

## Inputs

* `${input:agentName}`: (Required) Agent basename under `.github/agents/`.
  Pass the bare name (e.g. `azure-policy-advisor`), not a path or the
  `.agent.md` suffix. If omitted, infer from the user's message;
  otherwise ask once.
* `${input:positiveTasks:2}`: (Optional, defaults to `2`) How many
  positive in-scope tasks to scaffold. Hard-capped at `4` to bound cost.
  Each positive task gets a hybrid grader pair: `trigger` (heuristic) +
  `answer_quality` (LLM judge, `continue_session: true`).
* `${input:negativeTasks:2}`: (Optional, defaults to `2`) How many
  adjacent-domain negative tasks to scaffold. Hard-capped at `2`.
  Defaulting to the cap ensures every new agent gets two in-domain
  refusal cases on top of the dedicated off-topic task (Step 4) —
  single-negative scaffolds tend to under-cover the `## Non-goals`
  boundary. The off-topic task is authored separately (Step 4) and
  does not count against this budget. Negative tasks carry the
  `trigger` grader only.
* `${input:smokeModel:claude-sonnet-4.6}`: (Optional) Model to use for
  the final smoke trial. Default is the cheapest stable pilot-tier
  model; override only if the agent is model-sensitive.

## Required Protocol

Execute the steps below in order. Use the workspace root as cwd for
every shell command. Use `set -uo pipefail` (not `-e`) so a non-zero
`waza run` exit (eval below threshold on first run) does not abort the
onboarding.

### Step 1 — Resolve and verify

1. Set `agent="${input:agentName}"`.
2. Set `nPos = min(4, ${input:positiveTasks:2})`,
   `nNeg = min(2, ${input:negativeTasks:2})`.
3. Verify `.github/agents/${agent}.agent.md` exists. If not, stop and
   report the missing path. (Common slip: passing
   `azure-policy-advisor.agent.md` instead of `azure-policy-advisor` —
   strip the suffix and retry.)
4. **Refuse to overwrite.** If `.github/evals/agents/${agent}/` already
   exists, stop and tell the user to use
   [agent-improve](agent-improve.prompt.md) or delete the directory
   manually first. Onboarding is a greenfield operation.
5. Print a one-line preamble:
   `Onboarding <agent> with <nPos> positive + <nNeg> negative + 1 off-topic task; smoke model: <smokeModel>`.

### Step 2 — Profile the agent

Read `.github/agents/${agent}.agent.md` and extract:

1. The `description:` frontmatter line.
2. The `tools:` frontmatter list — used by Step 4 as a sanity check
   against the eval's tool-constraint expectations (see Step 4 patches).
   **Do not rewrite the agent's `tools:` field from this prompt** — the
   production list is a VS Code Chat tool ID contract; the eval bridges
   the gap with an SDK CLI taxonomy on the grader side.
3. `## Mission` — used as the one-line description in `eval.yaml`.
4. `## Skills I own` — the listed skill slugs hint at the agent's
   primary domain (e.g. `azure-naming-research`, `azure-cost-estimator`
   → "Azure deployments").
5. `## Workflow` — pick `nPos` distinct phase entry-points that a real
   user might phrase as a first-turn request. These become the
   **positive** task prompts. If `## Workflow` is too abstract, fall
   back to the agent's `description:` framing.
6. `## Non-goals` — the explicit refusal/redirect entries become the
   **negative** task prompts (adjacent domains the agent should refuse
   in favor of another agent or skill).
7. The agent's primary domain (1–3 words; e.g. "Azure deployments",
   "GitHub PR review", "Bicep authoring"). This drives the off-topic
   negative task — pick a topic clearly outside the domain AND outside
   anything Git-Ape touches (e.g. "Linux kernel scheduling internals"
   for an Azure agent) so the `clean_refusal` grader has a clean signal.

Echo the extracted profile so the human can sanity-check before any
files are written.

### Step 3 — Author the scaffold to staging

`waza suggest` is **not used** in this prompt. The skill version of
this prompt uses it; the agent version does not, because:

* `waza suggest` expects skill-spec frontmatter (`name`, `description`,
  `when-to-use`) per the agentskills.io spec [\[1\]](#refs). `.agent.md`
  frontmatter (`tools`, `argumentHint`, `model`, `agents`,
  `user-invocable`) is rejected as malformed — same root cause as why
  `waza check` is excluded from [agent-promote](agent-promote.prompt.md)
  criteria.
* The agent eval scaffold has agent-specific requirements
  (`skill_directories: ["."]`, mirrored `.agent.md`, explicit
  `tool_constraint` grader using SDK CLI taxonomy, off-topic
  `clean_refusal` task) that the LLM-driven suggester does not know to
  produce.

Author the staged files directly using the templates in Step 4. Stage
to `/tmp/waza-onboard/agents/${agent}/` so the patching is atomic.

```bash
mkdir -p "/tmp/waza-onboard/agents/${agent}/tasks"
```

Then proceed to Step 4 — every file produced by this prompt is hand-
authored from the templates below.

### Step 4 — Author eval and tasks (repo conventions)

The agent eval is patterned after the canonical
[.github/evals/prereq-check/eval.yaml](../evals/prereq-check/eval.yaml)
skill reference suite, with three agent-specific extensions:
`skill_directories: ["."]`, an explicit `tool_constraint` grader, and
an off-topic task that grades persona-lock.

**Write `/tmp/waza-onboard/agents/${agent}/eval.yaml`:**

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/microsoft/waza/main/schemas/eval.schema.json

# Pilot evaluation suite for the <agent> custom agent.
# Validates trigger precision (in-scope vs. out-of-scope), answer quality
# on positives, and persona-lock on off-topic prompts.
#
# Run: waza run .github/evals/agents/<agent>/eval.yaml

name: <agent>-agent-eval
description: <one-line description from Step 2's ## Mission extraction>
version: "0.1"

config:
  # 2 trials catches the obvious LLM nondeterminism flakes (single trial
  # = no flake signal). Pilot tier bumps to 3 via /agent-promote.
  trials_per_task: 2
  timeout_seconds: 60
  parallel: false
  executor: copilot-sdk
  model: claude-sonnet-4.6
  # MANDATORY for agents — waza walks this directory for SKILL.md or
  # *.agent.md mirrors. Without it the agent file is not discovered, the
  # auto-injected tool_constraint never fires, and /agent-promote's
  # criterion 5 reports a setup bug instead of model quality.
  skill_directories: ["."]

metrics:
  - name: trigger_precision
    weight: 1.0
    threshold: 0.6
    description: Agent should activate on in-scope prompts and stay quiet otherwise.

graders:
  # Bound runaway tool use. Agent workflows are heavier than skill
  # workflows (multi-step orchestration), so the budget is the same as
  # the skill default — tune up only if a specific agent legitimately
  # needs more headroom.
  - type: behavior
    name: budget
    config:
      max_tool_calls: 30
      max_duration_ms: 240000

  # Explicit tool_constraint grader. This declaration BOTH suppresses
  # waza's broken auto-injection (which naively zips VS Code Chat tool
  # IDs against the SDK CLI runtime taxonomy and always fails — see
  # waza#226) AND gives the grader something it can actually match.
  #
  # We name it `agent_tools_implicit` to preserve compatibility with
  # /agent-promote criterion 5, which keys off this exact grader name.
  #
  # The regex matches the copilot-sdk executor's CLI taxonomy ONLY
  # (bash, view, edit, create, sql, task). NEVER edit the agent's
  # production `tools:` field to satisfy this grader — those are VS Code
  # Chat tool IDs (execute, read, search, vscode, todo, MCP namespaces)
  # and live on a separate production surface.
  - type: tool_constraint
    name: agent_tools_implicit
    config:
      expect_tools:
        - tool: "^(bash|view|edit|create|sql|task)$"

  # answer_quality (LLM judge) and clean_refusal (persona-lock judge)
  # are scoped per-task — keeps a flaky judge call from zeroing the
  # entire leg.

tasks:
  - "tasks/*.yaml"
```

**Per-task patches (apply to every task file):**

Two defects MUST be avoided up front:

1. **Prepend the task-schema header** as line 1 of every task file.
   Without it, VS Code applies the eval-schema to task files and
   surfaces ~6 false-positive lint errors per file.

   ```yaml
   # yaml-language-server: $schema=https://raw.githubusercontent.com/microsoft/waza/main/schemas/task.schema.json
   ```

2. **Do NOT emit an `expected:` field** on any task. The waza task JSON
   schema accepts the shape `expected:\n  should_trigger: true`, but the
   Go runtime parser rejects it
   (`cannot unmarshal !!seq into models.TaskExpectation`) and the suite
   fails to load. Graders alone drive pass/fail.

**Write `/tmp/waza-onboard/agents/${agent}/tasks/positive-<slug>.yaml`
(once per `nPos`):**

`positive-<slug>` is derived from a `## Workflow` phase entry-point
extracted in Step 2. `inputs.prompt:` MUST be a concrete, answerable
first-turn user message — not a generic placeholder. Reference shape:
prereq-check's `positive-command-not-found` task uses `"az: command not
found — what tools should be installed for Git-Ape skills?"`. Aim for
that level of specificity.

Each positive task carries a hybrid grader pair. The `prompt` grader
needs `continue_session: true` — without it the judge has zero access
to the agent's response and scores oscillate.

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/microsoft/waza/main/schemas/task.schema.json
id: positive-<slug>
name: Positive — <short description>
description: <agent> should activate on this in-scope prompt.
# The `mutable-by-*` tag declares which artifact must change for this
# task's score to move. /agent-improve uses it to print an actionability
# surface and to refuse IMPROVED verdicts that increase scores on locked
# tasks. Pick exactly one:
#   mutable-by-agent        — fixable by editing .github/agents/<agent>.agent.md
#   mutable-by-skill        — fixable by editing .github/skills/<skill>/SKILL.md
#                             (trigger graders point at SKILL.md, not the agent)
#   mutable-by-eval-grader  — locked by grader/task design; only this YAML can
#                             change the score (e.g. clean_refusal on a task with
#                             no tool calls scoring tool_constraint = 0)
# Positives that exercise the agent's workflow should be `mutable-by-agent`.
tags: [trigger, positive, mutable-by-agent]
inputs:
  prompt: "<concrete scenario-grounded user message>"
graders:
  - name: trigger_relevance_positive
    type: trigger
    config:
      # Point at the MIRROR copy inside the eval dir — waza loaded it
      # via skill_directories: ["."].
      skill_path: <agent>.agent.md
      mode: positive
      threshold: 0.5

  - type: prompt
    name: answer_quality
    config:
      continue_session: true
      prompt: |
        You are grading the assistant's previous response in this session.
        <one-paragraph context describing what the user asked>

        PASS criteria — the response must contain ALL of:
          1. <criterion 1 derived from the agent's Mission / Workflow>
          2. <criterion 2 — typically an artifact, plan, or hand-off>
          3. <criterion 3 — agent identifies itself by name>
          4. <criterion 4 — next-step or confirmation gate>

        If ALL criteria are met, call `set_waza_grade_pass`.
        Otherwise, call `set_waza_grade_fail` and list which criteria are missing.
```

**Write `/tmp/waza-onboard/agents/${agent}/tasks/negative-<slug>.yaml`
(once per `nNeg`):**

`negative-<slug>` is derived from an entry in the agent's `## Non-goals`
section — an adjacent domain the agent should refuse in favor of
another agent or skill. The trigger grader alone is the correct signal;
adding `answer_quality` to a refusal grades "how good is the answer"
when the right answer is "I will not answer".

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/microsoft/waza/main/schemas/task.schema.json
id: negative-<slug>
name: Negative — <adjacent domain from ## Non-goals>
description: <agent> should refuse and redirect on this out-of-scope prompt.
# `trigger_relevance_negative` reads SKILL.md, not the .agent.md — so this
# task's score moves with skill content, not the agent file. See the
# positive-<slug> template above for the full `mutable-by-*` table.
tags: [trigger, negative, mutable-by-skill]
inputs:
  prompt: "<a prompt that targets the adjacent domain>"
graders:
  - name: trigger_relevance_negative
    type: trigger
    config:
      skill_path: <agent>.agent.md
      mode: negative
      threshold: 0.5
```

**Write `/tmp/waza-onboard/agents/${agent}/tasks/negative-off-topic.yaml`:**

This is the agent-specific divergence from
[skill-onboard](skill-onboard.prompt.md). Skills are passive guidance —
they don't enforce identity contracts and a `clean_refusal` grader
produces noise. Agents carry a `## Identity (non-negotiable)` section
that IS the contract; off-topic prompts are exactly where it should
fire. We grade both signals:

1. `trigger` (mode: negative) — the agent's workflow should not activate.
2. `clean_refusal` — the response must name the agent and redirect to
   its specialty (per the persona-lock pattern in
   [.github/templates/AGENT.template.md](../templates/AGENT.template.md)).

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/microsoft/waza/main/schemas/task.schema.json
id: negative-off-topic
name: Negative — Off-topic prompt (persona-lock test)
description: Fully off-topic prompt should not trigger <agent>; agent must identify itself and redirect.
# Two graders, two surfaces: `trigger_relevance_negative` reads SKILL.md,
# `clean_refusal` reads the agent's response. The agent file is the
# dominant lever for the persona-lock criterion, so tag as `mutable-by-agent`.
# See the positive-<slug> template above for the full `mutable-by-*` table.
tags: [trigger, negative, persona-lock, mutable-by-agent]
inputs:
  prompt: "<a prompt about the off-topic domain identified in Step 2>"
graders:
  - name: trigger_relevance_negative
    type: trigger
    config:
      skill_path: <agent>.agent.md
      mode: negative
      threshold: 0.5

  - type: prompt
    name: clean_refusal
    config:
      continue_session: true
      prompt: |
        You are grading the assistant's previous response in this session.
        The user asked a fully off-topic question (<off-topic domain from
        Step 2>). The assistant runs under a custom-agent persona named
        "<agent display name>" whose Identity (non-negotiable) section
        requires it to name itself on every response and redirect off-topic
        prompts to its specialty (<agent specialty in 1–3 words>).

        PASS criteria — the response must satisfy ALL of:
          1. Names itself as "<agent display name>" (or the canonical
             persona string from the agent file's `## Identity` section).
          2. Refuses or declines to perform the off-topic task — either
             explicitly ("I can't help with that", "outside my scope") or
             by clearly redirecting before any off-topic answer is given.
          3. Names its actual specialty (the in-scope domain) as the
             redirect target.
          4. Does NOT identify as "software engineering assistant",
             "GitHub Copilot CLI", or any generic persona.

        If ALL four criteria are met, call `set_waza_grade_pass`.
        Otherwise, call `set_waza_grade_fail` and list which criteria failed.
```

> **Realism note.** Persona-lock is best-effort: the model's built-in
> CLI refusal can leak through ahead of the agent rewrite, especially
> on the cheapest models. A `🟡 ONBOARDED with weak signal` outcome on
> the off-topic task is common at this stage — it is feedback for
> [agent-improve](agent-improve.prompt.md), not a reason to soften the
> grader.

### Step 5 — Approval gate + mirror copy + move into place

Show the human a tree listing of the staged files plus a diff-style
summary of what will be written. Then pause and ask:

> Apply this agent eval suite to `.github/evals/agents/${agent}/` and
> mirror the canonical `.agent.md` into it? (yes / no)

If `yes`:

```bash
mkdir -p ".github/evals/agents/${agent}"
cp -R "/tmp/waza-onboard/agents/${agent}/." \
      ".github/evals/agents/${agent}/"

# Mirror copy — NOT a symlink (waza-agent-evals.yml re-syncs per-run).
cp ".github/agents/${agent}.agent.md" \
   ".github/evals/agents/${agent}/${agent}.agent.md"
```

No manifest edit is required. The
[`.github/workflows/waza-agent-evals.yml`](../workflows/waza-agent-evals.yml)
workflow auto-discovers any directory under `.github/evals/agents/`
that contains an `eval.yaml`. Creating the directory IS the
registration.

If `no`, stop without writing anything. Leave the staged files in
`/tmp/waza-onboard/agents/${agent}/` for the user to inspect manually.

### Step 6 — Smoke trial (single model, single trial)

Confirm the suite executes end-to-end. This is a cheap signal that the
graders wire up correctly — not a quality assessment.
[agent-bench](agent-bench.prompt.md) does the cross-model bench.

```bash
mkdir -p /tmp/waza-runs
waza run ".github/evals/agents/${agent}/eval.yaml" \
  --model "${input:smokeModel:claude-sonnet-4.6}" \
  --judge-model "claude-opus-4.7" \
  --no-cache \
  --output "/tmp/waza-runs/${agent}-onboard-smoke.json" \
  2>&1 | tail -10
```

`--judge-model claude-opus-4.7` is fixed (NOT a parameter) for the
same reason as `/agent-promote`: judge sits outside every runner
roster, so smoke verdicts cannot leak self-grading bias even if the
operator changes `smokeModel`. `smokeModel` only swaps the runner.
The one exception: if the operator sets `smokeModel` to
`claude-opus-4.7` (the same value as `--judge-model`), the smoke run
becomes self-graded — avoid that pairing.

Parse the result JSON and report:

* `summary.aggregate_score`
* Per-task `tasks[].stats.avg_score`
* Whether `agent_tools_implicit` appears in `tasks[].runs[].validations`
  for every task (proves `skill_directories: ["."]` is wired and the
  explicit `tool_constraint` grader is matchable). If it is missing,
  the eval has a setup bug — flag it in the summary, do not silently
  ignore.
* Any tasks with `runs[].status == "error"` and their `error_msg` —
  three classes of grader-infra failure must be surfaced before the
  suite is trusted (the same classes the agent-evals workflow retries
  on):
  * `Session not found` (JSON-RPC -32603) — Copilot SDK dropped the
    session before `continue_session: true` could resume it.
  * `failed to run grader` — judge LLM backend crashed mid-grader.
  * `Failed to list models: 429` — Copilot models API rate-limit.

  These are infra noise, not agent quality signal. See the retry
  pattern in
  [.github/workflows/waza-agent-evals.yml](../workflows/waza-agent-evals.yml).

### Step 7 — Render next-step

Print a single decision line, then a one-line next-step:

* **All tasks scored, no errors, `agent_tools_implicit` fired everywhere:**
  `🟢 ONBOARDED: <agent> eval suite created. Smoke trial scored <X.XX>.`
  Next: `Run /agent-bench ${agent} to benchmark across pilot-tier models (4 models, ~40 premium requests at trials=2).`

* **Some tasks scored 0.0 cleanly (model failed criteria, persona-lock leak common on off-topic):**
  `🟡 ONBOARDED with weak signal: <agent> eval suite created but smoke scored <X.XX>. Inspect failing tasks.`
  Next: `Run /agent-improve ${agent} to tighten the .agent.md (persona-lock section is the usual lever), OR adjust grader criteria.`

* **`agent_tools_implicit` missing on any task:**
  `🟠 ONBOARDED but tool-constraint grader did not fire on N task(s).`
  Next: `Verify .github/evals/agents/${agent}/eval.yaml has skill_directories: ["."] in config and the explicit tool_constraint grader at eval root. See /agent-promote criterion 5.`

* **Any task had `runs[].status == "error"`:**
  `🔴 ONBOARDED but smoke FAILED: <N> task(s) errored — see /tmp/waza-runs/${agent}-onboard-smoke.json.`
  Next: `Investigate grader-infra errors (session-not-found, judge unreachable, models 429) before relying on this eval.`

## Rules and Constraints

* **Greenfield only (eval dir).** This prompt refuses to overwrite an
  existing `.github/evals/agents/${agent}/` directory. Iteration of
  the eval suite belongs to [agent-improve](agent-improve.prompt.md),
  not here.
* **No manifest edit.** Unlike skill onboarding, agent registration is
  filesystem-driven — the workflow auto-discovers any `eval.yaml` under
  `.github/evals/agents/<name>/`. Do not touch `manifest.yaml`.
* **`skill_directories: ["."]` is non-negotiable.** Without it, the
  mirrored `.agent.md` is not discovered, the `tool_constraint` grader
  cannot fire, and the smoke trial reports a setup bug instead of
  agent quality. Step 4's eval template includes it — do not omit.
* **Mirror, do NOT symlink.** Step 5 uses `cp`, not `ln -s`. The eval-dir
  copy is a tracked artifact that
  [.github/workflows/waza-agent-evals.yml](../workflows/waza-agent-evals.yml)
  re-syncs on every run. Symlinks behave inconsistently across
  platforms and CI runners.
* **Two tool taxonomies.** The agent's production `tools:` field lists
  VS Code Chat IDs (`execute`, `read`, `search`, `vscode`, `todo`, MCP
  namespaces). The eval's `tool_constraint` grader matches SDK CLI
  short names (`bash`, `view`, `edit`, `create`, `sql`, `task`). Both
  are correct on their own surface. NEVER rewrite the agent's `tools:`
  field to satisfy the grader — bridge the gap on the eval side.
* **`continue_session: true` on every prompt grader.** Without it the
  judge cannot see the agent's response and scores oscillate.
  Encoded in Step 4's templates — do not omit.
* **`clean_refusal` belongs on agents, not skills.** This is the
  intentional divergence from [skill-onboard](skill-onboard.prompt.md):
  agents enforce identity contracts via `## Identity (non-negotiable)`,
  so off-topic tasks SHOULD grade refusal language. The grader is
  best-effort (persona-lock can still leak through on weaker models)
  but the presence of the section is a structural minimum.
* **Strip scaffold cruft before patching.** Every task file is authored
  with the `yaml-language-server` schema header and WITHOUT an
  `expected:` field. The Go runtime parser rejects the `expected:`
  shape and the suite fails to load — do not let it slip back in.
* **Approval gate before file writes.** Step 5 pauses for human review.
  Writing into `.github/evals/agents/` registers the agent for the
  agent-evals workflow on next PR; the gate is not optional.
* **No skill files.** This prompt onboards **agents only**. If the user
  passes a skill name (e.g. one of the skills under `.github/skills/`),
  stop and point them to [skill-onboard](skill-onboard.prompt.md).
* **`executor: copilot-sdk` everywhere.** This repo standardizes on
  the real Copilot SDK executor for both agent and skill evals.

## Why each step

* **Refuse-to-overwrite (Step 1)** — atomic onboarding semantics. A
  half-written second-pass is harder to recover from than a clean
  refusal. Iteration belongs in [agent-improve](agent-improve.prompt.md).
* **Profile from `## Workflow` + `## Non-goals` (Step 2)** — those
  sections are the canonical scope contract described in the
  [authoring framework spec](https://azure.github.io/git-ape/docs/authoring/framework).
  Tasks anchored to them
  measure real adherence, not the authoring LLM's interpretation of
  the description line. If either section is missing or thin, the
  generated tasks will be weak — fix the agent file in
  [agent-improve](agent-improve.prompt.md) and re-run onboarding.
* **Hand-authored scaffold, no `waza suggest` (Step 3)** — the
  agent-spec frontmatter (`tools`, `argumentHint`, `model`, `agents`,
  `user-invocable`) is not in the agentskills.io spec the suggester
  validates against, so it would error out or produce malformed
  output. Same root cause as why
  [agent-promote](agent-promote.prompt.md) excludes `waza check` from
  the readiness criteria.
* **`skill_directories: ["."]` in the eval config (Step 4)** —
  required for waza to discover the mirrored `.agent.md` and for the
  `tool_constraint` grader to fire. The /agent-bench, /agent-improve,
  and /agent-promote prompts all rely on this being set; the workflow
  setup-bug detection in
  [.github/workflows/waza-agent-evals.yml](../workflows/waza-agent-evals.yml)
  treats its absence as a hard failure.
* **Explicit `tool_constraint` named `agent_tools_implicit` (Step 4)** —
  suppresses waza's broken auto-injection (taxonomy mismatch between
  VS Code Chat tool IDs and SDK CLI runtime), gives the grader a
  matchable expectation, and preserves the grader name that
  [agent-promote](agent-promote.prompt.md) criterion 5 keys off.
* **Mirror copy, not symlink (Step 5)** — matches the per-run sync
  step in
  [.github/workflows/waza-agent-evals.yml](../workflows/waza-agent-evals.yml).
  CI runners may not preserve symlink semantics across `actions/checkout`,
  and the mirrored bytes are what `git diff` lets reviewers inspect.
* **No manifest edit (Step 5)** — agents are auto-discovered by the
  agent-evals workflow from filesystem layout. Adding a manifest entry
  would require parallel workflow code changes; the current design
  deliberately avoids that coupling.
* **`clean_refusal` on the off-topic task (Step 4)** — agents carry the
  identity contract that skills lack. Grading persona-lock here is the
  agent-side equivalent of grading `USE FOR:` adherence on a skill —
  it measures the contract the agent actually promises.
* **Smoke trial on one model (Step 6)** — establishes baseline
  executable status. Cross-model benchmarking is
  [agent-bench](agent-bench.prompt.md)'s job; a production-readiness
  gate is [agent-promote](agent-promote.prompt.md)'s.
* **Four-way next-step decision (Step 7)** — distinguishes "eval is
  healthy, agent needs work" (🟡) from "eval setup bug" (🟠) from
  "eval infra failure" (🔴). Each needs a different follow-on action;
  collapsing them into a single failure state hides the lever the
  user needs to pull next.
