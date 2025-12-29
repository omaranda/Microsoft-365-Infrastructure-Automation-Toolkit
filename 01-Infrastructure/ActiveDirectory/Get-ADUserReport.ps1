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
    Generates comprehensive Active Directory user report.

.DESCRIPTION
    Creates detailed report of AD users including:
    - Account status and properties
    - Last logon information
    - Group memberships
    - Password status
    - Mailbox information

.PARAMETER ExportPath
    Path for CSV export

.PARAMETER IncludeDisabled
    Include disabled accounts in report

.EXAMPLE
    .\Get-ADUserReport.ps1
    .\Get-ADUserReport.ps1 -IncludeDisabled -ExportPath "C:\Reports\ADUsers.csv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "ADUserReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",

    [Parameter(Mandatory=$false)]
    [switch]$IncludeDisabled
)

Import-Module ActiveDirectory

Write-Host "Retrieving Active Directory users..." -ForegroundColor Cyan

$filter = if ($IncludeDisabled) { "*" } else { "Enabled -eq `$true" }
$users = Get-ADUser -Filter $filter -Properties *

$report = @()
foreach ($user in $users) {
    $report += [PSCustomObject]@{
        Username = $user.SamAccountName
        DisplayName = $user.DisplayName
        Email = $user.EmailAddress
        Enabled = $user.Enabled
        Created = $user.Created
        LastLogon = $user.LastLogonDate
        PasswordLastSet = $user.PasswordLastSet
        PasswordExpires = $user.PasswordExpired
        PasswordNeverExpires = $user.PasswordNeverExpires
        Department = $user.Department
        Title = $user.Title
        Manager = $user.Manager
        OU = $user.DistinguishedName -replace '^CN=.+?(?<!\\),'
    }
}

Write-Host "Found $($report.Count) users" -ForegroundColor Green
$report | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "Report exported to: $ExportPath" -ForegroundColor Green
