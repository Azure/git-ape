---
title: "Authoring Overview"
sidebar_label: "Overview"
sidebar_position: 1
description: "Where skills, agents, prompts, and evals live in the repo and how Copilot discovers them."
---

# Authoring Overview

Git-Ape is a [GitHub Copilot agent plugin](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference). The plugin manifest at the repo root declares two directories that Copilot discovers automatically:

```json title="plugin.json"
{
  "name": "git-ape",
  "agents": ".github/agents/",
  "skills": ".github/skills/"
}
```

Everything else — prompts, eval suites, the CI matrix — supports the contents of those two directories.

## Vocabulary

| Term | File pattern | Discovered by | Purpose |
|------|--------------|---------------|---------|
| **Skill** | `.github/skills/<name>/SKILL.md` | Plugin manifest (`skills:`) | A focused, callable capability with a documented procedure. Invoked by agents or directly with `/<skill-name>`. |
| **Agent** | `.github/agents/<name>.agent.md` | Plugin manifest (`agents:`) | A persona with a `tools:` allowlist that orchestrates one or more skills to deliver a workflow. Invoked with `@<agent-name>` in Copilot Chat or `/<agent-name>` in the CLI. |
| **Prompt** | `.github/prompts/<name>.prompt.md` | VS Code Chat prompt picker | A scripted authoring workflow (onboard, benchmark, improve, promote) you run while writing skills and agents. Not shipped to end users. Invoked with `/<prompt-name>`. |
| **Eval suite** | `.github/evals/<name>/eval.yaml` and `.github/evals/agents/<name>/eval.yaml` | [microsoft/waza](https://github.com/microsoft/waza) | A spec + tasks that score a skill or agent across models. |

## Repo layout

```
.github/
├── agents/
│   ├── azure-policy-advisor.agent.md
│   ├── git-ape.agent.md
│   └── ...
├── skills/
│   ├── azure-cost-estimator/SKILL.md
│   ├── prereq-check/SKILL.md
│   └── ...
├── prompts/
│   ├── skill-onboard.prompt.md
│   ├── skill-bench.prompt.md
│   ├── skill-improve.prompt.md
│   ├── skill-promote.prompt.md
│   ├── agent-onboard.prompt.md
│   ├── agent-bench.prompt.md
│   ├── agent-improve.prompt.md
│   └── agent-promote.prompt.md
├── evals/
│   ├── manifest.yaml                       # CI matrix configuration
│   ├── <skill-name>/eval.yaml              # Skill evals
│   └── agents/<agent-name>/eval.yaml       # Agent evals
└── workflows/
    ├── waza-evals.yml                      # Per-PR skill evals
    └── waza-agent-evals.yml                # Per-PR agent evals

plugin.json                                 # Plugin manifest
.waza.yaml                                  # Project-level waza config
```

## When to add what

| You want to… | Add a… |
|--------------|--------|
| Wrap a single API or workflow step (cost lookup, policy query, naming rule check) | [Skill](./skills) |
| Coordinate several skills behind a persona (deployment, advisory, onboarding) | [Agent](./agents) |
| Score quality of a skill or agent across models | [Eval suite](./evals) |
| Scaffold, benchmark, or harden the skill or agent you just wrote | Reuse an existing [prompt](./prompts) — onboard → bench → improve → promote covers the loop. New prompts are rarely needed. |

## Naming and registration

* Skill directory names and agent file basenames use lowercase kebab-case. The skill's `SKILL.md` frontmatter `name:` field must match the directory name; the agent's `.agent.md` frontmatter `name:` is a display name and is separate from the file basename.
* Adding a new file under `.github/skills/<name>/` or `.github/agents/<name>.agent.md` is all you need to register it — there is no separate index to update. The plugin manifest scans the directories on load.
* For a new skill to appear in CI evals, append a `{ name, tier }` entry to `.github/evals/manifest.yaml` and create `.github/evals/<name>/eval.yaml`. See [Eval suites](./evals).

## Read next

- [Authoring skills](./skills) — frontmatter, structure, and minimum bar
- [Authoring agents](./agents) — persona-lock, `tools:` taxonomy, sub-agent wiring
- [Eval suites](./evals) — what graders score, how tasks are structured
- [Prompts](./prompts) — onboard, bench, improve, and promote your skill or agent from creation
