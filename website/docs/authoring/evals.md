---
title: "Eval Suites"
sidebar_label: "Eval suites"
sidebar_position: 5
description: "How to scaffold an eval suite for a skill or agent, what each grader scores, and how CI picks it up."
---

# Eval Suites

Eval suites score skills and agents across multiple models so quality changes are caught at PR time, not after release. Git-Ape uses [microsoft/waza](https://github.com/microsoft/waza) as the eval runner; suites live under [`.github/evals/`](https://github.com/Azure/git-ape/tree/main/.github/evals).

```
.github/evals/
├── manifest.yaml                       # CI matrix (tiers + models)
├── <skill-name>/eval.yaml              # Skill evals
└── agents/<agent-name>/eval.yaml       # Agent evals
```

## Skill eval scaffold

Every skill eval needs an `eval.yaml` and at least two tasks (one positive, one negative):

```
.github/evals/my-skill/
├── eval.yaml
└── tasks/
    ├── positive-001-typical-use.yaml
    └── negative-001-off-topic.yaml
```

### `eval.yaml`

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/microsoft/waza/main/schemas/eval.schema.json

name: my-skill-eval
description: "What this suite scores."
skill: my-skill
version: "0.1"

config:
  trials_per_task: 2          # 2 = expanded-tier default (flake detection); bump to 3 for pilot/promotion
  timeout_seconds: 60
  parallel: false
  executor: copilot-sdk
  model: claude-sonnet-4.6    # Default — CI overrides via --model per matrix leg

metrics:
  - name: trigger_precision
    weight: 1.0
    threshold: 0.6
    description: Skill should activate on relevant prompts and stay quiet otherwise.

graders:
  # Cap runaway loops / unexpected plan expansion.
  - type: behavior
    name: budget
    config:
      max_tool_calls: 30
      max_duration_ms: 240000

tasks:
  - "tasks/*.yaml"
```

### Task file

```yaml
# tasks/positive-001-typical-use.yaml
name: positive-001-typical-use
description: "User asks for the canonical thing this skill does"
prompt: |
  <Verbatim user prompt that should trigger the skill>

expect:
  trigger: skill:my-skill
  behavior:
    - "describes what the skill should do procedurally"
    - "second behavioral assertion"
  prompt:
    must_include:
      - "literal substring that MUST appear in the reply"
```

Negative tasks omit the skill-specific `expect.trigger` and assert the agent should **not** invoke the skill:

```yaml
# tasks/negative-001-off-topic.yaml
name: negative-001-off-topic
description: "Unrelated request — skill should NOT fire"
prompt: |
  Help me write a sonnet about ducks.

expect:
  trigger: !skill:my-skill   # ! = negation
```

## Agent eval scaffold

Agent evals live under `.github/evals/agents/<agent-name>/`. They use the same waza schema with two extra pieces:

1. A **mirrored copy** of the agent file as a sibling, so waza's discovery picks it up.
2. `config.skill_directories` listing both the eval directory (for the agent mirror) and the real skill directory.

```
.github/evals/agents/my-agent/
├── eval.yaml
├── my-agent.agent.md       # Mirror of .github/agents/my-agent.agent.md
└── tasks/
    ├── positive-001-happy-path.yaml
    └── negative-001-off-topic.yaml
```

```yaml
name: my-agent-agent-eval
description: "End-to-end eval for the my-agent agent."
skill: my-agent
version: "0.1"

config:
  trials_per_task: 2
  timeout_seconds: 480
  parallel: false
  executor: copilot-sdk
  model: claude-sonnet-4.6
  skill_directories:
    - "."                                       # picks up the .agent.md mirror
    - "../../../skills/my-skill-the-agent-uses" # picks up the real skill
```

The eval-directory copy of `*.agent.md` must be kept in sync with the production agent. The [`/agent-improve`](./prompts#agent-improve) and [`/agent-bench`](./prompts#agent-bench) prompts do this resync automatically (`cp .github/agents/<name>.agent.md .github/evals/agents/<name>/`). Add a CI lint or pre-commit hook if you want hard enforcement.

## Graders

| Grader | Scores | When to include |
|--------|--------|-----------------|
| `trigger` (implicit via `metrics.trigger_precision`) | Did the agent route to the right skill on positives, and stay quiet on negatives? | Always |
| `behavior` | Tool-call budget, duration, or step-order assertions | Always (at minimum a `budget` config) |
| `prompt` (LLM-as-judge) | Did the reply text meet a documented quality bar? Scored by `claude-sonnet-4.6`. | Always for positive tasks |
| `skill_invocation` | Did the agent invoke the specific tool calls the skill expects? | Skills that wrap MCP tools or specific CLIs |
| `tool_constraint` | Did the agent stay within the declared tool allowlist? | Agent evals (waza auto-injects this from `.agent.md` `tools:` unless suppressed) |

### Per-task vs eval-root graders

Some graders should not fire on every task. For example, `prompt` quality scoring on a refusal task produces low scores because the agent (correctly) gave a short refusal — there's nothing to evaluate against a quality rubric.

Pattern: declare per-task graders inside each `tasks/*.yaml`, and only include eval-root graders that genuinely apply to every task (typically `budget`).

## Dual tool taxonomy

The production `tools:` field on an `.agent.md` uses **VS Code Copilot Chat IDs** (`read`, `search`, `execute/*`, `microsoftdocs/mcp/*`, `azure-mcp/*`). The waza `copilot-sdk` executor emits **SDK CLI short names** (`bash`, `view`, `edit`, `create`, `sql`, `task`).

If you write per-task `tool_constraint` graders, target the SDK taxonomy. To stop waza from auto-injecting an eval-root `tool_constraint` that would fail against VS Code IDs the SDK never emits, declare a no-op suppressor:

```yaml
graders:
  - type: tool_constraint
    name: _suppress_auto_inject
    config:
      reject_tools:
        - tool: "^___never_matches___$"
```

Real assertions then live per-task:

```yaml
# tasks/positive-001.yaml
expect_tools:
  - tool: "^(bash|view|edit|create|sql|task)$"
```

## How CI picks up your eval

The matrix is driven by [`.github/evals/manifest.yaml`](https://github.com/Azure/git-ape/blob/main/.github/evals/manifest.yaml):

```yaml
skills:
  - name: prereq-check
    tier: pilot
  # Add your skill here:
  - name: my-skill
    tier: expanded   # Start in expanded; promote to pilot via /skill-promote

tiers:
  pilot:                                # Full 4-model fan-out
    models:
      - name: claude-sonnet-4.6
      - name: gpt-5.4
        baseline: true
      - name: gpt-5-codex
      - name: claude-opus-4.6
  expanded:                             # 2-model fan-out (lower cost)
    models:
      - name: claude-sonnet-4.6
      - name: gpt-5-codex
```

| Tier | Models | Use when |
|------|--------|----------|
| `pilot` | 4 (claude-sonnet-4.6, gpt-5.4 baseline, gpt-5-codex, claude-opus-4.6) | Skill is stable; you want full cross-model signal |
| `expanded` | 2 (claude-sonnet-4.6, gpt-5-codex) | Skill is new; cap quota cost while it stabilises |

The PR workflows that consume the manifest:

- [`.github/workflows/waza-evals.yml`](https://github.com/Azure/git-ape/blob/main/.github/workflows/waza-evals.yml) — runs skill evals per PR
- [`.github/workflows/waza-agent-evals.yml`](https://github.com/Azure/git-ape/blob/main/.github/workflows/waza-agent-evals.yml) — runs agent evals per PR

Agent evals are discovered from the filesystem (every directory under `.github/evals/agents/` with an `eval.yaml` runs); they do not need a manifest entry.

> **Preflight gating:** both workflows include a `preflight` job that probes the `COPILOT_GITHUB_TOKEN` secret. If the token is missing or lacks access to the private `microsoft/waza` repo (where waza releases live), downstream jobs are skipped cleanly instead of failing red. Maintainers can validate the secret end-to-end by checking that the matrix actually runs on the next PR.

## Local validation

```bash
# Single run, single model
waza run .github/evals/my-skill/eval.yaml --no-cache

# Verbose with debug
waza run .github/evals/my-skill/eval.yaml -v --debug

# Cross-model bench (uses the bench prompt)
# In VS Code: /skill-bench skillName=my-skill
```

The [`/skill-bench`](./prompts#skill-bench) and [`/agent-bench`](./prompts#agent-bench) prompts wrap the cross-model run + `waza compare` for you and print a one-line winner summary.

## Read next

- [Prompts](./prompts) — onboard / bench / improve / promote loops
- [Authoring skills](./skills) — what an evaluable skill looks like
- [Authoring agents](./agents) — agent surface specifics
