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
    Bulk password reset for multiple users.

.DESCRIPTION
    Resets passwords for multiple users:
    - CSV input with usernames
    - Generate secure random passwords
    - Export credentials securely
    - Optionally email users
    - Unlock accounts

.PARAMETER CSVPath
    CSV file with Username column

.PARAMETER UnlockAccounts
    Unlock user accounts

.PARAMETER NotifyUsers
    Send password reset notification (requires email configuration)

.PARAMETER ExportPath
    Export path for new credentials

.EXAMPLE
    .\Reset-BulkPasswords.ps1 -CSVPath "users.csv" -UnlockAccounts
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$CSVPath,

    [Parameter(Mandatory=$false)]
    [switch]$UnlockAccounts,

    [Parameter(Mandatory=$false)]
    [switch]$NotifyUsers,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "PasswordReset_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Import-Module ActiveDirectory

if (-not (Test-Path $CSVPath)) {
    Write-Error "CSV file not found: $CSVPath"
    exit 1
}

$users = Import-Csv -Path $CSVPath
Write-Host "Processing $($users.Count) user(s) for password reset..." -ForegroundColor Cyan

$results = @()
$successCount = 0
$failCount = 0

foreach ($user in $users) {
    $username = $user.Username

    Write-Host "`nProcessing: $username" -ForegroundColor Yellow

    if ($PSCmdlet.ShouldProcess($username, "Reset password")) {
        try {
            # Get AD user
            $adUser = Get-ADUser -Identity $username -Properties LockedOut, EmailAddress

            # Generate random password
            Add-Type -AssemblyName 'System.Web'
            $newPassword = [System.Web.Security.Membership]::GeneratePassword(16, 4)
            $securePassword = ConvertTo-SecureString $newPassword -AsPlainText -Force

            # Reset password
            Set-ADAccountPassword -Identity $adUser -NewPassword $securePassword -Reset

            # Set to change at next logon
            Set-ADUser -Identity $adUser -ChangePasswordAtLogon $true

            # Unlock account if requested
            $wasUnlocked = $false
            if ($UnlockAccounts -and $adUser.LockedOut) {
                Unlock-ADAccount -Identity $adUser
                $wasUnlocked = $true
                Write-Host "  ✓ Account unlocked" -ForegroundColor Yellow
            }

            Write-Host "  ✓ Password reset successfully" -ForegroundColor Green

            $results += [PSCustomObject]@{
                Username = $username
                Email = $adUser.EmailAddress
                NewPassword = $newPassword
                Unlocked = $wasUnlocked
                Status = "Success"
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }

            $successCount++

        } catch {
            Write-Host "  ✗ Failed: $_" -ForegroundColor Red

            $results += [PSCustomObject]@{
                Username = $username
                Email = "N/A"
                NewPassword = "N/A"
                Unlocked = $false
                Status = "Failed: $_"
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }

            $failCount++
        }
    }
}

# Export results
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Password Reset Summary" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Total users: $($users.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })

$results | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "`nResults exported to: $ExportPath" -ForegroundColor Green
Write-Host "WARNING: This file contains passwords! Protect it appropriately." -ForegroundColor Red

# Display results
$results | Format-Table Username, Status, Unlocked -AutoSize

# Optional: Send notifications
if ($NotifyUsers) {
    Write-Host "`nEmail notifications would be sent here (not configured)" -ForegroundColor Yellow
    # Implement email sending logic here
}
