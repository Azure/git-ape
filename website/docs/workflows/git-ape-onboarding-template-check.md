---
title: "Git-Ape: Onboarding Template Check"
sidebar_label: "Onboarding Template Check"
description: "GitHub Actions workflow: Git-Ape: Onboarding Template Check"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-onboarding-template-check.yml -->


# Git-Ape: Onboarding Template Check

**Workflow file:** `.github/workflows/git-ape-onboarding-template-check.yml`

## Triggers

- **`pull_request`** — paths: `.github/skills/git-ape-onboarding/templates/**, .github/skills/git-ape-onboarding/scripts/sync-templates.sh, .github/skills/git-ape-onboarding/scripts/sync-templates.ps1...`
- **`workflow_dispatch`**


## Permissions

- `contents: read`

## Jobs

### `check-sync-bash`

| Property | Value |
|----------|-------|
| **Display Name** | Verify onboarding templates ↔ mirrors are in sync (bash) |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 2 |

### `check-sync-pwsh`

| Property | Value |
|----------|-------|
| **Display Name** | Verify onboarding templates ↔ mirrors are in sync (pwsh on Windows) |
| **Runs On** | `windows-latest` |
| **Steps** | 2 |

### `scaffold-parity-smoke`

| Property | Value |
|----------|-------|
| **Display Name** | Scaffold parity smoke (bash sandbox vs pwsh sandbox produces identical files) |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 2 |

### `scaffold-enterprise-parity-smoke`

| Property | Value |
|----------|-------|
| **Display Name** | Enterprise scaffold parity smoke (.github-private bash vs pwsh produces identical files) |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 2 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
name: "Git-Ape: Onboarding Template Check"

# Fails any PR that edits either the canonical onboarding templates or the
# .github/copilot-instructions.md mirror without keeping the two in sync.
#
# Note: The workflow templates under templates/workflows/ are NOT mirrored
# into this repository's .github/workflows/. They are scaffolded only into a
# USER's repository by scaffold-repo.{sh,ps1} during onboarding, so there is
# nothing to sync-check for them here. The scaffold-parity-smoke job still
# validates that the bash and pwsh scaffolders produce byte-identical output.
#
# Fix sync drift with:
#   .github/skills/git-ape-onboarding/scripts/sync-templates.sh apply
#   pwsh .github/skills/git-ape-onboarding/scripts/sync-templates.ps1 apply
# and commit the updated mirror alongside the template change.
#
# Three jobs run on every matching PR:
#   1. check-sync-bash  — Ubuntu, runs the .sh sync check.
#   2. check-sync-pwsh  — Windows, runs the .ps1 sync check.
#   3. scaffold-parity-smoke — Ubuntu, scaffolds via both runtimes into
#      separate sandboxes and fails on any byte-level divergence.
#   4. scaffold-enterprise-parity-smoke — Ubuntu, same byte-parity check for
#      the enterprise (.github-private) scaffolders.

on:
  pull_request:
    paths:
      - '.github/skills/git-ape-onboarding/templates/**'
      - '.github/skills/git-ape-onboarding/scripts/sync-templates.sh'
      - '.github/skills/git-ape-onboarding/scripts/sync-templates.ps1'
      - '.github/skills/git-ape-onboarding/scripts/scaffold-repo.sh'
      - '.github/skills/git-ape-onboarding/scripts/scaffold-repo.ps1'
      - '.github/skills/git-ape-onboarding/scripts/scaffold-enterprise.sh'
      - '.github/skills/git-ape-onboarding/scripts/scaffold-enterprise.ps1'
      - '.github/copilot-instructions.md'
      - '.github/workflows/git-ape-onboarding-template-check.yml'
  workflow_dispatch:

permissions:
  contents: read

jobs:
  check-sync-bash:
    name: Verify onboarding templates ↔ mirrors are in sync (bash)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Run sync check
        run: |
          chmod +x .github/skills/git-ape-onboarding/scripts/sync-templates.sh
          .github/skills/git-ape-onboarding/scripts/sync-templates.sh check

  check-sync-pwsh:
    name: Verify onboarding templates ↔ mirrors are in sync (pwsh on Windows)
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v6

      - name: Run sync check
        shell: pwsh
        run: |
          pwsh -NoProfile -File .github/skills/git-ape-onboarding/scripts/sync-templates.ps1 check

  scaffold-parity-smoke:
    name: Scaffold parity smoke (bash sandbox vs pwsh sandbox produces identical files)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Scaffold via bash and pwsh into separate sandboxes, then diff
        run: |
          set -euo pipefail
          SANDBOX_SH="$(mktemp -d)"
          SANDBOX_PS="$(mktemp -d)"
          chmod +x .github/skills/git-ape-onboarding/scripts/scaffold-repo.sh
          bash .github/skills/git-ape-onboarding/scripts/scaffold-repo.sh "$SANDBOX_SH" > /dev/null
          pwsh -NoProfile -File .github/skills/git-ape-onboarding/scripts/scaffold-repo.ps1 "$SANDBOX_PS" > /dev/null
          # Recursive diff: fails the job if the two scaffolds differ by a single byte.
          diff -r "$SANDBOX_SH" "$SANDBOX_PS"
          echo "scaffold-repo.sh and scaffold-repo.ps1 produce byte-identical output."

  scaffold-enterprise-parity-smoke:
    name: Enterprise scaffold parity smoke (.github-private bash vs pwsh produces identical files)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Scaffold via bash and pwsh into separate sandboxes, then diff
        run: |
          set -euo pipefail
          SANDBOX_SH="$(mktemp -d)"
          SANDBOX_PS="$(mktemp -d)"
          chmod +x .github/skills/git-ape-onboarding/scripts/scaffold-enterprise.sh
          bash .github/skills/git-ape-onboarding/scripts/scaffold-enterprise.sh "$SANDBOX_SH" > /dev/null
          pwsh -NoProfile -File .github/skills/git-ape-onboarding/scripts/scaffold-enterprise.ps1 "$SANDBOX_PS" > /dev/null
          # Recursive diff: fails the job if the two scaffolds differ by a single byte.
          diff -r "$SANDBOX_SH" "$SANDBOX_PS"
          # The distributed managed-settings.json must always be valid JSON.
          if command -v jq > /dev/null 2>&1; then
            jq empty "$SANDBOX_SH/.github/copilot/managed-settings.json"
          fi
          echo "scaffold-enterprise.sh and scaffold-enterprise.ps1 produce byte-identical output."

```

</details>
