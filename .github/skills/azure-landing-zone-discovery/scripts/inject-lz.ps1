#!/usr/bin/env pwsh
# Azure Landing Zone Manual Injection Script (PowerShell)
# Creates or updates .azure/landing-zone-context.json from user-provided values
# Use when auto-discovery is not possible (cross-tenant, limited RBAC, air-gapped)
#
# PowerShell parity port of inject-lz.sh. Produces an identical
# landing-zone-context.json schema.

[CmdletBinding()]
param(
    [string]$HubVnetId = "",
    [string]$LogAnalyticsId = "",
    [string]$AcrId = "",
    [string]$KeyVaultId = "",
    [string]$AllowedLocations = "",
    [string]$RequiredTags = "",
    [switch]$DenyPublicIp,
    [switch]$DenyPublicStorage,
    [string]$OutputFile = ".azure/landing-zone-context.json",
    [switch]$Merge,
    [ValidateSet("", "high", "medium", "low", "none")]
    [string]$Confidence = "",
    [switch]$NotLandingZone,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    @"
Azure Landing Zone Manual Injection Script (PowerShell)

Creates or updates .azure/landing-zone-context.json from user-provided values.
Use when auto-discovery is not possible (cross-tenant, limited RBAC, air-gapped).

Usage: ./inject-lz.ps1 [OPTIONS]

Options:
  -HubVnetId <id>           Azure resource ID of the hub VNet
  -LogAnalyticsId <id>      Azure resource ID of the shared Log Analytics workspace
  -AcrId <id>               Azure resource ID of the shared Container Registry
  -KeyVaultId <id>          Azure resource ID of the shared Key Vault
  -AllowedLocations <list>  Comma-separated list of allowed Azure regions
  -RequiredTags <list>      Comma-separated list of required tag names
  -DenyPublicIp             Flag: public IPs are denied by policy
  -DenyPublicStorage        Flag: public storage access is denied by policy
  -OutputFile <path>        Output file path (default: .azure/landing-zone-context.json)
  -Merge                    Merge with existing context file instead of replacing
  -Confidence <level>       Assert landing zone confidence: high|medium|low|none
                            (default: high — manual injection is an explicit
                            assertion that this tenant is landing-zone managed)
  -NotLandingZone           Shorthand for -Confidence none (assert NOT a landing zone)
  -Help                     Show this help message

Examples:
  # Inject hub VNet and Log Analytics
  ./inject-lz.ps1 -HubVnetId "/subscriptions/.../providers/Microsoft.Network/virtualNetworks/vnet-hub" `
     -LogAnalyticsId "/subscriptions/.../providers/Microsoft.OperationalInsights/workspaces/log-central"

  # Inject policy constraints
  ./inject-lz.ps1 -AllowedLocations "eastus,westus2,westeurope" `
     -RequiredTags "Environment,Project,CostCenter" -DenyPublicIp

  # Declare "I know my tenant is ALZ-managed" with no other data
  ./inject-lz.ps1 -Confidence high

  # Merge with existing discovery
  ./inject-lz.ps1 -Merge -AcrId "/subscriptions/.../providers/Microsoft.ContainerRegistry/registries/crshared"
"@ | Write-Host
    exit 1
}

if ($Help) { Show-Usage }

$ConfidenceExplicit = $PSBoundParameters.ContainsKey('Confidence') -or $NotLandingZone

# Check if at least one value was provided
if (-not $HubVnetId -and -not $LogAnalyticsId -and -not $AcrId -and `
    -not $KeyVaultId -and -not $AllowedLocations -and -not $RequiredTags -and `
    -not $DenyPublicIp -and -not $DenyPublicStorage -and -not $ConfidenceExplicit) {
    Write-Host "Error: At least one landing zone parameter must be provided" -ForegroundColor Red
    Write-Host ""
    Show-Usage
}

# ─────────────────────────────────────────────────────────────────────────────
# Resolve landing zone detection.
#
# Manual injection is an explicit assertion that this tenant is landing-zone
# managed, so unless the caller says otherwise we record a high-confidence,
# source="manual" detection. This is what allows the manual fallback to flip
# LZ-aware behaviour in downstream agents (the auto-scorer is bypassed here).
# ─────────────────────────────────────────────────────────────────────────────
if ($NotLandingZone) { $Confidence = "none" }
if (-not $Confidence) { $Confidence = "high" }
$Confidence = $Confidence.ToLower()
switch ($Confidence) {
    "high"   { $ConfScore = 90 }
    "medium" { $ConfScore = 50 }
    "low"    { $ConfScore = 20 }
    "none"   { $ConfScore = 0 }
    default {
        Write-Host "Error: -Confidence must be one of: high, medium, low, none" -ForegroundColor Red
        exit 1
    }
}
# isLandingZone threshold matches discover-lz.ps1 (score >= 40)
$IsLandingZone = ($ConfScore -ge 40)

$InjectionTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "Injecting landing zone context..." -ForegroundColor Blue
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# Helpers: extract name / subscription / location hint from a resource ID
# ─────────────────────────────────────────────────────────────────────────────
function Get-ResourceName {
    param([string]$Id)
    return ($Id -split '/')[-1]
}

function Get-ResourceSubscription {
    param([string]$Id)
    if ($Id -match 'subscriptions/([^/]+)') { return $matches[1] }
    return ""
}

function Get-LocationFromName {
    param([string]$Name)
    $locations = @(
        "eastus", "eastus2", "westus", "westus2", "westus3", "centralus",
        "northcentralus", "southcentralus", "westeurope", "northeurope",
        "uksouth", "ukwest", "southeastasia", "eastasia", "australiaeast",
        "japaneast", "brazilsouth", "canadacentral", "francecentral",
        "germanywestcentral", "norwayeast", "switzerlandnorth"
    )
    foreach ($loc in $locations) {
        if ($Name -match "(?i)$loc") { return $loc }
    }
    return "unknown"
}

# ─────────────────────────────────────────────────────────────────────────────
# Build shared services section
# ─────────────────────────────────────────────────────────────────────────────
$SharedServices = [ordered]@{}

$VnetName = ""; $VnetSub = ""; $VnetLoc = ""
if ($HubVnetId) {
    $VnetName = Get-ResourceName $HubVnetId
    $VnetSub = Get-ResourceSubscription $HubVnetId
    $VnetLoc = Get-LocationFromName $VnetName
    Write-Host "  Hub VNet: " -NoNewline; Write-Host "$VnetName" -ForegroundColor Green -NoNewline; Write-Host " (sub: $VnetSub)"
}

if ($LogAnalyticsId) {
    $laName = Get-ResourceName $LogAnalyticsId
    $SharedServices['logAnalytics'] = [ordered]@{
        id           = $LogAnalyticsId
        name         = $laName
        subscription = (Get-ResourceSubscription $LogAnalyticsId)
        location     = (Get-LocationFromName $laName)
    }
    Write-Host "  Log Analytics: " -NoNewline; Write-Host "$laName" -ForegroundColor Green
}

if ($AcrId) {
    $acrName = Get-ResourceName $AcrId
    $SharedServices['containerRegistry'] = [ordered]@{
        id           = $AcrId
        name         = $acrName
        subscription = (Get-ResourceSubscription $AcrId)
        location     = (Get-LocationFromName $acrName)
    }
    Write-Host "  Container Registry: " -NoNewline; Write-Host "$acrName" -ForegroundColor Green
}

if ($KeyVaultId) {
    $kvName = Get-ResourceName $KeyVaultId
    $SharedServices['keyVault'] = [ordered]@{
        id           = $KeyVaultId
        name         = $kvName
        subscription = (Get-ResourceSubscription $KeyVaultId)
        location     = (Get-LocationFromName $kvName)
    }
    Write-Host "  Key Vault: " -NoNewline; Write-Host "$kvName" -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
# Build networking section
# ─────────────────────────────────────────────────────────────────────────────
$Networking = [ordered]@{
    topology        = "unknown"
    hubs            = @()
    privateDnsZones = @()
    peerings        = @()
}

if ($HubVnetId) {
    $Networking['topology'] = "hub-spoke"
    $Networking['hubs'] = @(
        [ordered]@{
            id              = $HubVnetId
            name            = $VnetName
            subscription    = $VnetSub
            location        = $VnetLoc
            addressPrefixes = @()
        }
    )
}

# ─────────────────────────────────────────────────────────────────────────────
# Build policies section
# ─────────────────────────────────────────────────────────────────────────────
$DenyEffects = [System.Collections.ArrayList]::new()

if ($DenyPublicIp) {
    [void]$DenyEffects.Add([ordered]@{
        name   = "Deny-Public-IP"
        scope  = "manual-injection"
        impact = "Blocks public IP creation"
    })
    Write-Host "  Policy: " -NoNewline; Write-Host "Deny-Public-IP" -ForegroundColor Yellow
}

if ($DenyPublicStorage) {
    [void]$DenyEffects.Add([ordered]@{
        name   = "Deny-Storage-Public-Access"
        scope  = "manual-injection"
        impact = "Blocks public storage access"
    })
    Write-Host "  Policy: " -NoNewline; Write-Host "Deny-Storage-Public-Access" -ForegroundColor Yellow
}

$LocationsArr = @()
if ($AllowedLocations) {
    $LocationsArr = @($AllowedLocations -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Write-Host "  Allowed locations: " -NoNewline; Write-Host "$AllowedLocations" -ForegroundColor Green
}

$TagsArr = @()
if ($RequiredTags) {
    $TagsArr = @($RequiredTags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Write-Host "  Required tags: " -NoNewline; Write-Host "$RequiredTags" -ForegroundColor Green
}

$Policies = [ordered]@{
    denyEffects      = @($DenyEffects)
    auditEffects     = @()
    allowedLocations = @($LocationsArr)
    requiredTags     = @($TagsArr)
}

# ─────────────────────────────────────────────────────────────────────────────
# Assemble context object
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""

$NewContext = [ordered]@{
    discoveredAt     = $InjectionTimestamp
    discoveryMethod  = "manual"
    landingZoneDetection = [ordered]@{
        isLandingZone   = $IsLandingZone
        confidence      = $Confidence
        confidenceScore = $ConfScore
        source          = "manual"
        reference       = "https://azure.github.io/Azure-Landing-Zones/accelerator/"
        matchedSignals  = @(
            [ordered]@{
                signal   = "manual-injection"
                points   = $ConfScore
                evidence = "Landing zone context asserted via inject-lz.ps1 (-Confidence $Confidence)"
            }
        )
        missingSignals  = @()
    }
    managementGroups = [ordered]@{ root = ""; hasManagementGroups = $false; hierarchy = @() }
    subscriptions    = [ordered]@{ platform = @(); landingZones = @() }
    sharedServices   = $SharedServices
    networking       = $Networking
    policies         = $Policies
    currentIdentity  = [ordered]@{
        user                = "manual-injection"
        tenantId            = ""
        currentSubscription = [ordered]@{ id = ""; name = "" }
        roles               = @()
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Merge with existing context if requested
# ─────────────────────────────────────────────────────────────────────────────
function Get-Prop {
    param($Object, [string]$Name, $Default = $null)
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

$FinalContext = $NewContext

if ($Merge -and (Test-Path $OutputFile)) {
    Write-Host "Merging with existing context file..." -ForegroundColor Blue
    $existing = Get-Content $OutputFile -Raw | ConvertFrom-Json

    # sharedServices: existing merged with new (new keys override)
    $mergedShared = [ordered]@{}
    $existingShared = Get-Prop $existing 'sharedServices'
    if ($existingShared) {
        foreach ($p in $existingShared.PSObject.Properties) { $mergedShared[$p.Name] = $p.Value }
    }
    foreach ($k in $SharedServices.Keys) { $mergedShared[$k] = $SharedServices[$k] }

    # networking: use new only when it carries a concrete topology
    $existingNet = Get-Prop $existing 'networking'
    $mergedNet = if ($Networking.topology -ne "unknown") { $Networking } else { $existingNet }

    # policies: union deny/audit by name, prefer new allowedLocations when set,
    # union requiredTags
    $existingPol = Get-Prop $existing 'policies'
    $exDeny = @(Get-Prop $existingPol 'denyEffects' @())
    $exAudit = @(Get-Prop $existingPol 'auditEffects' @())
    $exLoc = @(Get-Prop $existingPol 'allowedLocations' @())
    $exTags = @(Get-Prop $existingPol 'requiredTags' @())

    $unionDeny = @($exDeny + @($DenyEffects)) | Group-Object -Property name | ForEach-Object { $_.Group[0] }
    $unionAudit = @($exAudit) | Group-Object -Property name | ForEach-Object { $_.Group[0] }
    $finalLoc = if ($LocationsArr.Count -gt 0) { @($LocationsArr) } else { @($exLoc) }
    $finalTags = @($exTags + $TagsArr) | Select-Object -Unique

    $mergedPolicies = [ordered]@{
        denyEffects      = @($unionDeny)
        auditEffects     = @($unionAudit)
        allowedLocations = @($finalLoc)
        requiredTags     = @($finalTags)
    }

    # Reconcile detection: an explicit -Confidence forces the injected value
    # (so the caller can raise OR lower it); otherwise injection can only raise
    # confidence, never silently downgrade a real discovery result.
    $existingDetection = Get-Prop $existing 'landingZoneDetection'
    $newDetection = $NewContext.landingZoneDetection
    if ($ConfidenceExplicit -or (-not $existingDetection)) {
        $mergedDetection = $newDetection
    }
    else {
        $existingScore = [int](Get-Prop $existingDetection 'confidenceScore' 0)
        if ($ConfScore -ge $existingScore) { $mergedDetection = $newDetection }
        else { $mergedDetection = $existingDetection }
    }

    $FinalContext = [ordered]@{
        discoveredAt     = $InjectionTimestamp
        discoveryMethod  = "merged"
        landingZoneDetection = $mergedDetection
        managementGroups = (Get-Prop $existing 'managementGroups' $NewContext.managementGroups)
        subscriptions    = (Get-Prop $existing 'subscriptions' $NewContext.subscriptions)
        sharedServices   = $mergedShared
        networking       = $mergedNet
        policies         = $mergedPolicies
        currentIdentity  = (Get-Prop $existing 'currentIdentity' $NewContext.currentIdentity)
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Write output
# ─────────────────────────────────────────────────────────────────────────────
$OutputDir = Split-Path -Parent $OutputFile
if ($OutputDir -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$FinalContext | ConvertTo-Json -Depth 20 | Set-Content -Path $OutputFile -Encoding utf8

Write-Host "✅ Landing zone context saved to: $OutputFile" -ForegroundColor Green
Write-Host ""
Write-Host "To verify: " -NoNewline; Write-Host "Get-Content $OutputFile | ConvertFrom-Json" -ForegroundColor Blue
Write-Host "To merge with auto-discovery: " -NoNewline; Write-Host ".github/skills/azure-landing-zone-discovery/scripts/discover-lz.ps1 -OutputFile $OutputFile" -ForegroundColor Blue
exit 0
