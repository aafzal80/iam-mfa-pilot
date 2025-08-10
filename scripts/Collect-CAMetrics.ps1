<#
.SYNOPSIS
Enables/disables specified CA policies. Pre-checks Security Defaults and can disable it on request.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string[]]$PolicyNames,
  [ValidateSet('enabled','disabled','enabledForReportingButNotEnforced')]
  [string]$State = 'enabled',
  [switch]$AutoDisableSecurityDefaults
)

Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

if (-not (Get-MgContext)) {
  Connect-MgGraph -UseDeviceCode -Scopes 'Policy.Read.All','Policy.ReadWrite.ConditionalAccess'
}

function Get-SecurityDefaultsEnabled {
  try {
    $p = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy
    return [bool]$p.IsEnabled
  } catch {
    Write-Warning "Could not read Security Defaults: $($_.Exception.Message)"
    return $false
  }
}

# Pre-check
$sdEnabled = Get-SecurityDefaultsEnabled
if ($State -eq 'enabled' -and $sdEnabled) {
  Write-Warning "Security Defaults is enabled. You must disable it to enable CA policies."
  if ($AutoDisableSecurityDefaults) {
    try {
      Update-MgPolicyIdentitySecurityDefaultEnforcementPolicy -Identity 'securityDefaultsEnforcementPolicy' -IsEnabled:$false
      Write-Host "Security Defaults disabled." -ForegroundColor Yellow
    } catch {
      throw "Failed to disable Security Defaults automatically: $($_.Exception.Message)"
    }
  } else {
    Write-Host "Disable via portal: Entra → Identity → Properties → Manage security defaults → No → Save" -ForegroundColor DarkGray
    throw "Stop: Disable Security Defaults first or re-run with -AutoDisableSecurityDefaults."
  }
}

$all = Get-MgIdentityConditionalAccessPolicy -All
foreach ($name in $PolicyNames) {
  $p = $all | Where-Object DisplayName -eq $name
  if (-not $p) { Write-Warning "Policy not found: $name"; continue }
  Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $p.Id -BodyParameter @{ state=$State } | Out-Null
  Write-Host "Set '$name' -> $State"
}
