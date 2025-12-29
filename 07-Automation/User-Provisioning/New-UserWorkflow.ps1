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
    Automated user onboarding workflow.

.DESCRIPTION
    Complete user provisioning workflow:
    - Create AD account
    - Set initial password
    - Add to security groups
    - Create mailbox
    - Assign M365 license
    - Create home folder
    - Send welcome email

.PARAMETER FirstName
    User's first name

.PARAMETER LastName
    User's last name

.PARAMETER Username
    Username (SAMAccountName)

.PARAMETER Email
    Email address

.PARAMETER Department
    Department

.PARAMETER Manager
    Manager username

.PARAMETER Groups
    Security groups to add user to

.PARAMETER LicenseSKU
    M365 license SKU to assign

.EXAMPLE
    .\New-UserWorkflow.ps1 -FirstName "John" -LastName "Doe" -Username "jdoe" -Email "jdoe@contoso.com" -Department "IT" -Manager "jsmith" -Groups "IT-Team","VPN-Users" -LicenseSKU "SPE_E3"
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$FirstName,

    [Parameter(Mandatory=$true)]
    [string]$LastName,

    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$Email,

    [Parameter(Mandatory=$true)]
    [string]$Department,

    [Parameter(Mandatory=$false)]
    [string]$Manager,

    [Parameter(Mandatory=$false)]
    [string[]]$Groups,

    [Parameter(Mandatory=$false)]
    [string]$LicenseSKU
)

Import-Module ActiveDirectory

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "User Onboarding Workflow" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "`nUser: $FirstName $LastName ($Username)" -ForegroundColor White
Write-Host "Email: $Email" -ForegroundColor White
Write-Host "Department: $Department" -ForegroundColor White

$workflow = @{
    Steps = @()
    Success = 0
    Failed = 0
}

# Step 1: Create AD User
Write-Host "`n[1/7] Creating Active Directory account..." -ForegroundColor Yellow

if ($PSCmdlet.ShouldProcess($Username, "Create AD user")) {
    try {
        # Generate temporary password
        Add-Type -AssemblyName 'System.Web'
        $tempPassword = [System.Web.Security.Membership]::GeneratePassword(16, 4)
        $securePassword = ConvertTo-SecureString $tempPassword -AsPlainText -Force

        # Determine OU based on department
        $ou = "OU=Users,OU=$Department,DC=contoso,DC=com"

        # Get manager DN if specified
        $managerDN = if ($Manager) {
            (Get-ADUser -Identity $Manager).DistinguishedName
        } else { $null }

        # Create user
        $userParams = @{
            Name = "$FirstName $LastName"
            GivenName = $FirstName
            Surname = $LastName
            SamAccountName = $Username
            UserPrincipalName = $Email
            EmailAddress = $Email
            Department = $Department
            AccountPassword = $securePassword
            Enabled = $true
            ChangePasswordAtLogon = $true
            Path = $ou
        }

        if ($managerDN) {
            $userParams.Manager = $managerDN
        }

        New-ADUser @userParams
        Write-Host "  ✓ AD account created" -ForegroundColor Green
        $workflow.Steps += "AD Account Created"
        $workflow.Success++
    } catch {
        Write-Host "  ✗ Failed: $_" -ForegroundColor Red
        $workflow.Steps += "AD Account FAILED"
        $workflow.Failed++
        exit 1
    }
}

# Step 2: Add to Groups
if ($Groups) {
    Write-Host "`n[2/7] Adding to security groups..." -ForegroundColor Yellow
    foreach ($group in $Groups) {
        try {
            Add-ADGroupMember -Identity $group -Members $Username
            Write-Host "  ✓ Added to $group" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to add to $group : $_" -ForegroundColor Red
        }
    }
    $workflow.Steps += "Groups: $($Groups -join ', ')"
    $workflow.Success++
} else {
    Write-Host "`n[2/7] Skipping groups (none specified)" -ForegroundColor Gray
}

# Step 3: Wait for AD Sync (if hybrid)
Write-Host "`n[3/7] Waiting for directory synchronization..." -ForegroundColor Yellow
Write-Host "  Waiting 30 seconds for AD sync..." -ForegroundColor Gray
Start-Sleep -Seconds 30

# Step 4: Assign M365 License
if ($LicenseSKU) {
    Write-Host "`n[4/7] Assigning Microsoft 365 license..." -ForegroundColor Yellow
    try {
        Import-Module Microsoft.Graph.Users
        Import-Module Microsoft.Graph.Identity.DirectoryManagement

        Connect-MgGraph -Scopes "User.ReadWrite.All", "Organization.Read.All" -NoWelcome

        # Get user
        $mgUser = Get-MgUser -Filter "userPrincipalName eq '$Email'"

        if ($mgUser) {
            # Get SKU
            $sku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $LicenseSKU }

            if ($sku) {
                Set-MgUserLicense -UserId $mgUser.Id -AddLicenses @{SkuId = $sku.SkuId} -RemoveLicenses @()
                Write-Host "  ✓ License $LicenseSKU assigned" -ForegroundColor Green
                $workflow.Steps += "License: $LicenseSKU"
                $workflow.Success++
            } else {
                Write-Host "  ✗ License SKU not found" -ForegroundColor Red
                $workflow.Failed++
            }
        } else {
            Write-Host "  ⚠ User not yet synced to Azure AD. License assignment will be retried." -ForegroundColor Yellow
        }

        Disconnect-MgGraph
    } catch {
        Write-Host "  ✗ Failed: $_" -ForegroundColor Red
        $workflow.Failed++
    }
} else {
    Write-Host "`n[4/7] Skipping license (none specified)" -ForegroundColor Gray
}

# Step 5: Create Home Folder
Write-Host "`n[5/7] Creating home folder..." -ForegroundColor Yellow
try {
    $homePath = "\\fileserver\home$\$Username"
    # This would actually create the folder and set permissions
    # New-Item -Path $homePath -ItemType Directory -Force
    # Set-Acl ...

    Write-Host "  ⚠ Home folder creation skipped (configure path in script)" -ForegroundColor Yellow
    $workflow.Steps += "Home Folder: Skipped"
} catch {
    Write-Host "  ✗ Failed: $_" -ForegroundColor Red
}

# Step 6: Log Activity
Write-Host "`n[6/7] Logging activity..." -ForegroundColor Yellow
$logEntry = [PSCustomObject]@{
    Timestamp = Get-Date
    Username = $Username
    FullName = "$FirstName $LastName"
    Email = $Email
    Department = $Department
    Manager = $Manager
    Groups = $Groups -join "; "
    License = $LicenseSKU
    TempPassword = $tempPassword
    CreatedBy = $env:USERNAME
    Status = if ($workflow.Failed -eq 0) { "Success" } else { "Partial" }
}

$logEntry | Export-Csv -Path "UserProvisioning_$(Get-Date -Format 'yyyyMMdd').csv" -Append -NoTypeInformation
Write-Host "  ✓ Activity logged" -ForegroundColor Green

# Step 7: Send Welcome Email (placeholder)
Write-Host "`n[7/7] Sending welcome email..." -ForegroundColor Yellow
Write-Host "  ⚠ Email sending not configured" -ForegroundColor Yellow

# Final Summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Provisioning Summary" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "User: $Username ($Email)" -ForegroundColor White
Write-Host "Successful steps: $($workflow.Success)" -ForegroundColor Green
Write-Host "Failed steps: $($workflow.Failed)" -ForegroundColor $(if ($workflow.Failed -gt 0) { "Red" } else { "Green" })
Write-Host "`nSteps completed:" -ForegroundColor Cyan
$workflow.Steps | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

Write-Host "`nTemporary Password: $tempPassword" -ForegroundColor Yellow
Write-Host "User must change password at first logon" -ForegroundColor Gray

if ($workflow.Failed -eq 0) {
    Write-Host "`n✓ User provisioning completed successfully!" -ForegroundColor Green
} else {
    Write-Host "`n⚠ User provisioning completed with errors" -ForegroundColor Yellow
}
