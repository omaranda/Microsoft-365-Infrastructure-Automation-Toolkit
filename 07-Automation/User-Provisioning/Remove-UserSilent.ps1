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
    Silently remove a user, their licenses, and all associated data without notifications.

.DESCRIPTION
    This script provides complete silent user offboarding:

    - Removes all Microsoft 365 licenses (reclaims them)
    - Blocks sign-in immediately
    - Removes from all groups
    - Revokes all sessions/tokens
    - Deletes the user account
    - No email notifications sent to anyone
    - Complete audit logging

    This is useful for:
    - Immediate terminations
    - Security incidents
    - Silent cleanup of accounts
    - Automated offboarding without notifications

.PARAMETER UserEmail
    Email address or UPN of the user to remove

.PARAMETER UserEmails
    Array of email addresses to remove multiple users

.PARAMETER FromCSV
    Path to CSV file with users to remove (must have Email or UserPrincipalName column)

.PARAMETER KeepLicense
    Don't remove licenses before deleting (not recommended)

.PARAMETER BlockOnly
    Only block sign-in, don't delete the user

.PARAMETER RemoveFromGroups
    Remove user from all groups before deletion

.PARAMETER RevokeTokens
    Revoke all active sessions and tokens

.PARAMETER BackupToCSV
    Export user data to CSV before deletion

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Preview changes without applying

.EXAMPLE
    .\Remove-UserSilent.ps1 -UserEmail "john.doe@contoso.com"

    Silently removes user, reclaims licenses, no notifications

.EXAMPLE
    .\Remove-UserSilent.ps1 -UserEmail "john.doe@contoso.com" -RevokeTokens -RemoveFromGroups

    Full cleanup: revoke sessions, remove from groups, then delete

.EXAMPLE
    .\Remove-UserSilent.ps1 -UserEmail "john.doe@contoso.com" -BlockOnly

    Only blocks sign-in without deleting (for investigation)

.EXAMPLE
    .\Remove-UserSilent.ps1 -UserEmails "user1@contoso.com","user2@contoso.com" -Force

    Remove multiple users without confirmation

.EXAMPLE
    .\Remove-UserSilent.ps1 -FromCSV "users-to-remove.csv" -BackupToCSV

    Remove users from CSV, backup their data first

.EXAMPLE
    .\Remove-UserSilent.ps1 -UserEmail "john.doe@contoso.com" -WhatIf

    Preview what would happen without making changes
#>

[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='Single')]
param(
    [Parameter(ParameterSetName='Single', Mandatory=$true)]
    [string]$UserEmail,

    [Parameter(ParameterSetName='Multiple', Mandatory=$true)]
    [string[]]$UserEmails,

    [Parameter(ParameterSetName='CSV', Mandatory=$true)]
    [string]$FromCSV,

    [Parameter(Mandatory=$false)]
    [switch]$KeepLicense,

    [Parameter(Mandatory=$false)]
    [switch]$BlockOnly,

    [Parameter(Mandatory=$false)]
    [switch]$RemoveFromGroups,

    [Parameter(Mandatory=$false)]
    [switch]$RevokeTokens,

    [Parameter(Mandatory=$false)]
    [switch]$BackupToCSV,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

#region Helper Functions

function Write-SilentLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Action")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Action" { "Magenta" }
        default { "Cyan" }
    }

    $icon = switch ($Level) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error" { "✗" }
        "Action" { "→" }
        default { "ℹ" }
    }

    Write-Host "[$timestamp] $icon $Message" -ForegroundColor $color
}

function Get-UserLicenseNames {
    param($User, $Skus)

    $licenseNames = @()
    foreach ($license in $User.AssignedLicenses) {
        $sku = $Skus | Where-Object { $_.SkuId -eq $license.SkuId }
        if ($sku) {
            $licenseNames += $sku.SkuPartNumber
        }
    }
    return $licenseNames -join ", "
}

function Remove-UserCompletely {
    param(
        [object]$User,
        [array]$Skus,
        [bool]$KeepLicense,
        [bool]$BlockOnly,
        [bool]$RemoveFromGroups,
        [bool]$RevokeTokens,
        [bool]$WhatIf
    )

    $result = [PSCustomObject]@{
        Email = $User.UserPrincipalName
        DisplayName = $User.DisplayName
        Actions = @()
        Success = $true
        Error = $null
    }

    Write-Host ""
    Write-Host "  Processing: $($User.DisplayName) <$($User.UserPrincipalName)>" -ForegroundColor Yellow

    try {
        # Step 1: Block sign-in
        Write-SilentLog "    Blocking sign-in..." -Level "Action"
        if (-not $WhatIf) {
            Update-MgUser -UserId $User.Id -AccountEnabled:$false -ErrorAction Stop
        }
        $result.Actions += "Sign-in blocked"
        Write-SilentLog "    Sign-in blocked" -Level "Success"

        # Step 2: Revoke tokens if requested
        if ($RevokeTokens) {
            Write-SilentLog "    Revoking all sessions..." -Level "Action"
            if (-not $WhatIf) {
                Revoke-MgUserSignInSession -UserId $User.Id -ErrorAction Stop
            }
            $result.Actions += "Sessions revoked"
            Write-SilentLog "    All sessions revoked" -Level "Success"
        }

        # Step 3: Remove from groups if requested
        if ($RemoveFromGroups) {
            Write-SilentLog "    Removing from groups..." -Level "Action"
            if (-not $WhatIf) {
                $memberOf = Get-MgUserMemberOf -UserId $User.Id -All
                $groupCount = 0
                foreach ($group in $memberOf) {
                    if ($group.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group') {
                        try {
                            Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $User.Id -ErrorAction SilentlyContinue
                            $groupCount++
                        } catch {
                            # Some groups may not allow removal
                        }
                    }
                }
                $result.Actions += "Removed from $groupCount groups"
                Write-SilentLog "    Removed from $groupCount groups" -Level "Success"
            }
        }

        # Step 4: Remove licenses
        if (-not $KeepLicense -and $User.AssignedLicenses.Count -gt 0) {
            Write-SilentLog "    Removing licenses..." -Level "Action"
            $licenseNames = Get-UserLicenseNames -User $User -Skus $Skus

            if (-not $WhatIf) {
                $licensesToRemove = $User.AssignedLicenses | ForEach-Object { $_.SkuId }
                Set-MgUserLicense -UserId $User.Id -AddLicenses @() -RemoveLicenses $licensesToRemove -ErrorAction Stop
            }
            $result.Actions += "Licenses removed: $licenseNames"
            Write-SilentLog "    Licenses removed: $licenseNames" -Level "Success"
        }

        # Step 5: Delete user (unless BlockOnly)
        if (-not $BlockOnly) {
            Write-SilentLog "    Deleting user account..." -Level "Action"
            if (-not $WhatIf) {
                Remove-MgUser -UserId $User.Id -ErrorAction Stop
            }
            $result.Actions += "User deleted"
            Write-SilentLog "    User account deleted" -Level "Success"
        } else {
            Write-SilentLog "    User blocked but NOT deleted (BlockOnly mode)" -Level "Warning"
            $result.Actions += "User blocked (not deleted)"
        }

    } catch {
        $result.Success = $false
        $result.Error = $_.Exception.Message
        Write-SilentLog "    Error: $_" -Level "Error"
    }

    return $result
}

#endregion

#region Main Script

Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Silent User Removal Tool" -ForegroundColor Cyan
Write-Host "Remove users without sending any notifications" -ForegroundColor Gray
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

# Check for required modules
$requiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Identity.DirectoryManagement'
)

Write-SilentLog "Checking required modules..." -Level "Info"
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-SilentLog "Required module not found: $module" -Level "Warning"
        Write-Host ""
        Write-Host "To install required modules, run:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser -Force" -ForegroundColor White
        exit 1
    }
}

# Import modules
Write-SilentLog "Importing Microsoft Graph modules..." -Level "Info"
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
    Write-SilentLog "Modules imported successfully" -Level "Success"
} catch {
    Write-SilentLog "Failed to import modules: $_" -Level "Error"
    exit 1
}

# Connect to Microsoft Graph
Write-Host ""
Write-SilentLog "Connecting to Microsoft Graph..." -Level "Info"
$scopes = @(
    "User.ReadWrite.All",
    "Directory.ReadWrite.All",
    "Group.ReadWrite.All",
    "Organization.Read.All"
)

try {
    Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
    Write-SilentLog "Successfully connected to Microsoft Graph" -Level "Success"
} catch {
    Write-SilentLog "Failed to connect to Microsoft Graph: $_" -Level "Error"
    exit 1
}

# Get license information for display
Write-SilentLog "Retrieving license information..." -Level "Info"
$subscribedSkus = Get-MgSubscribedSku -All

# Build list of users to process
$usersToRemove = @()

switch ($PSCmdlet.ParameterSetName) {
    'Single' {
        $usersToRemove = @($UserEmail)
    }
    'Multiple' {
        $usersToRemove = $UserEmails
    }
    'CSV' {
        if (-not (Test-Path $FromCSV)) {
            Write-SilentLog "CSV file not found: $FromCSV" -Level "Error"
            Disconnect-MgGraph | Out-Null
            exit 1
        }

        $csvData = Import-Csv $FromCSV
        foreach ($row in $csvData) {
            $email = $row.Email
            if (-not $email) { $email = $row.UserPrincipalName }
            if (-not $email) { $email = $row.email }
            if (-not $email) { $email = $row.UPN }

            if ($email) {
                $usersToRemove += $email
            }
        }

        Write-SilentLog "Found $($usersToRemove.Count) users in CSV" -Level "Info"
    }
}

if ($usersToRemove.Count -eq 0) {
    Write-SilentLog "No users specified" -Level "Error"
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Retrieve user details
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Users to Process" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host ""

$userObjects = @()
$backupData = @()

foreach ($email in $usersToRemove) {
    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$email'" `
            -Property Id, DisplayName, UserPrincipalName, Mail, AccountEnabled, `
                      AssignedLicenses, Department, JobTitle, CreatedDateTime `
            -ErrorAction Stop

        if ($user) {
            $licenseNames = Get-UserLicenseNames -User $user -Skus $subscribedSkus
            $status = if ($user.AccountEnabled) { "Active" } else { "Disabled" }
            $statusColor = if ($user.AccountEnabled) { "Green" } else { "Red" }

            Write-Host "  • " -NoNewline
            Write-Host ("{0,-30}" -f $user.DisplayName) -ForegroundColor White -NoNewline
            Write-Host (" [{0}]" -f $status) -ForegroundColor $statusColor -NoNewline
            Write-Host (" Licenses: $licenseNames") -ForegroundColor DarkGray

            $userObjects += $user

            # Backup data
            $backupData += [PSCustomObject]@{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                DisplayName = $user.DisplayName
                Email = $user.UserPrincipalName
                Department = $user.Department
                JobTitle = $user.JobTitle
                AccountEnabled = $user.AccountEnabled
                Licenses = $licenseNames
                CreatedDateTime = $user.CreatedDateTime
                RemovedBy = (Get-MgContext).Account
            }
        } else {
            Write-SilentLog "User not found: $email" -Level "Warning"
        }
    } catch {
        Write-SilentLog "Failed to retrieve user $email : $_" -Level "Error"
    }
}

if ($userObjects.Count -eq 0) {
    Write-SilentLog "No valid users found to process" -Level "Error"
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Show summary of actions
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Actions to Perform" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host ""
Write-Host "  ✓ Block sign-in immediately" -ForegroundColor White
if ($RevokeTokens) {
    Write-Host "  ✓ Revoke all active sessions/tokens" -ForegroundColor White
}
if ($RemoveFromGroups) {
    Write-Host "  ✓ Remove from all groups" -ForegroundColor White
}
if (-not $KeepLicense) {
    Write-Host "  ✓ Remove all licenses (reclaim them)" -ForegroundColor White
}
if ($BlockOnly) {
    Write-Host "  ⚠ Block only - user will NOT be deleted" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Delete user account permanently" -ForegroundColor Red
}
Write-Host ""
Write-Host "  📧 NO notifications will be sent" -ForegroundColor Magenta
Write-Host ""

# Backup to CSV if requested
if ($BackupToCSV) {
    $backupPath = "UserBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $backupData | Export-Csv -Path $backupPath -NoTypeInformation -Encoding UTF8
    Write-SilentLog "User data backed up to: $backupPath" -Level "Success"
}

# Confirm unless forced
if (-not $Force -and -not $WhatIfPreference) {
    Write-Host "⚠ WARNING: This will " -ForegroundColor Red -NoNewline
    if ($BlockOnly) {
        Write-Host "BLOCK" -ForegroundColor Yellow -NoNewline
    } else {
        Write-Host "PERMANENTLY DELETE" -ForegroundColor Red -NoNewline
    }
    Write-Host " $($userObjects.Count) user(s)" -ForegroundColor Red
    Write-Host ""
    $confirmation = Read-Host "Type 'YES' to confirm (no notifications will be sent)"

    if ($confirmation -ne "YES") {
        Write-SilentLog "Operation cancelled" -Level "Info"
        Disconnect-MgGraph | Out-Null
        exit 0
    }
}

# Process users
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Red
Write-Host "Processing Users" -ForegroundColor Red
Write-Host ("=" * 80) -ForegroundColor Red

$results = @()
$successCount = 0
$failCount = 0

foreach ($user in $userObjects) {
    $result = Remove-UserCompletely `
        -User $user `
        -Skus $subscribedSkus `
        -KeepLicense $KeepLicense `
        -BlockOnly $BlockOnly `
        -RemoveFromGroups $RemoveFromGroups `
        -RevokeTokens $RevokeTokens `
        -WhatIf $WhatIfPreference

    $results += $result

    if ($result.Success) {
        $successCount++
    } else {
        $failCount++
    }
}

# Save removal log
$logPath = "UserRemoval_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$logEntries = @()

foreach ($result in $results) {
    $logEntries += [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Email = $result.Email
        DisplayName = $result.DisplayName
        Actions = ($result.Actions -join "; ")
        Success = $result.Success
        Error = $result.Error
        RemovedBy = (Get-MgContext).Account
    }
}

$logEntries | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8

# Summary
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

if ($WhatIfPreference) {
    Write-Host "  [WHATIF MODE] No changes were made" -ForegroundColor Yellow
    Write-Host "  Would have processed: $($userObjects.Count) user(s)" -ForegroundColor Gray
} else {
    Write-Host "  Successfully processed: $successCount" -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host "  Failed: $failCount" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  📋 Removal log: $logPath" -ForegroundColor Gray
    if ($BackupToCSV) {
        Write-Host "  💾 Backup file: $backupPath" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "  🔇 No notifications were sent" -ForegroundColor Magenta
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-SilentLog "Operation completed" -Level "Success"
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

# Disconnect
Disconnect-MgGraph | Out-Null

#endregion
