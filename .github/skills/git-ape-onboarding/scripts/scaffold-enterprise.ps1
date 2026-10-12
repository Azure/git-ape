<#
.SYNOPSIS
    Scaffold the Git-Ape enterprise distribution files into a `.github-private`
    repository working copy.

.DESCRIPTION
    PowerShell parity for scaffold-enterprise.sh.

    - Copies each template to its destination ONLY if destination does not exist
    - Prints "✓ Created" for new files, "⊝ Skipped" for collisions
    - Final line summarizes counts; lists skipped files at the end so the user
      can reconcile them manually
    - NEVER runs git add / commit / push / PR — the resulting files are left
      unstaged in the working copy

    This scaffolds the ENTERPRISE distribution layer (the `.github-private`
    repo), not a deployment repo. For per-repository CI onboarding, use
    scaffold-repo.ps1.

.PARAMETER TargetRepoRoot
    The `.github-private` repository root to scaffold into.
    Default: `git rev-parse --show-toplevel`, or the current working directory
    if not inside a git repo. Run it from inside your cloned `.github-private`
    repo, or pass that repo's path explicitly.

.EXAMPLE
    pwsh .github/skills/git-ape-onboarding/scripts/scaffold-enterprise.ps1

.EXAMPLE
    pwsh .github/skills/git-ape-onboarding/scripts/scaffold-enterprise.ps1 C:\path\to\.github-private
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetRepoRoot
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$skillDir = Split-Path -Parent $scriptDir
$templatesDir = Join-Path $skillDir 'templates'

if (-not $TargetRepoRoot) {
    $TargetRepoRoot = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $TargetRepoRoot) {
        $TargetRepoRoot = (Get-Location).Path
    }
}

if (-not (Test-Path -LiteralPath $templatesDir -PathType Container)) {
    [Console]::Error.WriteLine("ERROR: templates directory not found at $templatesDir")
    exit 1
}

if (-not (Test-Path -LiteralPath $TargetRepoRoot -PathType Container)) {
    [Console]::Error.WriteLine("ERROR: target repo root not found: $TargetRepoRoot")
    exit 1
}

# src (relative to templates dir) : dst (relative to target_repo_root)
$mappings = @(
    @{ Src = 'github-private/README.md';                                Dst = 'README.md' }
    @{ Src = 'github-private/.github/copilot/managed-settings.json';    Dst = '.github/copilot/managed-settings.json' }
    @{ Src = 'github-private/agents/.gitkeep';                          Dst = 'agents/.gitkeep' }
)

Write-Host "Scaffolding Git-Ape enterprise files into: $TargetRepoRoot" -ForegroundColor White
Write-Host ""

$created = 0
$skipped = 0
$skippedPaths = New-Object System.Collections.Generic.List[string]

foreach ($m in $mappings) {
    $srcPath = Join-Path $templatesDir $m.Src
    $dstPath = Join-Path $TargetRepoRoot $m.Dst

    if (-not (Test-Path -LiteralPath $srcPath -PathType Leaf)) {
        [Console]::Error.WriteLine("ERROR: template missing: $srcPath")
        exit 1
    }

    if (Test-Path -LiteralPath $dstPath) {
        Write-Host "  ⊝ Skipped  $($m.Dst) (already exists)" -ForegroundColor Yellow
        $skipped++
        $skippedPaths.Add($m.Dst) | Out-Null
    } else {
        $dstDir = Split-Path -Parent $dstPath
        if (-not (Test-Path -LiteralPath $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $srcPath -Destination $dstPath -Force
        Write-Host "  ✓ Created  $($m.Dst)" -ForegroundColor Green
        $created++
    }
}

Write-Host ""
Write-Host "Created $created file(s), skipped $skipped file(s)." -ForegroundColor White

if ($skipped -gt 0) {
    Write-Host ""
    Write-Host "Skipped files were left unchanged. Diff against the canonical templates with:"
    foreach ($path in $skippedPaths) {
        switch -Regex ($path) {
            '^README\.md$' {
                $srcRel = 'github-private/README.md'
            }
            '^\.github/copilot/managed-settings\.json$' {
                $srcRel = 'github-private/.github/copilot/managed-settings.json'
            }
            '^agents/\.gitkeep$' {
                $srcRel = 'github-private/agents/.gitkeep'
            }
            default {
                $srcRel = "github-private/$path"
            }
        }
        Write-Host "  diff -u $path $templatesDir/$srcRel"
    }
}

Write-Host ""
Write-Host "Files were left UNSTAGED. Review them, then commit and push to your .github-private repo."
Write-Host "Then finish setup in Enterprise → AI controls (designate the org + create the ruleset)."
