#!/usr/bin/env pwsh
# prereq-check: detect installed CLI tool versions for Git-Ape skills.
# Read-only. Emits one TSV row per tool: <name>\t<status>\t<version>\t<minimum>
# where <status> is one of: OK | OUTDATED | MISSING.
# Mirrors scripts/check-tools.sh — keep the TSV contract in sync.

$ErrorActionPreference = 'Continue'

$min = @{
    az  = '2.50'
    gh  = '2.0'
    jq  = '1.6'
    git = '0'
}

function Test-VersionAtLeast {
    param([string]$Found, [string]$Minimum)
    if ($Minimum -eq '0') { return $true }
    try {
        $f = ($Found -replace '[^0-9.].*$', '')
        $m = ($Minimum -replace '[^0-9.].*$', '')
        if ($f -notmatch '\.') { $f = "$f.0" }
        if ($m -notmatch '\.') { $m = "$m.0" }
        return [version]$f -ge [version]$m
    } catch {
        return $false
    }
}

function Write-Row {
    param([string]$Tool, [string]$Status, [string]$Found)
    "{0}`t{1}`t{2}`t{3}" -f $Tool, $Status, $Found, $min[$Tool]
}

function Test-Tool {
    param([string]$Tool, [scriptblock]$Extract)
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        Write-Row $Tool 'MISSING' '-'
        return
    }
    $found = ''
    try { $found = (& $Extract) } catch { $found = '' }
    if (-not $found) { $found = 'unknown' }
    if ($min[$Tool] -ne '0' -and -not (Test-VersionAtLeast $found $min[$Tool])) {
        Write-Row $Tool 'OUTDATED' $found
    } else {
        Write-Row $Tool 'OK' $found
    }
}

$os = if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'Darwin' } elseif ($IsLinux) { 'Linux' } else { 'Windows' }
$arch = if ($env:PROCESSOR_ARCHITECTURE) {
    $env:PROCESSOR_ARCHITECTURE
} else {
    try { (uname -m 2>$null) } catch { '?' }
}
"Platform: $os / $arch"

Test-Tool 'az' {
    # Avoid `--query '"azure-cli"'` — PowerShell's native-command parser strips
    # the inner double-quotes, leaving JMESPath with an unquoted hyphenated
    # identifier (`azure-cli`) that fails to parse. Parse JSON instead.
    $v = az version -o json 2>$null | ConvertFrom-Json
    if ($v) { $v.'azure-cli' } else { '' }
}
Test-Tool 'gh' {
    $line = (gh --version 2>$null | Select-Object -First 1)
    if ($line -match '\d+\.\d+\.\d+') { $matches[0] } else { '' }
}
Test-Tool 'jq' {
    $v = (jq --version 2>$null)
    if ($v -match '\d+\.\d+[a-z]*') { $matches[0] } else { '' }
}
Test-Tool 'git' {
    $v = (git --version 2>$null)
    if ($v -match '\d+\.\d+\.\d+') { $matches[0] } else { '' }
}
