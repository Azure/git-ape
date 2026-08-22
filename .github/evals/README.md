# Git-Ape eval harness

Behavioral evals for the skills under `.github/skills/` and the agents
under `.github/agents/`. Investigated as part of [#61][issue-61].

## Decision: waza

We evaluated three options before landing the harness:

| Option | Verdict | Why |
|---|---|---|
| [`openai/evals`][openai-evals] | Rejected | Python-only ecosystem, Completion-Function-Protocol coupling to OpenAI models, and a registry shape that doesn't match how this repo loads skills/agents (filesystem-discovered Markdown with YAML frontmatter). |
| Custom Node harness (per [PR #40][pr-40] spike) | Rejected | Would have to reinvent grader composition, multi-model fan-out, CI fixture management, and PR-comment rendering. Net new surface area to maintain. |
| **[`waza`][waza]** | **Selected** | Already speaks the "skill / agent / task" vocabulary this repo uses, ships native cross-model `waza compare`, has a token/quality auditor, and integrates with both VS Code Copilot and GitHub Actions. Matches the maintainer workflow we want (`/skill-onboard` → `/skill-bench` → `/skill-improve` → `/skill-promote`). |

## Layout

```
.github/evals/
├── manifest.yaml                       # Skill tier configuration (skills only)
├── <skill-name>/
│   ├── eval.yaml                       # Skill eval definition
│   └── tasks/*.yaml                    # Per-task graders
└── agents/<agent-name>/
    ├── eval.yaml                       # Agent eval definition
    ├── <agent-name>.agent.md           # Mirror of the canonical .agent.md
    └── tasks/*.yaml                    # Per-task graders
```

Skills are discovered via [`manifest.yaml`](./manifest.yaml). Agents are
auto-discovered from the filesystem (no manifest entry needed).

## How to add a new eval suite

Run one of the slash commands from VS Code (Copilot Chat). They scaffold
the directory, patch it to repo conventions, and run a smoke trial:

- **Skills** — `/skill-onboard skillName=<name>`
- **Agents** — `/agent-onboard agentName=<name>`

Full lifecycle (onboard → bench → improve → promote) is documented in
the [authoring docs][authoring-evals].

## CI wiring

- Skills — [`.github/workflows/waza-evals.yml`](../workflows/waza-evals.yml)
- Agents — [`.github/workflows/waza-agent-evals.yml`](../workflows/waza-agent-evals.yml)

Both run on PRs touching the relevant artifacts, post results as a PR
comment, and are currently **non-blocking**.

[issue-61]: https://github.com/Azure/git-ape/issues/61
[pr-40]: https://github.com/Azure/git-ape/pull/40
[openai-evals]: https://github.com/openai/evals
[waza]: https://github.com/microsoft/waza
[authoring-evals]: https://azure.github.io/git-ape/docs/authoring/evals
