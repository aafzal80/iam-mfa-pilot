# SPDX-License-Identifier: MIT
# Copyright (c) 2025 aafzal80
<#
.SYNOPSIS
  Safely rolls back MFA pilot artifacts created by this repo.

.DESCRIPTION
  Disables pilot Conditional Access policies, removes the temporary named
  location, and (optionally) re-enables Security Defaults.

.EXAMPLE
  ./Rollback.ps1 -WhatIf
  ./Rollback.ps1 -ReEnableSecurityDefaults
  ./Rollback.ps1 -PolicyNames "MFA Pilot - Require MFA (Canary)","MFA Pilot - Block legacy auth (Canary)","MFA Pilot - Session controls (Canary)" -NamedLocation "MFA Pilot - Trusted Test Egress"
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
  [string[]]$PolicyNames = @(
    "MFA Pilot - Require MFA (Canary)",
    "MFA Pilot - Block legacy auth (Canary)",
    "MFA Pilot - Session controls (Canary)"
  ),
  [string]$NamedLocation = "MFA Pilot - Trusted Test Egress",
  [switch]$ReEnableSecurityDefaults
)

$ErrorActionPreference = 'Stop'

function Connect-GraphLeastPrivilege {
  $scopes = @(
    "Policy.ReadWrite.ConditionalAccess",
    "Policy.Read.All"
  )
  Write-Host "Connecting to Microsoft Graph with scopes: $($scopes -join ', ')"
  Connect-MgGraph -Scopes $scopes | Out-Null
  $profile = (Get-MgContext).GraphEndpoint
  Write-Host "Connected to: $profile"
}

function Disable-PilotPolicies {
  param([string[]]$Names)
  Write-Host "Disabling pilot Conditional Access policies..."
  $all = Get-MgIdentityConditionalAccessPolicy -All
  foreach ($name in $Names) {
    $policy = $all | Where-Object { $_.DisplayName -eq $name }
    if ($null -ne $policy) {
      if ($PSCmdlet.ShouldProcess($name, "Disable Conditional Access policy")) {
        Update-MgIdentityConditionalAccessPolicy `
          -ConditionalAccessPolicyId $policy.Id `
          -State "disabled" | Out-Null
        Write-Host "Disabled: $name"
      }
    } else {
      Write-Host "Not found (skipped): $name"
    }
  }
}

function Remove-TempNamedLocation {
  param([string]$Name)
  Write-Host "Removing temporary named location..."
  $nl = Get-MgIdentityConditionalAccessNamedLocation -All |
        Where-Object { $_.DisplayName -eq $Name }
  if ($null -ne $nl) {
    if ($PSCmdlet.ShouldProcess($Name, "Delete named location")) {
      Remove-MgIdentityConditionalAccessNamedLocation `
        -NamedLocationId $nl.Id -Confirm:$false
      Write-Host "Removed named location: $Name"
    }
  } else {
    Write-Host "Named location not found (skipped): $Name"
  }
}

function Enable-SecurityDefaultsIfRequested {
  if (-not $ReEnableSecurityDefaults) { return }
  Write-Host "Re-enabling Security Defaults..."
  $sd = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy
  if (-not $sd.IsEnabled) {
    if ($PSCmdlet.ShouldProcess("Security Defaults", "Enable")) {
      Update-MgPolicyIdentitySecurityDefaultEnforcementPolicy -IsEnabled:$true | Out-Null
      Write-Host "Security Defaults re-enabled."
    }
  } else {
    Write-Host "Security Defaults already enabled."
  }
}

try {
  Import-Module Microsoft.Graph -ErrorAction Stop
  Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
  # Named locations/policy cmdlets are exposed by the Identity.SignIns module in v1.0
  Connect-GraphLeastPrivilege
  Disable-PilotPolicies -Names $PolicyNames
  Remove-TempNamedLocation -Name $NamedLocation
  Enable-SecurityDefaultsIfRequested
  Write-Host "Rollback completed successfully."
}
catch {
  Write-Error $_
  throw
}
