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
    Identify and remove unused Microsoft 365 licenses.

.DESCRIPTION
    This script helps reclaim unused Microsoft 365 licenses by:

    - Showing license usage summary (assigned vs available)
    - Identifying users with licenses who haven't signed in
    - Finding disabled accounts that still have licenses
    - Detecting inactive users (no sign-in for X days)
    - Removing licenses from inactive/disabled users
    - Generating reports for license optimization

    Use cases:
    - Reclaim licenses from departed employees
    - Clean up licenses from inactive accounts
    - Reduce license costs by identifying waste
    - Audit license assignments

.PARAMETER ListOnly
    Show license usage report without making changes (default)

.PARAMETER ShowInactiveUsers
    Show users with licenses who haven't signed in for specified days

.PARAMETER InactiveDays
    Number of days to consider a user inactive (default: 90)

.PARAMETER RemoveFromInactive
    Remove licenses from inactive users (requires confirmation)

.PARAMETER RemoveFromDisabled
    Remove licenses from disabled accounts

.PARAMETER SkuPartNumber
    Filter by specific license SKU (e.g., "O365_BUSINESS_PREMIUM", "SPE_E3")

.PARAMETER ExportPath
    Export report to CSV file

.PARAMETER Interactive
    Interactive mode to select which licenses to remove

.PARAMETER WhatIf
    Preview changes without applying

.EXAMPLE
    .\Remove-UnusedLicenses.ps1 -ListOnly

    Shows license usage summary

.EXAMPLE
    .\Remove-UnusedLicenses.ps1 -ShowInactiveUsers -InactiveDays 90

    Shows users with licenses who haven't signed in for 90 days

.EXAMPLE
    .\Remove-UnusedLicenses.ps1 -RemoveFromDisabled -WhatIf

    Preview removing licenses from disabled accounts

.EXAMPLE
    .\Remove-UnusedLicenses.ps1 -RemoveFromInactive -InactiveDays 180 -SkuPartNumber "O365_BUSINESS_PREMIUM"

    Remove Business Premium licenses from users inactive for 180+ days

.EXAMPLE
    .\Remove-UnusedLicenses.ps1 -Interactive

    Interactive mode to select which user licenses to remove
#>

[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='List')]
param(
    [Parameter(ParameterSetName='List')]
    [switch]$ListOnly,

    [Parameter(Mandatory=$false)]
    [switch]$ShowInactiveUsers,

    [Parameter(Mandatory=$false)]
    [int]$InactiveDays = 90,

    [Parameter(ParameterSetName='RemoveInactive')]
    [switch]$RemoveFromInactive,

    [Parameter(ParameterSetName='RemoveDisabled')]
    [switch]$RemoveFromDisabled,

    [Parameter(ParameterSetName='Interactive')]
    [switch]$Interactive,

    [Parameter(Mandatory=$false)]
    [string]$SkuPartNumber,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

#region Helper Functions

function Write-LicenseLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }

    $icon = switch ($Level) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error" { "✗" }
        default { "ℹ" }
    }

    Write-Host "[$timestamp] $icon $Message" -ForegroundColor $color
}

function Get-LicenseFriendlyName {
    param([string]$SkuPartNumber)

    $friendlyNames = @{
        "O365_BUSINESS_PREMIUM" = "Microsoft 365 Business Premium"
        "O365_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
        "O365_BUSINESS" = "Microsoft 365 Apps for Business"
        "SMB_BUSINESS_PREMIUM" = "Microsoft 365 Business Premium"
        "SMB_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
        "SPE_E3" = "Microsoft 365 E3"
        "SPE_E5" = "Microsoft 365 E5"
        "ENTERPRISEPACK" = "Office 365 E3"
        "ENTERPRISEPREMIUM" = "Office 365 E5"
        "EXCHANGESTANDARD" = "Exchange Online Plan 1"
        "EXCHANGEENTERPRISE" = "Exchange Online Plan 2"
        "POWER_BI_PRO" = "Power BI Pro"
        "POWER_BI_STANDARD" = "Power BI Free"
        "PROJECTPROFESSIONAL" = "Project Plan 3"
        "VISIOCLIENT" = "Visio Plan 2"
        "FLOW_FREE" = "Power Automate Free"
        "TEAMS_EXPLORATORY" = "Teams Exploratory"
        "STREAM" = "Microsoft Stream"
        "WINDOWS_STORE" = "Windows Store for Business"
        "AAD_PREMIUM" = "Azure AD Premium P1"
        "AAD_PREMIUM_P2" = "Azure AD Premium P2"
        "EMS" = "Enterprise Mobility + Security E3"
        "EMSPREMIUM" = "Enterprise Mobility + Security E5"
        "INTUNE_A" = "Intune"
        "ATP_ENTERPRISE" = "Microsoft Defender for Office 365 P1"
        "THREAT_INTELLIGENCE" = "Microsoft Defender for Office 365 P2"
        "STANDARDPACK" = "Office 365 E1"
    }

    if ($friendlyNames.ContainsKey($SkuPartNumber)) {
        return $friendlyNames[$SkuPartNumber]
    }
    return $SkuPartNumber
}

function Show-UserSelectionMenu {
    param([array]$Users)

    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host "Select Users to Remove Licenses" -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Enter numbers (comma-separated), 'all' for all, or 'q' to quit:" -ForegroundColor Yellow
    Write-Host ""

    $index = 1
    foreach ($user in $Users) {
        $signIn = if ($user.LastSignIn) { $user.LastSignIn.ToString("yyyy-MM-dd") } else { "Never" }
        $status = if ($user.AccountEnabled) { "Active" } else { "Disabled" }
        $statusColor = if ($user.AccountEnabled) { "Green" } else { "Red" }

        Write-Host ("[{0,3}] " -f $index) -ForegroundColor White -NoNewline
        Write-Host ("{0,-25}" -f $user.DisplayName.Substring(0, [Math]::Min(25, $user.DisplayName.Length))) -ForegroundColor Gray -NoNewline
        Write-Host (" {0,-30}" -f $user.Email.Substring(0, [Math]::Min(30, $user.Email.Length))) -ForegroundColor DarkGray -NoNewline
        Write-Host (" Last: {0,-12}" -f $signIn) -ForegroundColor DarkYellow -NoNewline
        Write-Host (" [{0}]" -f $status) -ForegroundColor $statusColor -NoNewline
        Write-Host (" $($user.Licenses)" -f $user.Licenses) -ForegroundColor Magenta

        $index++
    }

    Write-Host ""
    Write-Host "─" * 100 -ForegroundColor Gray
    $selection = Read-Host "Selection"

    return $selection
}

#endregion

#region Main Script

Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Microsoft 365 License Cleanup Tool" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

# Check for required modules
$requiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Identity.DirectoryManagement'
)

Write-LicenseLog "Checking required modules..." -Level "Info"
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-LicenseLog "Required module not found: $module" -Level "Warning"
        Write-Host ""
        Write-Host "To install required modules, run:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser -Force" -ForegroundColor White
        exit 1
    }
}

# Import modules
Write-LicenseLog "Importing Microsoft Graph modules..." -Level "Info"
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
    Write-LicenseLog "Modules imported successfully" -Level "Success"
} catch {
    Write-LicenseLog "Failed to import modules: $_" -Level "Error"
    exit 1
}

# Connect to Microsoft Graph
Write-Host ""
Write-LicenseLog "Connecting to Microsoft Graph..." -Level "Info"
$scopes = @(
    "User.ReadWrite.All",
    "Directory.ReadWrite.All",
    "Organization.Read.All",
    "AuditLog.Read.All"
)

try {
    Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
    Write-LicenseLog "Successfully connected to Microsoft Graph" -Level "Success"
} catch {
    Write-LicenseLog "Failed to connect to Microsoft Graph: $_" -Level "Error"
    exit 1
}

# Get license information
Write-Host ""
Write-LicenseLog "Retrieving license information..." -Level "Info"

try {
    $subscribedSkus = Get-MgSubscribedSku -All
    Write-LicenseLog "Found $($subscribedSkus.Count) license types" -Level "Success"
} catch {
    Write-LicenseLog "Failed to retrieve licenses: $_" -Level "Error"
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Display license summary
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "License Summary" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host ""

$licenseSummary = @()
$totalAvailable = 0
$totalAssigned = 0
$totalWasted = 0

foreach ($sku in $subscribedSkus) {
    $total = $sku.PrepaidUnits.Enabled
    $assigned = $sku.ConsumedUnits
    $available = $total - $assigned
    $friendlyName = Get-LicenseFriendlyName -SkuPartNumber $sku.SkuPartNumber

    # Skip if filtering by SKU and this doesn't match
    if ($SkuPartNumber -and $sku.SkuPartNumber -ne $SkuPartNumber) {
        continue
    }

    $licenseSummary += [PSCustomObject]@{
        SkuPartNumber = $sku.SkuPartNumber
        SkuId = $sku.SkuId
        FriendlyName = $friendlyName
        Total = $total
        Assigned = $assigned
        Available = $available
        PercentUsed = if ($total -gt 0) { [math]::Round(($assigned / $total) * 100, 1) } else { 0 }
    }

    $totalAvailable += $available
    $totalAssigned += $assigned

    # Display
    $usageColor = if ($available -gt 5) { "Green" } elseif ($available -gt 0) { "Yellow" } else { "Red" }

    Write-Host ("  {0,-45}" -f $friendlyName) -ForegroundColor White -NoNewline
    Write-Host ("Assigned: {0,3}/{1,-3}" -f $assigned, $total) -ForegroundColor Gray -NoNewline
    Write-Host ("  Available: {0,3}" -f $available) -ForegroundColor $usageColor
}

Write-Host ""
Write-Host "  ─" * 40 -ForegroundColor Gray
Write-Host ("  Total Licenses Assigned: $totalAssigned") -ForegroundColor White
Write-Host ("  Total Licenses Available: $totalAvailable") -ForegroundColor Green

# Get all licensed users with sign-in activity
Write-Host ""
Write-LicenseLog "Retrieving licensed users..." -Level "Info"

try {
    $licensedUsers = Get-MgUser -Filter "assignedLicenses/`$count ne 0" -All `
        -Property Id, DisplayName, UserPrincipalName, Mail, AccountEnabled, `
                  AssignedLicenses, SignInActivity, CreatedDateTime `
        -ConsistencyLevel eventual -CountVariable userCount

    Write-LicenseLog "Found $($licensedUsers.Count) users with licenses" -Level "Success"
} catch {
    Write-LicenseLog "Failed to retrieve users: $_" -Level "Error"
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Process users and identify inactive/disabled
$userLicenseInfo = @()
$inactiveUsers = @()
$disabledUsers = @()
$neverSignedIn = @()

foreach ($user in $licensedUsers) {
    # Get license names
    $userLicenses = @()
    foreach ($license in $user.AssignedLicenses) {
        $sku = $subscribedSkus | Where-Object { $_.SkuId -eq $license.SkuId }
        if ($sku) {
            $userLicenses += Get-LicenseFriendlyName -SkuPartNumber $sku.SkuPartNumber
        }
    }

    # Get last sign-in
    $lastSignIn = $null
    $daysSinceSignIn = "Never"
    if ($user.SignInActivity -and $user.SignInActivity.LastSignInDateTime) {
        $lastSignIn = $user.SignInActivity.LastSignInDateTime
        $daysSinceSignIn = [math]::Round(((Get-Date) - $lastSignIn).TotalDays)
    }

    $userInfo = [PSCustomObject]@{
        Id = $user.Id
        DisplayName = $user.DisplayName
        Email = if ($user.Mail) { $user.Mail } else { $user.UserPrincipalName }
        AccountEnabled = $user.AccountEnabled
        LastSignIn = $lastSignIn
        DaysSinceSignIn = $daysSinceSignIn
        Licenses = ($userLicenses -join ", ")
        LicenseSkuIds = ($user.AssignedLicenses | ForEach-Object { $_.SkuId })
        CreatedDateTime = $user.CreatedDateTime
    }

    $userLicenseInfo += $userInfo

    # Categorize
    if (-not $user.AccountEnabled) {
        $disabledUsers += $userInfo
    }

    if ($daysSinceSignIn -eq "Never") {
        $neverSignedIn += $userInfo
    } elseif ($daysSinceSignIn -ge $InactiveDays) {
        $inactiveUsers += $userInfo
    }
}

# Summary of potential savings
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Potential License Recovery" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host ""

Write-Host "  Disabled accounts with licenses:     $($disabledUsers.Count)" -ForegroundColor $(if ($disabledUsers.Count -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Users never signed in:               $($neverSignedIn.Count)" -ForegroundColor $(if ($neverSignedIn.Count -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Inactive users ($InactiveDays+ days):           $($inactiveUsers.Count)" -ForegroundColor $(if ($inactiveUsers.Count -gt 0) { "Yellow" } else { "Green" })

$potentialSavings = $disabledUsers.Count + $neverSignedIn.Count
Write-Host ""
Write-Host "  💰 Potential licenses to reclaim: $potentialSavings" -ForegroundColor Magenta

# Show inactive users if requested
if ($ShowInactiveUsers -or $Interactive -or $RemoveFromInactive) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Inactive Users (No sign-in for $InactiveDays+ days)" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host ""

    $targetUsers = @()
    $targetUsers += $inactiveUsers
    $targetUsers += $neverSignedIn | Where-Object { $_ -notin $inactiveUsers }

    if ($targetUsers.Count -eq 0) {
        Write-LicenseLog "No inactive users found" -Level "Info"
    } else {
        $targetUsers | Sort-Object DaysSinceSignIn -Descending | ForEach-Object {
            $status = if ($_.AccountEnabled) { "Active" } else { "Disabled" }
            $statusColor = if ($_.AccountEnabled) { "Gray" } else { "Red" }
            $signIn = if ($_.LastSignIn) { $_.LastSignIn.ToString("yyyy-MM-dd") } else { "Never" }

            Write-Host "  • " -NoNewline
            Write-Host ("{0,-25}" -f $_.DisplayName.Substring(0, [Math]::Min(25, $_.DisplayName.Length))) -ForegroundColor White -NoNewline
            Write-Host (" Last: {0,-12}" -f $signIn) -ForegroundColor DarkYellow -NoNewline
            Write-Host (" [{0}]" -f $status) -ForegroundColor $statusColor -NoNewline
            Write-Host (" $($_.Licenses)") -ForegroundColor DarkGray
        }
    }
}

# Export if requested
if ($ExportPath) {
    Write-Host ""
    Write-LicenseLog "Exporting to CSV: $ExportPath" -Level "Info"
    try {
        $userLicenseInfo | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
        Write-LicenseLog "Exported $($userLicenseInfo.Count) users to $ExportPath" -Level "Success"
    } catch {
        Write-LicenseLog "Failed to export: $_" -Level "Error"
    }
}

# Handle removal modes
$usersToProcess = @()

if ($RemoveFromDisabled) {
    $usersToProcess = $disabledUsers
    Write-Host ""
    Write-LicenseLog "Selected $($usersToProcess.Count) disabled users for license removal" -Level "Info"
}

if ($RemoveFromInactive) {
    $usersToProcess = $inactiveUsers + ($neverSignedIn | Where-Object { $_ -notin $inactiveUsers })
    Write-Host ""
    Write-LicenseLog "Selected $($usersToProcess.Count) inactive users for license removal" -Level "Info"
}

if ($Interactive) {
    $allCandidates = @()
    $allCandidates += $disabledUsers
    $allCandidates += $inactiveUsers | Where-Object { $_ -notin $disabledUsers }
    $allCandidates += $neverSignedIn | Where-Object { $_ -notin $disabledUsers -and $_ -notin $inactiveUsers }

    if ($allCandidates.Count -eq 0) {
        Write-LicenseLog "No candidates for license removal" -Level "Info"
    } else {
        $selection = Show-UserSelectionMenu -Users $allCandidates

        if ($selection -eq 'q' -or $selection -eq 'Q') {
            Write-LicenseLog "Operation cancelled" -Level "Info"
            Disconnect-MgGraph | Out-Null
            exit 0
        }

        if ($selection -eq 'all') {
            $usersToProcess = $allCandidates
        } else {
            $indices = $selection -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
            foreach ($idx in $indices) {
                $num = [int]$idx
                if ($num -ge 1 -and $num -le $allCandidates.Count) {
                    $usersToProcess += $allCandidates[$num - 1]
                }
            }
        }
    }
}

# Remove licenses
if ($usersToProcess.Count -gt 0) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Red
    Write-Host "Removing Licenses from $($usersToProcess.Count) Users" -ForegroundColor Red
    Write-Host ("=" * 80) -ForegroundColor Red
    Write-Host ""

    # Show what will be removed
    foreach ($user in $usersToProcess) {
        Write-Host "  • $($user.DisplayName) <$($user.Email)>" -ForegroundColor Yellow
        Write-Host "    Licenses: $($user.Licenses)" -ForegroundColor DarkGray
    }

    # Confirm
    if (-not $Force -and -not $WhatIfPreference) {
        Write-Host ""
        Write-Host "⚠ WARNING: This will remove licenses from $($usersToProcess.Count) user(s)" -ForegroundColor Red
        $confirmation = Read-Host "Type 'YES' to confirm"

        if ($confirmation -ne "YES") {
            Write-LicenseLog "Operation cancelled" -Level "Info"
            Disconnect-MgGraph | Out-Null
            exit 0
        }
    }

    # Process removals
    Write-Host ""
    $removed = 0
    $failed = 0
    $logEntries = @()

    foreach ($user in $usersToProcess) {
        if ($PSCmdlet.ShouldProcess($user.Email, "Remove licenses")) {
            try {
                # Remove all licenses
                $licensesToRemove = $user.LicenseSkuIds

                Set-MgUserLicense -UserId $user.Id `
                    -AddLicenses @() `
                    -RemoveLicenses $licensesToRemove `
                    -ErrorAction Stop

                Write-LicenseLog "Removed licenses from: $($user.DisplayName)" -Level "Success"
                $removed++

                $logEntries += [PSCustomObject]@{
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    Action = "License Removed"
                    User = $user.DisplayName
                    Email = $user.Email
                    Licenses = $user.Licenses
                    Status = "Success"
                }
            } catch {
                Write-LicenseLog "Failed to remove from $($user.Email): $_" -Level "Error"
                $failed++

                $logEntries += [PSCustomObject]@{
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    Action = "License Removal Failed"
                    User = $user.DisplayName
                    Email = $user.Email
                    Licenses = $user.Licenses
                    Status = "Failed: $_"
                }
            }
        }
    }

    # Save log
    $logPath = "LicenseRemoval_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $logEntries | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Summary" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Licenses Removed: $removed" -ForegroundColor Green
    if ($failed -gt 0) {
        Write-Host "  Failed: $failed" -ForegroundColor Red
    }
    Write-Host "  Log saved to: $logPath" -ForegroundColor Gray
}

# Final summary
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-LicenseLog "Operation completed" -Level "Success"
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

# Disconnect
Disconnect-MgGraph | Out-Null

#endregion
