---
agent: 'agent'
description: 'Cross-model benchmark for a single skill: runs waza eval once per model, captures results, compares with waza compare, and prints a one-line winner summary'
argument-hint: '[skillName=...] [models=claude-sonnet-4.6,gpt-5.4,gpt-5.3-codex,claude-opus-4.6]'
---

# Skill Bench

Run a cross-model benchmark against a single skill's eval suite. Executes
`waza run` once per model, captures per-model result JSON to `/tmp/waza-runs/`,
then compares all runs with `waza compare` and prints a one-line summary
identifying the best model and the gap to the next.

> **Cost notice:** This prompt consumes **one premium Copilot request per
> (model × task × trial)** combination. With 4 models and a suite of 3 tasks,
> that is ≥ 12 premium requests per invocation. Set `models` to a subset if
> quota is limited.

This is **non-interactive** — it runs to completion and reports results.

## Inputs

* `${input:skillName}`: (Required) Skill directory name under
  `.github/skills/`. Pass the bare name (e.g. `azure-cost-estimator`),
  not a path. If omitted, ask once then proceed.
* `${input:models:claude-sonnet-4.6,gpt-5.4,gpt-5.3-codex,claude-opus-4.6}`:
  (Optional) Comma-separated list of waza model IDs to benchmark.
  Defaults to all four matrix models. Run `waza models` to see the
  currently-supported IDs.

## Required Protocol

Execute the steps below in order. Use the workspace root as cwd for every
shell command. Use `set -uo pipefail` (not `-e`) so a non-zero `waza run`
exit (eval below threshold) does not abort the benchmark.

### Step 1 — Resolve and verify

1. Set `skill="${input:skillName}"`.
2. Verify `.github/evals/${skill}/eval.yaml` exists. If not, stop and
   report the missing path. Benchmarking requires an eval suite.
3. Parse `${input:models}` by splitting on commas, trimming whitespace.
   Store as an array `models`. If empty or not provided, use the default
   list: `claude-sonnet-4.6`, `gpt-5.4`, `gpt-5.3-codex`, `claude-opus-4.6`.
4. Print a one-line preamble:
   `Benchmarking <skill> across <N> models: <model1>, <model2>, ...`

### Step 2 — Run evals (one per model)

```bash
mkdir -p /tmp/waza-runs

for model in ${models[@]}; do
  echo "▶ Running: ${model}"
  waza run ".github/evals/${skill}/eval.yaml" \
    --model "${model}" \
    --no-cache \
    --output "/tmp/waza-runs/${skill}-${model}-bench.json" \
    2>&1 | tail -5
  echo "  → saved /tmp/waza-runs/${skill}-${model}-bench.json"
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

### Step 3 — Compare results

```bash
# Collect all result files produced in Step 2
result_files=(/tmp/waza-runs/${skill}-*-bench.json)
if [ ${#result_files[@]} -lt 2 ]; then
  echo "⚠ Only ${#result_files[@]} result file(s) found — skipping compare."
else
  waza compare "${result_files[@]}" --format table
fi
```

If `waza compare` exits non-zero, print the error and continue to Step 4.

### Step 4 — One-line summary

Parse the `waza compare` table output (or the per-run score lines from
Step 2 if compare failed). Then print:

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
  `"Clear winner: use <best-model> for this skill in the matrix."`

## Rules and Constraints

* **Always pass `--no-cache`.** Results cached from a prior run make the
  delta meaningless.
* **Never parallelize `waza run` calls.** Serial execution keeps quota
  consumption predictable and avoids hitting rate limits.
* **Respect unsupported model IDs.** If a model fails with an "unsupported"
  error, log it and move on — do not abort the entire bench.
* **Stay scoped to eval runs.** Do not edit `SKILL.md`, `eval.yaml`,
  fixtures, or task files as part of this prompt. Eval changes belong in
  a separate review.
* **No agent files.** waza only evaluates skills. If the user passes an
  agent name, stop and point them to `docs/WAZA.md` → "Agent evals".
* **Cost transparency.** At the start (Step 1) always remind the user of
  the estimated premium request count: `models × tasks × trials_per_task`.

## Why each step

* **`--no-cache` on every run (Step 2)** — a cached result makes the
  comparison delta meaningless; the bench only has value if each model is
  exercised fresh.
* **Serial runs (Step 2)** — parallel `waza run` calls multiply quota
  consumption and can hit rate limits; serial is slightly slower but
  predictable and cost-safe.
* **`waza compare` (Step 3)** — produces a structured table normalised
  across runs; parsing raw score lines from stdout is fragile.
* **One-line summary (Step 4)** — answers the only question that matters:
  which model to use in the matrix, and how confident we should be.
