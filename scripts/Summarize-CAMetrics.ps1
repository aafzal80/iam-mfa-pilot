# SPDX-License-Identifier: MIT
# Copyright (c) 2025 aafzal80
<#
.SYNOPSIS
Compares before/after CSVs and writes a summary report with a resume bullet.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Before,
  [Parameter(Mandatory=$true)][string]$After,
  [string]$Out = 'summary.txt',
  [switch]$VerboseChecks
)

function Assert-File($path, $name){
  if (-not (Test-Path $path)) { throw "File not found: $name → $path" }
  $len = (Get-Item $path).Length
  if ($len -eq 0) { throw "File is empty: $name → $path" }
}

function Load-CsvSafe([string]$path, [string]$label){
  try {
    $rows = Import-Csv -Path $path
  } catch {
    throw "Failed to Import-Csv for $label ($path): $($_.Exception.Message)"
  }
  if ($VerboseChecks) {
    Write-Host "$label rows: $($rows.Count)"
    if ($rows.Count -gt 0) {
      Write-Host "$label headers: $((($rows[0] | Get-Member -MemberType NoteProperty).Name) -join ', ')"
    }
  }
  return $rows
}

function As-Bool($val){
  if ($null -eq $val) { return $false }
  $s = $val.ToString().Trim()
  return @('True','true','TRUE','1') -contains $s
}

# Preconditions
Assert-File $Before 'Before CSV'
Assert-File $After  'After CSV'

$before = Load-CsvSafe $Before 'Before'
$after  = Load-CsvSafe $After  'After'

foreach ($r in $before) { $r.IsLegacyClient = As-Bool $r.IsLegacyClient }
foreach ($r in $after ) { $r.IsLegacyClient = As-Bool $r.IsLegacyClient }

# Ensure required columns exist
$needed = @('ConditionalAccessStatus','IsLegacyClient')
foreach ($n in $needed){
  foreach ($set in @(@{Name='Before';Rows=$before}, @{Name='After';Rows=$after})) {
    if (-not ($set.Rows | Get-Member -Name $n -MemberType NoteProperty -ErrorAction SilentlyContinue)) {
      Write-Warning "$($set.Name) CSV missing column '$n'. Counting as zero."
      foreach ($r in $set.Rows) { Add-Member -InputObject $r -NotePropertyName $n -NotePropertyValue '' -Force }
    }
  }
}

# Tallies
$beforeTotal  = $before.Count
$afterTotal   = $after.Count
$beforeLegacy = ($before | Where-Object { $_.IsLegacyClient -eq $true }).Count
$afterLegacy  = ($after  | Where-Object { $_.IsLegacyClient -eq $true }).Count
$beforeCASucc = ($before | Where-Object { $_.ConditionalAccessStatus -eq 'success' }).Count
$afterCASucc  = ($after  | Where-Object { $_.ConditionalAccessStatus -eq 'success' }).Count
$beforeCAFail = ($before | Where-Object { $_.ConditionalAccessStatus -eq 'failure' }).Count
$afterCAFail  = ($after  | Where-Object { $_.ConditionalAccessStatus -eq 'failure' }).Count

$legacyDelta = $afterLegacy - $beforeLegacy
$legacyPct   = if ($beforeLegacy -gt 0) { [math]::Round((($beforeLegacy - $afterLegacy) / $beforeLegacy) * 100, 1) } else { if ($afterLegacy -eq 0) { 100 } else { 0 } }

$bullet = @()
$bullet += "Piloted Microsoft Entra Conditional Access (Report-only → Enforced) for a canary group with a break-glass guardrail;"
$bullet += " blocked legacy authentication ($beforeLegacy → $afterLegacy, ${legacyPct}% reduction) and enforced MFA for all cloud apps"
$bullet += " outside trusted locations and Azure management paths, with audit-ready before/after Graph sign-in metrics."

$report = @()
$report += "=== Conditional Access Pilot Summary ==="
$report += "Before  : Total=$beforeTotal | Legacy=$beforeLegacy | CA Success=$beforeCASucc | CA Failure=$beforeCAFail"
$report += "After   : Total=$afterTotal  | Legacy=$afterLegacy  | CA Success=$afterCASucc  | CA Failure=$afterCAFail"
$report += ""
$report += "Legacy delta (After - Before): $legacyDelta  | Reduction: ${legacyPct}%"
$report += ""
$report += "Resume bullet:"
$report += ($bullet -join '')

$report | Set-Content -Path $Out -Encoding UTF8
Write-Host ($report -join [Environment]::NewLine)
Write-Host "`nSaved $Out"

