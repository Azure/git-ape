---
description: |
  This workflow creates daily repo status reports. It gathers recent repository
  activity (issues, PRs, discussions, releases, code changes) and generates
  engaging GitHub issues with productivity insights, community highlights,
  and project recommendations.

on:
  # 08:00 SGT (UTC+8) every day = 00:00 UTC
  schedule:
    - cron: "0 0 * * *"
  workflow_dispatch:

permissions:
  contents: read
  issues: read
  pull-requests: read
  copilot-requests: write

network: defaults

tools:
  cli-proxy: true
  github:
    allowed-repos: [azure/git-ape]
    min-integrity: approved

safe-outputs:
  mentions: false
  allowed-github-references: []
  create-issue:
    title-prefix: "[repo-status] "
    labels: [report, daily-status]
    close-older-issues: true
source: githubnext/agentics/workflows/daily-repo-status.md@fc4ab36dedc44e2a1cdc195cecce262f06c81230
---

# Daily Repo Status

Create an upbeat daily status report for the repo as a GitHub issue.

## What to include

- Recent repository activity (issues, PRs, discussions, releases, code changes)
- Progress tracking, goal reminders and highlights
- Project status and recommendations
- Actionable next steps for maintainers

## Style

- Be positive, encouraging, and helpful 🌟
- Use emojis moderately for engagement
- Keep it concise - adjust length based on actual activity

## Process

1. Gather recent activity from the repository
2. Study the repository, its issues and its pull requests
3. Create a new GitHub issue with your findings and insights

## Required completion behavior

- Do not delegate the report or safe-output call to a subagent.
- Always call `create_issue` exactly once with the completed report before finishing.
- Use the configured GitHub tools for reads; do not use the unauthenticated `gh` CLI.
- If direct safe-output tools are not listed, use the configured `safeoutputs` CLI.
