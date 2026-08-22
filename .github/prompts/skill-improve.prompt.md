---
agent: 'agent'
description: 'Local feedback loop for a single skill: baseline → audit → propose edits → apply (with approval) → re-rank via waza compare. Optionally loops up to 3 rounds for deeper refinement.'
argument-hint: '[skillName=...] [iterations={1|2|3}] [rescoreQuality={true|false}]'
---

# Skill Improve

Run a local improvement loop against a single skill in this repository.
Captures a baseline eval score, gathers token + quality + frontmatter
audits, proposes concrete edits to `SKILL.md`, applies the ones the user
approves, re-runs the eval, and shows the delta.

By default this is a **single pass** (one round of audit → propose → apply
→ verify). Pass `iterations=2` or `iterations=3` for a deeper refinement
loop that re-runs `waza dev` between rounds with a fresh approval gate per
iteration — useful when driving a `SKILL.md` toward a specific adherence
level methodically. Values above `3` are clamped to bound premium-request
cost.

This is **interactive**. The protocol always pauses before editing.

## Inputs

* `${input:skillName}`: (Required) Skill directory name under
  `.github/skills/`. Pass the bare name (e.g. `prereq-check`), not a
  path. If omitted, infer from the user's message; otherwise ask once.
* `${input:iterations:1}`: (Optional, defaults to `1`) Number of
  audit-propose-apply rounds to run inside this invocation. Hard-capped
  at `3` to bound cost. When `iterations > 1`, only `waza dev` re-runs
  between rounds (tokens + quality audits stay fixed at their baseline
  values from round 1).
* `${input:rescoreQuality:false}`: (Optional, defaults to `false`)
  When `true`, re-run `waza quality` after edits and include the
  per-dimension before/after delta in the summary. Costs one extra
  premium Copilot request (the LLM-as-judge call). Off by default to
  keep the loop cheap; turn on when trigger-precision or another
  quality dimension is the lever you're trying to move.

## Required Protocol

Execute the steps below in order. Do not parallelize across steps.
Within step 3, the three audit commands MAY run in parallel.

Use the workspace root as cwd for every shell command. Use `set -uo
pipefail` (not `-e`) so a non-zero `waza run` exit (eval below
threshold) does not abort the loop.

### Step 1 — Resolve and verify

1. Set `skill="${input:skillName}"`.
2. Set `maxIter = min(3, ${input:iterations:1})`.
3. Verify `.github/skills/${skill}/SKILL.md` exists. If not, stop and
   report the missing path.
4. Note whether `.github/evals/${skill}/eval.yaml` exists. If not, the
   loop runs in **audit-only** mode: skip steps 2, 7, 8 and warn the
   user that score deltas cannot be measured.
5. Print a one-line preamble:
   `Improving <skill> (eval: present|absent, iterations: <maxIter>)`.

### Step 2 — Baseline eval (skip in audit-only mode)

Run **once**, with cache disabled so a later re-run produces a real
delta even when `eval.yaml` is unchanged:

```bash
mkdir -p /tmp/waza-runs
waza run ".github/evals/${skill}/eval.yaml" \
  --no-cache \
  --output "/tmp/waza-runs/${skill}-baseline.json"
```

Capture the printed score line (e.g. `Score: 0.62`) for the summary.
(`--format` only accepts `default` or `github-comment`; the default is
what we want here.)

### Step 3 — Initial audits (run in parallel, once)

Run all four audits to seed iteration 1. Each writes to a temp file so
later steps can read them.

```bash
waza tokens suggest ".github/skills/${skill}/SKILL.md" --format text \
  > "/tmp/waza-runs/${skill}-tokens.txt" 2>&1 &

waza quality ".github/skills/${skill}/SKILL.md" \
  --model claude-sonnet-4.6 --format table \
  > "/tmp/waza-runs/${skill}-quality.txt" 2>&1 &

waza dev "${skill}" --copilot --model claude-sonnet-4.6 \
  > "/tmp/waza-runs/${skill}-dev-iter1.md" 2>&1 &

wait
```

If any of the three exits non-zero, keep going but flag the failure in
the summary. They are advisory inputs, not gates.

### Step 4 — Iteration loop

Repeat the audit → propose → approve → apply cycle up to `maxIter`
times. Track iteration index `i` starting at `1`. Maintain a running
log `applied[i] = [list of indices]` for the final summary.

**For iteration `i = 1`**: skip step 4a (audits are already in
`/tmp/waza-runs/${skill}-dev-iter1.md` from step 3).

**For iteration `i >= 2`**: run a fresh `waza dev` only — tokens and
quality are not re-run between rounds (they're advisory inputs that
rarely shift on small edits, and re-running quality costs a premium
request each time):

```bash
waza dev "${skill}" --copilot --model claude-sonnet-4.6 \
  > "/tmp/waza-runs/${skill}-dev-iter${i}.md" 2>&1
```

If the report says "target adherence reached" or contains zero
recommendations, **stop the loop** with stop reason `target reached`
or `no recommendations` and jump to step 5.

#### Step 4a — Read iteration context

Read into context (do not echo back to the user verbatim — they will
see the synthesis in step 4b):

* `.github/skills/${skill}/SKILL.md` (current on-disk version)
* `.github/evals/${skill}/eval.yaml` (if present)
* `/tmp/waza-runs/${skill}-tokens.txt` (iter 1 only — reused after)
* `/tmp/waza-runs/${skill}-quality.txt` (iter 1 only — reused after)
* `/tmp/waza-runs/${skill}-dev-iter${i}.md` (fresh each iteration)

#### Step 4b — Propose edits

Produce a numbered list of **3 to 7** concrete, actionable edits to
`SKILL.md`. Each item has:

* **Index** — sequential within this iteration, starts at 1.
* **Lever** — one of: `clarity` | `trigger-precision` | `scope-boundary`
  | `token-saving` | `anti-pattern`.
* **Rationale** — one or two sentences citing the audit input that
  surfaced the suggestion (e.g. "tokens suggest flagged 280-token
  example block" or "quality scored trigger-precision 2/5" or
  "`waza dev` iter 2 recommendation: tighten `when-to-use` against
  scope overlap with `azure-cost`").
* **Proposed change** — the exact text to add, modify, or delete.

Do not invent edits beyond what the audits + your reading of
`SKILL.md` and `eval.yaml` justify. Prefer fewer high-confidence edits
to a long list of speculative ones.

After the list, ask the user a single question. The options vary by
iteration:

* **If `maxIter == 1` or this is the final iteration:**
  > Reply with the indices to apply (e.g. `1, 3, 5`), `all`, or `skip`.
* **If more iterations remain (`i < maxIter`):**
  > Reply with the indices to apply (e.g. `1, 3, 5`), `all`, `skip`,
  > or `stop` to end the loop now.

#### Step 4c — Apply approved edits

On user response:

* `stop` — record `applied[${i}] = []` with reason `user stopped`,
  exit the loop, jump to step 5.
* `skip` — record `applied[${i}] = []`, continue to iteration `i + 1`
  (or exit if `i == maxIter`).
* `all` or a list of indices — apply the corresponding edits using
  `edit` tool calls (never shell `sed`/`awk`). Record applied indices.

After applying, increment `i`. If `i > maxIter`, exit the loop with
stop reason `max iterations`.

### Step 5 — Verify (skip in audit-only mode, skip if no edits applied)

Re-run with cache disabled:

```bash
waza run ".github/evals/${skill}/eval.yaml" \
  --no-cache \
  --output "/tmp/waza-runs/${skill}-after.json"
```

### Step 6 — Compare (skip in audit-only mode, skip if no edits applied)

```bash
waza compare \
  "/tmp/waza-runs/${skill}-baseline.json" \
  "/tmp/waza-runs/${skill}-after.json" \
  --format table
```

### Step 6b — Re-score quality (only when `rescoreQuality=true`)

Run a fresh quality judge against the edited `SKILL.md` and capture
the table for the summary.

```bash
waza quality ".github/skills/${skill}/SKILL.md" \
  --model claude-sonnet-4.6 --format table \
  > "/tmp/waza-runs/${skill}-quality-after.txt" 2>&1
```

Parse both `/tmp/waza-runs/${skill}-quality.txt` (baseline, captured
in step 3) and `/tmp/waza-runs/${skill}-quality-after.txt`. Skip this
step silently when `rescoreQuality` is `false`.

### Step 7 — Summary

Print a Markdown summary table with:

| Metric | Before | After | Δ |
|---|---|---|---|
| Overall score | … | … | … |
| Per-task: <name> | … | … | … |
| SKILL.md tokens | … | … | … |
| Quality (clarity / completeness / trigger-precision / scope / anti-patterns) | … | … | … |

The Quality row populates with real before/after numbers **only when
`rescoreQuality=true`**. Otherwise show the baseline column from step
3 and write `not re-scored (pass rescoreQuality=true to enable)` in
the After column.

If `maxIter > 1`, also print a per-iteration breakdown:

* **Iterations run** — `<actual>` of `<maxIter>`.
* **Stop reason** — one of: `target reached` | `max iterations` |
  `user stopped` | `no recommendations` | `eval missing — only ran
  audits` | `no edits applied`.
* **Per-iteration applied items** — bullet list grouped by iteration
  index, citing each applied edit's lever.

Then a "Verdict" paragraph using one of these labels:

* `IMPROVED` — overall score increased AND no negative-task score
  increased AND no positive-task score decreased.
* `MIXED` — overall score increased BUT at least one of: negative-task
  score went up, positive-task score went down.
* `REGRESSED` — overall score decreased.
* `NO CHANGE` — overall delta is zero.
* `AUDIT ONLY` — no eval present; only token + quality numbers shown.

End with a one-line "Next" suggestion:

* If `IMPROVED`: "Commit and open a PR to verify in CI."
* If `MIXED` or `REGRESSED`: "Re-run `/skill-improve ${skill}` after
  reverting or refining the offending edits."
* If `NO CHANGE`: "Audits had no actionable findings. Consider
  expanding the eval suite."
* If `AUDIT ONLY`: "Add `.github/evals/${skill}/eval.yaml` to enable
  score-based feedback."

## Rules and Constraints

* **Always** pass `--no-cache` to `waza run` for both baseline and
  verify. Without it, an unchanged `eval.yaml` returns cached results
  and the delta is meaningless.
* **Never** auto-apply edits. The approval gate in step 4b is
  mandatory on every iteration.
* **Hard cap of 3 iterations.** `${input:iterations}` values above 3
  are clamped to 3. Each extra `waza dev --copilot` round consumes
  premium requests; an unbounded loop is a cost trap.
* **One baseline per invocation.** The baseline captured in step 2 is
  reused for the final compare in step 6. Do not re-baseline inside
  the iteration loop — that would mask cumulative regressions.
* **`waza dev` is the only audit re-run between iterations.** Tokens
  and quality are advisory inputs that rarely shift on small edits;
  re-running quality would also burn a premium request per round.
* **Refuse to label `IMPROVED`** if a negative-task score increased.
  Broadening a description to win positives at the cost of negatives
  is overfitting; surface it instead of hiding it.
* **Stay scoped to `SKILL.md`.** Do not edit `eval.yaml`, fixtures,
  tasks, or unrelated files. `waza dev` only mutates frontmatter; if
  a recommendation requires touching `eval.yaml`, fixtures, or tasks,
  surface it but do not apply it — those changes belong in a separate
  manual review.
* **No agent files.** waza only evaluates skills. If the user passes
  an `.agent.md` name, stop and point them at `/agent-improve`.

## Why every step

* **Step 2/5 with `--no-cache`** — the verify step needs a real
  execution; without `--no-cache` an unchanged spec returns the cached
  baseline and delta is always 0.
* **Step 3 in parallel** — the three audits are independent;
  `waza dev --copilot` can take 30–60 s while `waza tokens suggest` and
  `waza quality` finish faster, so backgrounding them costs nothing and
  gives the synthesis step a complete picture in one shot.
* **Step 4 loop with fresh `waza dev`** — `waza dev`'s recommendations
  shift between rounds: issues hidden behind round-1 problems only
  surface after the round-1 fix lands. Re-running it is the unique
  value of `iterations > 1`.
* **Step 4b numbered approval** — gives the user partial-acceptance
  control without re-prompting per item.
* **Step 7 verdict labels** — distinguishes the most common failure
  mode (overfitting positives at the cost of negatives) from a real
  improvement.
