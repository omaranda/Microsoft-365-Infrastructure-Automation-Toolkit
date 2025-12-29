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
    Automates Microsoft 365 license assignment and management.

.DESCRIPTION
    Bulk assigns or removes Microsoft 365 licenses:
    - License assignment based on user attributes
    - Department-based licensing
    - CSV-based bulk operations
    - License usage reporting

.PARAMETER CSVPath
    Path to CSV with users and licenses
    Columns: UserPrincipalName, LicenseSKU, Action (Add/Remove)

.PARAMETER LicenseSKU
    License SKU to assign (e.g., SPE_E3, SPE_E5)

.PARAMETER Department
    Assign licenses to all users in specified department

.EXAMPLE
    .\Set-M365Licenses.ps1 -CSVPath "licenses.csv"
    .\Set-M365Licenses.ps1 -LicenseSKU "SPE_E3" -Department "IT"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$CSVPath,

    [Parameter(Mandatory=$false)]
    [string]$LicenseSKU,

    [Parameter(Mandatory=$false)]
    [string]$Department
)

Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Identity.DirectoryManagement

Connect-MgGraph -Scopes "User.ReadWrite.All", "Organization.Read.All"

Write-Host "Managing Microsoft 365 Licenses" -ForegroundColor Cyan

# Get available licenses
$subscribedSkus = Get-MgSubscribedSku
Write-Host "`nAvailable Licenses:" -ForegroundColor White
foreach ($sku in $subscribedSkus) {
    $available = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
    Write-Host "  $($sku.SkuPartNumber): $available available (Total: $($sku.PrepaidUnits.Enabled))" -ForegroundColor Gray
}

$results = @()

if ($CSVPath) {
    # CSV-based bulk operation
    $users = Import-Csv -Path $CSVPath

    foreach ($user in $users) {
        Write-Host "`nProcessing: $($user.UserPrincipalName)" -ForegroundColor Yellow

        try {
            $mgUser = Get-MgUser -UserId $user.UserPrincipalName

            $sku = $subscribedSkus | Where-Object { $_.SkuPartNumber -eq $user.LicenseSKU }

            if ($user.Action -eq "Add") {
                Set-MgUserLicense -UserId $mgUser.Id -AddLicenses @{SkuId = $sku.SkuId} -RemoveLicenses @()
                Write-Host "  License assigned: $($user.LicenseSKU)" -ForegroundColor Green
                $status = "Success - Added"
            } else {
                Set-MgUserLicense -UserId $mgUser.Id -AddLicenses @() -RemoveLicenses @($sku.SkuId)
                Write-Host "  License removed: $($user.LicenseSKU)" -ForegroundColor Green
                $status = "Success - Removed"
            }

            $results += [PSCustomObject]@{
                User = $user.UserPrincipalName
                License = $user.LicenseSKU
                Action = $user.Action
                Status = $status
            }

        } catch {
            Write-Host "  Failed: $_" -ForegroundColor Red
            $results += [PSCustomObject]@{
                User = $user.UserPrincipalName
                License = $user.LicenseSKU
                Action = $user.Action
                Status = "Failed: $($_.Exception.Message)"
            }
        }
    }

} elseif ($Department -and $LicenseSKU) {
    # Department-based licensing
    Write-Host "`nAssigning $LicenseSKU to all users in $Department department" -ForegroundColor Yellow

    $users = Get-MgUser -Filter "department eq '$Department'" -All

    $sku = $subscribedSkus | Where-Object { $_.SkuPartNumber -eq $LicenseSKU }

    foreach ($user in $users) {
        try {
            Set-MgUserLicense -UserId $user.Id -AddLicenses @{SkuId = $sku.SkuId} -RemoveLicenses @()
            Write-Host "  Licensed: $($user.UserPrincipalName)" -ForegroundColor Green

            $results += [PSCustomObject]@{
                User = $user.UserPrincipalName
                License = $LicenseSKU
                Action = "Add"
                Status = "Success"
            }
        } catch {
            Write-Host "  Failed: $($user.UserPrincipalName) - $_" -ForegroundColor Red
            $results += [PSCustomObject]@{
                User = $user.UserPrincipalName
                License = $LicenseSKU
                Action = "Add"
                Status = "Failed: $_"
            }
        }
    }
}

# Export results
if ($results.Count -gt 0) {
    $results | Export-Csv -Path "LicenseAssignment_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
    Write-Host "`nResults exported to CSV" -ForegroundColor Green
    $results | Format-Table -AutoSize
}

Disconnect-MgGraph
