---
agent: 'agent'
description: 'Cross-model benchmark for a single custom agent: runs waza eval once per model, captures results, compares with waza compare, and prints a one-line winner summary'
argument-hint: '[agentName=...] [models=claude-sonnet-4.6,gpt-5.4,gpt-5.3-codex,claude-opus-4.6]'
---

# Agent Bench

Run a cross-model benchmark against a single custom agent's eval suite.
Executes `waza run` once per model, captures per-model result JSON to
`/tmp/waza-runs/`, then compares all runs with `waza compare` and prints
a one-line summary identifying the best model and the gap to the next.

This is the agent-side counterpart of `/skill-bench`. It targets
`.github/evals/agents/<agent>/eval.yaml` and uses the waza ≥ 0.31
custom-agent eval feature ([PR #226](https://github.com/microsoft/waza/pull/226)).

> **Cost notice:** This prompt consumes **one premium Copilot request per
> (model × task × trial)** combination. With 4 models and a suite of 3 tasks,
> that is ≥ 12 premium requests per invocation. Set `models` to a subset if
> quota is limited.

This is **non-interactive** — it runs to completion and reports results.

## Inputs

* `${input:agentName}`: (Required) Bare agent name (e.g.
  `azure-policy-advisor`), matching the basename of
  `.github/agents/<name>.agent.md`. If omitted, ask once then proceed.
* `${input:models:claude-sonnet-4.6,gpt-5.4,gpt-5.3-codex,claude-opus-4.6}`:
  (Optional) Comma-separated list of waza model IDs to benchmark.
  Defaults to all four pilot-tier models. Run `waza models` to see the
  currently-supported IDs.

## Required Protocol

Execute the steps below in order. Use the workspace root as cwd for every
shell command. Use `set -uo pipefail` (not `-e`) so a non-zero `waza run`
exit (eval below threshold) does not abort the benchmark.

### Step 1 — Resolve and verify

1. Set `agent="${input:agentName}"`.
2. Verify `.github/agents/${agent}.agent.md` exists. If not, stop and
   report the missing path.
3. Verify `.github/evals/agents/${agent}/eval.yaml` exists. If not, stop
   and report the missing path. Benchmarking requires an eval suite —
   point the user at `.github/evals/agents/azure-policy-advisor/` as a
   reference layout.
4. Parse `${input:models}` by splitting on commas, trimming whitespace.
   Store as an array `models`. If empty or not provided, use the default
   list: `claude-sonnet-4.6`, `gpt-5.4`, `gpt-5.3-codex`, `claude-opus-4.6`.
5. Print a one-line preamble:
   `Benchmarking <agent> across <N> models: <model1>, <model2>, ...`

### Step 2 — Resync eval-dir copy

The eval directory holds a **copy** of the production agent file (not a
symlink). Refresh it once before any runs so every model sees the same
on-disk bytes:

```bash
cp ".github/agents/${agent}.agent.md" \
   ".github/evals/agents/${agent}/${agent}.agent.md"
```

This is a one-shot copy, not a per-model sync — the production file
does not change during the benchmark, so re-copying between runs would
be redundant.

### Step 3 — Run evals (one per model)

```bash
mkdir -p /tmp/waza-runs

for model in ${models[@]}; do
  echo "▶ Running: ${model}"
  waza run ".github/evals/agents/${agent}/eval.yaml" \
    --model "${model}" \
    --no-cache \
    --output "/tmp/waza-runs/${agent}-${model}-bench.json" \
    2>&1 | tail -5
  echo "  → saved /tmp/waza-runs/${agent}-${model}-bench.json"
done
```

**Rules:**
- Pass `--no-cache` on every run. Without it, a cached result from a
  previous run makes the comparison meaningless.
- Do not pass `--format` here; the default output is what we want for the
  JSON capture. The `waza compare` step formats the results.
- If a model ID is unsupported, `waza run` will exit non-zero; log the
  failure and continue to the next model (do not abort the whole bench).
- Do not parallelise the runs (no background `&`). Running serially bounds
  memory and makes quota consumption predictable.

### Step 4 — Compare results

```bash
# Collect all result files produced in Step 3
result_files=(/tmp/waza-runs/${agent}-*-bench.json)
if [ ${#result_files[@]} -lt 2 ]; then
  echo "⚠ Only ${#result_files[@]} result file(s) found — skipping compare."
else
  waza compare "${result_files[@]}" --format table
fi
```

If `waza compare` exits non-zero, print the error and continue to Step 5.

### Step 5 — One-line summary

Parse the `waza compare` table output (or the per-run score lines from
Step 3 if compare failed). Then print:

```
Best model:  <model-name>   overall score <X.XX>
Second best: <model-name>   overall score <X.XX>   gap: <+/-Δ>
```

If only one model produced a valid result, print:
```
Only one valid result: <model-name>   overall score <X.XX> — no comparison possible.
```

Then close with a "Next steps" line:
- If best and second-best are close (gap < 0.05):
  `"Gap is narrow — consider running with trials_per_task=3 on the best model to confirm."`
- If gap ≥ 0.05:
  `"Clear winner: use <best-model> for this agent in the matrix."`

Also include a one-line **infra-failure check**: scan each result JSON
for `tasks[].runs[].error_msg` containing `"Session not found"` or
`"failed to run grader"`. If any are present, surface the model + count
in a `⚠ Infra-failed legs:` line so the human knows the comparison is
contaminated and rerun is warranted.

## Rules and Constraints

* **Always pass `--no-cache`.** Results cached from a prior run make the
  delta meaningless.
* **Never parallelize `waza run` calls.** Serial execution keeps quota
  consumption predictable and avoids hitting rate limits.
* **Respect unsupported model IDs.** If a model fails with an "unsupported"
  error, log it and move on — do not abort the entire bench.
* **Stay scoped to eval runs.** Do not edit `.agent.md`, `eval.yaml`,
  fixtures, or task files as part of this prompt. Eval changes belong in
  a separate review.
* **Sync rule.** Step 2 refreshes the eval-dir copy from the production
  file once at the top. Never hand-edit the eval-dir copy directly — it
  is a derived artifact.
* **`skill_directories` is required.** The auto-injected `tool_constraint`
  grader only fires when the eval's `config:` block includes
  `skill_directories: ["."]`. If `agent_tools_implicit` is missing from
  every per-model run, flag the setup bug in the summary and recommend
  fixing the eval before trusting bench results.
* **`executor: copilot-sdk` everywhere.** This repo standardizes on the
  real Copilot SDK executor for both agent and skill evals.
* **Cost transparency.** At the start (Step 1) always remind the user of
  the estimated premium request count: `models × tasks × trials_per_task`.

## Why each step

* **`--no-cache` on every run (Step 3)** — a cached result makes the
  comparison delta meaningless; the bench only has value if each model is
  exercised fresh.
* **Serial runs (Step 3)** — parallel `waza run` calls multiply quota
  consumption and can hit rate limits; serial is slightly slower but
  predictable and cost-safe.
* **Single resync at Step 2** — the production agent file is the source
  of truth; the eval-dir copy must reflect it before benchmarking. Doing
  it once (not per-model) prevents accidental mid-bench drift.
* **`waza compare` (Step 4)** — produces a structured table normalised
  across runs; parsing raw score lines from stdout is fragile.
* **One-line summary (Step 5)** — answers the only question that matters:
  which model to pin for this agent, and how confident we should be.
* **Infra-failure scan (Step 5)** — `Session not found` and grader-infra
  errors silently flatten scores. Surfacing them prevents reading
  contaminated bench data as a quality signal.
