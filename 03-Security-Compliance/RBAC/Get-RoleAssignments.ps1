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
    Reports on Azure RBAC role assignments.

.DESCRIPTION
    Generates comprehensive RBAC reports:
    - Role assignments by scope
    - User and group role mappings
    - Privileged role assignments
    - Custom role definitions

.PARAMETER Scope
    Scope to analyze (subscription, resource group, or resource)

.PARAMETER IncludeCustomRoles
    Include custom role definitions

.PARAMETER ExportPath
    CSV export path

.EXAMPLE
    .\Get-RoleAssignments.ps1
    .\Get-RoleAssignments.ps1 -Scope "/subscriptions/xxxxx" -IncludeCustomRoles
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Scope,

    [Parameter(Mandatory=$false)]
    [switch]$IncludeCustomRoles,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "RBACAssignments_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Import-Module Az.Resources

# Connect to Azure
if (-not (Get-AzContext)) {
    Write-Host "Connecting to Azure..." -ForegroundColor Cyan
    Connect-AzAccount
}

Write-Host "Retrieving RBAC role assignments..." -ForegroundColor Cyan

# Get role assignments
if ($Scope) {
    $assignments = Get-AzRoleAssignment -Scope $Scope
} else {
    $assignments = Get-AzRoleAssignment
}

Write-Host "Found $($assignments.Count) role assignment(s)" -ForegroundColor White

$report = @()

foreach ($assignment in $assignments) {
    $report += [PSCustomObject]@{
        DisplayName = $assignment.DisplayName
        SignInName = $assignment.SignInName
        RoleDefinitionName = $assignment.RoleDefinitionName
        RoleDefinitionId = $assignment.RoleDefinitionId
        ObjectType = $assignment.ObjectType
        Scope = $assignment.Scope
        CanDelegate = $assignment.CanDelegate
    }
}

# Export assignments
$report | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "Assignments exported to: $ExportPath" -ForegroundColor Green

# Summary by role
Write-Host "`nAssignments by Role:" -ForegroundColor Cyan
$byRole = $report | Group-Object RoleDefinitionName | Sort-Object Count -Descending
$byRole | Format-Table Name, Count -AutoSize

# Privileged roles
$privilegedRoles = @("Owner", "Contributor", "User Access Administrator", "Global Administrator")
$privileged = $report | Where-Object { $privilegedRoles -contains $_.RoleDefinitionName }

if ($privileged.Count -gt 0) {
    Write-Host "`nPrivileged Role Assignments:" -ForegroundColor Yellow
    $privileged | Format-Table DisplayName, RoleDefinitionName, Scope -AutoSize
}

# Custom roles
if ($IncludeCustomRoles) {
    Write-Host "`nRetrieving custom roles..." -ForegroundColor Cyan
    $customRoles = Get-AzRoleDefinition | Where-Object { $_.IsCustom -eq $true }

    if ($customRoles.Count -gt 0) {
        Write-Host "Found $($customRoles.Count) custom role(s):" -ForegroundColor White
        $customRoles | Format-Table Name, Description -AutoSize

        $customRoles | Export-Csv -Path "CustomRoles_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
    }
}
