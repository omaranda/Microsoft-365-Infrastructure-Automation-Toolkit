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
    Installs all required PowerShell modules for Microsoft 365 administration.

.DESCRIPTION
    This script installs and updates all necessary PowerShell modules for:
    - Exchange Online Management
    - Microsoft Graph (Azure AD/Entra ID, Intune, Teams, SharePoint)
    - SharePoint Online (PnP PowerShell)
    - Microsoft Teams
    - Security & Compliance

.PARAMETER UpdateExisting
    Update existing modules to the latest version

.PARAMETER SkipPnP
    Skip installation of PnP.PowerShell module

.EXAMPLE
    .\Install-M365Dependencies.ps1
    Installs all required modules

.EXAMPLE
    .\Install-M365Dependencies.ps1 -UpdateExisting
    Installs and updates all modules to latest versions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$UpdateExisting,

    [Parameter(Mandatory=$false)]
    [switch]$SkipPnP
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Microsoft 365 PowerShell Module Installer" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $($psVersion.Major).$($psVersion.Minor).$($psVersion.Patch)" -ForegroundColor White

if ($psVersion.Major -lt 7) {
    Write-Host "WARNING: PowerShell 7+ is recommended for best compatibility" -ForegroundColor Yellow
    Write-Host "Current version: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Yellow
    Write-Host ""
}

# Define all required modules
$modules = @(
    @{
        Name = "ExchangeOnlineManagement"
        Description = "Exchange Online and Security & Compliance Center"
        Required = $true
    },
    @{
        Name = "Microsoft.Graph.Authentication"
        Description = "Microsoft Graph Authentication"
        Required = $true
    },
    @{
        Name = "Microsoft.Graph.Users"
        Description = "Microsoft Graph - User Management"
        Required = $true
    },
    @{
        Name = "Microsoft.Graph.Groups"
        Description = "Microsoft Graph - Group Management"
        Required = $true
    },
    @{
        Name = "Microsoft.Graph.DeviceManagement"
        Description = "Microsoft Graph - Intune Device Management"
        Required = $true
    },
    @{
        Name = "Microsoft.Graph.DeviceManagement.Enrolment"
        Description = "Microsoft Graph - Intune Enrollment"
        Required = $true
    },
    @{
        Name = "Microsoft.Graph.Teams"
        Description = "Microsoft Graph - Teams Management"
        Required = $true
    },
    @{
        Name = "Microsoft.Graph.Sites"
        Description = "Microsoft Graph - SharePoint Sites"
        Required = $true
    },
    @{
        Name = "Microsoft.Graph.Files"
        Description = "Microsoft Graph - File Management"
        Required = $true
    },
    @{
        Name = "Microsoft.Graph.Mail"
        Description = "Microsoft Graph - Mail Operations"
        Required = $true
    },
    @{
        Name = "MicrosoftTeams"
        Description = "Microsoft Teams PowerShell Module"
        Required = $true
    },
    @{
        Name = "PnP.PowerShell"
        Description = "SharePoint PnP PowerShell (for advanced SharePoint operations)"
        Required = $false
    }
)

# Filter out PnP if requested
if ($SkipPnP) {
    $modules = $modules | Where-Object { $_.Name -ne "PnP.PowerShell" }
    Write-Host "Skipping PnP.PowerShell installation" -ForegroundColor Yellow
    Write-Host ""
}

$totalModules = $modules.Count
$currentModule = 0
$installedCount = 0
$updatedCount = 0
$skippedCount = 0
$failedModules = @()

Write-Host "Modules to process: $totalModules" -ForegroundColor White
Write-Host ""

foreach ($module in $modules) {
    $currentModule++
    $moduleName = $module.Name
    $description = $module.Description

    Write-Progress -Activity "Installing Microsoft 365 Modules" `
                   -Status "Processing $moduleName ($currentModule of $totalModules)" `
                   -PercentComplete (($currentModule / $totalModules) * 100)

    Write-Host "[$currentModule/$totalModules] $moduleName" -ForegroundColor Cyan
    Write-Host "  Description: $description" -ForegroundColor Gray

    try {
        # Check if module is already installed
        $installedModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1

        if ($installedModule) {
            Write-Host "  Current version: $($installedModule.Version)" -ForegroundColor White

            if ($UpdateExisting) {
                Write-Host "  Checking for updates..." -ForegroundColor Yellow

                # Find latest version available
                try {
                    $latestModule = Find-Module -Name $moduleName -ErrorAction Stop

                    if ([version]$latestModule.Version -gt [version]$installedModule.Version) {
                        Write-Host "  Update available: $($latestModule.Version)" -ForegroundColor Yellow
                        Write-Host "  Updating module..." -ForegroundColor Yellow

                        Update-Module -Name $moduleName -Force -ErrorAction Stop
                        Write-Host "  ✓ Updated to version $($latestModule.Version)" -ForegroundColor Green
                        $updatedCount++
                    } else {
                        Write-Host "  ✓ Already at latest version" -ForegroundColor Green
                        $skippedCount++
                    }
                } catch {
                    Write-Host "  ⚠ Could not check for updates: $_" -ForegroundColor Yellow
                    $skippedCount++
                }
            } else {
                Write-Host "  ✓ Already installed (use -UpdateExisting to update)" -ForegroundColor Green
                $skippedCount++
            }
        } else {
            Write-Host "  Installing module..." -ForegroundColor Yellow

            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop

            $installedModule = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
            Write-Host "  ✓ Installed version $($installedModule.Version)" -ForegroundColor Green
            $installedCount++
        }
    } catch {
        Write-Host "  ✗ Failed to install: $_" -ForegroundColor Red
        $failedModules += @{
            Name = $moduleName
            Error = $_.Exception.Message
        }
    }

    Write-Host ""
}

Write-Progress -Activity "Installing Microsoft 365 Modules" -Completed

# Display summary
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""
Write-Host "Total modules processed: $totalModules" -ForegroundColor White
Write-Host "Newly installed: $installedCount" -ForegroundColor Green
Write-Host "Updated: $updatedCount" -ForegroundColor Green
Write-Host "Already installed/skipped: $skippedCount" -ForegroundColor Yellow
Write-Host "Failed: $($failedModules.Count)" -ForegroundColor $(if ($failedModules.Count -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($failedModules.Count -gt 0) {
    Write-Host "Failed Modules:" -ForegroundColor Red
    foreach ($failed in $failedModules) {
        Write-Host "  - $($failed.Name)" -ForegroundColor Red
        Write-Host "    Error: $($failed.Error)" -ForegroundColor Gray
    }
    Write-Host ""
}

# List installed modules
Write-Host "Installed Microsoft 365 Modules:" -ForegroundColor Cyan
Write-Host ""

$allInstalledModules = @()
foreach ($module in $modules) {
    $installed = Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1
    if ($installed) {
        $allInstalledModules += [PSCustomObject]@{
            Name = $module.Name
            Version = $installed.Version
            Description = $module.Description
        }
    }
}

$allInstalledModules | Format-Table -AutoSize

# Provide next steps
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Connect to Exchange Online:" -ForegroundColor White
Write-Host "   Connect-ExchangeOnline" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Connect to Microsoft Graph:" -ForegroundColor White
Write-Host "   Connect-MgGraph -Scopes 'User.Read.All','Group.ReadWrite.All'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Connect to Microsoft Teams:" -ForegroundColor White
Write-Host "   Connect-MicrosoftTeams" -ForegroundColor Gray
Write-Host ""

if (-not $SkipPnP) {
    Write-Host "4. Connect to SharePoint (PnP):" -ForegroundColor White
    Write-Host "   Connect-PnPOnline -Url 'https://yourtenant.sharepoint.com' -Interactive" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "Available scripts in this directory:" -ForegroundColor White
Write-Host "  - Get-MailboxForwardingRules.ps1" -ForegroundColor Gray
Write-Host "  - Remove-MailboxForwardingRules.ps1" -ForegroundColor Gray
Write-Host "  - Get-IntuneNonCompliantDevices.ps1" -ForegroundColor Gray
Write-Host "  - Get-InactiveUsers-SharePoint-Teams.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
