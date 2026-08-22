---
title: "Authoring Agents"
sidebar_label: "Agents"
sidebar_position: 4
description: "How to add a new agent: persona, tools allowlist, sub-agent wiring, and the dual tool taxonomy."
---

# Authoring Agents

An **agent** is a persona with a `tools:` allowlist that orchestrates one or more skills to deliver a complete workflow. Agents are single `.agent.md` files under [`.github/agents/`](https://github.com/Azure/git-ape/tree/main/.github/agents).

Where a [skill](./skills) is a runbook, an agent is the character that executes it — it owns scope, refusals, tool selection, and inter-skill orchestration.

## Quick start

```bash
AGENT=my-new-agent
$EDITOR .github/agents/"$AGENT".agent.md
```

No further registration is needed — `plugin.json` declares `"agents": ".github/agents/"` and Copilot auto-discovers every `*.agent.md` file in that directory.

> **Optimize your agent from the start.** Don't ship an `.agent.md` blind — use the prompts listed in [Prompts](./prompts) to evaluate and harden it as you write:
>
> - [`/agent-onboard`](./prompts#agent-onboard) — scaffolds `.github/evals/agents/<agent>/` with positive tasks, negative tasks, and an off-topic persona-lock check, then runs a smoke trial so you can watch your tool allowlist, refusals, and orchestration in action.
> - [`/agent-bench`](./prompts#agent-bench) — benchmarks the agent across models so you know which ones honor the persona.
> - [`/agent-improve`](./prompts#agent-improve) — diagnoses failing tasks (leaked persona, wrong tool, missed skill) and proposes targeted edits to your `.agent.md`.
> - [`/agent-promote`](./prompts#agent-promote) — locks the agent in once it's stable.
>
> Run `/agent-onboard` as soon as your first draft is readable. Agent evals are auto-discovered from the filesystem; no manifest edit is required.

## File template

```markdown
---
name: "My New Agent"
description: "One sentence summarising the agent's job and when to invoke it."
tools: ["read", "search", "execute/runInTerminal", "execute/awaitTerminal"]
user-invocable: true
argument-hint: "Optional free-text hint shown in the invocation picker"
---

## Warning

This agent is experimental and not production-ready.

You are **My New Agent**, responsible for <one-sentence mission>.

**Always identify yourself as "My New Agent" in your responses.** Never describe
yourself as a generic "software engineering assistant", "GitHub Copilot CLI", or
any other persona — this agent has a single, narrow purpose and your identity is
part of its contract.

## Non-goals

This agent does **not**:

- Deploy Azure resources — that is `/git-ape`'s job.
- Onboard repositories — that is `/git-ape-onboarding`'s job.
- Answer questions unrelated to <agent's domain>.

If a request is unrelated to <domain>, identify yourself as **My New Agent**,
decline in one sentence, and redirect the user to the appropriate agent.

## Your Role

Describe what this agent does in two or three sentences.

## Use Skill

Always use the `/<skill-name>` skill for procedure and output format.

## Workflow

1. Ask the user what they want to do.
2. Read any configuration or context files needed (e.g. `copilot-instructions.md`).
3. Execute the `/<skill-name>` skill procedure end-to-end.
4. Present the result.

## Output Requirements

- Concrete bullet about format (tables, JSON, fenced code blocks)
- Concrete bullet about anything that MUST appear in the response

## Key Principle

One paragraph stating the non-negotiable rule the agent enforces.
```

## Frontmatter reference

| Field | Required | Purpose |
|-------|:--------:|---------|
| `name` | ✅ | Display name shown in invocation menus. Use Title Case (`"Azure Policy Advisor"`). |
| `description` | ✅ | One sentence used by routers and surfaced in tooling. |
| `tools` | ✅ | Allowlist of tool IDs the agent can call. See [Dual tool taxonomy](#dual-tool-taxonomy) below. |
| `user-invocable` | ⚪ | Defaults to `true`. Set `false` for sub-agents (e.g. `azure-template-generator`) that only run as a step inside another agent's workflow. |
| `argument-hint` | ⚪ | Free-text hint. |
| `agents` | ⚪ | List of sub-agent file basenames this agent delegates to. Sub-agents must also exist under `.github/agents/`. |

## Persona-lock (non-negotiable)

Without a persona-lock paragraph, models default to a generic "GitHub Copilot CLI assistant" persona on off-topic prompts. Every agent in this repo includes:

```markdown
**Always identify yourself as "<Agent Name>" in your responses.** Never describe
yourself as a generic "software engineering assistant", "GitHub Copilot CLI", or
any other persona — this agent has a single, narrow purpose and your identity is
part of its contract.
```

Plus a `## Non-goals` section listing out-of-scope domains and the agent each should be redirected to.

Persona-lock is enforced by the agent's eval `tasks/off-topic.yaml` task — a negative test that confirms the agent declines unrelated requests in its own voice. Treat persona-lock as best-effort: the model's built-in CLI refusal sometimes fires before the agent rewrite, so do not rely on it being respected 100% of the time. The eval grader accepts both clean-refusal markers and agent-name mentions to avoid false negatives.

## Wiring sub-agents

If your agent calls other agents, declare them in frontmatter:

```yaml
agents:
  - azure-requirements-gatherer
  - azure-template-generator
  - azure-resource-deployer
```

Each sub-agent should set `user-invocable: false` so it only runs through the parent. See [`git-ape.agent.md`](https://github.com/Azure/git-ape/blob/main/.github/agents/git-ape.agent.md) for a multi-stage deployment pipeline that chains six sub-agents.

## Dual tool taxonomy

The `tools:` field lists **VS Code Copilot Chat** tool IDs — the surface where the agent runs in production. Common values:

| Tool ID | What it grants |
|---------|----------------|
| `read` | File reads in the workspace |
| `search` | Workspace search (grep/semantic) |
| `execute/runInTerminal` | Run a terminal command |
| `execute/awaitTerminal` | Wait for an async terminal command |
| `execute/getTerminalOutput` | Read terminal output |
| `execute/createAndRunTask` | Create and run a VS Code task |
| `microsoftdocs/mcp/*` | Microsoft Learn MCP server |
| `azure-mcp/<service>` | Azure MCP server scoped to a service (`cosmos`, `keyvault`, etc.) |
| `todo` | The todo list tool |
| `vscode` | VS Code commands |

**Important:** the [eval harness](./evals) runs agents under the `copilot-sdk` executor, which emits a **different taxonomy** (SDK CLI short names: `bash`, `view`, `edit`, `create`, `sql`, `task`). Per-task `tool_constraint` graders in eval suites must target SDK names. Do **not** rewrite the production `tools:` field to satisfy a grader — fix the grader instead. See [Eval suites → Dual tool taxonomy](./evals#dual-tool-taxonomy) for the bridging pattern.

## Always delegate to a skill

If procedural detail (steps, output format, classification tables) belongs anywhere in the agent file, move it into a skill and have the agent reference it:

```markdown
## Use Skill

Always use the `/azure-policy-advisor` skill for procedure, classification tiers, and output format.
```

This keeps agents thin (persona + orchestration) and skills reusable (procedure). When the procedure changes, only the skill is edited; the agent picks up the new behaviour automatically.

## Local validation

```bash
# Lint the agent file (waza accepts .agent.md, but flags spec gaps)
waza check .github/agents/my-new-agent.agent.md

# If you wrote an eval suite:
waza run .github/evals/agents/my-new-agent/eval.yaml -v
```

> `waza check` is built around the SKILL.md spec, so `.agent.md` files will surface frontmatter warnings even when well-formed. The signal that matters is the eval pass rate, not `waza check` clean exit.

## Common pitfalls

- **Missing persona-lock** — agent leaks "I'm a GitHub Copilot CLI assistant" on off-topic prompts. Add the standard paragraph above.
- **`tools:` field rewritten for the eval executor** — breaks the production agent. Keep `tools:` in VS Code Chat taxonomy and write per-task `tool_constraint` graders in SDK taxonomy.
- **Agent embeds procedure** — move it into a skill, keep the agent thin.
- **No `## Non-goals`** — without explicit redirects, off-topic refusals are generic and fail the off-topic eval task.

## Read next

- [Eval suites](./evals) — score the agent across models
- [Prompts](./prompts#agent-improve) — local audit + edit loop
- [Authoring skills](./skills) — the runbooks agents delegate to
