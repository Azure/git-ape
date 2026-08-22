---
agent: 'agent'
description: 'Onboard a new skill into the waza eval harness: scaffold eval.yaml + tasks, patch to repo conventions (hybrid graders, concrete prompts, schema headers), register at the expanded tier in manifest.yaml, then run a smoke trial.'
argument-hint: '[skillName=...] [positiveTasks={2|3|4}] [negativeTasks={1|2}] [smokeModel=claude-sonnet-4.6]'
---

# Skill Onboard

Bootstrap a brand-new eval suite for a skill that currently has no
evaluation. This is **stage 0** of the eval lifecycle — it precedes
[skill-bench](skill-bench.prompt.md), [skill-improve](skill-improve.prompt.md),
and [skill-promote](skill-promote.prompt.md).

What it produces:

* `.github/evals/<skill>/eval.yaml`
* `.github/evals/<skill>/tasks/positive-*.yaml` (default 2)
* `.github/evals/<skill>/tasks/negative-*.yaml` (default 2)
* `.github/evals/<skill>/tasks/negative-off-topic.yaml` (one off-topic negative, trigger-grader only)
* A new `{ name: <skill>, tier: expanded }` entry appended to
  `.github/evals/manifest.yaml`

What it does **not** do:

* Edit `SKILL.md`. Onboarding consumes the skill as-is. Use
  [skill-improve](skill-improve.prompt.md) for SKILL.md edits.
* Promote the skill to the pilot tier. That gate is
  [skill-promote](skill-promote.prompt.md), and only after the skill has
  matured in the expanded tier.

This is **interactive**. The protocol pauses for approval before writing
the manifest entry and before running the smoke trial.

> **Cost notice:** Step 3 (`waza suggest --apply`) consumes ~1 premium
> request to author the initial scaffold. Step 6 (smoke trial) consumes
> `trials_per_task × len(tasks)` premium requests (default `2 × 5 = 10`)
> plus per-task judge calls (one `answer_quality` judge per positive
> trial). Total budget ≈ **12–16 premium requests** per invocation —
> larger than a single-trial scaffold but enough to surface obvious
> flakes during onboarding.

## Inputs

* `${input:skillName}`: (Required) Skill directory name under
  `.github/skills/`. Pass the bare name (e.g. `azure-naming-research`),
  not a path. If omitted, infer from the user's message; otherwise ask
  once.
* `${input:positiveTasks:2}`: (Optional, defaults to `2`) How many
  positive trigger tasks to scaffold. Hard-capped at `4` to bound cost.
  Each positive task gets a hybrid grader pair: `trigger` (heuristic) +
  `answer_quality` (LLM judge, `continue_session: true`).
* `${input:negativeTasks:2}`: (Optional, defaults to `2`) How many
  negative trigger tasks to scaffold. Hard-capped at `2`. Defaulting to
  the cap gives every new skill at least two in-domain refusal cases on
  top of the dedicated off-topic task — single-negative scaffolds tend
  to under-cover the `DO NOT USE FOR:` boundary. Negative tasks carry
  the `trigger` grader only — refusals shouldn't call tools or be
  graded on answer quality.
* `${input:smokeModel:claude-sonnet-4.6}`: (Optional) Model to use for
  the final smoke trial. Default is the cheapest stable model in the
  matrix; override only if the skill is model-sensitive.

## Required Protocol

Execute the steps below in order. Use the workspace root as cwd for
every shell command. Use `set -uo pipefail` (not `-e`) so a non-zero
`waza run` exit (eval below threshold on first run) does not abort the
onboarding.

### Step 1 — Resolve and verify

1. Set `skill="${input:skillName}"`.
2. Set `nPos = min(4, ${input:positiveTasks:2})`,
   `nNeg = min(2, ${input:negativeTasks:2})`.
3. Verify `.github/skills/${skill}/SKILL.md` exists. If not, stop and
   report the missing path.
4. **Refuse to overwrite.** If `.github/evals/${skill}/` already exists,
   stop and tell the user to use [skill-improve](skill-improve.prompt.md)
   or delete the directory manually first. Onboarding is a greenfield
   operation.
5. Check the manifest. If `.github/evals/manifest.yaml` already lists
   `name: ${skill}`, stop and report — the skill is already registered.
6. Print a one-line preamble:
   `Onboarding <skill> with <nPos> positive + <nNeg> negative + 1 off-topic task; smoke model: <smokeModel>`.

### Step 2 — Profile the skill

Read `.github/skills/${skill}/SKILL.md` and extract:

1. The `description:` frontmatter line.
2. The `USE FOR:` list — these become **positive** task prompts. Pick
   the `nPos` most distinct phrasings. If `USE FOR:` is missing, scan
   the body for "When to use" / "Triggers on" / "Triggers:" and use
   those phrasings.
3. The `DO NOT USE FOR:` list — these become **negative** task prompts.
   Pick the `nNeg` most distinct phrasings.
4. The skill's primary domain (1–3 words; e.g. "Azure naming",
   "Bicep templates", "prereq tooling"). This drives the off-topic
   negative task — pick a topic clearly outside the domain (e.g. "Linux
   kernel scheduling internals" for an Azure skill) so the trigger
   grader can confirm the skill stays inactive.

Echo the extracted profile so the human can sanity-check before any
files are written.

### Step 3 — Scaffold with `waza suggest`

Generate the initial eval scaffold using waza's LLM-driven suggester.
Stage to a temp directory first so we can patch and move atomically.

```bash
mkdir -p /tmp/waza-onboard/${skill}
waza suggest ".github/skills/${skill}" \
  --apply \
  --output-dir "/tmp/waza-onboard/${skill}" \
  --model "claude-sonnet-4.6" \
  2>&1 | tail -10
```

If `waza suggest` fails (e.g. LLM unavailable), **fall back to the
deterministic scaffold**:

```bash
waza new eval "${skill}" \
  --output "/tmp/waza-onboard/${skill}/eval.yaml" \
  2>&1 | tail -5
```

Either way, verify the staged tree contains `eval.yaml` and at least
one task file. If not, stop and report.

### Step 4 — Patch to repo conventions

The waza-generated scaffold is generic. Patch it to match the
prereq-check reference suite ([.github/evals/prereq-check/eval.yaml](.github/evals/prereq-check/eval.yaml)).
Apply ALL of the following edits to the staged files before they leave
`/tmp/waza-onboard/${skill}/`.

**`eval.yaml` patches:**

1. Top-of-file schema comment: prepend
   `# yaml-language-server: $schema=https://raw.githubusercontent.com/microsoft/waza/main/schemas/eval.schema.json`.
2. `config:` block must include:
   ```yaml
   config:
     # 2 trials catches the obvious LLM nondeterminism flakes (single trial
     # = no flake signal). Pilot tier bumps to 3 via /skill-promote.
     trials_per_task: 2
     timeout_seconds: 60
     parallel: false
     executor: copilot-sdk
     model: claude-sonnet-4.6
   ```
3. `metrics:` block must contain exactly one entry:
   ```yaml
   metrics:
     - name: trigger_precision
       weight: 1.0
       threshold: 0.6
       description: <one-line description derived from SKILL.md>
   ```
4. `graders:` block at the eval level must contain ONLY the `budget`
   behavior grader. **Do NOT add `skill_invocation` with `required_skills:`
   here** — eval-level prompt graders fire on every task including
   negatives, drag every leg by ~25%, and produce zero model signal
   (the same score across all models proves it's noise, not value).
   ```yaml
   graders:
     - type: behavior
       name: budget
       config:
         max_tool_calls: 30
         max_duration_ms: 240000
   ```
5. `tasks:` block: `["tasks/*.yaml"]`.
6. Remove any `tool_constraint` grader waza auto-injected at the eval
   root. To suppress the auto-injection, add the no-op pattern from the
   eval-harness convention:
   ```yaml
   _suppress_auto_inject:
     type: tool_constraint
     reject_tools: [{tool: "^___never_matches___$"}]
   ```

**Per-task patches (all task files — apply first):**

`waza new eval` (and `waza suggest`) emit each task file with two
defects that MUST be cleaned up before patching graders:

1. **Prepend the task-schema header** as line 1 of every task file:
   ```yaml
   # yaml-language-server: $schema=https://raw.githubusercontent.com/microsoft/waza/main/schemas/task.schema.json
   ```
   Without this, VS Code applies the eval-schema to task files and
   surfaces ~6 false-positive lint errors per file ("Property graders
   is not allowed", etc.).
2. **Remove any `expected:` field** the scaffold emitted. The waza
   task JSON schema accepts the shape `expected:\n  should_trigger: true`,
   but the **Go runtime parser rejects it**
   (`cannot unmarshal !!seq into models.TaskExpectation`) and the suite
   fails to load. Graders alone drive pass/fail — reference
   [.github/evals/prereq-check/tasks/](.github/evals/prereq-check/tasks/)
   which has no `expected:` field on any task.

**Per-task patches (`tasks/positive-*.yaml`):**

Before patching graders, **rewrite `inputs.prompt:` to a concrete,
answerable scenario** derived from the `USE FOR:` phrasings extracted
in Step 2. The scaffold emits generic placeholders like `"Use <skill>
to help me complete this task"` which cause the agent to ask for
clarification → `answer_quality` fails deterministically. Reference
shape: prereq-check's `positive-command-not-found` task uses
`"az: command not found — what tools should be installed for Git-Ape
skills?"` — concrete, scenario-grounded, immediately answerable.

Each positive task MUST have a hybrid grader pair. The `prompt` grader
needs `continue_session: true` — without it the judge has zero access
to the agent's response and scores fail/pass at random.

```yaml
graders:
  - name: trigger_relevance_positive
    type: trigger
    config:
      skill_path: .github/skills/<skill>/SKILL.md
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
          1. <criterion 1 derived from SKILL.md's expected output>
          2. <criterion 2>
          3. <criterion 3>
          4. <criterion 4>

        If ALL criteria are met, call `set_waza_grade_pass`.
        Otherwise, call `set_waza_grade_fail` and list which criteria are missing.
```

**Per-task patches (`tasks/negative-*.yaml`):**

Negative tasks carry the `trigger` grader only. No `answer_quality`
grader — a refusal that's syntactically correct shouldn't be graded on
"how good is the answer".

```yaml
graders:
  - name: trigger_relevance_negative
    type: trigger
    config:
      skill_path: .github/skills/<skill>/SKILL.md
      mode: negative
      threshold: 0.5
```

**New file — `tasks/negative-off-topic.yaml`:**

Author from scratch as a trigger-only negative task targeting the
off-topic domain identified in Step 2. **Do NOT add a `clean_refusal`
prompt grader.** Skills are passive guidance — persona-lock and identity
contracts belong to `.agent.md` mirrors, not SKILL.md. Grading a skill
on refusal language confuses two surfaces and produces deterministic
0.0 noise when the model simply answers the off-topic question (which
it will, absent agent-level identity enforcement). The trigger grader
alone is the right signal: it confirms the skill stays inactive on
out-of-scope prompts.

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/microsoft/waza/main/schemas/task.schema.json
id: negative-off-topic
name: Negative — Off-topic prompt
description: Off-topic prompt should not trigger this skill.
tags: [trigger, negative]
inputs:
  prompt: "<a prompt about the off-topic domain identified in Step 2>"
graders:
  - name: trigger_relevance_negative
    type: trigger
    config:
      skill_path: .github/skills/<skill>/SKILL.md
      mode: negative
      threshold: 0.5
```

### Step 5 — Approval gate + move into place

Show the human a tree listing of the staged files plus a diff-style
summary of what will be written. Then pause and ask:

> Apply this eval suite to `.github/evals/${skill}/` and register
> `${skill}` at the **expanded** tier in `manifest.yaml`? (yes / no)

If `yes`:

```bash
mkdir -p ".github/evals/${skill}"
cp -R "/tmp/waza-onboard/${skill}/." ".github/evals/${skill}/"
```

Then append to `.github/evals/manifest.yaml`. The expanded tier is the
correct landing zone — pilot is reserved for skills with proven cross-
model stability (gated by [skill-promote](skill-promote.prompt.md)).

```yaml
# Append under skills:, after existing entries
  - name: <skill>
    tier: expanded
```

Use `yq` to make the manifest edit idempotent:

```bash
yq -i ".skills += [{\"name\": \"${skill}\", \"tier\": \"expanded\"}]" \
  .github/evals/manifest.yaml
```

If `no`, stop without writing anything. Leave the staged files in
`/tmp/waza-onboard/${skill}/` for the user to inspect manually.

### Step 6 — Validate

`waza check` is a **skill-side** validator (compliance scoring, token
budget, frontmatter). There is currently no first-class linter for
`.github/evals/<skill>/eval.yaml` — Step 7's smoke trial is the runtime
validator. Run `waza check` against the **skill** directory, not the
eval directory (the latter returns `no SKILL.md found`):

```bash
waza check ".github/skills/${skill}" 2>&1 | tail -30
```

Triage the output:

* **Blocking failures** — stop and surface; do NOT proceed to the smoke
  trial. These include: compliance score `Low`, broken or missing
  frontmatter, missing `name:` or `description:`, invalid YAML.
* **Advisory findings** — surface but do NOT block. Common advisories
  that should NOT halt onboarding: token-budget overage, hardcoded
  URLs, missing examples section, complexity score, body-structure
  recommendations on an otherwise-passing skill.

### Step 7 — Smoke trial (single model, single trial)

Confirm the suite executes end-to-end. This is a cheap signal that the
graders wire up correctly — not a quality assessment.

```bash
mkdir -p /tmp/waza-runs
waza run ".github/evals/${skill}/eval.yaml" \
  --model "${input:smokeModel:claude-sonnet-4.6}" \
  --judge-model "claude-opus-4.7" \
  --no-cache \
  --output "/tmp/waza-runs/${skill}-smoke.json" \
  2>&1 | tail -10
```

`--judge-model claude-opus-4.7` is fixed (NOT a parameter) for the
same reason as `/skill-promote`: judge sits outside every runner
roster, so smoke verdicts cannot leak self-grading bias even if the
operator changes `smokeModel`. `smokeModel` only swaps the runner.
The one exception: if the operator sets `smokeModel` to
`claude-opus-4.7` (the same value as `--judge-model`), the smoke run
becomes self-graded — avoid that pairing.

Parse the result JSON and report:

* `summary.aggregate_score`
* Per-task `tasks[].stats.avg_score`
* Any tasks with `runs[].status == "error"` and their `error_msg` —
  these indicate grader-infra failures and must be investigated before
  the suite is trusted (see workflow-level retry pattern in
  [.github/workflows/waza-evals.yml](.github/workflows/waza-evals.yml)).

### Step 8 — Render next-step

Print a single decision line, then a one-line next-step:

* **All tasks scored, no errors:**
  `🟢 ONBOARDED: <skill> registered at expanded tier. Smoke trial scored <X.XX>.`
  Next: `Run /skill-bench ${skill} to benchmark across the expanded tier (2 models, ~20 premium requests at trials=2).`

* **Some tasks scored 0.0 cleanly (model failed criteria):**
  `🟡 ONBOARDED with weak signal: <skill> registered at expanded tier but smoke scored <X.XX>. Inspect failing tasks.`
  Next: `Run /skill-improve ${skill} to tighten SKILL.md, OR edit the eval grader criteria.`

* **Any task had `runs[].status == "error"`:**
  `🔴 ONBOARDED but smoke FAILED: <N> task(s) errored — see /tmp/waza-runs/${skill}-smoke.json.`
  Next: `Investigate grader-infra errors (session-not-found, judge unreachable) before relying on this eval.`

## Rules and Constraints

* **Greenfield only.** This prompt refuses to overwrite an existing
  `.github/evals/${skill}/` directory. Iteration belongs to
  [skill-improve](skill-improve.prompt.md), not here.
* **Expanded tier is the only landing zone.** Never write `tier: pilot`
  from this prompt — promotion is gated separately and requires
  cross-model evidence.
* **Approval gate before file writes.** Step 5 pauses for human review.
  Do not bypass.
* **No SKILL.md edits.** Onboarding is non-destructive to the skill
  itself. If SKILL.md is malformed (no `USE FOR:` / `DO NOT USE FOR:`),
  Step 2 stops and redirects to [skill-improve](skill-improve.prompt.md).
* **`continue_session: true` on every prompt grader.** Without it the
  judge cannot see the agent's response and scores oscillate. This is
  encoded in Step 4's templates — do not omit.
* **No `skill_invocation` grader with `required_skills:` at eval level.**
  Eval-level prompt graders fire on EVERY task (including negatives) and
  produce deterministic 0.0 noise. Removed in commit `2f699c79` from
  git-ape-onboarding for this reason.
* **No `clean_refusal` grader on negative tasks.** Skills don't enforce
  identity contracts — persona-lock belongs to `.agent.md` mirrors. Use
  the trigger grader alone on negative and off-topic tasks; let the
  smoke trial confirm the skill stays inactive on out-of-scope prompts.
* **Strip scaffold cruft before patching.** `waza new eval` emits each
  task file without the `yaml-language-server` schema header and with
  an `expected:` field the runtime parser rejects. Step 4's first
  per-task patch removes both — do not skip it.
* **No agent files.** This prompt onboards **skills only**. If the user
  passes an agent name (e.g. one of the agents under `.github/agents/`),
  stop and point them to [agent-onboard](agent-onboard.prompt.md) (or to
  the `.agent.md` mirror convention if onboarding a hybrid).

## Why each step

* **Refuse-to-overwrite (Step 1)** — atomic onboarding semantics. A
  half-written second-pass is harder to recover from than a clean refusal.
* **Profile from `USE FOR:` / `DO NOT USE FOR:` (Step 2)** — those
  sections are the canonical scope contract per the agent-customization
  conventions. Tasks anchored to them measure real adherence, not the
  authoring LLM's interpretation.
* **`waza suggest --apply` to staging (Step 3)** — the LLM-driven scaffold
  is faster than hand-authoring, but its defaults need patching. Staging
  to `/tmp/` makes the patching atomic.
* **Patch to prereq-check conventions (Step 4)** — hybrid graders,
  `continue_session: true`, no eval-level `skill_invocation`. Every one
  of these is a hard-won lesson encoded in the harness; the scaffold
  alone doesn't produce them.
* **Approval gate (Step 5)** — manifest edits and `.github/evals/`
  writes touch CI matrix dispatch. Human review is non-negotiable.
* **`waza check` before smoke (Step 6)** — fail fast on SKILL.md
  compliance failures (broken frontmatter, low compliance score) before
  spending premium requests. Advisory findings (token budget, missing
  examples) surface but do not block, since `waza check` covers the
  skill side only — Step 7's smoke trial is the eval-side runtime
  validator.
* **Smoke trial on one model (Step 7)** — establishes baseline executable
  status. Cross-model benchmarking is `/skill-bench`'s job.
* **Three-way next-step decision (Step 8)** — distinguishes "eval is
  healthy, skill needs work" from "eval is broken". The two need different
  follow-on prompts.
