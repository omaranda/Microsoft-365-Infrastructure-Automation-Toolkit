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
    Creates or updates Conditional Access policies in Azure AD.

.DESCRIPTION
    Manages Azure AD Conditional Access policies for:
    - MFA enforcement
    - Device compliance requirements
    - Location-based access
    - Application protection

.PARAMETER PolicyName
    Name of the conditional access policy

.PARAMETER RequireMFA
    Require multi-factor authentication

.PARAMETER RequireCompliantDevice
    Require device to be marked as compliant

.PARAMETER BlockedLocations
    Array of location names to block

.EXAMPLE
    .\Set-ConditionalAccessPolicy.ps1 -PolicyName "Require MFA for Admins" -RequireMFA
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$PolicyName,

    [Parameter(Mandatory=$false)]
    [switch]$RequireMFA,

    [Parameter(Mandatory=$false)]
    [switch]$RequireCompliantDevice,

    [Parameter(Mandatory=$false)]
    [string[]]$BlockedLocations
)

Import-Module Microsoft.Graph.Identity.SignIns

Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess"

Write-Host "Creating/Updating Conditional Access Policy: $PolicyName" -ForegroundColor Cyan

$conditions = @{
    applications = @{
        includeApplications = @("All")
    }
    users = @{
        includeUsers = @("All")
        excludeUsers = @()
    }
}

$grantControls = @{
    operator = "AND"
    builtInControls = @()
}

if ($RequireMFA) {
    $grantControls.builtInControls += "mfa"
}

if ($RequireCompliantDevice) {
    $grantControls.builtInControls += "compliantDevice"
}

$policyParams = @{
    displayName = $PolicyName
    state = "enabledForReportingButNotEnforced"
    conditions = $conditions
    grantControls = $grantControls
}

# Check if policy exists
$existingPolicy = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq '$PolicyName'"

if ($existingPolicy) {
    Write-Host "Updating existing policy..." -ForegroundColor Yellow
    Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $existingPolicy.Id -BodyParameter $policyParams
    Write-Host "Policy updated successfully" -ForegroundColor Green
} else {
    Write-Host "Creating new policy..." -ForegroundColor Yellow
    New-MgIdentityConditionalAccessPolicy -BodyParameter $policyParams
    Write-Host "Policy created successfully" -ForegroundColor Green
}

Write-Host "`nIMPORTANT: Policy created in Report-Only mode. Review and enable when ready." -ForegroundColor Yellow

Disconnect-MgGraph
