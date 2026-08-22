<#
.SYNOPSIS
    Sync mirror between canonical onboarding templates and the repository's
    active .github/copilot-instructions.md.

.DESCRIPTION
    Canonical source:
      .github/skills/git-ape-onboarding/templates/

    Mirror destinations:
      .github/copilot-instructions.md

    Note: The workflow templates under templates/workflows/ are NOT mirrored
    into this repository's .github/workflows/. They are scaffolded only into
    a USER's repository by scaffold-repo.{sh,ps1} during onboarding.

    PowerShell parity for sync-templates.sh. The two scripts MUST produce
    identical results on the same tree — CI runs the .ps1 on windows-latest
    and the .sh on ubuntu-latest in the same workflow.

.PARAMETER Action
    check  Exit 1 on drift (CI gate).
    apply  Overwrite each mirror with its canonical template.
    diff   Show per-file diffs. Exits 0 regardless.

.EXAMPLE
    pwsh .github/skills/git-ape-onboarding/scripts/sync-templates.ps1 check
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('check', 'apply', 'diff')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

# Locate the repo root via git, fall back to current directory.
$repoRoot = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    $repoRoot = (Get-Location).Path
}
$templatesDir = Join-Path $repoRoot '.github/skills/git-ape-onboarding/templates'

# template-relative-path -> repo-relative-destination
$mappings = @(
    @{ Src = 'copilot-instructions.md';           Dst = '.github/copilot-instructions.md' }
)

function Test-FileByteEquality {
    param([string]$Left, [string]$Right)
    if (-not (Test-Path -LiteralPath $Left -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $Right -PathType Leaf)) { return $false }
    $a = [System.IO.File]::ReadAllBytes($Left)
    $b = [System.IO.File]::ReadAllBytes($Right)
    if ($a.Length -ne $b.Length) { return $false }
    for ($i = 0; $i -lt $a.Length; $i++) {
        if ($a[$i] -ne $b[$i]) { return $false }
    }
    return $true
}

function Write-Status {
    param([string]$Icon, [string]$Color, [string]$Message, [switch]$Err)
    # Error lines go to stderr only (no double-print to stdout).
    # Color stays on the success path; stderr is plain to keep CI logs readable.
    if ($Err) {
        [Console]::Error.WriteLine("$Icon $Message")
    } else {
        Write-Host "$Icon $Message" -ForegroundColor $Color
    }
}

$drift = 0
$applied = 0
$checked = 0

foreach ($m in $mappings) {
    $src = Join-Path $templatesDir $m.Src
    $dst = Join-Path $repoRoot   $m.Dst
    $checked++

    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        [Console]::Error.WriteLine("ERROR missing canonical template: $($m.Src)")
        exit 2
    }

    switch ($Action) {
        'apply' {
            if ((Test-Path -LiteralPath $dst -PathType Leaf) -and (Test-FileByteEquality -Left $src -Right $dst)) {
                Write-Host "= $($m.Dst) (already in sync)" -ForegroundColor Yellow
            } else {
                $dstDir = Split-Path -Parent $dst
                if (-not (Test-Path -LiteralPath $dstDir)) {
                    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
                }
                Copy-Item -LiteralPath $src -Destination $dst -Force
                Write-Host "✓ $($m.Dst) (updated from template)" -ForegroundColor Green
                $applied++
            }
        }
        'check' {
            if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) {
                Write-Status -Icon '✗' -Color Red -Message "$($m.Dst) (mirror missing)" -Err
                $drift++
            } elseif (-not (Test-FileByteEquality -Left $src -Right $dst)) {
                Write-Status -Icon '✗' -Color Red -Message "$($m.Dst) (drift from template)" -Err
                $drift++
            } else {
                Write-Host "✓ $($m.Dst)" -ForegroundColor Green
            }
        }
        'diff' {
            if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) {
                Write-Host "✗ $($m.Dst) (missing)" -ForegroundColor Red
                $drift++
            } elseif (-not (Test-FileByteEquality -Left $src -Right $dst)) {
                Write-Host "--- diff: .github/skills/git-ape-onboarding/templates/$($m.Src) vs $($m.Dst)" -ForegroundColor Cyan
                # Use git diff for parity with the .sh output style; fall back to Compare-Object.
                & git --no-pager diff --no-index -- $src $dst 2>$null
                $drift++
            }
        }
    }
}

switch ($Action) {
    'apply' {
        if ($applied -eq 0) {
            Write-Host ""
            Write-Host "All $checked mirror(s) already in sync." -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "Updated $applied mirror file(s). Commit them with the template changes." -ForegroundColor Green
        }
    }
    'check' {
        if ($drift -gt 0) {
            [Console]::Error.WriteLine("")
            [Console]::Error.WriteLine("$drift file(s) out of sync. Run:")
            [Console]::Error.WriteLine("  pwsh .github/skills/git-ape-onboarding/scripts/sync-templates.ps1 apply")
            [Console]::Error.WriteLine("(or the .sh equivalent on macOS/Linux) and commit the updated mirror(s).")
            exit 1
        }
        Write-Host ""
        Write-Host "All $checked mirror(s) match the canonical templates." -ForegroundColor Green
    }
    'diff' {
        if ($drift -eq 0) {
            Write-Host ""
            Write-Host "No divergence detected." -ForegroundColor Green
        }
    }
}
