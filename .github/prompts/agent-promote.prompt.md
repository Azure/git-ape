---
agent: 'agent'
description: 'Assess whether a custom agent is ready for production: runs the eval suite across pilot-tier models, checks against numeric readiness criteria, and prints a graduation report.'
argument-hint: '[agentName=...] [models=claude-sonnet-4.6,gpt-5.4,gpt-5-codex,claude-opus-4.6]'
---

# Agent Promote

Assess whether a custom agent (`.github/agents/<name>.agent.md`) has
earned a "ready for production" stamp. Unlike skills, agents in this
repo do not have a tier system (expanded → pilot); they run in a single
CI matrix today. This prompt therefore functions as a **production-
readiness gate**, not a tier graduation.

This is the agent-side counterpart of `/skill-promote`. It runs the
full agent eval suite across the pilot-tier model fan-out, applies the
SKILL.md staging trick to score quality, scans the agent file for
persona-lock and structural hygiene, and prints a graduation report.

This is **advisory**. The prompt produces a readiness report; the
actual "ship it" decision is a human review of the report (and, if
gates fail, a follow-up `/agent-improve` cycle).

> **Cost notice:** This prompt runs the full agent eval suite four
> times (one per pilot-tier model) plus a `waza quality` audit. Set
> `models` to a subset if quota is limited. Total premium request
> count is roughly `models × tasks × trials_per_task + 1`.

This is **non-interactive** — it runs to completion and prints a report.

## Inputs

* `${input:agentName}`: (Required) Bare agent name (e.g.
  `azure-policy-advisor`), matching the basename of
  `.github/agents/<name>.agent.md`. If omitted, ask once.
* `${input:models:claude-sonnet-4.6,gpt-5.4,gpt-5-codex,claude-opus-4.6}`:
  (Optional) Comma-separated list of waza model IDs to assess.
  Defaults to the full pilot-tier matrix.

## Readiness Criteria

An agent is **ready for production** when **all** of the following hold:

| # | Criterion | Threshold |
|---|-----------|-----------|
| 1 | Positive-task pass rate across all (model × task × trial) | ≥ 90% |
| 2 | Negative-task pass rate (off-topic refusals fire correctly) | ≥ 90% |
| 3 | Token count of the `.agent.md` file | ≤ `tokens.warningThreshold` from `.waza.yaml` |
| 4 | `waza quality` per-dimension score (clarity / completeness / trigger-precision / scope / anti-patterns) | each ≥ 3.5 / 5.0 |
| 5 | `agent_tools_implicit` grader fires on **every** per-model run (proves `skill_directories: ["."]` is wired and tool-list is matchable) | fires on 100% of legs |
| 6 | Persona-lock present in `.agent.md` (grep for `Identity (non-negotiable)` or `Always identify yourself`) | present |
| 7 | No infra-failed legs (`Session not found` or `failed to run grader` in any per-model run's `error_msg`) | 0 |

If any criterion fails, the agent stays in its current state; the
report explains which gates blocked promotion.

`waza check` is **excluded** from the criteria list because waza's
compliance checker validates SKILL.md frontmatter (`agentskills.io`
spec) and rejects `.agent.md` frontmatter as malformed. That's not a
real failure — it's a spec mismatch.

The **`tools:` taxonomy** is **not** automatically validated. The
production `tools:` field lists VS Code Chat tool IDs (`execute`,
`read`, `search`, `vscode`, `todo`, MCP namespaces); the eval runtime
emits SDK CLI short names (`bash`, `view`, `edit`, `create`, `sql`,
`task`). The criterion-5 check (`agent_tools_implicit` fires) is the
closest mechanical proxy for "tool-list is wired correctly". A
deeper taxonomy audit is a manual review item, flagged in the report
when criterion 5 fails.

## Required Protocol

Execute the steps below in order. Use the workspace root as cwd for
every shell command. Use `set -uo pipefail` (not `-e`) so a non-zero
`waza run` exit does not abort the assessment.

### Step 1 — Resolve and verify

1. Set `agent="${input:agentName}"`.
2. Verify `.github/agents/${agent}.agent.md` exists. If not, stop and
   report the missing path.
3. Verify `.github/evals/agents/${agent}/eval.yaml` exists. If not,
   stop and report the missing path. A readiness assessment requires
   an eval suite. Point the user at
   `.github/evals/agents/azure-policy-advisor/` as a reference.
4. Parse `${input:models}` by splitting on commas, trimming whitespace.
5. Print a one-line preamble:
   `Readiness assessment: <agent> against production criteria`.

### Step 2 — Resync eval-dir copy

```bash
cp ".github/agents/${agent}.agent.md" \
   ".github/evals/agents/${agent}/${agent}.agent.md"
```

One-shot sync — the production file does not change during the
assessment. The eval-dir copy is the bytes graded by Step 3.

### Step 3 — Run the eval suite per model

```bash
mkdir -p /tmp/waza-promote
for model in ${models[@]}; do
  echo "▶ Eval: ${model}"
  waza run ".github/evals/agents/${agent}/eval.yaml" \
    --model "${model}" \
    --judge-model "claude-opus-4.7" \
    --no-cache \
    --output "/tmp/waza-promote/${agent}-${model}.json" \
    2>&1 | tail -3
done
```

`--judge-model claude-opus-4.7` pins the LLM-as-judge to a model that
is NOT in any runner roster (pilot or expanded). Two reasons:

1. **No self-grading bias.** When the same model is both runner and
   judge, that leg's prompt-grader verdicts conflate model capability
   with judge agreement. Pinning the judge outside the roster gives
   every leg an independent grader.
2. **Judge capability ≥ every runner.** `claude-opus-4.7` is chosen as
   a higher-capability judge than the current pilot/expanded runner mix
   (sonnet-4.6, gpt-5.4, gpt-5-codex, opus-4.6) to reduce ceiling
   effects when scoring the strongest runner outputs.

Run sequentially — quota consumption stays predictable.

### Step 4 — Token budget check

```bash
waza tokens count ".github/agents/${agent}.agent.md" --format json \
  > "/tmp/waza-promote/${agent}-tokens.json"
warning_threshold="$(yq -r '.tokens.warningThreshold' .waza.yaml)"
agent_tokens="$(jq -r '.[0].tokens' "/tmp/waza-promote/${agent}-tokens.json")"
echo "Agent tokens: ${agent_tokens} / ${warning_threshold} (warningThreshold)"
```

### Step 5 — Quality audit (via SKILL.md staging trick)

`waza quality` requires a `SKILL.md` filename; staging the agent file
into a NON-DOT path (`waza-agent-stage/<agent>/SKILL.md`) is the
smallest workaround. `sed` strips the prefix from the output so the
human sees the real agent path.

```bash
mkdir -p "waza-agent-stage/${agent}"
cp ".github/agents/${agent}.agent.md" \
   "waza-agent-stage/${agent}/SKILL.md"

waza quality "waza-agent-stage/${agent}/SKILL.md" \
  --model claude-sonnet-4.6 --format json \
  | sed "s|waza-agent-stage/${agent}/SKILL.md|${agent}.agent.md|g" \
  > "/tmp/waza-promote/${agent}-quality.json" 2>&1

rm -rf "waza-agent-stage/${agent}"
```

Parse per-dimension scores (clarity, completeness, trigger-precision,
scope, anti-patterns) from the JSON for criterion 4.

### Step 6 — Persona-lock check

```bash
if grep -qE "Identity \(non-negotiable\)|Always identify yourself" \
     ".github/agents/${agent}.agent.md"; then
  persona_lock="present"
else
  persona_lock="missing"
fi
echo "Persona-lock: ${persona_lock}"
```

A persona-lock block is best-effort (the model's built-in CLI
refusal can still leak through on fully off-topic prompts), but its
presence is a structural minimum for production readiness.

### Step 7 — Infra-failure scan

For each `/tmp/waza-promote/${agent}-<model>.json`, count entries in
`tasks[].runs[].error_msg` containing `Session not found` or
`failed to run grader`. Both indicate the eval result was corrupted
by infrastructure noise, not model quality.

```bash
infra_errors=0
for f in /tmp/waza-promote/${agent}-*.json; do
  count=$(jq '[.tasks[]?.runs[]? | (.error_msg // "")
              | select(contains("Session not found")
                    or contains("failed to run grader"))]
              | length' "$f")
  infra_errors=$((infra_errors + count))
done
echo "Infra errors: ${infra_errors}"
```

### Step 8 — Render the readiness report

Aggregate Step 3 per-model JSONs, Step 4 token count, Step 5 quality
scores, Step 6 persona-lock state, and Step 7 infra-error count into
a single markdown block.

For each criterion, print one of:

* `✅ PASS` — value at or above threshold
* `❌ FAIL` — value below threshold (and what the value was)

Then a per-model breakdown table:

| Model | Positive pass% | Negative pass% | `agent_tools_implicit` fired | Infra errors |
|---|---|---|---|---|
| … | … | … | yes/no | … |

End with a single decision line:

* `🟢 RECOMMEND PROMOTE: <agent> meets all 7 criteria. Safe for production matrix.`
* `🔴 HOLD: <agent> failed N criteria — run /agent-improve <agent> iterations=3 to address, then re-assess.`

When criterion 5 (`agent_tools_implicit` fired) is the only failure,
include a tail line: `Tool-list mismatch likely. Verify the eval declares an explicit tool_constraint grader (per waza#226) using SDK CLI taxonomy, not VS Code Chat tool IDs.`

Do not modify any workflow file, `.agent.md`, or `eval.yaml` from
this prompt — promotion is a deliberate human-reviewed change.

## Rules and Constraints

* **Always pass `--no-cache`.** Cached results from a prior run make
  the assessment meaningless.
* **Never parallelize `waza run` calls.** Serial execution keeps
  quota consumption predictable and avoids hitting rate limits.
* **Stay scoped to assessment.** Do not edit `.agent.md`, `eval.yaml`,
  fixtures, task files, or workflow files. Promotion belongs in a
  separate human-reviewed PR.
* **Sync rule.** Step 2 refreshes the eval-dir copy once. Never
  hand-edit the eval-dir copy directly.
* **Staging cleanup.** Always `rm -rf "waza-agent-stage/${agent}"`
  after Step 5, even on failure. The stage dir is workspace-local
  scratch space, not a tracked artifact.
* **`executor: copilot-sdk` everywhere.** This repo standardizes on
  the real Copilot SDK executor for both agent and skill evals.
* **Cost transparency.** At the start (Step 1) always remind the
  user of the estimated premium request count.

## Why each step

* **`--no-cache` (Step 3)** — promotion requires a fresh execution
  per model; cached results would let stale numbers ride into a
  ship/no-ship decision.
* **Single resync at Step 2** — the production agent file is the
  source of truth; the eval-dir copy must reflect it before scoring.
* **Staging trick at Step 5** — `waza quality` requires a SKILL.md
  filename and silently skips dotted paths (the same .NET
  `FileAttributes.Hidden` quirk that bites MSDO template-analyzer).
  Staging to `waza-agent-stage/<agent>/SKILL.md` is the smallest
  workaround that lets us run the 5-dim LLM judge on an agent file.
* **Persona-lock grep (Step 6)** — a structural check, not a behavior
  test. The presence of the block is necessary but not sufficient;
  the production matrix still catches behavior regressions.
* **Infra-failure scan (Step 7)** — `Session not found` and
  grader-infra errors silently flatten task scores. Without this
  scan, a "passing" assessment could be reading contaminated 0.0s
  as legitimate model output. Promotion based on infra-corrupted
  data is worse than no promotion at all.
* **No `waza check` criterion** — waza's compliance checker
  validates SKILL.md frontmatter spec, not `.agent.md` spec.
  Including it would produce a deterministic FAIL with zero signal.
