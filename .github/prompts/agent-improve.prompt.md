---
agent: 'agent'
description: 'Local feedback loop for a single custom agent: baseline → audit → propose edits → apply (with approval) → re-rank via waza compare. Optionally loops up to 3 rounds for deeper refinement.'
argument-hint: '[agentName=...] [iterations={1|2|3}] [rescoreQuality={true|false}]'
---

# Agent Improve

Run a local improvement loop against a single custom agent
(`.github/agents/<name>.agent.md`) in this repository. Captures a
baseline eval score, audits the agent file with `waza tokens suggest` +
`waza quality` (via the SKILL.md staging trick), proposes concrete
edits, applies the ones the user approves, re-runs the eval, and shows
the delta.

This is the agent-side counterpart of `/skill-improve`. It targets the
`.agent.md` file and uses the waza ≥ 0.31 custom-agent eval feature
([PR #226](https://github.com/microsoft/waza/pull/226)) — the
auto-injected `tool_constraint` grader is what gives the loop its
teeth.

By default this is a **single pass** (one round of audit → propose →
apply → verify). Pass `iterations=2` or `iterations=3` for a deeper
refinement loop with a fresh approval gate per round — useful when
driving an `.agent.md` toward a specific behavior shape methodically.
Values above `3` are clamped to bound premium-request cost.

This prompt is **interactive**. The protocol always pauses before
editing.


## Inputs

* `${input:agentName}`: (Required) Bare agent name (e.g.
  `azure-policy-advisor`), matching the basename of
  `.github/agents/<name>.agent.md`. If omitted, infer from the user's
  message; otherwise ask once.
* `${input:iterations:1}`: (Optional, defaults to `1`) Number of
  audit-propose-apply rounds to run inside this invocation. Hard-capped
  at `3`. The audit signals are reused across rounds (re-running them
  costs premium requests); only the LLM's edit proposal refreshes per
  iteration as it re-reads the now-edited agent file.
* `${input:rescoreQuality:false}`: (Optional, defaults to `false`)
  When `true`, re-run `waza quality` after edits (or after the final
  iteration when `iterations > 1`) and include the per-dimension
  before/after delta in the summary. Costs one extra premium Copilot
  request. Off by default to keep the loop cheap; turn on when
  trigger-precision or another quality dimension is the lever you're
  trying to move.
## Required Protocol

Execute the steps below in order. Do not parallelize across steps.

Use the workspace root as cwd for every shell command. Use `set -uo
pipefail` (not `-e`) so a non-zero `waza run` exit (eval below
threshold) does not abort the loop.

### Step 1 — Resolve and verify

1. Set `agent="${input:agentName}"`.
2. Set `maxIter = min(3, ${input:iterations:1})`.
3. Verify `.github/agents/${agent}.agent.md` exists. If not, stop and
   report the missing path.
4. Check whether `.github/evals/agents/${agent}/eval.yaml` exists.
   * **If yes**, proceed to step 2.
   * **If no**, this is an audit-only loop: warn the user, skip steps
     2, 6b, 7, 8, and jump from step 6 to step 9. Also offer (in the
     same turn, as a one-line aside) to scaffold an eval dir on the
     next invocation using `.github/evals/agents/azure-policy-advisor/`
     as the template.
5. Print a one-line preamble:
   `Improving <agent> (eval: present|absent, iterations: <maxIter>)`.

### Step 2 — Sync agent file into eval dir (skip in audit-only mode)

The eval dir holds a **copy** of the production agent file so waza's
discovery picks it up via `config.skill_directories: ["."]`. Refresh
the copy before every run so the eval reflects on-disk truth:

```bash
cp ".github/agents/${agent}.agent.md" \
   ".github/evals/agents/${agent}/${agent}.agent.md"
```

If `${agent}.agent.md` already exists in the eval dir and differs
from the production file, the `cp` overwrites it. That is the
intended behavior — the production file is the single source of
truth.

### Step 3 — Baseline eval (skip in audit-only mode)

Run **once**, with cache disabled so a later re-run produces a real
delta even when nothing else changes:

```bash
mkdir -p /tmp/waza-runs
waza run ".github/evals/agents/${agent}/eval.yaml" \
  --no-cache \
  --output "/tmp/waza-runs/${agent}-baseline.json"
```

Capture the printed score line for the summary. Also note which
graders fired — in particular whether `agent_tools_implicit` appears
(auto-injection working) or is missing (`config.skill_directories`
not set, or `tool_constraint` already declared in eval.yaml).

### Step 4 — Audits (run in parallel, once)

Run both audits to seed iteration 1. `waza quality` is normally
SKILL.md-specific, but works on `.agent.md` after staging the file as
`waza-agent-stage/<agent>/SKILL.md` (a NON-DOT path — dotted paths
are silently skipped by waza's workspace walker). The stage dir is
ephemeral and cleaned up after the audit.

`waza dev` is excluded — it expects skill-spec frontmatter
(`name`/`description`/`when-to-use`) that `.agent.md` does not have,
so its recommendations would be nonsense.

```bash
mkdir -p "waza-agent-stage/${agent}"
cp ".github/agents/${agent}.agent.md" \
   "waza-agent-stage/${agent}/SKILL.md"

waza tokens suggest ".github/agents/${agent}.agent.md" --format text \
  > "/tmp/waza-runs/${agent}-tokens.txt" 2>&1 &

waza quality "waza-agent-stage/${agent}/SKILL.md" \
  --model claude-sonnet-4.6 --format table \
  | sed "s|waza-agent-stage/${agent}/SKILL.md|${agent}.agent.md|g" \
  > "/tmp/waza-runs/${agent}-quality.txt" 2>&1 &

wait
rm -rf "waza-agent-stage/${agent}"
```

If either exits non-zero, keep going but flag the failure in the
summary. They are advisory inputs, not gates.

### Step 5 — Iteration loop

Repeat the read → propose → approve → apply cycle up to `maxIter`
times. Track iteration index `i` starting at `1`. Maintain a running
log `applied[i] = [list of indices]` for the final summary.

The audit signals from step 4 are reused across all iterations. Each
round, re-read the (now-edited) agent file so the LLM proposes fresh
edits against current state.

#### Step 5a — Read iteration context

Read into context (do not echo back to the user verbatim — they will
see the synthesis in step 5b):

* `.github/agents/${agent}.agent.md` (current on-disk version)
* `.github/evals/agents/${agent}/eval.yaml` (if present)
* All task files matching
  `.github/evals/agents/${agent}/tasks/*.yaml` (if present)
* `/tmp/waza-runs/${agent}-baseline.json` (if present)
* `/tmp/waza-runs/${agent}-tokens.txt`
* `/tmp/waza-runs/${agent}-quality.txt`

#### Step 5b — Propose edits

First, print an **actionability surface** preamble in one block,
derived from the `mutable-by-*` tag on each task in
`.github/evals/agents/${agent}/tasks/*.yaml`:

```text
Actionability surface (from task `mutable-by-*` tags):
  mutable-by-agent       : <count>  ← edits to .agent.md can move these
  mutable-by-skill       : <count>  ← only SKILL.md edits move these (out of scope here)
  mutable-by-eval-grader : <count>  ← locked; only task YAML edits move these
  (no mutable-by-* tag)  : <count>  ← unknown; treat as mutable-by-agent until tagged
```

The ceiling for this loop is `(mutable-by-agent + unknown) / total`.
If that ceiling is <50%, warn the user explicitly: "Most tasks are
locked or skill-driven; expect a small delta."

Then produce a numbered list of **3 to 7** concrete, actionable edits to
`.github/agents/${agent}.agent.md`. Each item has:

* **Index** — sequential within this iteration, starts at 1.
* **Lever** — one of:
  * `clarity` — the role, workflow, or output format is ambiguous
  * `trigger-precision` — the description/name fires on the wrong
    prompts, or misses prompts it should fire on
  * `scope-boundary` — the agent overreaches or underreaches its
    stated scope
  * `tool-list` — the `tools:` frontmatter is missing a tool the
    workflow needs, or lists a tool the workflow never uses (this
    feeds straight into the auto-injected `tool_constraint` grader)
  * `token-saving` — the agent file has redundant or verbose blocks
  * `anti-pattern` — disclaimers, prohibitions, or fluff that the
    model ignores
* **Rationale** — one or two sentences citing the input that
  surfaced the suggestion (e.g. "tokens suggest flagged a 220-token
  example block", "quality scored trigger-precision 2/5", "baseline
  `agent_tools_implicit` reported `read` not used across both tasks",
  "negative task `off-topic` matched positive-task regex").
* **Proposed change** — the exact text to add, modify, or delete.

Do not invent edits beyond what the audits + your reading of the
agent file, eval.yaml, and tasks justify. Prefer fewer high-confidence
edits over a long list of speculative ones.

After the list, ask the user a single question. The options vary by
iteration:

* **If `maxIter == 1` or this is the final iteration:**
  > Reply with the indices to apply (e.g. `1, 3, 5`), `all`, `skip`,
  > or `add: <freeform edit you want included>`.
* **If more iterations remain (`i < maxIter`):**
  > Reply with the indices to apply (e.g. `1, 3, 5`), `all`, `skip`,
  > `add: <freeform edit you want included>`, or `stop` to end the
  > loop now.

`add:` is a first-class option — use it when you've spotted a needed
edit the auditor missed (e.g. a production-UI regression, a phrase the
grader requires that's about to be removed). The freeform text is
treated as a new proposed edit; it goes through the same apply step.
You may combine `add:` with indices, e.g.
`1, 3, add: restore one-at-a-time vscode_askQuestions in First-turn`.
#### Step 5c — Apply approved edits

On user response:

* `stop` — record `applied[${i}] = []` with reason `user stopped`,
  exit the loop, jump to step 6.
* `skip` — record `applied[${i}] = []`, continue to iteration `i + 1`
  (or exit if `i == maxIter`).
* `all`, a list of indices, and/or `add: <text>` — apply the
  corresponding edits to `.github/agents/${agent}.agent.md` exclusively
  (never the eval-dir copy, eval.yaml, tasks, or fixtures). For each
  `add:` entry, treat the freeform text as an additional edit
  description and apply it the same way. Use `edit` tool calls; never
  shell `sed`/`awk`. Record applied indices plus any `add:` entries
  (label them `add-<n>` in the iteration log).

After applying, run **Step 5d** (grader-literal lint) before
incrementing the iteration counter.

#### Step 5d — Grader-literal lint (post-edit, pre-rerun)

This catches the most common regression: an edit removes a literal
string that a per-task `answer_quality` or `clean_refusal` grader
requires the agent's response to contain. Without this check, the
regression is only visible after a full eval re-run.

1. For each task in `.github/evals/agents/${agent}/tasks/*.yaml`,
   read the `graders[].config.prompt` field of every `type: prompt`
   grader.
2. Extract the **literal strings** the grader requires the agent to
   contain. Heuristic:
   * Strings in the grader prompt that appear inside double quotes,
     single quotes, or backticks AND are referenced by PASS criteria
     using verbs like "names", "mentions", "identifies", "includes",
     "contains", or "says".
   * Filter out judge tooling literals: `set_waza_grade_pass`,
     `set_waza_grade_fail`, `continue_session`, and the literal
     strings `PASS`/`FAIL` themselves.
3. For each extracted literal, grep the **post-edit**
   `.github/agents/${agent}.agent.md` (case-insensitive, fixed-string).
4. Compare against the **pre-edit** version (use `git show
   HEAD:.github/agents/${agent}.agent.md` if uncommitted, otherwise
   the prior iteration's snapshot).
5. Print one of these outcomes:
   * ✅ `lint clean` — no required literals removed.
   * ⚠️ `lint warning` — list each removed literal with the task that
     requires it and the criterion number. Then ask:
     > These edits removed strings the grader requires. Re-add them
     > to the agent file, revert the offending edit, or proceed
     > anyway? (`re-add` / `revert` / `proceed`).
     * `re-add` — insert each missing literal back into the closest
       semantically appropriate section (use `edit` calls) and re-run
       the lint.
     * `revert` — undo the offending edit(s) only, keep other applied
       edits, re-run the lint.
     * `proceed` — continue with the regression. Record in the
       summary as `⚠️ known regression: <literal> removed`.

This step uses no premium requests. It runs in pure local context.

After the lint, increment `i`. If `i > maxIter`, exit the loop with
stop reason `max iterations`.

### Step 6 — Re-sync and verify (skip in audit-only mode, skip if no edits applied)

Refresh the eval-dir copy, then re-run:

```bash
cp ".github/agents/${agent}.agent.md" \
   ".github/evals/agents/${agent}/${agent}.agent.md"

waza run ".github/evals/agents/${agent}/eval.yaml" \
  --no-cache \
  --output "/tmp/waza-runs/${agent}-after.json"
```

### Step 7 — Compare (skip in audit-only mode, skip if no edits applied)

```bash
waza compare \
  "/tmp/waza-runs/${agent}-baseline.json" \
  "/tmp/waza-runs/${agent}-after.json" \
  --format table
```

### Step 7b — Re-score quality (only when `rescoreQuality=true`)

Run a fresh quality judge against the edited `.agent.md` and capture
the table for the summary. Stage again with the same trick:

```bash
mkdir -p "waza-agent-stage/${agent}"
cp ".github/agents/${agent}.agent.md" \
   "waza-agent-stage/${agent}/SKILL.md"

waza quality "waza-agent-stage/${agent}/SKILL.md" \
  --model claude-sonnet-4.6 --format table \
  | sed "s|waza-agent-stage/${agent}/SKILL.md|${agent}.agent.md|g" \
  > "/tmp/waza-runs/${agent}-quality-after.txt" 2>&1

rm -rf "waza-agent-stage/${agent}"
```

Parse both `/tmp/waza-runs/${agent}-quality.txt` (baseline, captured
in step 4) and `/tmp/waza-runs/${agent}-quality-after.txt`. Skip this
step silently when `rescoreQuality` is `false`.

### Step 8 — Summary

Print a Markdown summary table with:

| Metric | Before | After | Δ | Locked? |
|---|---|---|---|---|
| Overall score | … | … | … | — |
| Per-task: <name> | … | … | … | yes/no |
| `agent_tools_implicit` fired | yes/no | yes/no | — | — |
| Agent file tokens | … | … | … | — |
| Quality (clarity / completeness / trigger-precision / scope / anti-patterns) | … | … | — | — |

The **Locked?** column populates from the task's `mutable-by-*` tag:
`yes` when the tag is `mutable-by-skill` or `mutable-by-eval-grader`
(the agent file cannot move this score); `no` when the tag is
`mutable-by-agent` or absent. The Overall, tool-fired, tokens, and
Quality rows show `—` (not applicable).

If the lint step (5d) recorded any `known regression`, append a
⚠️ line below the table summarizing them (one bullet per literal,
with the task name).

The Quality row populates with real before/after numbers **only when
`rescoreQuality=true`**. Otherwise show the baseline column from step
4 and write `not re-scored (pass rescoreQuality=true to enable)` in
the After column.

If `maxIter > 1`, also print a per-iteration breakdown:

* **Iterations run** — `<actual>` of `<maxIter>`.
* **Stop reason** — one of: `max iterations` | `user stopped` |
  `eval missing — only ran audits` | `no edits applied`.
* **Per-iteration applied items** — bullet list grouped by iteration
  index, citing each applied edit's lever.

Then a "Verdict" paragraph using one of these labels:

* `IMPROVED` — overall score increased AND no negative-task score
  increased AND no positive-task score decreased AND no locked-task
  (`mutable-by-skill` / `mutable-by-eval-grader`) score increased.
  A locked-task score moving on agent-file edits alone is suspicious
  — either the tag is wrong or the test is noisy. Demote to `MIXED`
  and call it out.
* `MIXED` — overall score increased BUT at least one of: negative-task
  score went up, positive-task score went down, a locked-task score
  moved, or the lint step (5d) recorded a `known regression`.
* `REGRESSED` — overall score decreased.
* `NO CHANGE` — overall delta is zero.
* `AUDIT ONLY` — no eval present; only token + quality numbers shown.

End with a one-line "Next" suggestion:

* If `IMPROVED`: "Commit `.github/agents/${agent}.agent.md` and the
  refreshed eval-dir copy, then open a PR."
* If `MIXED` or `REGRESSED`: "Re-run `/agent-improve ${agent}` after
  reverting or refining the offending edits."
* If `NO CHANGE`: "Audits had no actionable findings. Expand the
  task suite under `.github/evals/agents/${agent}/tasks/` to surface
  weaker behaviors."
* If `AUDIT ONLY`: "Add `.github/evals/agents/${agent}/eval.yaml`
  with `config.skill_directories: ['.']` to enable score-based
  feedback. See `.github/evals/agents/azure-policy-advisor/` for a
  reference layout."

## Rules and Constraints

* **Always** pass `--no-cache` to `waza run` for both baseline and
  verify. Without it, unchanged eval inputs return cached results
  and the delta is meaningless.
* **Never** auto-apply edits. The approval gate in step 5b is
  mandatory — every iteration of the loop pauses for explicit user
  input.
* **`iterations` is hard-capped at 3.** Higher values are silently
  clamped down. This bounds premium-request cost (each round adds an
  LLM proposal turn; with `rescoreQuality=true` it also adds one
  premium request for the final quality re-score).
* **Refuse to label `IMPROVED`** if a negative-task score increased
  OR a locked-task score (`mutable-by-skill` /
  `mutable-by-eval-grader`) moved. Broadening the agent's description
  to win positives at the cost of negatives is overfitting; an
  agent-file edit moving a skill-graded score means the tag is wrong
  or the run is noisy. Surface both instead of hiding them.
* **Stay scoped to `.github/agents/${agent}.agent.md`.** Do not edit
  `eval.yaml`, fixtures, tasks, or `.github/agents/` siblings. Eval
  changes belong in a separate manual review.
* **Sync rule.** The eval-dir `.agent.md` is a derived copy; always
  refresh it from the production file before running the eval. Never
  hand-edit the eval-dir copy.
* **`skill_directories` is required.** The auto-injected
  `tool_constraint` grader only fires when the eval's `config:` block
  includes `skill_directories: ["."]`. If `agent_tools_implicit` is
  missing from the baseline run, flag this as a setup bug and stop
  before proposing edits.
* **`executor: copilot-sdk` everywhere.** This repo standardizes on
  the real Copilot SDK executor for both agent and skill evals. Each
  run consumes a few premium requests and ~100k model tokens —
  budget accordingly.
* **Never rewrite an agent's `tools:` field to satisfy the eval.**
  The `tools:` frontmatter is the **production-surface contract**
  — it lists VS Code Chat tool IDs (e.g. `execute`, `read`, `search`,
  `vscode`, `todo`) and MCP namespaces (e.g. `azure-mcp/cloudarchitect`,
  `microsoftdocs/mcp/*`) that the agent uses when run inside VS Code.
  Waza's `executor: copilot-sdk` emits a **different taxonomy** at
  runtime: SDK CLI short names like `bash`, `view`, `edit`, `create`,
  `sql`, `task`. Auto-injection naively zips the two together and
  always fails. The fix lives **on the eval**, not the agent: declare
  an explicit `tool_constraint` grader in the agent eval that lists
  the SDK CLI names. This opts out of auto-injection ([waza#226](https://github.com/microsoft/waza/pull/226))
  and gives the grader something it can match. If the implicit
  grader is producing nonsense, that's a grader-config bug, not an
  agent bug.

## Why every step

* **Step 2 sync** — eval-dir holds a copy (not a symlink) so the
  eval is reproducible across platforms and git tracks the exact bytes
  evaluated. The sync step keeps the copy honest.
* **Step 3/6 with `--no-cache`** — the verify step needs a real
  execution; without `--no-cache` an unchanged spec returns the
  cached baseline and the delta is always 0.
* **Step 4 staging trick** — `waza quality` requires a SKILL.md
  filename, and waza's workspace walker silently skips dotted paths
  (the same `.NET FileAttributes.Hidden` quirk that bites the MSDO
  template-analyzer). Staging `.agent.md` as
  `waza-agent-stage/<agent>/SKILL.md` (NON-DOT path) is the smallest
  workaround that lets us run the 5-dim LLM judge on an agent file.
  `sed` strips the prefix from the output so the user sees the real
  agent path. `waza dev` is excluded because the recommendation
  engine assumes skill-spec frontmatter (`name`, `description`,
  `when-to-use`) that `.agent.md` does not have.
* **Step 5 iteration loop** — audits in step 4 cost premium requests,
  so we run them once and reuse the signal. The LLM re-reads the
  edited agent file each round and proposes fresh edits against
  current state, which is the cheap part. The per-iteration approval
  gate keeps a human in the loop between rounds.
* **Step 5b numbered approval** — partial-acceptance control without
  re-prompting per item. The `add:` option in step 5b is the
  user-supplied edit channel — production-UI fixes, grader-required
  phrases the auditor missed, or any edit the LLM didn't propose.
  Without it, the only way to inject such edits is to abort the loop
  and re-invoke, which replays baseline and audits at premium cost.
* **Step 5d static lint** — catches the most common regression class
  (an edit removes a literal string the grader requires) BEFORE the
  ~90s/premium-request eval re-run. The lint uses no premium
  requests; the eval re-run does. Mutability tags (`mutable-by-*` on
  task `tags:`) drive the actionability preamble in step 5b and the
  Locked column in step 8 — they prevent the loop from chasing scores
  that agent-file edits cannot move.
* **Step 8 verdict labels** — distinguishes the most common failure
  mode (overfitting positives at the cost of negatives) from a real
  improvement.
