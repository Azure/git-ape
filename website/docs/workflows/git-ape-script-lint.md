---
title: "Git-Ape: Script Lint"
sidebar_label: "Script Lint"
description: "GitHub Actions workflow: Git-Ape: Script Lint"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-script-lint.yml -->


# Git-Ape: Script Lint

**Workflow file:** `.github/workflows/git-ape-script-lint.yml`

## Triggers

- **`pull_request`** — paths: `.github/skills/**/*.sh, .github/skills/**/*.ps1, .github/linters/PSScriptAnalyzerSettings.psd1...`
- **`workflow_dispatch`**


## Permissions

- `contents: read`

## Jobs

### `shell-lint`

| Property | Value |
|----------|-------|
| **Display Name** | Shell scripts (shellcheck + bash -n) |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 3 |

### `pwsh-lint`

| Property | Value |
|----------|-------|
| **Display Name** | PowerShell scripts (PSScriptAnalyzer + parser) |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 3 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
name: "Git-Ape: Script Lint"

# Static analysis + parse gate for the shell and PowerShell scripts embedded in
# Git-Ape skills (.github/skills/**). This is the L0+L1 layer of the script
# testing strategy:
#   L0 - lint:  shellcheck (.sh) and PSScriptAnalyzer (.ps1)
#   L1 - parse: bash -n (.sh) and the PowerShell language parser (.ps1)
#
# Both jobs are static — they need neither Azure credentials nor a live
# subscription, so they run on every matching PR in seconds.
#
# Severity policy:
#   * shellcheck gates at --severity=warning (errors + warnings block;
#     info/style findings are surfaced by the dedicated audit step but do
#     not fail the build).
#   * PSScriptAnalyzer gates on Error + Warning via
#     .github/linters/PSScriptAnalyzerSettings.psd1 (which documents the two
#     intentionally-excluded rules).

on:
  pull_request:
    paths:
      - '.github/skills/**/*.sh'
      - '.github/skills/**/*.ps1'
      - '.github/linters/PSScriptAnalyzerSettings.psd1'
      - '.github/workflows/git-ape-script-lint.yml'
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shell-lint:
    name: Shell scripts (shellcheck + bash -n)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Ensure shellcheck is available
        run: |
          set -euo pipefail
          if ! command -v shellcheck >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y shellcheck
          fi
          shellcheck --version

      - name: Lint and parse-check shell scripts
        run: |
          set -euo pipefail
          mapfile -t FILES < <(find .github/skills -type f -name '*.sh' | sort)
          if [ "${#FILES[@]}" -eq 0 ]; then
            echo "No skill shell scripts found."
            exit 0
          fi
          echo "Found ${#FILES[@]} shell script(s):"
          printf '  %s\n' "${FILES[@]}"

          echo "::group::Syntax check (bash -n)"
          syntax_rc=0
          for f in "${FILES[@]}"; do
            if bash -n "$f"; then
              echo "ok   $f"
            else
              echo "FAIL $f"
              syntax_rc=1
            fi
          done
          echo "::endgroup::"
          if [ "$syntax_rc" -ne 0 ]; then
            echo "::error::One or more shell scripts failed 'bash -n' syntax check."
            exit 1
          fi

          echo "::group::ShellCheck (severity=warning, gating)"
          shellcheck --severity=warning --color=always "${FILES[@]}"
          echo "All scripts passed shellcheck at severity=warning."
          echo "::endgroup::"

          echo "::group::ShellCheck info/style audit (non-gating)"
          shellcheck --severity=style --color=always "${FILES[@]}" || true
          echo "::endgroup::"

  pwsh-lint:
    name: PowerShell scripts (PSScriptAnalyzer + parser)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Install PSScriptAnalyzer
        shell: pwsh
        run: |
          $ErrorActionPreference = 'Stop'
          if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
          }
          $v = (Get-Module -ListAvailable -Name PSScriptAnalyzer | Select-Object -First 1).Version
          Write-Host "PSScriptAnalyzer $v"

      - name: Lint and parse-check PowerShell scripts
        shell: pwsh
        run: |
          $ErrorActionPreference = 'Stop'
          $files = Get-ChildItem -Recurse -Path .github/skills -Filter *.ps1 | Sort-Object FullName
          if (-not $files) {
            Write-Host 'No skill PowerShell scripts found.'
            exit 0
          }
          Write-Host ("Found {0} PowerShell script(s):" -f @($files).Count)
          $files | ForEach-Object { Write-Host "  $($_.FullName)" }

          # --- L1: parser gate ---
          Write-Host '::group::Parser gate'
          $parseFail = 0
          foreach ($f in $files) {
            $errs = $null
            [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs) | Out-Null
            if ($errs -and $errs.Count -gt 0) {
              $parseFail = 1
              Write-Host "::error file=$($f.FullName)::$($errs.Count) parse error(s)"
              $errs | ForEach-Object { Write-Host "    $($_.Message)" }
            } else {
              Write-Host "ok   $($f.FullName)"
            }
          }
          Write-Host '::endgroup::'
          if ($parseFail -ne 0) {
            Write-Host '::error::One or more PowerShell scripts failed to parse.'
            exit 1
          }

          # --- L0: PSScriptAnalyzer gate ---
          Write-Host '::group::PSScriptAnalyzer (Error + Warning, gating)'
          $settings = '.github/linters/PSScriptAnalyzerSettings.psd1'
          $results = $files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings $settings }
          if ($results) {
            $results |
              Sort-Object Severity, ScriptName, Line |
              Format-Table Severity, RuleName, @{ n = 'File'; e = { Split-Path $_.ScriptName -Leaf } }, Line, Message -AutoSize -Wrap |
              Out-String -Width 200 |
              Write-Host
            Write-Host "::error::PSScriptAnalyzer reported $(@($results).Count) finding(s) at Error/Warning severity."
            exit 1
          }
          Write-Host 'All scripts passed PSScriptAnalyzer at Error/Warning severity.'
          Write-Host '::endgroup::'

```

</details>
