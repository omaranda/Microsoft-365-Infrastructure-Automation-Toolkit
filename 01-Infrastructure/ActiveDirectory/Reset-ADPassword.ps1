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
    Resets Active Directory user passwords.

.DESCRIPTION
    Reset passwords for AD users with options for:
    - Single user password reset
    - Bulk password resets from CSV
    - Force password change at next logon
    - Unlock account

.PARAMETER Username
    Username to reset password

.PARAMETER NewPassword
    New password (secure string)

.PARAMETER CSVPath
    CSV file with Username, NewPassword columns

.PARAMETER UnlockAccount
    Unlock account if locked

.PARAMETER MustChangePassword
    Force password change at next logon

.EXAMPLE
    .\Reset-ADPassword.ps1 -Username "jdoe" -UnlockAccount -MustChangePassword
    .\Reset-ADPassword.ps1 -CSVPath "passwords.csv"
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false, ParameterSetName="Single")]
    [string]$Username,

    [Parameter(Mandatory=$false, ParameterSetName="Single")]
    [SecureString]$NewPassword,

    [Parameter(Mandatory=$false, ParameterSetName="Bulk")]
    [string]$CSVPath,

    [Parameter(Mandatory=$false)]
    [switch]$UnlockAccount,

    [Parameter(Mandatory=$false)]
    [switch]$MustChangePassword = $true
)

Import-Module ActiveDirectory

$results = @()

function Reset-UserPassword {
    param(
        [string]$User,
        [SecureString]$Password
    )

    try {
        $adUser = Get-ADUser -Identity $User -Properties LockedOut

        # Generate random password if not provided
        if (-not $Password) {
            Add-Type -AssemblyName 'System.Web'
            $tempPassword = [System.Web.Security.Membership]::GeneratePassword(16, 4)
            $Password = ConvertTo-SecureString $tempPassword -AsPlainText -Force
            $passwordText = $tempPassword
        } else {
            $passwordText = "[Provided]"
        }

        if ($PSCmdlet.ShouldProcess($User, "Reset password")) {
            # Reset password
            Set-ADAccountPassword -Identity $adUser -NewPassword $Password -Reset

            # Set change password at logon
            if ($MustChangePassword) {
                Set-ADUser -Identity $adUser -ChangePasswordAtLogon $true
            }

            # Unlock account if needed
            if ($UnlockAccount -and $adUser.LockedOut) {
                Unlock-ADAccount -Identity $adUser
                Write-Host "[UNLOCKED] Account $User" -ForegroundColor Yellow
            }

            Write-Host "[SUCCESS] Password reset for $User" -ForegroundColor Green

            return [PSCustomObject]@{
                Username = $User
                Status = "Success"
                NewPassword = $passwordText
                PasswordChangeRequired = $MustChangePassword
                AccountUnlocked = ($UnlockAccount -and $adUser.LockedOut)
            }
        }
    } catch {
        Write-Host "[ERROR] Failed to reset password for $User : $_" -ForegroundColor Red
        return [PSCustomObject]@{
            Username = $User
            Status = "Failed: $_"
            NewPassword = "N/A"
            PasswordChangeRequired = $false
            AccountUnlocked = $false
        }
    }
}

if ($CSVPath) {
    # Bulk password reset
    Write-Host "Processing bulk password reset from CSV..." -ForegroundColor Cyan
    $users = Import-Csv -Path $CSVPath

    foreach ($user in $users) {
        $pwd = if ($user.NewPassword) {
            ConvertTo-SecureString $user.NewPassword -AsPlainText -Force
        } else {
            $null
        }

        $result = Reset-UserPassword -User $user.Username -Password $pwd
        $results += $result
    }

} else {
    # Single user
    if (-not $Username) {
        Write-Error "Username is required for single user password reset"
        exit 1
    }

    $result = Reset-UserPassword -User $Username -Password $NewPassword
    $results += $result
}

# Export results
if ($results.Count -gt 0) {
    $logPath = "PasswordReset_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $results | Export-Csv -Path $logPath -NoTypeInformation
    Write-Host "`nResults exported to: $logPath" -ForegroundColor Green
    Write-Host "WARNING: Protect this file - it contains passwords!" -ForegroundColor Red

    # Display results
    $results | Format-Table -AutoSize
}
