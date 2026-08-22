---
agent: 'agent'
description: 'Assess whether a skill in the expanded eval tier is ready to graduate to the pilot tier (full 4-model fan-out). Runs the eval suite, checks against numeric promotion criteria, and prints a graduation report.'
argument-hint: '[skillName=...]'
---

# Skill Promote

Assess whether a skill that lives in the **expanded eval tier** (2 models in
CI: `claude-sonnet-4.6` + `gpt-5-codex`) has earned promotion to the **pilot
tier** (full 4-model fan-out + `trials_per_task: 3` flake detection).

This is **advisory**. The prompt produces a graduation report; an actual
promotion is a separate code change to remove the skill's `exclude:` entries
from `.github/workflows/waza-evals.yml` and `waza-trends.yml` (and to bump
`config.trials_per_task` in the skill's `eval.yaml`).

> **Cost notice:** This prompt runs the full skill eval suite four times
> (one per pilot-tier model) plus a tokens profile. Set `models` to a subset
> if quota is limited.

This is **non-interactive** — it runs to completion and prints a report.

## Inputs

* `${input:skillName}`: (Required) Skill directory name under
  `.github/skills/` (bare name, not a path). If omitted, ask once.
* `${input:models:claude-sonnet-4.6,gpt-5.4,gpt-5-codex,claude-opus-4.6}`:
  (Optional) Comma-separated list of waza model IDs to benchmark for
  promotion. Defaults to the full pilot-tier matrix.

## Promotion Criteria

A skill is **ready to promote** when **all** of the following hold:

| # | Criterion | Threshold |
|---|-----------|-----------|
| 1 | Trigger precision — every model in the bench scores at or above the eval's `metrics.trigger_precision.threshold` | ≥ each model's threshold (default 0.6) |
| 2 | Behavior grader pass rate across all (model × task × trial) | ≥ 90% |
| 3 | Prompt grader (`answer_quality`) median score across all legs | ≥ 4.0 / 5.0 |
| 4 | Token count of the skill's `SKILL.md` | ≤ `tokens.warningThreshold` from `.waza.yaml` |
| 5 | No `waza check` errors (compliance) | 0 errors |
| 6 | `eval.yaml` already validates against upstream schema | OK |

If any criterion fails, the skill stays in the expanded tier; the report
explains which gates blocked promotion.

## Required Protocol

Execute the steps below in order. Use the workspace root as cwd for every
shell command. Use `set -uo pipefail` (not `-e`) so a non-zero `waza run`
exit does not abort the assessment.

### Step 1 — Resolve and verify

1. Set `skill="${input:skillName}"`.
2. Verify `.github/evals/${skill}/eval.yaml` exists. If not, stop and
   report the missing path.
3. Verify `.github/skills/${skill}/SKILL.md` exists. If not, stop.
4. Parse `${input:models}` by splitting on commas, trimming whitespace.
5. Print a one-line preamble:
   `Promotion assessment: <skill> against pilot-tier criteria`.

### Step 2 — Run the eval suite per model

```bash
mkdir -p /tmp/waza-promote
for model in ${models[@]}; do
  echo "▶ Eval: ${model}"
  waza run ".github/evals/${skill}/eval.yaml" \
    --model "${model}" \
    --judge-model "claude-opus-4.7" \
    --no-cache \
    --output "/tmp/waza-promote/${skill}-${model}.json" \
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

### Step 3 — Token budget check

```bash
waza tokens count ".github/skills/${skill}/SKILL.md" --format json \
  > "/tmp/waza-promote/${skill}-tokens.json"
warning_threshold="$(yq -r '.tokens.warningThreshold' .waza.yaml)"
skill_tokens="$(jq -r '.[0].tokens' "/tmp/waza-promote/${skill}-tokens.json")"
echo "Skill tokens: ${skill_tokens} / ${warning_threshold} (warningThreshold)"
```

### Step 4 — Compliance check

```bash
waza check ".github/skills/${skill}" \
  > "/tmp/waza-promote/${skill}-check.txt" 2>&1 || true
errors="$(grep -ciE '^(error|✗|fail)' "/tmp/waza-promote/${skill}-check.txt" || echo 0)"
echo "Compliance errors: ${errors}"
```

### Step 5 — Render the graduation report

Aggregate the per-model JSONs from Step 2, the token count from Step 3,
and the compliance result from Step 4 into a single markdown block.

For each criterion, print one of:
- `✅ PASS` — value at or above threshold
- `❌ FAIL` — value below threshold (and what the value was)

End with a single decision line:

- `🟢 RECOMMEND PROMOTE: <skill> meets all 7 criteria. Open a PR to remove its exclude entries from waza-evals.yml + waza-trends.yml and bump trials_per_task to 3.`
- `🔴 HOLD IN EXPANDED TIER: <skill> failed N criteria — fix and re-assess.`

Do not modify any workflow file or `eval.yaml` from this prompt — promotion
is a deliberate human-reviewed change.
