# SPDX-License-Identifier: MIT
# Copyright (c) 2025 aafzal80
<#
.SYNOPSIS
Creates the canary group, trusted named location, and three CA policies in Report-only.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$TenantId,
  [string[]]$BreakGlassUpns = @(),
  [string[]]$CanaryMemberUpns = @('you@contoso.com'),
  [string]$CanaryGroupName = 'IAM-CA-Canary',
  [string]$TrustedLocationName = 'Trusted - Home IP'
)

if ($MaximumFunctionCount -lt 32768) { $MaximumFunctionCount = 32768 }

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop
Import-Module Microsoft.Graph.Groups -ErrorAction Stop
Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop

if (-not (Get-MgContext)) {
  Write-Verbose "Connecting to Graph (Device Code)..."
  Connect-MgGraph -TenantId $TenantId -UseDeviceCode -Scopes `
    'Policy.Read.All','Policy.ReadWrite.ConditionalAccess','Directory.ReadWrite.All','Group.ReadWrite.All','Application.Read.All','AuditLog.Read.All'
}

function Resolve-UserIds([string[]]$Upns){
  $ids = @()
  foreach ($u in $Upns) {
    try {
      $id = (Get-MgUser -UserId $u -ErrorAction Stop).Id
      $ids += $id
      Write-Verbose "Resolved $u -> $id"
    } catch {
      Write-Warning "User not found (skip): $u | $($_.Exception.Message)"
    }
  }
  return $ids
}

# 1) Canary group
Write-Verbose "Ensuring canary group '$CanaryGroupName' exists..."
$canary = Get-MgGroup -Filter "displayName eq '$CanaryGroupName'"
if (-not $canary) {
  $canary = New-MgGroup -DisplayName $CanaryGroupName -Description "Pilot group for Conditional Access" `
            -MailEnabled:$false -MailNickname "iamcacanary" -SecurityEnabled:$true
  Write-Host "Created group: $($canary.Id)"
} else {
  $canary = $canary[0]
  Write-Host "Found group: $($canary.Id)"
}

foreach ($upn in $CanaryMemberUpns) {
  try {
    $u = Get-MgUser -UserId $upn -ErrorAction Stop
    Add-MgGroupMember -GroupId $canary.Id -DirectoryObjectId $u.Id -ErrorAction SilentlyContinue
    Write-Host "Added canary member: $upn"
  } catch {
    Write-Warning "Could not add $upn: $($_.Exception.Message)"
  }
}

# 2) Trusted named location
Write-Verbose "Ensuring trusted named location '$TrustedLocationName' exists..."
try { $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 10).ip }
catch { $publicIp = Read-Host "Enter your public IP (e.g., 203.0.113.10)" }

$namedLoc = Get-MgIdentityConditionalAccessNamedLocation | Where-Object DisplayName -eq $TrustedLocationName
if (-not $namedLoc) {
  $params = @{
    ipNamedLocation = @{
      "@odata.type"="#microsoft.graph.ipNamedLocation"
      displayName   = $TrustedLocationName
      isTrusted     = $true
      ipRanges      = @(@{ "@odata.type"="#microsoft.graph.iPv4CidrRange"; cidrAddress="$publicIp/32" })
    }
  }
  $namedLoc = New-MgIdentityConditionalAccessNamedLocation -BodyParameter $params
  Write-Host "Created named location: $TrustedLocationName ($publicIp/32)"
} else {
  Write-Host "Named location exists: $TrustedLocationName"
}

# 3) CA policies (Report-only)
$breakGlassIds = Resolve-UserIds $BreakGlassUpns

Write-Verbose "Creating / ensuring three Report-only CA policies..."
# CA01: Block legacy auth
$paramsCA01 = @{
  displayName = "CA01 - Block legacy auth (Canary)"
  state       = "enabledForReportingButNotEnforced"
  conditions  = @{
    users         = @{ includeGroups=@($canary.Id); excludeUsers=@($breakGlassIds) }
    applications  = @{ includeApplications=@("All") }
    clientAppTypes= @("exchangeActiveSync","other")
  }
  grantControls = @{ operator="OR"; builtInControls=@("block") }
}
# CA02: Require MFA outside Trusted
$paramsCA02 = @{
  displayName = "CA02 - Require MFA all apps outside Trusted (Canary)"
  state       = "enabledForReportingButNotEnforced"
  conditions  = @{
    users         = @{ includeGroups=@($canary.Id); excludeUsers=@($breakGlassIds) }
    applications  = @{ includeApplications=@("All") }
    locations     = @{ includeLocations=@("All"); excludeLocations=@($namedLoc.Id) }
    clientAppTypes= @("browser","mobileAppsAndDesktopClients")
  }
  grantControls = @{ operator="OR"; builtInControls=@("mfa") }
}
# CA03: Require MFA for Azure management
$azureMgmtAppId = "797f4846-ba00-4fd7-ba43-dac1f8f63013"
$paramsCA03 = @{
  displayName = "CA03 - Require MFA for Azure management (Canary)"
  state       = "enabledForReportingButNotEnforced"
  conditions  = @{
    users         = @{ includeGroups=@($canary.Id); excludeUsers=@($breakGlassIds) }
    applications  = @{ includeApplications=@($azureMgmtAppId) }
    clientAppTypes= @("all")
  }
  grantControls = @{ operator="OR"; builtInControls=@("mfa") }
}

# Idempotent create (create if missing, otherwise leave as-is)
function Ensure-Policy([hashtable]$body){
  $name = $body.displayName
  $existing = Get-MgIdentityConditionalAccessPolicy -All | Where-Object DisplayName -eq $name
  if ($existing) {
    Write-Host "Policy exists: $name (State: $($existing.State))"
    return $existing
  } else {
    $new = New-MgIdentityConditionalAccessPolicy -BodyParameter $body
    Write-Host "Created (Report-only): $name"
    return $new
  }
}
$ca01 = Ensure-Policy $paramsCA01
$ca02 = Ensure-Policy $paramsCA02
$ca03 = Ensure-Policy $paramsCA03

Write-Host "Done. Validate in portal → Conditional Access → Policies (should show 3 in Report-only)."
