<#
.SYNOPSIS
    Deploy a Git-Ape deployment artifact as a subscription-scoped Azure Deployment Stack.

.DESCRIPTION
    PowerShell port of deploy-stack.sh. Mirrors the logic of
    .github/workflows/git-ape-deploy.exampleyml so local CLI / VS Code
    deployments produce identical state.json (schemaVersion 1.0).

.PARAMETER DeploymentId
    Folder name under .azure/deployments/. Required.

.PARAMETER Location
    Override the location from parameters.json. Optional.

.PARAMETER NoFallback
    Fail loudly if the stack call fails instead of falling back to az deployment sub create.

.EXAMPLE
    ./deploy-stack.ps1 -DeploymentId deploy-20260506-001

.EXAMPLE
    ./deploy-stack.ps1 -DeploymentId deploy-20260506-001 -Location westus2 -NoFallback

.NOTES
    Requires: PowerShell 7+, az CLI ≥ 2.59, jq, active az login session.
#>
[CmdletBinding()]
param(
    [string]$DeploymentId,

    [string]$Location,

    [switch]$NoFallback,

    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    @'
Azure Stack Deploy — deploy as subscription-scoped Deployment Stack

Usage: deploy-stack.ps1 -DeploymentId <id> [OPTIONS]

Required:
  -DeploymentId <id>      Folder name under .azure/deployments/

Options:
  -Location <region>      Override location from parameters.json
  -NoFallback             Fail loudly if stack create fails (no fallback to az deployment sub create)
  -Help                   Show this help

Examples:
  ./deploy-stack.ps1 -DeploymentId deploy-20260506-001
  ./deploy-stack.ps1 -DeploymentId deploy-20260506-001 -Location westus2
  ./deploy-stack.ps1 -DeploymentId deploy-20260506-001 -NoFallback
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

# Soft-deletable resource types (must match the CI workflow list)
$SoftDeletableTypes = @(
    'Microsoft.KeyVault/vaults'
    'Microsoft.CognitiveServices/accounts'
    'Microsoft.AppConfiguration/configurationStores'
    'Microsoft.ApiManagement/service'
    'Microsoft.MachineLearningServices/workspaces'
    'Microsoft.RecoveryServices/vaults'
)

function Write-Color {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
}

if (-not (Test-Path -PathType Container $DeploymentPath)) {
    Write-Color "Deployment not found: $DeploymentId" Red
    exit 1
}
$TemplateFile = Join-Path $DeploymentPath 'template.json'
if (-not (Test-Path $TemplateFile)) {
    Write-Color "Template not found: $TemplateFile" Red
    exit 1
}

# Internal helpers ------------------------------------------------------------

function Get-ResourceClassification {
    param([string]$ResourceId)

    $type = $null
    # Use the LAST providers/<namespace>/<type> segment so extension/nested
    # resources (e.g. a role assignment scoped to a Key Vault) are classified by
    # their own type rather than the parent resource's type.
    if ($ResourceId -match '.*providers/([^/]+/[^/]+)') {
        $type = $matches[1]
    }
    $scope = if ($ResourceId -match '/resourceGroups/') { 'resourceGroup' } else { 'subscription' }
    $isSoft = $SoftDeletableTypes -contains $type

    $purgeProtected = $false
    if ($type -eq 'Microsoft.KeyVault/vaults') {
        $pp = az resource show --ids $ResourceId --query 'properties.enablePurgeProtection // `false`' -o tsv 2>$null
        $purgeProtected = ($pp -eq 'true')
    }

    [pscustomobject]@{
        id              = $ResourceId
        type            = $type
        scope           = $scope
        softDeletable   = $isSoft
        purgeProtected  = $purgeProtected
    }
}

function Build-ManagedResource {
    param([string[]]$ResourceIds)
    $list = @()
    foreach ($id in $ResourceIds) {
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        $list += Get-ResourceClassification -ResourceId $id
    }
    , $list
}

# Resolve deployment parameters ----------------------------------------------

$ParamsArg   = @()
$ResolvedLoc = 'eastus'
$Project     = 'unknown'
$Environment = 'dev'
$ParametersFile = Join-Path $DeploymentPath 'parameters.json'
if (Test-Path $ParametersFile) {
    $ParamsArg += '--parameters'
    $ParamsArg += "@$ParametersFile"
    $params = Get-Content $ParametersFile -Raw | ConvertFrom-Json
    if ($params.parameters.location.value)         { $ResolvedLoc = $params.parameters.location.value }
    if ($params.parameters.project.value)          { $Project     = $params.parameters.project.value }
    elseif ($params.parameters.projectName.value)  { $Project     = $params.parameters.projectName.value }
    if ($params.parameters.environment.value)      { $Environment = $params.parameters.environment.value }
}
if ($PSBoundParameters.ContainsKey('Location') -and $Location) { $ResolvedLoc = $Location }

$Subscription = az account show --query id -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($Subscription)) {
    Write-Color "Not logged in to Azure. Run 'az login' first." Red
    exit 1
}

Write-Color "🚀 Deploying $DeploymentId" Blue
Write-Host  "  Subscription: $Subscription"
Write-Host  "  Location:     $ResolvedLoc"
Write-Host  '  Method:       stack (az stack sub create --action-on-unmanage deleteAll)'

# Deploy ---------------------------------------------------------------------

$StartTime    = Get-Date
$DeployMethod = 'stack'
$StackId      = $null
$DeployOutput = $null
$ExitCode     = 0

$stackArgs = @(
    'stack', 'sub', 'create',
    '--name', $DeploymentId,
    '--location', $ResolvedLoc,
    '--template-file', $TemplateFile
) + $ParamsArg + @(
    '--action-on-unmanage', 'deleteAll',
    '--deny-settings-mode', 'none',
    '--description', "Git-Ape deployment $DeploymentId",
    '--tags', 'managedBy=git-ape', "deploymentId=$DeploymentId",
    '--yes', '--verbose', '--output', 'json'
)

# Capture stdout (JSON) and stderr (verbose log) separately so the JSON we hand
# to ConvertFrom-Json downstream stays clean.
$VerboseLog = New-TemporaryFile
try {
    $DeployOutput = & az @stackArgs 2>$VerboseLog
    if ($LASTEXITCODE -ne 0) {
        if ($NoFallback) {
            Write-Color '❌ Stack deploy failed and -NoFallback was set' Red
            Write-Host $DeployOutput
            Get-Content $VerboseLog | Write-Host
            $ExitCode = 1
        } else {
            Write-Color '⚠ Stack deploy failed; check whether Deployment Stacks are available in this subscription/region.' Yellow
            Write-Host $DeployOutput
            Get-Content $VerboseLog | Write-Host
            Write-Color 'Falling back to az deployment sub create (NOT idempotent for soft-delete / multi-RG).' Yellow
            $DeployMethod = 'subscription'
            $fallbackArgs = @(
                'deployment', 'sub', 'create',
                '--name', $DeploymentId,
                '--location', $ResolvedLoc,
                '--template-file', $TemplateFile
            ) + $ParamsArg + @('--output', 'json')
            $DeployOutput = & az @fallbackArgs 2>$VerboseLog
            if ($LASTEXITCODE -ne 0) {
                Get-Content $VerboseLog | Write-Host
                $ExitCode = 1
            }
        }
    }
} finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $VerboseLog
}

$EndTime  = Get-Date
$Duration = [int]($EndTime - $StartTime).TotalSeconds

if ($ExitCode -ne 0) {
    Write-Color '❌ Deployment failed' Red
    Write-Host $DeployOutput
    Write-Host ''
    Write-Color '── Underlying failed operations ──' Yellow
    $opsJson = az deployment operation sub list --name $DeploymentId --output json 2>$null
    if ($opsJson) {
        $ops = $opsJson | ConvertFrom-Json
        $failed = $ops | Where-Object { $_.properties.provisioningState -eq 'Failed' }
        if ($failed.Count -eq 0) {
            Write-Host '(no failed operations reported)'
        } else {
            foreach ($op in $failed) {
                Write-Host '──────────'
                Write-Host ("Resource : {0} ({1})" -f ($op.properties.targetResource.resourceName ?? 'n/a'), ($op.properties.targetResource.resourceType ?? 'n/a'))
                Write-Host ("Status   : {0}" -f ($op.properties.statusCode ?? 'n/a'))
                $msg = if ($op.properties.statusMessage.error.message) { $op.properties.statusMessage.error.message } else { $op.properties.statusMessage }
                Write-Host ("Message  : {0}" -f $msg)
            }
        }
    } else {
        Write-Host '(no per-operation details available — deployment may not have reached Azure)'
    }
    exit 1
}

# Capture state --------------------------------------------------------------

$DeployJson = $DeployOutput | ConvertFrom-Json
if ($DeployMethod -eq 'stack') {
    $StackId = $DeployJson.id
    $Outputs = $DeployJson.outputs
} else {
    $Outputs = $DeployJson.properties.outputs
}
$RgName = if ($Outputs -and $Outputs.resourceGroupName) { $Outputs.resourceGroupName.value } else { '' }

Write-Color "✅ Deployment succeeded in ${Duration}s (method: $DeployMethod)" Green

if ($DeployMethod -eq 'stack' -and $StackId) {
    $stackResources = az stack sub show --name $DeploymentId --query 'resources[].id' -o json 2>$null
    if ($stackResources) {
        $resourceIds = $stackResources | ConvertFrom-Json
    } else { $resourceIds = @() }
} else {
    $opsTsv = az deployment operation sub list --name $DeploymentId `
        --query "[?properties.provisioningState=='Succeeded' && properties.targetResource.id != null].properties.targetResource.id" `
        -o tsv 2>$null
    $resourceIds = if ($opsTsv) { $opsTsv -split "`n" | Where-Object { $_ } } else { @() }
}

$ManagedResources = Build-ManagedResource -ResourceIds $resourceIds
$ResourceGroups   = @($ManagedResources | ForEach-Object {
    if ($_.id -match '/resourceGroups/([^/]+)') { $matches[1] }
} | Sort-Object -Unique)
if ($ResourceGroups.Count -eq 0 -and $RgName) { $ResourceGroups = @($RgName) }

$StateFile = Join-Path $DeploymentPath 'state.json'
$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$state = [ordered]@{
    schemaVersion       = '1.0'
    deploymentId        = $DeploymentId
    timestamp           = $Timestamp
    status              = 'succeeded'
    duration            = "${Duration}s"
    subscription        = $Subscription
    location            = $ResolvedLoc
    project             = $Project
    environment         = $Environment
    resourceGroup       = $RgName
    deployMethod        = $DeployMethod
    stackId             = $(if ([string]::IsNullOrWhiteSpace($StackId)) { $null } else { $StackId })
    managedResources    = $ManagedResources
    resourceGroups      = $ResourceGroups
    subscriptions       = @($Subscription)
    externalReferences  = @()
}
$state | ConvertTo-Json -Depth 10 | Set-Content -Path $StateFile -Encoding utf8

$MetadataFile = Join-Path $DeploymentPath 'metadata.json'
if (Test-Path $MetadataFile) {
    $metadata = Get-Content $MetadataFile -Raw | ConvertFrom-Json
    $metadata | Add-Member -MemberType NoteProperty -Name status -Value 'succeeded' -Force
    $metadata | Add-Member -MemberType NoteProperty -Name deployMethod -Value $DeployMethod -Force
    $metadata | Add-Member -MemberType NoteProperty -Name resourceGroups -Value $ResourceGroups -Force
    $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $MetadataFile -Encoding utf8
}

Write-Color "State written to: $StateFile" Green
if ($StackId) { Write-Host "Stack ID: $StackId" }
Write-Host ''
Write-Host 'To destroy this deployment:'
Write-Host "  /azure-stack-destroy $DeploymentId"
