<#
################################################################################
# Copyright (c) 2025 Omar Miranda
# All rights reserved.
#
# This script is provided "as is" without warranty of any kind, express or
# implied. Use at your own risk.
#
# Author: Omar Miranda
# Created: 2025
################################################################################
<#
.SYNOPSIS
    Generates comprehensive Group Policy Object report.

.DESCRIPTION
    Reports on all GPOs including:
    - GPO settings and configurations
    - Link locations
    - Permissions
    - Last modification

.PARAMETER ExportPath
    Path for HTML report

.EXAMPLE
    .\Get-GPOReport.ps1
    .\Get-GPOReport.ps1 -ExportPath "C:\Reports\GPO-Report.html"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "GPOReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
)

Import-Module GroupPolicy

Write-Host "Generating Group Policy Report..." -ForegroundColor Cyan

$domain = Get-ADDomain
Get-GPOReport -All -Domain $domain.DNSRoot -ReportType Html -Path $ExportPath

Write-Host "GPO report exported to: $ExportPath" -ForegroundColor Green

# Generate summary
$gpos = Get-GPO -All
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total GPOs: $($gpos.Count)" -ForegroundColor White

$gpoData = @()
foreach ($gpo in $gpos) {
    $links = (Get-GPO -Guid $gpo.Id).GpoLinks
    $gpoData += [PSCustomObject]@{
        Name = $gpo.DisplayName
        Status = $gpo.GpoStatus
        Created = $gpo.CreationTime
        Modified = $gpo.ModificationTime
        LinksCount = $links.Count
    }
}

$gpoData | Export-Csv -Path "GPOSummary_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
