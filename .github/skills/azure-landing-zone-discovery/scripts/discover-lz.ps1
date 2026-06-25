#!/usr/bin/env pwsh
# Azure Landing Zone Discovery Script (PowerShell)
# Auto-discovers management groups, subscriptions, policies, networking, and shared services
#
# PowerShell parity port of discover-lz.sh. Produces an identical
# landing-zone-context.json schema and the same exit codes:
#   0  Discovery completed successfully
#   1  Partial discovery (some targets failed, results still usable)
#   2  Discovery failed (no Azure access or critical error)

param(
    [ValidateSet("json", "markdown")]
    [string]$OutputFormat = "json",
    [string]$OutputFile = "",
    [switch]$SkipNetwork,
    [switch]$SkipPolicies,
    [switch]$SkipSharedServices,
    [switch]$Verbose,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    @"
Azure Landing Zone Discovery Script (PowerShell)

Discovers management group hierarchy, subscription classification, policy
assignments, network topology, and shared services from the current Azure context.

Usage: ./discover-lz.ps1 [OPTIONS]

Options:
  -OutputFormat <fmt>     Output format: json, markdown (default: json)
  -OutputFile <path>      Output file path (default: stdout)
  -SkipNetwork            Skip network topology discovery
  -SkipPolicies           Skip policy assignment discovery
  -SkipSharedServices     Skip shared services discovery
  -Verbose                Show detailed discovery progress
  -Help                   Show this help message

Examples:
  ./discover-lz.ps1 -OutputFile .azure/landing-zone-context.json
  ./discover-lz.ps1 -OutputFormat markdown
  ./discover-lz.ps1 -OutputFile .azure/landing-zone-context.json -SkipNetwork
  ./discover-lz.ps1 -Verbose

Exit Codes:
  0  Discovery completed successfully
  1  Partial discovery (some targets failed, results still usable)
  2  Discovery failed (no Azure access or critical error)
"@ | Write-Host
    exit 1
}

if ($Help) { Show-Usage }

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-AzJson {
    # Run an az command and parse JSON output, returning $null on failure.
    param([string[]]$AzArgs)
    try {
        $raw = & az @AzArgs -o json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $raw) { return $null }
        return ($raw | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        return $null
    }
}

function Get-Prop {
    param($Object, [string]$Name, $Default = $null)
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        $val = $Object.$Name
        if ($null -ne $val) { return $val }
    }
    return $Default
}

function ConvertTo-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}

# ─────────────────────────────────────────────────────────────────────────────
# Validate Azure CLI is available and logged in
# ─────────────────────────────────────────────────────────────────────────────
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Azure CLI (az) is not installed" -ForegroundColor Red
    exit 2
}

$null = az account show -o json 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Not logged in to Azure. Run 'az login' first." -ForegroundColor Red
    exit 2
}

$DiscoveryTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "Starting Azure Landing Zone Discovery" -ForegroundColor Blue
Write-Host "Timestamp: $DiscoveryTimestamp"
Write-Host ""

$PartialFailure = $false

# ─────────────────────────────────────────────────────────────────────────────
# [1/7] Current Identity
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "[1/7] Discovering current identity..." -ForegroundColor Cyan

$CurrentAccount = Invoke-AzJson @("account", "show")
$CurrentUser = Get-Prop (Get-Prop $CurrentAccount 'user') 'name' "unknown"
$CurrentTenantId = Get-Prop $CurrentAccount 'tenantId' "unknown"
$CurrentSubId = Get-Prop $CurrentAccount 'id' "unknown"
$CurrentSubName = Get-Prop $CurrentAccount 'name' "unknown"

Write-Host "  User: " -NoNewline; Write-Host "$CurrentUser" -ForegroundColor Green
Write-Host "  Tenant: $CurrentTenantId"
Write-Host "  Subscription: $CurrentSubName ($CurrentSubId)"
Write-Host ""

$IdentityJson = [ordered]@{
    user                = $CurrentUser
    tenantId            = $CurrentTenantId
    currentSubscription = [ordered]@{ id = $CurrentSubId; name = $CurrentSubName }
    roles               = @()
}

# ─────────────────────────────────────────────────────────────────────────────
# [2/7] Management Group Hierarchy
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "[2/7] Discovering management group hierarchy..." -ForegroundColor Cyan

$MgHierarchy = @()
$MgRoot = ""
$HasManagementGroups = $false

$MgList = ConvertTo-Array (Invoke-AzJson @("account", "management-group", "list"))

function Get-MgRole {
    param($Mg, [string]$TenantId)
    $displayName = Get-Prop $Mg 'displayName'
    $name = Get-Prop $Mg 'name'
    if ($displayName -eq "Tenant Root Group" -or $name -eq $TenantId) { return "root" }

    $n = ("" + ($(if ($displayName) { $displayName } else { $name }))).ToLower()

    switch -Regex ($n) {
        '^platform$'        { return "platform" }
        '^connectivity$'    { return "connectivity" }
        '^identity$'        { return "identity" }
        '^management$'      { return "management" }
        '^(landing zones|landingzones|landing-zones)$' { return "landing-zones" }
        '^corp$'            { return "corp" }
        '^online$'          { return "online" }
        '^sandbox$'         { return "sandbox" }
        '^decommissioned$'  { return "decommissioned" }
    }
    # Substring fallback for custom-named environments (lower precision)
    if ($n -match 'platform|infra')                  { return "platform" }
    if ($n -match 'connectivity|network|hub')        { return "connectivity" }
    if ($n -match 'identity|aad|entra')              { return "identity" }
    if ($n -match 'management|logging|monitor')      { return "management" }
    if ($n -match 'landing.?zone|workload|application') { return "landing-zones" }
    if ($n -match 'sandbox|dev.?test')               { return "sandbox" }
    if ($n -match 'decommission|deprecated|retired') { return "decommissioned" }
    # corp/online matched last so the more specific archetypes win first.
    # The ALZ accelerator prefixes MG names (e.g. "alz-corp"), so the
    # exact-name checks above never fire — these substring tests are what
    # actually classify Corp/Online landing-zone archetypes in practice.
    if ($n -match 'corp')                            { return "corp" }
    if ($n -match 'online')                          { return "online" }
    return "other"
}

if ($MgList.Count -gt 0) {
    $HasManagementGroups = $true
    Write-Host "  Found " -NoNewline; Write-Host "$($MgList.Count)" -ForegroundColor Green -NoNewline; Write-Host " management groups"

    # Find root management group (Tenant Root Group)
    $rootMg = $MgList | Where-Object {
        (Get-Prop $_ 'displayName') -eq "Tenant Root Group" -or
        (Get-Prop $_ 'name') -eq (Get-Prop $_ 'tenantId') -or
        ($null -eq (Get-Prop (Get-Prop (Get-Prop $_ 'properties') 'details') 'parent'))
    } | Select-Object -First 1
    $MgRoot = if ($rootMg) { Get-Prop $rootMg 'displayName' "Tenant Root Group" } else { "Tenant Root Group" }

    $MgHierarchy = @($MgList | ForEach-Object {
        $parent = Get-Prop (Get-Prop (Get-Prop $_ 'properties') 'details') 'parent'
        [ordered]@{
            id          = (Get-Prop $_ 'id')
            name        = (Get-Prop $_ 'name')
            displayName = (Get-Prop $_ 'displayName')
            role        = (Get-MgRole $_ $CurrentTenantId)
            parentId    = (Get-Prop $parent 'id')
        }
    })

    if ($Verbose) {
        Write-Host "  Management group classification:"
        $MgHierarchy | ForEach-Object { Write-Host "    $($_.displayName) → $($_.role)" }
    }
}
else {
    Write-Host "  No management groups found (flat subscription model)" -ForegroundColor Yellow
}
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# [3/7] Subscription Discovery & Classification
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "[3/7] Discovering and classifying subscriptions..." -ForegroundColor Cyan

$Subscriptions = ConvertTo-Array (Invoke-AzJson @("account", "list", "--query", "[?state=='Enabled']"))
Write-Host "  Found " -NoNewline; Write-Host "$($Subscriptions.Count)" -ForegroundColor Green -NoNewline; Write-Host " enabled subscriptions"

$PlatformSubs = [System.Collections.ArrayList]::new()
$LzSubs = [System.Collections.ArrayList]::new()

foreach ($sub in $Subscriptions) {
    $subId = Get-Prop $sub 'id'
    $subName = Get-Prop $sub 'name'

    $mgPath = ""
    if ($HasManagementGroups) {
        $chain = & az account management-group subscription show `
            --subscription-id "$subId" `
            --query "managementGroupAncestorsChain[].displayName" `
            -o tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and $chain) {
            $mgPath = (($chain -split "`n" | Where-Object { $_ }) -join '/')
        }
    }

    $subNameLower = ("" + $subName).ToLower()
    $mgPathLower = ("" + $mgPath).ToLower()
    $role = "landing-zone"
    $environment = ""

    if ($mgPathLower) {
        # Prefer MG-path classification (canonical ALZ placement)
        if     ($mgPathLower -match '/connectivity') { $role = "connectivity" }
        elseif ($mgPathLower -match '/identity')     { $role = "identity" }
        elseif ($mgPathLower -match '/management')   { $role = "management" }
        elseif ($mgPathLower -match 'platform')      { $role = "platform-other" }
        elseif ($mgPathLower -match 'landing.*zones'){ $role = "landing-zone" }
        elseif ($mgPathLower -match 'sandbox')       { $role = "sandbox" }
        elseif ($mgPathLower -match 'decommission')  { $role = "decommissioned" }
    }

    # Name-based fallback only when MG path didn't classify
    if ($role -eq "landing-zone") {
        if     ($subNameLower -match 'connectivity')              { $role = "connectivity" }
        elseif ($subNameLower -match 'identity|aad|entra')        { $role = "identity" }
        elseif ($subNameLower -match 'management|logging|monitor'){ $role = "management" }
    }

    # Determine environment for landing zone subscriptions
    if ($role -eq "landing-zone") {
        if     ($subNameLower -match 'production')          { $environment = "prod" }
        elseif ($subNameLower -match 'prod')               { $environment = "prod" }
        elseif ($subNameLower -match 'staging|stg|uat|qa') { $environment = "staging" }
        elseif ($subNameLower -match 'develop|test|sandbox') { $environment = "dev" }
        elseif ($subNameLower -match 'dev')                { $environment = "dev" }
        else                                               { $environment = "unknown" }
    }

    $subEntry = [ordered]@{
        id          = $subId
        name        = $subName
        role        = $role
        mgPath      = $mgPath
        environment = $(if ($environment) { $environment } else { $null })
    }

    if ($role -in @("connectivity", "identity", "management", "platform-other")) {
        [void]$PlatformSubs.Add($subEntry)
    }
    else {
        [void]$LzSubs.Add($subEntry)
    }

    if ($Verbose) {
        $envSuffix = if ($environment) { " ($environment)" } else { "" }
        Write-Host "    $subName → $role$envSuffix"
    }
}

Write-Host "  Platform subscriptions: " -NoNewline; Write-Host "$($PlatformSubs.Count)" -ForegroundColor Green
Write-Host "  Landing zone subscriptions: " -NoNewline; Write-Host "$($LzSubs.Count)" -ForegroundColor Green
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# [4/7] Policy Discovery
# ─────────────────────────────────────────────────────────────────────────────
$Policies = [ordered]@{
    denyEffects             = @()
    auditEffects            = @()
    allowedLocations        = @()
    requiredTags            = @()
    alzCanonicalAssignments = @()
}

if (-not $SkipPolicies) {
    Write-Host "[4/7] Discovering policy assignments..." -ForegroundColor Cyan

    $assignments = ConvertTo-Array (Invoke-AzJson @("policy", "assignment", "list", "--query", "[?enforcementMode=='Default']"))

    # Canonical ALZ policies are assigned at management-group scope (e.g. the
    # "alz" and "alz-platform" MGs), not the subscription — so a sub-scope-only
    # query misses them entirely. Enumerate each discovered MG scope and merge,
    # deduplicating by assignment id (a given assignment lives at one scope).
    # NOTE: use the default atScope() filter (a bare --scope). The
    # --disable-scope-strict-match (atScopeAndBelow) flag is unsupported at MG
    # scope and errors out, so we query each MG explicitly instead.
    if ($HasManagementGroups) {
        $seenAssignmentIds = @{}
        $combinedAssignments = [System.Collections.ArrayList]::new()
        foreach ($a in $assignments) {
            $aid = Get-Prop $a 'id'
            if ($aid -and -not $seenAssignmentIds.ContainsKey($aid)) { $seenAssignmentIds[$aid] = $true; [void]$combinedAssignments.Add($a) }
        }
        foreach ($mg in $MgList) {
            $mgScope = Get-Prop $mg 'id'
            if (-not $mgScope) { continue }
            $mgAssignments = ConvertTo-Array (Invoke-AzJson @("policy", "assignment", "list", "--scope", $mgScope, "--query", "[?enforcementMode=='Default']"))
            foreach ($a in $mgAssignments) {
                $aid = Get-Prop $a 'id'
                if ($aid -and -not $seenAssignmentIds.ContainsKey($aid)) { $seenAssignmentIds[$aid] = $true; [void]$combinedAssignments.Add($a) }
            }
        }
        $assignments = @($combinedAssignments)
    }
    Write-Host "  Found " -NoNewline; Write-Host "$($assignments.Count)" -ForegroundColor Green -NoNewline; Write-Host " enforced policy assignments (subscription + management-group scopes)"

    $denyPolicies = [System.Collections.ArrayList]::new()
    $auditPolicies = [System.Collections.ArrayList]::new()
    $allowedLocations = [System.Collections.ArrayList]::new()
    $requiredTags = [System.Collections.ArrayList]::new()
    $alzCanonical = [System.Collections.ArrayList]::new()

    $alzPattern = 'Deploy-MDFC-Config|Deploy-MDEndpoints|Deploy-AzActivity-?Log|Deploy-Diag-LogsCat-LAW|Deploy-Diagnostics-LogAnalytics|Deploy-VM-Monitoring|Deploy-VMSS-Monitoring|Deploy-VM-Backup|Enforce-Encryption-CMK|Enforce-EncryptTransit|Enforce-TLS-SSL|Enforce-ACSB|Deny-Classic-Resources|Deny-PublicIP|Deny-Public-Endpoints|Deny-RDP-From-Internet|Deny-MgmtPorts-From-Internet|Deny-Subnet-Without-Nsg|Deny-Storage-http|Deploy-Resource-Diag|Deploy-Private-DNS-Zones|Audit-UnusedResources'

    foreach ($a in $assignments) {
        $displayName = Get-Prop $a 'displayName'
        $name = Get-Prop $a 'name'
        $params = Get-Prop $a 'parameters'

        # Resolve effect from parameters block
        $effect = ""
        if ($params) {
            $effParam = Get-Prop $params 'effect'
            if (-not $effParam) { $effParam = Get-Prop $params 'Effect' }
            if ($effParam) { $effect = ("" + (Get-Prop $effParam 'value')).ToLower() }
        }

        if ($displayName) {
            $dnLower = ("" + $displayName).ToLower()
            if ($effect -eq "deny") {
                $impact =
                    if     ($dnLower -match 'public.?ip')     { "Blocks public IP creation" }
                    elseif ($dnLower -match 'location|region') { "Restricts allowed regions" }
                    elseif ($dnLower -match 'storage.*public') { "Blocks public storage access" }
                    elseif ($dnLower -match 'tag')             { "Requires specific tags" }
                    elseif ($dnLower -match 'subnet.*nsg')     { "Requires NSG on subnets" }
                    elseif ($dnLower -match 'sql.*public')     { "Blocks public SQL access" }
                    else                                       { "Blocks deployments matching this policy" }
                [void]$denyPolicies.Add([ordered]@{
                    name               = $displayName
                    scope              = (Get-Prop $a 'scope')
                    policyDefinitionId = (Get-Prop $a 'policyDefinitionId')
                    effect             = $effect
                    impact             = $impact
                })
            }
            elseif ($effect.StartsWith("audit")) {
                [void]$auditPolicies.Add([ordered]@{
                    name               = $displayName
                    scope              = (Get-Prop $a 'scope')
                    policyDefinitionId = (Get-Prop $a 'policyDefinitionId')
                    effect             = $effect
                })
            }

            # Allowed locations parameter
            if ($params) {
                $locParam = Get-Prop $params 'listOfAllowedLocations'
                if ($locParam) {
                    foreach ($l in (ConvertTo-Array (Get-Prop $locParam 'value'))) { [void]$allowedLocations.Add($l) }
                }
                $tagParam = Get-Prop $params 'tagName'
                if ($tagParam -and (Get-Prop $tagParam 'value')) { [void]$requiredTags.Add((Get-Prop $tagParam 'value')) }
            }
        }

        # Canonical ALZ accelerator policy assignment names. The canonical token
        # (e.g. "Deploy-VM-Monitoring") lives in the assignment .name;
        # .displayName is a long human description that rarely contains it. Test
        # BOTH fields and record the .name as the label.
        $haystack = (("" + $name) + " " + ("" + $displayName))
        if ($haystack -match "(?i)$alzPattern") {
            $label = if ($name) { $name } else { $displayName }
            [void]$alzCanonical.Add($label)
        }
    }

    $Policies['denyEffects'] = @($denyPolicies)
    $Policies['auditEffects'] = @($auditPolicies)
    $Policies['allowedLocations'] = @($allowedLocations | Select-Object -Unique)
    $Policies['requiredTags'] = @($requiredTags | Select-Object -Unique)
    $Policies['alzCanonicalAssignments'] = @($alzCanonical | Select-Object -Unique)

    if ($Verbose -and $alzCanonical.Count -gt 0) {
        Write-Host "  Canonical ALZ policy assignments found:"
        $Policies['alzCanonicalAssignments'] | ForEach-Object { Write-Host "    ✓ $_" }
    }
    if ($Verbose -and $denyPolicies.Count -gt 0) {
        Write-Host "  Deny-effect policies:"
        $denyPolicies | ForEach-Object { Write-Host "    ⚠️  $($_.name) — $($_.impact)" }
    }
}
else {
    Write-Host "[4/7] Skipping policy discovery (-SkipPolicies)" -ForegroundColor Cyan
}
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# [5/7] Network Topology Discovery
# ─────────────────────────────────────────────────────────────────────────────
$Networking = [ordered]@{
    topology        = "unknown"
    hubs            = @()
    privateDnsZones = @()
    peerings        = @()
}
$Topology = "unknown"
$HasGraph = $false

if (-not $SkipNetwork) {
    Write-Host "[5/7] Discovering network topology..." -ForegroundColor Cyan

    $hubVnets = @()
    $peerings = @()
    $dnsZoneNames = @()

    # Try Azure Resource Graph first (faster, cross-subscription)
    $HasGraph = $true
    $null = az graph query -q "Resources | take 1" -o json 2>$null
    if ($LASTEXITCODE -ne 0) { $HasGraph = $false }

    if ($HasGraph) {
        $hubResult = Invoke-AzJson @("graph", "query", "-q", @"
Resources
| where type == 'microsoft.network/virtualnetworks'
| where name contains 'hub' or tags['network-role'] == 'hub' or tags['NetworkRole'] == 'Hub'
| project id, name, location, subscriptionId, addressPrefixes=properties.addressSpace.addressPrefixes
"@, "--query", "data")
        $hubVnets = ConvertTo-Array $hubResult

        if ($hubVnets.Count -gt 0) {
            $Topology = "hub-spoke"
            Write-Host "  Topology: " -NoNewline; Write-Host "Hub-Spoke" -ForegroundColor Green -NoNewline; Write-Host " ($($hubVnets.Count) hub VNets found)"
        }
        else {
            $Topology = "flat"
            Write-Host "  Topology: " -NoNewline; Write-Host "Flat" -ForegroundColor Yellow -NoNewline; Write-Host " (no hub VNets found)"
        }

        $peerResult = Invoke-AzJson @("graph", "query", "-q", @"
Resources
| where type == 'microsoft.network/virtualnetworks'
| mv-expand peering=properties.virtualNetworkPeerings
| project vnetName=name, vnetId=id, peerName=peering.name, remoteVnet=peering.properties.remoteVirtualNetwork.id, peeringState=peering.properties.peeringState
"@, "--query", "data")
        $peerings = ConvertTo-Array $peerResult
        if ($peerings.Count -gt 0) {
            Write-Host "  VNet peerings: " -NoNewline; Write-Host "$($peerings.Count)" -ForegroundColor Green
        }

        $dnsResult = Invoke-AzJson @("graph", "query", "-q", @"
Resources
| where type == 'microsoft.network/privatednszones'
| project id, name, subscriptionId
"@, "--query", "data")
        $dnsZoneNames = @((ConvertTo-Array $dnsResult) | ForEach-Object { Get-Prop $_ 'name' } | Select-Object -Unique)
        if ($dnsZoneNames.Count -gt 0) {
            Write-Host "  Private DNS zones: " -NoNewline; Write-Host "$($dnsZoneNames.Count)" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  Azure Resource Graph not available, using direct queries" -ForegroundColor Yellow
        $PartialFailure = $true

        $vnetQuery = '[?contains(name, ''hub'') || tags."network-role" == ''hub'']'
        $vnetList = ConvertTo-Array (Invoke-AzJson @("network", "vnet", "list", "--query", $vnetQuery))
        $hubVnets = @($vnetList | ForEach-Object {
            $id = Get-Prop $_ 'id'
            [ordered]@{
                id              = $id
                name            = (Get-Prop $_ 'name')
                location        = (Get-Prop $_ 'location')
                subscriptionId  = (($id -split '/')[2])
                addressPrefixes = (Get-Prop (Get-Prop $_ 'addressSpace') 'addressPrefixes')
            }
        })

        if ($hubVnets.Count -gt 0) {
            $Topology = "hub-spoke"
            Write-Host "  Topology: " -NoNewline; Write-Host "Hub-Spoke" -ForegroundColor Green -NoNewline; Write-Host " ($($hubVnets.Count) hub VNets in current subscription)"
        }
        else {
            $Topology = "flat"
            Write-Host "  Topology: " -NoNewline; Write-Host "Flat" -ForegroundColor Yellow -NoNewline; Write-Host " (no hub VNets in current subscription)"
        }
        $dnsZoneNames = @()
    }

    $hubsOutput = @($hubVnets | ForEach-Object {
        [ordered]@{
            id              = (Get-Prop $_ 'id')
            name            = (Get-Prop $_ 'name')
            subscription    = (Get-Prop $_ 'subscriptionId')
            location        = (Get-Prop $_ 'location')
            addressPrefixes = (ConvertTo-Array (Get-Prop $_ 'addressPrefixes'))
        }
    })

    $Networking = [ordered]@{
        topology        = $Topology
        hubs            = @($hubsOutput)
        privateDnsZones = @($dnsZoneNames)
        peerings        = @($peerings)
    }
}
else {
    Write-Host "[5/7] Skipping network discovery (-SkipNetwork)" -ForegroundColor Cyan
}
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# [6/7] Shared Services Discovery
# ─────────────────────────────────────────────────────────────────────────────
$SharedServices = [ordered]@{}

if (-not $SkipSharedServices) {
    Write-Host "[6/7] Discovering shared services..." -ForegroundColor Cyan

    $logAnalytics = [ordered]@{}
    $containerRegistry = [ordered]@{}
    $keyVault = [ordered]@{}

    if ($HasGraph) {
        $laResults = ConvertTo-Array (Invoke-AzJson @("graph", "query", "-q", @"
Resources
| where type == 'microsoft.operationalinsights/workspaces'
| where tags['shared'] == 'true' or name contains 'platform' or name contains 'central' or name contains 'shared'
| project id, name, subscriptionId, location, sku=properties.sku.name, retentionDays=properties.retentionInDays
| take 5
"@, "--query", "data"))
        if ($laResults.Count -gt 0) {
            $first = $laResults[0]
            $logAnalytics = [ordered]@{
                id           = (Get-Prop $first 'id')
                name         = (Get-Prop $first 'name')
                subscription = (Get-Prop $first 'subscriptionId')
                location     = (Get-Prop $first 'location')
            }
            Write-Host "  Log Analytics: " -NoNewline; Write-Host "$($logAnalytics.name)" -ForegroundColor Green
        }
        else {
            Write-Host "  Log Analytics: " -NoNewline; Write-Host "none found" -ForegroundColor Yellow
        }

        $acrResults = ConvertTo-Array (Invoke-AzJson @("graph", "query", "-q", @"
Resources
| where type == 'microsoft.containerregistry/registries'
| where tags['shared'] == 'true' or sku.name == 'Premium'
| project id, name, subscriptionId, location, sku=sku.name, loginServer=properties.loginServer
| take 5
"@, "--query", "data"))
        if ($acrResults.Count -gt 0) {
            $first = $acrResults[0]
            $containerRegistry = [ordered]@{
                id           = (Get-Prop $first 'id')
                name         = (Get-Prop $first 'name')
                subscription = (Get-Prop $first 'subscriptionId')
                location     = (Get-Prop $first 'location')
                loginServer  = (Get-Prop $first 'loginServer')
            }
            Write-Host "  Container Registry: " -NoNewline; Write-Host "$($containerRegistry.name)" -ForegroundColor Green
        }
        else {
            Write-Host "  Container Registry: " -NoNewline; Write-Host "none found" -ForegroundColor Yellow
        }

        $kvResults = ConvertTo-Array (Invoke-AzJson @("graph", "query", "-q", @"
Resources
| where type == 'microsoft.keyvault/vaults'
| where tags['shared'] == 'true' or name contains 'platform' or name contains 'shared'
| project id, name, subscriptionId, location
| take 5
"@, "--query", "data"))
        if ($kvResults.Count -gt 0) {
            $first = $kvResults[0]
            $keyVault = [ordered]@{
                id           = (Get-Prop $first 'id')
                name         = (Get-Prop $first 'name')
                subscription = (Get-Prop $first 'subscriptionId')
                location     = (Get-Prop $first 'location')
            }
            Write-Host "  Key Vault: " -NoNewline; Write-Host "$($keyVault.name)" -ForegroundColor Green
        }
        else {
            Write-Host "  Key Vault: " -NoNewline; Write-Host "none found" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  Azure Resource Graph not available, skipping shared services" -ForegroundColor Yellow
        $PartialFailure = $true
    }

    $SharedServices = [ordered]@{
        logAnalytics      = $logAnalytics
        containerRegistry = $containerRegistry
        keyVault          = $keyVault
    }
}
else {
    Write-Host "[6/7] Skipping shared services discovery (-SkipSharedServices)" -ForegroundColor Cyan
}
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# [7/7] Landing Zone Detection & Confidence Scoring
# ─────────────────────────────────────────────────────────────────────────────
# Weighted signals (max 100): see discover-lz.sh for the full rationale.
#   Top-level MGs        0–30   Platform children   0–20
#   LZ archetypes        0/10   Platform subs       0–10
#   Hub-spoke topology   0/5    Hub in conn sub     0/5
#   Canonical ALZ policy 0–15
# Confidence: high ≥ 70, medium ≥ 40, low ≥ 10, none < 10. isLandingZone = (score ≥ 40)
Write-Host "[7/7] Scoring landing zone confidence..." -ForegroundColor Cyan

$roles = @($MgHierarchy | ForEach-Object { if ($_.role) { $_.role } else { "other" } })
$hasPlatform       = $roles -contains "platform"
$hasLandingZones   = $roles -contains "landing-zones"
$hasSandbox        = $roles -contains "sandbox"
$hasDecommissioned = $roles -contains "decommissioned"
$hasConnectivity   = $roles -contains "connectivity"
$hasIdentity       = $roles -contains "identity"
$hasManagement     = $roles -contains "management"
$hasCorp           = $roles -contains "corp"
$hasOnline         = $roles -contains "online"

$topLevel = @($hasPlatform, $hasLandingZones, $hasSandbox, $hasDecommissioned | Where-Object { $_ }).Count
$platChildren = @($hasConnectivity, $hasIdentity, $hasManagement | Where-Object { $_ }).Count
$platSubCount = $PlatformSubs.Count
$hasHubSpoke = ($Networking.topology -eq "hub-spoke")
$hubs = ConvertTo-Array $Networking.hubs
$connSubIds = @($PlatformSubs | Where-Object { $_.role -eq "connectivity" } | ForEach-Object { $_.id })
$hubInConn = $false
foreach ($h in $hubs) {
    if ($connSubIds -contains (Get-Prop $h 'subscription')) { $hubInConn = $true; break }
}
$alzPolList = @($Policies.alzCanonicalAssignments | Sort-Object)
$alzPolCount = $alzPolList.Count

# Points per signal
$ptsTop = if ($topLevel -eq 4) { 30 } elseif ($topLevel -eq 3) { 20 } elseif ($topLevel -eq 2) { 10 } else { 0 }
$ptsChildren = if ($platChildren -eq 3) { 20 } elseif ($platChildren -eq 2) { 10 } else { 0 }
$ptsArchetypes = if ($hasCorp -and $hasOnline) { 10 } else { 0 }
$ptsPlatSubs = if ($platSubCount -ge 3) { 10 } elseif ($platSubCount -ge 1) { 5 } else { 0 }
$ptsHubSpoke = if ($hasHubSpoke) { 5 } else { 0 }
$ptsHubInConn = if ($hubInConn) { 5 } else { 0 }
$ptsAlzPols = [Math]::Min($alzPolCount * 5, 15)

$score = $ptsTop + $ptsChildren + $ptsArchetypes + $ptsPlatSubs + $ptsHubSpoke + $ptsHubInConn + $ptsAlzPols
$confidence = if ($score -ge 70) { "high" } elseif ($score -ge 40) { "medium" } elseif ($score -ge 10) { "low" } else { "none" }

$matchedSignals = [System.Collections.ArrayList]::new()
if ($topLevel -gt 0) { [void]$matchedSignals.Add([ordered]@{ signal = "alz-top-level-mgs"; points = $ptsTop; evidence = "$topLevel/4 canonical top-level MGs (Platform, Landing zones, Sandbox, Decommissioned)" }) }
if ($platChildren -gt 0) { [void]$matchedSignals.Add([ordered]@{ signal = "platform-children"; points = $ptsChildren; evidence = "$platChildren/3 platform children (Connectivity, Identity, Management)" }) }
if ($hasCorp -and $hasOnline) { [void]$matchedSignals.Add([ordered]@{ signal = "alz-lz-archetypes"; points = $ptsArchetypes; evidence = "Corp and Online MGs present under Landing zones" }) }
if ($platSubCount -gt 0) { [void]$matchedSignals.Add([ordered]@{ signal = "platform-subscriptions"; points = $ptsPlatSubs; evidence = "$platSubCount platform subscription(s) classified" }) }
if ($hasHubSpoke) { [void]$matchedSignals.Add([ordered]@{ signal = "hub-spoke-topology"; points = $ptsHubSpoke; evidence = "Hub VNet(s): $((@($hubs | ForEach-Object { Get-Prop $_ 'name' })) -join ', ')" }) }
if ($hubInConn) { [void]$matchedSignals.Add([ordered]@{ signal = "hub-in-connectivity-sub"; points = $ptsHubInConn; evidence = "Hub VNet sits in a connectivity-classified subscription" }) }
if ($alzPolCount -gt 0) { [void]$matchedSignals.Add([ordered]@{ signal = "alz-canonical-policies"; points = $ptsAlzPols; evidence = "$alzPolCount canonical ALZ policy assignment(s): $($alzPolList -join ', ')" }) }

$missingSignals = [System.Collections.ArrayList]::new()
if ($topLevel -lt 4) { [void]$missingSignals.Add("alz-top-level-mgs ($topLevel/4)") }
if ($platChildren -lt 3) { [void]$missingSignals.Add("platform-children ($platChildren/3)") }
if (-not ($hasCorp -and $hasOnline)) { [void]$missingSignals.Add("alz-lz-archetypes (Corp/Online MGs)") }
if ($platSubCount -lt 3) { [void]$missingSignals.Add("platform-subscriptions ($platSubCount/3+)") }
if (-not $hasHubSpoke) { [void]$missingSignals.Add("hub-spoke-topology") }
if (-not $hubInConn) { [void]$missingSignals.Add("hub-in-connectivity-sub") }
if ($alzPolCount -eq 0) { [void]$missingSignals.Add("alz-canonical-policies") }

$Detection = [ordered]@{
    isLandingZone   = ($score -ge 40)
    confidence      = $confidence
    confidenceScore = $score
    reference       = "https://azure.github.io/Azure-Landing-Zones/accelerator/"
    matchedSignals  = @($matchedSignals)
    missingSignals  = @($missingSignals)
    checks          = [ordered]@{
        topLevelMgs = [ordered]@{
            platform       = $hasPlatform
            landingZones   = $hasLandingZones
            sandbox        = $hasSandbox
            decommissioned = $hasDecommissioned
        }
        platformChildren = [ordered]@{
            connectivity = $hasConnectivity
            identity     = $hasIdentity
            management   = $hasManagement
        }
        lzChildren = [ordered]@{ corp = $hasCorp; online = $hasOnline }
        platformSubscriptionCount = $platSubCount
        hubSpoke = $hasHubSpoke
        hubInConnectivitySubscription = $hubInConn
        knownAlzPolicies = @($alzPolList)
    }
}

switch ($confidence) {
    "high"   { Write-Host "  Landing zone detection: " -NoNewline; Write-Host "high" -ForegroundColor Green -NoNewline; Write-Host " ($score/100) — canonical ALZ deployment" }
    "medium" { Write-Host "  Landing zone detection: " -NoNewline; Write-Host "medium" -ForegroundColor Green -NoNewline; Write-Host " ($score/100) — partial ALZ alignment" }
    "low"    { Write-Host "  Landing zone detection: " -NoNewline; Write-Host "low" -ForegroundColor Yellow -NoNewline; Write-Host " ($score/100) — some LZ signals" }
    default  { Write-Host "  Landing zone detection: " -NoNewline; Write-Host "none" -ForegroundColor Yellow -NoNewline; Write-Host " ($score/100) — no canonical signals" }
}

if ($Verbose) {
    Write-Host "  Matched signals:"
    $matchedSignals | ForEach-Object { Write-Host "    + $($_.points) pts — $($_.signal): $($_.evidence)" }
    if ($missingSignals.Count -gt 0) {
        Write-Host "  Missing signals:"
        $missingSignals | ForEach-Object { Write-Host "    - $_" }
    }
}
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# Assemble Output
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "Assembling landing zone context..." -ForegroundColor Blue

$ContextJson = [ordered]@{
    discoveredAt         = $DiscoveryTimestamp
    discoveryMethod      = "auto"
    landingZoneDetection = $Detection
    managementGroups     = [ordered]@{
        root                = $MgRoot
        hasManagementGroups = $HasManagementGroups
        hierarchy           = @($MgHierarchy)
    }
    subscriptions        = [ordered]@{
        platform     = @($PlatformSubs)
        landingZones = @($LzSubs)
    }
    sharedServices       = $SharedServices
    networking           = $Networking
    policies             = $Policies
    currentIdentity      = $IdentityJson
}

# ─────────────────────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────────────────────
if ($OutputFormat -eq "markdown") {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Landing Zone Discovery Report").AppendLine()
    [void]$sb.AppendLine("**Discovered:** $DiscoveryTimestamp  ")
    [void]$sb.AppendLine("**User:** $CurrentUser  ")
    [void]$sb.AppendLine("**Tenant:** $CurrentTenantId").AppendLine()

    [void]$sb.AppendLine("## Management Groups").AppendLine()
    if ($HasManagementGroups) {
        [void]$sb.AppendLine("Root: $MgRoot").AppendLine()
        [void]$sb.AppendLine("| Management Group | Role | ID |")
        [void]$sb.AppendLine("|------------------|------|----|")
        foreach ($mg in $MgHierarchy) {
            [void]$sb.AppendLine("| $($mg.displayName) | $($mg.role) | $($mg.name) |")
        }
    }
    else {
        [void]$sb.AppendLine("No management groups found (flat subscription model)")
    }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine("## Subscriptions").AppendLine()
    [void]$sb.AppendLine("### Platform").AppendLine()
    if ($PlatformSubs.Count -gt 0) {
        [void]$sb.AppendLine("| Name | Role | MG Path |")
        [void]$sb.AppendLine("|------|------|---------|")
        foreach ($s in $PlatformSubs) {
            $mg = if ($s.mgPath) { $s.mgPath } else { "N/A" }
            [void]$sb.AppendLine("| $($s.name) | $($s.role) | $mg |")
        }
    }
    else {
        [void]$sb.AppendLine("No platform subscriptions found")
    }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine("### Landing Zones").AppendLine()
    if ($LzSubs.Count -gt 0) {
        [void]$sb.AppendLine("| Name | Environment | MG Path |")
        [void]$sb.AppendLine("|------|-------------|---------|")
        foreach ($s in $LzSubs) {
            $env = if ($s.environment) { $s.environment } else { "N/A" }
            $mg = if ($s.mgPath) { $s.mgPath } else { "N/A" }
            [void]$sb.AppendLine("| $($s.name) | $env | $mg |")
        }
    }
    else {
        [void]$sb.AppendLine("No landing zone subscriptions found")
    }
    [void]$sb.AppendLine()

    $output = $sb.ToString()
    if ($OutputFile) { $output | Set-Content -Path $OutputFile -Encoding utf8 } else { Write-Host $output }
}
else {
    $json = $ContextJson | ConvertTo-Json -Depth 20
    if ($OutputFile) {
        $OutputDir = Split-Path -Parent $OutputFile
        if ($OutputDir -and -not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        $json | Set-Content -Path $OutputFile -Encoding utf8
        Write-Host "Landing zone context saved to: $OutputFile" -ForegroundColor Green
    }
    else {
        Write-Host $json
    }
}

Write-Host ""

# Summary
Write-Host "Discovery Summary:" -ForegroundColor Blue
if ($HasManagementGroups) {
    Write-Host "  Management Groups: " -NoNewline; Write-Host "$($MgHierarchy.Count) found" -ForegroundColor Green
}
else {
    Write-Host "  Management Groups: " -NoNewline; Write-Host "none (flat model)" -ForegroundColor Yellow
}
Write-Host "  Platform Subscriptions: " -NoNewline; Write-Host "$($PlatformSubs.Count)" -ForegroundColor Green
Write-Host "  Landing Zone Subscriptions: " -NoNewline; Write-Host "$($LzSubs.Count)" -ForegroundColor Green
$netSummary = if ($SkipNetwork) { "skipped" } else { $Topology }
Write-Host "  Network Topology: $netSummary"
$polSummary = if ($SkipPolicies) { "skipped" } else { "$(@($Policies.denyEffects).Count) deny-effect" }
Write-Host "  Policy Assignments: $polSummary"
Write-Host ""

if ($PartialFailure) {
    Write-Host "⚠️ Partial discovery — some targets could not be reached. Results are still usable." -ForegroundColor Yellow
    Write-Host "   Consider manual injection for missing data: .github/skills/azure-landing-zone-discovery/scripts/inject-lz.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Landing zone discovery complete" -ForegroundColor Green
exit 0
