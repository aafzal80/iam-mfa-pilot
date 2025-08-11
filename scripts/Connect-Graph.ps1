# SPDX-License-Identifier: MIT
# Copyright (c) 2025 aafzal80
<#
.SYNOPSIS
Connects to Microsoft Graph with the correct scopes for this project.
#>

[CmdletBinding()]
param(
  [ValidateSet('Interactive','DeviceCode')]
  [string]$Method = 'Interactive'
)

if ($MaximumFunctionCount -lt 32768) { $MaximumFunctionCount = 32768 }

Write-Verbose "Importing Graph modules..."
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop
Import-Module Microsoft.Graph.Groups -ErrorAction Stop
Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
Import-Module Microsoft.Graph.Reports -ErrorAction SilentlyContinue

$scopes = @(
  'Policy.Read.All',
  'Policy.ReadWrite.ConditionalAccess',
  'Directory.ReadWrite.All',
  'Group.ReadWrite.All',
  'Application.Read.All',
  'AuditLog.Read.All'
)

Write-Verbose "Connecting with scopes: $($scopes -join ', ')"
if ($Method -eq 'DeviceCode') {
  Connect-MgGraph -Scopes $scopes -UseDeviceCode
} else {
  Connect-MgGraph -Scopes $scopes
}

$ctx = Get-MgContext
Write-Host ""
Write-Host "Connected as $($ctx.Account) in tenant $($ctx.TenantId)" -ForegroundColor Green
Write-Host "Scopes: $($ctx.Scopes -join ', ')" -ForegroundColor Green
Write-Host ""
Write-Host "Tip: If something acts weird, clear tokens:" -ForegroundColor DarkGray
Write-Host 'Remove-Item "$HOME\.mg\*.json" -ErrorAction SilentlyContinue' -ForegroundColor DarkGray

