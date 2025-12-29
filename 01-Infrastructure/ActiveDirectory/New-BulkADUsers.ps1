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
    Creates multiple Active Directory users from CSV file.

.DESCRIPTION
    Bulk creates AD users with:
    - Account creation
    - Password setting
    - Group membership assignment
    - OU placement

.PARAMETER CSVPath
    Path to CSV file with user data
    Required columns: FirstName, LastName, Username, Email, Department, OU

.PARAMETER DefaultPassword
    Default password for new accounts

.EXAMPLE
    .\New-BulkADUsers.ps1 -CSVPath "users.csv" -DefaultPassword "Welcome2024!"
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$CSVPath,

    [Parameter(Mandatory=$true)]
    [SecureString]$DefaultPassword
)

Import-Module ActiveDirectory

$users = Import-Csv -Path $CSVPath
$results = @()

foreach ($user in $users) {
    if ($PSCmdlet.ShouldProcess($user.Username, "Create AD user")) {
        try {
            $params = @{
                Name = "$($user.FirstName) $($user.LastName)"
                GivenName = $user.FirstName
                Surname = $user.LastName
                SamAccountName = $user.Username
                UserPrincipalName = "$($user.Username)@$((Get-ADDomain).DNSRoot)"
                EmailAddress = $user.Email
                Department = $user.Department
                Path = $user.OU
                AccountPassword = $DefaultPassword
                Enabled = $true
                ChangePasswordAtLogon = $true
            }

            New-ADUser @params
            Write-Host "[SUCCESS] Created user: $($user.Username)" -ForegroundColor Green

            $results += [PSCustomObject]@{
                Username = $user.Username
                Status = "Success"
                Message = "User created successfully"
            }
        } catch {
            Write-Host "[ERROR] Failed to create $($user.Username): $_" -ForegroundColor Red
            $results += [PSCustomObject]@{
                Username = $user.Username
                Status = "Failed"
                Message = $_.Exception.Message
            }
        }
    }
}

$results | Export-Csv -Path "UserCreation_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
Write-Host "`nCompleted. See log file for details." -ForegroundColor Green
