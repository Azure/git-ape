<#
.SYNOPSIS
    Destroy a Git-Ape deployment by deleting its Azure Deployment Stack.

.DESCRIPTION
    PowerShell port of destroy-stack.sh. Mirrors the logic of
    .github/workflows/git-ape-destroy.exampleyml so local destroys produce
    identical state.json transitions.

.PARAMETER DeploymentId
    Folder name under .azure/deployments/. Required.

.PARAMETER Yes
    Skip the typed 'destroy' confirmation prompt (CI-only).

.EXAMPLE
    ./destroy-stack.ps1 -DeploymentId deploy-20260506-001

.EXAMPLE
    ./destroy-stack.ps1 -DeploymentId deploy-20260506-001 -Yes

.NOTES
    Requires: PowerShell 7+, az CLI ≥ 2.59, jq, active az login session,
    existing state.json under .azure/deployments/<id>/.
#>
[CmdletBinding()]
param(
    [string]$DeploymentId,

    [switch]$Yes,

    [switch]$Wait,

    [int]$PollTimeout = 600,

    [int]$PollInterval = 10,

    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    @'
Azure Stack Destroy — destroy a Deployment Stack and purge soft-deletables

Usage: destroy-stack.ps1 -DeploymentId <id> [OPTIONS]

Required:
  -DeploymentId <id>      Folder name under .azure/deployments/

Options:
  -Yes                    Skip the typed 'destroy' confirmation prompt
  -Wait                   Sync mode (matches CI): block on 'az stack sub delete'
                          until Azure has cleaned up stack metadata. Slower but
                          fully deterministic. Default is fast mode (run the
                          same command in the background, then poll managed
                          resource groups until they are gone, ~2-3x faster).
  -PollTimeout <sec>      Fast-mode timeout per managed RG poll (default: 600)
  -Help                   Show this help

Examples:
  ./destroy-stack.ps1 -DeploymentId deploy-20260506-001            # fast (default)
  ./destroy-stack.ps1 -DeploymentId deploy-20260506-001 -Yes       # fast, no prompt
  ./destroy-stack.ps1 -DeploymentId deploy-20260506-001 -Wait      # CI-equivalent sync
'@ | Write-Host
}

if ($Help -or [string]::IsNullOrWhiteSpace($DeploymentId)) {
    Show-Usage
    exit 1
}

$ScriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceRoot   = (Resolve-Path (Join-Path $ScriptDir '../../../..')).Path
$DeploymentsDir  = '.azure/deployments'
$DeploymentPath  = Join-Path $WorkspaceRoot (Join-Path $DeploymentsDir $DeploymentId)
$StateFile       = Join-Path $DeploymentPath 'state.json'

function Write-Color {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
}

if (-not (Test-Path -PathType Container $DeploymentPath)) {
    Write-Color "Deployment not found: $DeploymentId" Red
    exit 1
}
if (-not (Test-Path $StateFile)) {
    Write-Color "state.json not found: $StateFile" Red
    Write-Host 'Cannot destroy without deployment state.'
    exit 1
}

$state           = Get-Content $StateFile -Raw | ConvertFrom-Json
$StackId         = if ($state.stackId)        { [string]$state.stackId }      else { '' }
$DeployMethod    = if ($state.deployMethod)   { [string]$state.deployMethod } else { 'subscription' }
$RgName          = if ($state.resourceGroup)  { [string]$state.resourceGroup } else { '' }
$ManagedRgs      = @($state.resourceGroups | Where-Object { $_ })
$ManagedResources = @($state.managedResources)
$SoftDeletable   = @($ManagedResources | Where-Object { $_.softDeletable -eq $true })

if ([string]::IsNullOrWhiteSpace($StackId) -and [string]::IsNullOrWhiteSpace($RgName)) {
    Write-Color 'No stackId or resourceGroup in state.json — cannot destroy.' Red
    exit 1
}

# Plan -----------------------------------------------------------------------

Write-Color '=== Destroy Plan ===' Yellow
Write-Host  "Deployment:   $DeploymentId"
Write-Host  "Method:       $DeployMethod"
if ($StackId) { Write-Host "Stack ID:     $StackId" }
if ($RgName)  { Write-Host "Resource RG:  $RgName" }

$SoftCount = $SoftDeletable.Count
if ($SoftCount -gt 0) {
    Write-Host "Soft-deletable: $SoftCount resource(s) — will purge non-protected after delete"
    foreach ($r in $SoftDeletable) {
        $suffix = if ($r.purgeProtected) { ' (purge-protected)' } else { '' }
        Write-Host ("  - {0}: {1}{2}" -f $r.type, $r.id, $suffix)
    }
}
Write-Color '====================' Yellow

if (-not $Yes) {
    $confirm = Read-Host "Proceed with destroy? Type 'destroy' to confirm"
    if ($confirm -ne 'destroy') {
        Write-Host 'Cancelled'
        exit 0
    }
}

# Execute --------------------------------------------------------------------

$StackDeleted = $false
$RgDeleted    = $false
$AlreadyGone  = $true
# Tracks whether a stack/RG delete command was actually invoked. Used to
# distinguish a partial failure (attempted but did not complete ->
# partially-destroyed) from the catch-all destroy-failed, mirroring CI.
$DeleteAttempted = $false
$StartTime    = Get-Date

if ($StackId) {
    $stackExists = az stack sub show --name $DeploymentId --query 'id' -o tsv 2>$null
    if ($stackExists) {
        $AlreadyGone = $false
        $DeleteAttempted = $true
        if ($Wait) {
            Write-Color "🗑️  Deleting deployment stack (sync wait): $DeploymentId" Blue
            # --bypass-stack-out-of-sync-error: a destroy run is one-shot; we
            # don't need the safety check that protects against stale manifests
            # during iterative updates.
            az stack sub delete `
                --name $DeploymentId `
                --action-on-unmanage deleteAll `
                --bypass-stack-out-of-sync-error true `
                --yes
            if ($LASTEXITCODE -eq 0) { $StackDeleted = $true }
            else { Write-Color '❌ Stack delete failed' Red }
        } elseif ($ManagedRgs.Count -eq 0) {
            Write-Color '⚠️  No resourceGroups[] in state.json — falling back to sync wait' Yellow
            az stack sub delete `
                --name $DeploymentId `
                --action-on-unmanage deleteAll `
                --bypass-stack-out-of-sync-error true `
                --yes
            if ($LASTEXITCODE -eq 0) { $StackDeleted = $true }
            else { Write-Color '❌ Stack delete failed' Red }
        } else {
            Write-Color "🗑️  Submitting stack delete (fast mode): $DeploymentId" Blue
            $stackLog = New-TemporaryFile
            $stackErr = New-TemporaryFile
            # Spawn the blocking stack delete in a detached process; we exit
            # as soon as the managed RGs are gone, leaving Azure to finish
            # stack-metadata cleanup asynchronously. Azure CLI does not expose
            # --no-wait on `az stack sub delete`, so backgrounding the call
            # is the only way to get fast interactive return.
            $bg = Start-Process -FilePath az `
                -ArgumentList @(
                    'stack', 'sub', 'delete',
                    '--name', $DeploymentId,
                    '--action-on-unmanage', 'deleteAll',
                    '--bypass-stack-out-of-sync-error', 'true',
                    '--yes'
                ) `
                -RedirectStandardOutput $stackLog.FullName `
                -RedirectStandardError  $stackErr.FullName `
                -PassThru -NoNewWindow

            Write-Color ("⏳ Polling {0} managed resource group(s) (timeout: {1}s)..." -f $ManagedRgs.Count, $PollTimeout) Blue
            $pollStart  = Get-Date
            $pollFailed = $false
            foreach ($rg in $ManagedRgs) {
                while ($true) {
                    $elapsed = [int]((Get-Date) - $pollStart).TotalSeconds
                    if ($elapsed -ge $PollTimeout) {
                        Write-Color ("  ⚠️  Timeout ({0}s) polling {1}" -f $elapsed, $rg) Red
                        $logBody = (Get-Content $stackLog.FullName -Raw -ErrorAction SilentlyContinue) +
                                   (Get-Content $stackErr.FullName -Raw -ErrorAction SilentlyContinue)
                        if ($logBody) {
                            Write-Color '  Background stack-delete output:' Yellow
                            $logBody.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
                        }
                        Write-Color '  Rerun with -Wait for synchronous diagnostics' Yellow
                        $pollFailed = $true
                        break
                    }
                    if ($bg.HasExited -and $bg.ExitCode -ne 0) {
                        $existsCheck = az group exists --name $rg 2>$null
                        if ($existsCheck -eq 'true') {
                            Write-Color ("  ❌ Background stack-delete exited (code {0}) before {1} was removed" -f $bg.ExitCode, $rg) Red
                            $logBody = (Get-Content $stackLog.FullName -Raw -ErrorAction SilentlyContinue) +
                                       (Get-Content $stackErr.FullName -Raw -ErrorAction SilentlyContinue)
                            if ($logBody) {
                                $logBody.TrimEnd() -split "`n" | ForEach-Object { Write-Host "    $_" }
                            }
                            $pollFailed = $true
                            break
                        }
                    }
                    $exists = az group exists --name $rg 2>$null
                    if ($exists -ne 'true') {
                        Write-Color ("  ✓ {0} gone ({1}s)" -f $rg, $elapsed) Green
                        break
                    }
                    Start-Sleep -Seconds $PollInterval
                }
                if ($pollFailed) { break }
            }
            Remove-Item $stackLog.FullName -Force -ErrorAction SilentlyContinue
            Remove-Item $stackErr.FullName -Force -ErrorAction SilentlyContinue
            if ($pollFailed) {
                $StackDeleted = $false
            } else {
                $StackDeleted = $true
                Write-Color 'ℹ️  Azure is finishing stack-metadata cleanup asynchronously' Blue
            }
        }
    } else {
        if ($RgName) {
            Write-Color 'Stack already gone — falling back to resource group delete from state.json' Yellow
            $StackId = $null
        } else {
            Write-Color 'Stack already gone — skipping stack delete' Yellow
            $StackDeleted = $true
        }
    }
}

if (-not $StackId -and $RgName) {
    $rgExists = az group exists --name $RgName 2>$null
    if ($rgExists -eq 'true') {
        $AlreadyGone = $false
        $DeleteAttempted = $true
        Write-Color "🗑️  Deleting resource group: $RgName" Blue
        az group delete --name $RgName --yes
        if ($LASTEXITCODE -eq 0) { $RgDeleted = $true }
        else { Write-Color '❌ Resource group delete failed' Red }
    } else {
        Write-Color 'Resource group already gone — skipping' Yellow
        $RgDeleted = $true
    }
}

# Soft-delete purge sweep
$PurgeResults  = @()
$RetainedCount = 0
if ($SoftCount -gt 0 -and ($StackDeleted -or $RgDeleted)) {
    Write-Color '🧹 Purging soft-deleted resources...' Blue
    foreach ($r in $SoftDeletable) {
        $resType = $r.type
        $resId   = $r.id
        $resName = ($resId -split '/')[-1]
        $protected = [bool]$r.purgeProtected

        switch ($resType) {
            'Microsoft.KeyVault/vaults' {
                $deletedVaultJson = az keyvault list-deleted --query "[?name=='$resName']" -o json 2>$null
                $deletedVault = if ($deletedVaultJson) { $deletedVaultJson | ConvertFrom-Json } else { @() }
                if ($deletedVault.Count -gt 0) {
                    if ($protected) {
                        Write-Host "  ⚠️  ${resName}: soft-deleted but purge-protected — retained"
                        $RetainedCount++
                        $PurgeResults += [pscustomobject]@{ name=$resName; type=$resType; action='retained-soft-deleted'; reason='purge-protected' }
                    } else {
                        Write-Host "  🗑️  Purging vault: $resName"
                        az keyvault purge --name $resName 2>$null
                        if ($LASTEXITCODE -eq 0) {
                            $PurgeResults += [pscustomobject]@{ name=$resName; type=$resType; action='purged' }
                        } else {
                            Write-Host "  ⚠️  Failed to purge vault: $resName"
                            $RetainedCount++
                            $PurgeResults += [pscustomobject]@{ name=$resName; type=$resType; action='purge-failed' }
                        }
                    }
                } else {
                    Write-Host "  ✓ ${resName}: not in soft-deleted state"
                }
            }
            'Microsoft.CognitiveServices/accounts' {
                if (-not $protected) {
                    # Account IDs are resource-group scoped (no /locations/<region>
                    # segment); resolve the region from the soft-deleted account
                    # list and the resource group from the original resource ID.
                    $loc = az cognitiveservices account list-deleted --query "[?name=='$resName'] | [0].location" -o tsv 2>$null
                    $resRg = ''
                    if ($resId -match '/resourceGroups/([^/]+)') { $resRg = $matches[1] }
                    if ($loc) {
                        az cognitiveservices account purge --name $resName --location $loc --resource-group $resRg 2>$null | Out-Null
                    }
                }
            }
            default {
                Write-Host "  ℹ️  ${resType}: no purge implementation (soft-delete will expire naturally)"
            }
        }
    }
}

# Clean subscription deployment history entry to stay under the 800/scope limit
az deployment sub delete --name $DeploymentId 2>$null | Out-Null

$EndTime  = Get-Date
$Duration = [int]($EndTime - $StartTime).TotalSeconds

# Determine final status
$Status = if ($AlreadyGone) {
    'already-destroyed'
} elseif ($StackDeleted -or $RgDeleted) {
    if ($RetainedCount -gt 0) { 'retained-soft-deleted' } else { 'destroyed' }
} elseif ($DeleteAttempted) {
    # A stack/RG existed and a delete was invoked, but it did not complete
    # (e.g. fast-mode poll timeout or a failed delete command). Some resources
    # may remain. Mirrors CI: stack/RG delete status == failed ->
    # partially-destroyed (distinct from the destroy-failed catch-all).
    'partially-destroyed'
} else {
    'destroy-failed'
}

# Update state.json + metadata.json
$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$Actor     = az account show --query user.name -o tsv 2>$null
if (-not $Actor) { $Actor = 'unknown' }

$state | Add-Member -MemberType NoteProperty -Name status           -Value $Status                -Force
$state | Add-Member -MemberType NoteProperty -Name destroyedAt      -Value $Timestamp             -Force
$state | Add-Member -MemberType NoteProperty -Name destroyedBy      -Value $Actor                 -Force
$state | Add-Member -MemberType NoteProperty -Name destroyDuration  -Value "${Duration}s"         -Force
$state | Add-Member -MemberType NoteProperty -Name purgeResults     -Value $PurgeResults          -Force
$state | ConvertTo-Json -Depth 10 | Set-Content -Path $StateFile -Encoding utf8

$MetadataFile = Join-Path $DeploymentPath 'metadata.json'
if (Test-Path $MetadataFile) {
    $metadata = Get-Content $MetadataFile -Raw | ConvertFrom-Json
    $metadata | Add-Member -MemberType NoteProperty -Name status -Value $Status -Force
    $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $MetadataFile -Encoding utf8
}

Write-Host ''
Write-Color '=== Destroy Summary ===' Green
Write-Host  "Status:   $Status"
Write-Host  "Duration: ${Duration}s"
if ($RetainedCount -gt 0) {
    Write-Color "Retained: $RetainedCount soft-deleted resource(s) (purge-protected)" Yellow
}
Write-Color '=======================' Green
