---
name: prereq-check
description: "Validate Git-Ape CLI tool installation (az, gh, jq, git), versions, and auth sessions. Shows platform-specific install commands for anything missing. USE FOR: check Git-Ape prerequisites, what do I need to install for Git-Ape, verify Git-Ape CLI tools, az: command not found, gh: command not found, jq: command not found, git: command not found, az missing, gh missing, jq missing, git missing, fresh machine setup for Git-Ape, dev container setup for Git-Ape, before running git-ape-onboarding, az login required, gh auth login, auth expired, not logged in, outdated az version, minimum az version, upgrade az. DO NOT USE FOR: Anything else. This skill is narrowly scoped to prerequisites checks for Git-Ape's CLI tools and auth sessions. Do not use it for any other purpose."
license: MIT
metadata:
  argument-hint: "Run without arguments to check all prerequisites"
  user-invocable: true
  author: Git-Ape
  version: "0.1.0"
---

# Prerequisites Check

Validate that the local environment has the CLI tools and auth sessions needed to run Git-Ape skills. Print platform-specific install commands and PATH-repair guidance for anything missing or version-stale.

## Quick Reference

| Property | Value |
|----------|-------|
| Best for | First-time setup, `command not found` triage, dev container validation |
| Required binaries | `az` ≥ 2.50, `gh` ≥ 2.0, `jq` ≥ 1.6, `git` (any) |
| Required auth | `az login`, `gh auth login` |
| Shell | bash on macOS/Linux, PowerShell 7+ on Windows |
| MCP tools | None — runs locally via shell |
| Related skills | `git-ape-onboarding` (next step), `azure-validate` (deployment-time checks) |
| Side effects | Read-only — never installs or modifies anything |

## When to Use

- Before first-time onboarding (`/git-ape-onboarding`)
- When any Git-Ape skill fails with `command not found`
- When the user reports a missing binary in their prompt (e.g., `az: command not found`)
- After switching machines, shells, or dev containers
- When the user asks "what do I need to install?"

## Rules

1. **Run read-only** — never `brew install`, `apt-get install`, or any state-changing command. Print the commands; the user runs them.
2. **Trust user reports** — if the user reports a tool missing, treat it as ⚠️ even when this terminal can find it (different shell, PATH, container, or machine).
3. **Stop at first blocking failure** — do not continue to auth checks while any tool is ❌.
4. **Do not chain into other skills** — never auto-invoke `git-ape-onboarding`; tell the user to run it after `READY`.

## Steps

| # | Action | Reference |
|---|--------|-----------|
| 1 | **Detect Platform** — `uname -s` / `uname -m` on bash, `$PSVersionTable.OS` on PowerShell → macOS / Linux (apt vs dnf) / Windows (PowerShell 7+) | inline |
| 2 | **Scan Prompt for Reported Missing Tools** — match `<tool>: command not found`, `command not found: <tool>`, `<tool> is not installed` | inline |
| 3 | **Run Tool Check** — macOS/Linux: `bash scripts/check-tools.sh` · Windows: `pwsh -File scripts/check-tools.ps1` | [scripts/check-tools.sh](scripts/check-tools.sh), [scripts/check-tools.ps1](scripts/check-tools.ps1) |
| 4 | **Present Status Table** — pass/fail with found vs. minimum version | See [Status Table](#status-table) |
| 5 | **Show Install / PATH Repair** — only for ❌ and ⚠️ entries, scoped to platform | [references/install-commands.md](references/install-commands.md) |
| 6 | **Check Auth Sessions** — only if Step 4 reports all tools ✅ | See [Auth Checks](#auth-checks) |
| 7 | **Emit Verdict** — exactly one of READY / TOOLS MISSING / REPORTED MISSING / AUTH MISSING | See [Outputs](#outputs) |

### Status Table

`scripts/check-tools.sh` emits TSV rows of `tool<TAB>status<TAB>found<TAB>minimum`. Render them as:

| Tool | Status | Found | Required |
|------|--------|-------|----------|
| az   | ✅ / ⚠️ / ❌ | x.y.z | 2.50 |
| gh   | ✅ / ⚠️ / ❌ | x.y.z | 2.0  |
| jq   | ✅ / ⚠️ / ❌ | x.y   | 1.6  |
| git  | ✅ / ❌      | x.y.z | any  |

Status mapping:

- `OK` → ✅
- `OUTDATED` or `MISSING` → ❌
- Reported missing in Step 2 but `OK` in this terminal → ⚠️ with note `reported missing by user`

### Auth Checks

macOS / Linux (bash):

```bash
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table 2>/dev/null \
  || echo "❌ Not logged in to Azure. Run: az login"

gh auth status 2>/dev/null \
  || echo "❌ Not logged in to GitHub. Run: gh auth login"
```

Windows (PowerShell 7+):

```powershell
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table 2>$null
if (-not $?) { Write-Output "❌ Not logged in to Azure. Run: az login" }

gh auth status 2>$null
if (-not $?) { Write-Output "❌ Not logged in to GitHub. Run: gh auth login" }
```

## Outputs

A single chat message containing:

1. **Status table** from Step 4.
2. **Install / PATH repair commands** for ❌ and ⚠️ entries — pulled from [references/install-commands.md](references/install-commands.md), scoped to the detected platform.
3. **Auth status** (Azure subscription + GitHub user) from Step 6, only when all tools ✅.
4. **Final verdict** — exactly one of:
   - `✅ READY` — all tools installed, versions OK, auth sessions active. Render the handoff chip from `## Next` so the user can click into onboarding.
   - `⚠️ TOOLS MISSING` — list what to install. Do not continue.
   - `⚠️ REPORTED MISSING` — this terminal finds the tool but the user reported it missing. Print install / PATH repair + verification block.
   - `⚠️ AUTH MISSING` — tools OK but `az login` and/or `gh auth login` required.

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `az --version` hangs | Stale telemetry / extension cache | `az config set core.collect_telemetry=false`; reinstall if persistent |
| `gh auth status` says "not logged into any hosts" | No GitHub session | `gh auth login --web` |
| `az account show` returns `Please run 'az login'` | Expired or missing session | `az login` (use `--use-device-code` in headless shells) |
| User reports missing tool but this terminal finds it | Different shell / PATH / container / machine | Treat as ⚠️ REPORTED MISSING — print install + PATH repair, do not contradict |
| `jq --version` starts with `1.5` | Below minimum (1.6) | Upgrade via platform package manager |
| `check-tools.sh: Permission denied` | Script not executable | `chmod +x .github/skills/prereq-check/scripts/check-tools.sh` |
| `check-tools.ps1 cannot be loaded because running scripts is disabled` | PowerShell execution policy | Run via `pwsh -File scripts/check-tools.ps1` (bypasses script-block policy), or `Set-ExecutionPolicy -Scope Process RemoteSigned` |
| `pwsh: command not found` on Windows | PowerShell 7+ not installed | `winget install Microsoft.PowerShell` — Windows PowerShell 5.1 also works but ship `pwsh` for parity |

## Constraints

**Always:**

- Print install commands; let the user run them
- Detect platform before printing recipes
- Honor user-reported missing tools even when this terminal finds them
- Stop at the first blocking failure
- Verify with `command -v <tool>` + `<tool> --version` after suggested fixes

**Never:**

- Run `brew install`, `apt-get install`, `winget install`, or any state-changing command
- Require git-bash on Windows — use the PowerShell script (`scripts/check-tools.ps1`) instead
- Auto-invoke `git-ape-onboarding` after a `READY` verdict
- Silently drop a reported-missing tool because this terminal finds it
- Continue to auth checks while any tool is ❌
- Recommend `sudo` on macOS (Homebrew handles non-root install)

## Next

After a `✅ READY` verdict, render this line verbatim so the chat surface turns it into a clickable handoff:

> Next: **@Git-Ape Onboarding** — or run `/git-ape-onboarding` to start setup.

VS Code Copilot Chat renders `@AgentName` mentions and `/skill-name` slash commands as clickable chips — the user clicks once to dispatch. Do not auto-invoke (Rule 4).

For deployment-time validation of an Azure project, use `azure-validate` instead.
