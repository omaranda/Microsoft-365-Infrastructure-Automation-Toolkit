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
    List and remove guest users from Azure Active Directory.

.DESCRIPTION
    This script provides comprehensive management of Azure AD guest users:

    Features:
    - List all guest users with detailed information
    - Interactive selection mode for choosing which guests to remove
    - Delete specific guests by email or ID
    - Delete all guest users (with confirmation)
    - Export guest list to CSV for review before deletion
    - Filter by domain, creation date, or last sign-in
    - Identify stale guests (no sign-in for X days)
    - WhatIf support for safe preview
    - Detailed logging of all actions

    Information collected per guest:
    - Display Name
    - Email/UPN
    - Creation Date
    - Last Sign-In
    - Invited By
    - Company Name
    - Account Status

.PARAMETER ListOnly
    List all guest users without deleting (default behavior)

.PARAMETER ExportPath
    Export guest list to CSV file

.PARAMETER Interactive
    Interactive mode - select guests to delete from a list

.PARAMETER DeleteAll
    Delete ALL guest users (requires confirmation)

.PARAMETER DeleteByEmail
    Delete specific guest(s) by email address

.PARAMETER DeleteFromCSV
    Path to CSV file containing guests to delete (must have Email column)

.PARAMETER FilterDomain
    Filter guests by email domain (e.g., "gmail.com", "outlook.com")

.PARAMETER StaleGuests
    Show only stale guests (no sign-in for specified days)

.PARAMETER StaleDays
    Number of days to consider a guest as stale (default: 90)

.PARAMETER ExcludeDomains
    Domains to exclude from deletion (e.g., partner companies)

.PARAMETER Force
    Skip confirmation prompts (use with caution!)

.PARAMETER WhatIf
    Preview what would be deleted without making changes

.EXAMPLE
    .\Remove-GuestUsers.ps1 -ListOnly

    Lists all guest users with details

.EXAMPLE
    .\Remove-GuestUsers.ps1 -ListOnly -ExportPath "guests.csv"

    Exports all guest users to CSV file

.EXAMPLE
    .\Remove-GuestUsers.ps1 -Interactive

    Interactive mode to select and delete guests

.EXAMPLE
    .\Remove-GuestUsers.ps1 -DeleteByEmail "guest@gmail.com","guest2@outlook.com"

    Delete specific guests by email

.EXAMPLE
    .\Remove-GuestUsers.ps1 -StaleGuests -StaleDays 180 -Interactive

    Show guests with no sign-in for 180 days and select which to delete

.EXAMPLE
    .\Remove-GuestUsers.ps1 -FilterDomain "gmail.com" -DeleteAll

    Delete all guests with Gmail addresses

.EXAMPLE
    .\Remove-GuestUsers.ps1 -DeleteAll -ExcludeDomains "partner.com","vendor.com"

    Delete all guests except those from partner/vendor domains

.EXAMPLE
    .\Remove-GuestUsers.ps1 -DeleteFromCSV "guests-to-remove.csv"

    Delete guests listed in CSV file

.EXAMPLE
    .\Remove-GuestUsers.ps1 -DeleteAll -WhatIf

    Preview what would happen when deleting all guests
#>

[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='List')]
param(
    [Parameter(ParameterSetName='List')]
    [switch]$ListOnly,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath,

    [Parameter(ParameterSetName='Interactive')]
    [switch]$Interactive,

    [Parameter(ParameterSetName='DeleteAll')]
    [switch]$DeleteAll,

    [Parameter(ParameterSetName='DeleteByEmail')]
    [string[]]$DeleteByEmail,

    [Parameter(ParameterSetName='DeleteFromCSV')]
    [string]$DeleteFromCSV,

    [Parameter(Mandatory=$false)]
    [string]$FilterDomain,

    [Parameter(Mandatory=$false)]
    [switch]$StaleGuests,

    [Parameter(Mandatory=$false)]
    [int]$StaleDays = 90,

    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeDomains,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

#region Helper Functions

function Write-GuestLog {
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

function Get-GuestLastSignIn {
    param([object]$User)

    try {
        if ($User.SignInActivity -and $User.SignInActivity.LastSignInDateTime) {
            return $User.SignInActivity.LastSignInDateTime
        }
    } catch {
        # Sign-in activity not available
    }
    return $null
}

function Format-GuestInfo {
    param([object]$Guest)

    $lastSignIn = Get-GuestLastSignIn -User $Guest
    $daysSinceSignIn = if ($lastSignIn) {
        [math]::Round(((Get-Date) - $lastSignIn).TotalDays)
    } else {
        "Never"
    }

    return [PSCustomObject]@{
        DisplayName = $Guest.DisplayName
        Email = $Guest.Mail
        UserPrincipalName = $Guest.UserPrincipalName
        Id = $Guest.Id
        CreatedDateTime = $Guest.CreatedDateTime
        LastSignIn = $lastSignIn
        DaysSinceSignIn = $daysSinceSignIn
        CompanyName = $Guest.CompanyName
        AccountEnabled = $Guest.AccountEnabled
        UserType = $Guest.UserType
        ExternalUserState = $Guest.ExternalUserState
    }
}

function Show-GuestSelectionMenu {
    param([array]$Guests)

    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host "Select Guests to Delete" -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Enter the numbers of guests to delete (comma-separated), 'all' for all, or 'q' to quit:" -ForegroundColor Yellow
    Write-Host ""

    # Display numbered list
    $index = 1
    foreach ($guest in $Guests) {
        $signIn = if ($guest.LastSignIn) { $guest.LastSignIn.ToString("yyyy-MM-dd") } else { "Never" }
        $status = if ($guest.AccountEnabled) { "Active" } else { "Disabled" }

        Write-Host ("[{0,3}] " -f $index) -ForegroundColor White -NoNewline
        Write-Host ("{0,-30}" -f $guest.DisplayName.Substring(0, [Math]::Min(30, $guest.DisplayName.Length))) -ForegroundColor Gray -NoNewline
        Write-Host (" {0,-40}" -f $guest.Email.Substring(0, [Math]::Min(40, $guest.Email.Length))) -ForegroundColor DarkGray -NoNewline
        Write-Host (" Last: {0,-12}" -f $signIn) -ForegroundColor DarkYellow -NoNewline
        Write-Host (" [$status]" -f $status) -ForegroundColor $(if ($guest.AccountEnabled) { "Green" } else { "Red" })

        $index++
    }

    Write-Host ""
    Write-Host "─" * 100 -ForegroundColor Gray
    $selection = Read-Host "Selection"

    return $selection
}

function Confirm-Deletion {
    param(
        [int]$Count,
        [string]$Message = "Are you sure you want to delete $Count guest user(s)?"
    )

    if ($Force) {
        return $true
    }

    Write-Host ""
    Write-Host "⚠ WARNING: $Message" -ForegroundColor Red
    Write-Host ""
    $confirmation = Read-Host "Type 'YES' to confirm deletion"

    return ($confirmation -eq "YES")
}

#endregion

#region Main Script

Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Azure AD Guest User Management" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

# Check for required modules
$requiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Users'
)

Write-GuestLog "Checking required modules..." -Level "Info"
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-GuestLog "Required module not found: $module" -Level "Warning"
        Write-Host ""
        Write-Host "To install required modules, run:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser -Force" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

# Import modules
Write-GuestLog "Importing Microsoft Graph modules..." -Level "Info"
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Write-GuestLog "Modules imported successfully" -Level "Success"
} catch {
    Write-GuestLog "Failed to import modules: $_" -Level "Error"
    exit 1
}

# Connect to Microsoft Graph
Write-Host ""
Write-GuestLog "Connecting to Microsoft Graph..." -Level "Info"
$scopes = @(
    "User.ReadWrite.All",
    "Directory.ReadWrite.All",
    "AuditLog.Read.All"
)

try {
    Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
    Write-GuestLog "Successfully connected to Microsoft Graph" -Level "Success"
} catch {
    Write-GuestLog "Failed to connect to Microsoft Graph: $_" -Level "Error"
    exit 1
}

# Retrieve all guest users
Write-Host ""
Write-GuestLog "Retrieving guest users..." -Level "Info"

try {
    # Get guests with sign-in activity
    $allGuests = Get-MgUser -Filter "userType eq 'Guest'" -All -Property `
        Id, DisplayName, Mail, UserPrincipalName, CreatedDateTime, `
        CompanyName, AccountEnabled, UserType, ExternalUserState, `
        SignInActivity

    Write-GuestLog "Found $($allGuests.Count) total guest users" -Level "Success"
} catch {
    Write-GuestLog "Failed to retrieve guests: $_" -Level "Error"
    Disconnect-MgGraph | Out-Null
    exit 1
}

if ($allGuests.Count -eq 0) {
    Write-Host ""
    Write-GuestLog "No guest users found in the directory" -Level "Info"
    Disconnect-MgGraph | Out-Null
    exit 0
}

# Format guest information
$guestList = $allGuests | ForEach-Object { Format-GuestInfo -Guest $_ }

# Apply filters
$filteredGuests = $guestList

# Filter by domain
if ($FilterDomain) {
    Write-GuestLog "Filtering by domain: $FilterDomain" -Level "Info"
    $filteredGuests = $filteredGuests | Where-Object {
        $_.Email -like "*@$FilterDomain" -or $_.UserPrincipalName -like "*$FilterDomain*"
    }
    Write-GuestLog "Found $($filteredGuests.Count) guests matching domain filter" -Level "Info"
}

# Filter stale guests
if ($StaleGuests) {
    Write-GuestLog "Filtering stale guests (no sign-in for $StaleDays days)..." -Level "Info"
    $filteredGuests = $filteredGuests | Where-Object {
        $_.DaysSinceSignIn -eq "Never" -or $_.DaysSinceSignIn -ge $StaleDays
    }
    Write-GuestLog "Found $($filteredGuests.Count) stale guests" -Level "Info"
}

# Exclude domains
if ($ExcludeDomains) {
    Write-GuestLog "Excluding domains: $($ExcludeDomains -join ', ')" -Level "Info"
    foreach ($domain in $ExcludeDomains) {
        $filteredGuests = $filteredGuests | Where-Object {
            $_.Email -notlike "*@$domain" -and $_.UserPrincipalName -notlike "*$domain*"
        }
    }
    Write-GuestLog "Remaining guests after exclusion: $($filteredGuests.Count)" -Level "Info"
}

if ($filteredGuests.Count -eq 0) {
    Write-Host ""
    Write-GuestLog "No guests match the specified filters" -Level "Warning"
    Disconnect-MgGraph | Out-Null
    exit 0
}

# Display summary
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Guest User Summary" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host ""
Write-Host "Total Guests: $($guestList.Count)" -ForegroundColor White
Write-Host "Filtered Guests: $($filteredGuests.Count)" -ForegroundColor White

# Group by domain
$byDomain = $filteredGuests | Group-Object { ($_.Email -split '@')[1] } | Sort-Object Count -Descending
Write-Host ""
Write-Host "Top Domains:" -ForegroundColor White
$byDomain | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.Count) guests from $($_.Name)" -ForegroundColor Gray
}

# Stale guests count
$staleCount = ($filteredGuests | Where-Object { $_.DaysSinceSignIn -eq "Never" -or $_.DaysSinceSignIn -ge 90 }).Count
Write-Host ""
Write-Host "Stale Guests (90+ days): $staleCount" -ForegroundColor Yellow

# Export to CSV if requested
if ($ExportPath) {
    Write-Host ""
    Write-GuestLog "Exporting to CSV: $ExportPath" -Level "Info"
    try {
        $filteredGuests | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
        Write-GuestLog "Exported $($filteredGuests.Count) guests to $ExportPath" -Level "Success"
    } catch {
        Write-GuestLog "Failed to export: $_" -Level "Error"
    }
}

# Handle different modes
$guestsToDelete = @()

switch ($PSCmdlet.ParameterSetName) {
    'List' {
        # Just list the guests
        Write-Host ""
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host "Guest User List" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host ""

        $filteredGuests | Format-Table `
            @{L='Display Name'; E={$_.DisplayName}; W=25},
            @{L='Email'; E={$_.Email}; W=35},
            @{L='Created'; E={if($_.CreatedDateTime){$_.CreatedDateTime.ToString("yyyy-MM-dd")}else{"Unknown"}}; W=12},
            @{L='Last Sign-In'; E={if($_.LastSignIn){$_.LastSignIn.ToString("yyyy-MM-dd")}else{"Never"}}; W=12},
            @{L='Days'; E={$_.DaysSinceSignIn}; W=6},
            @{L='Status'; E={if($_.AccountEnabled){"Active"}else{"Disabled"}}; W=8} `
            -AutoSize

        Write-Host ""
        Write-GuestLog "Use -Interactive to select guests to delete" -Level "Info"
        Write-GuestLog "Use -ExportPath to export this list to CSV" -Level "Info"
    }

    'Interactive' {
        # Interactive selection mode
        $selection = Show-GuestSelectionMenu -Guests $filteredGuests

        if ($selection -eq 'q' -or $selection -eq 'Q') {
            Write-GuestLog "Operation cancelled by user" -Level "Info"
            Disconnect-MgGraph | Out-Null
            exit 0
        }

        if ($selection -eq 'all') {
            $guestsToDelete = $filteredGuests
        } else {
            # Parse comma-separated numbers
            $indices = $selection -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }

            foreach ($idx in $indices) {
                $num = [int]$idx
                if ($num -ge 1 -and $num -le $filteredGuests.Count) {
                    $guestsToDelete += $filteredGuests[$num - 1]
                }
            }
        }

        if ($guestsToDelete.Count -eq 0) {
            Write-GuestLog "No valid guests selected" -Level "Warning"
        }
    }

    'DeleteAll' {
        $guestsToDelete = $filteredGuests
    }

    'DeleteByEmail' {
        foreach ($email in $DeleteByEmail) {
            $guest = $filteredGuests | Where-Object { $_.Email -eq $email -or $_.UserPrincipalName -like "*$email*" }
            if ($guest) {
                $guestsToDelete += $guest
            } else {
                Write-GuestLog "Guest not found: $email" -Level "Warning"
            }
        }
    }

    'DeleteFromCSV' {
        if (-not (Test-Path $DeleteFromCSV)) {
            Write-GuestLog "CSV file not found: $DeleteFromCSV" -Level "Error"
            Disconnect-MgGraph | Out-Null
            exit 1
        }

        $csvGuests = Import-Csv $DeleteFromCSV

        foreach ($row in $csvGuests) {
            $email = $row.Email
            if (-not $email) { $email = $row.UserPrincipalName }
            if (-not $email) { $email = $row.email }

            if ($email) {
                $guest = $filteredGuests | Where-Object { $_.Email -eq $email -or $_.UserPrincipalName -like "*$email*" }
                if ($guest) {
                    $guestsToDelete += $guest
                } else {
                    Write-GuestLog "Guest not found: $email" -Level "Warning"
                }
            }
        }

        Write-GuestLog "Found $($guestsToDelete.Count) guests from CSV" -Level "Info"
    }
}

# Delete guests if any selected
if ($guestsToDelete.Count -gt 0) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Red
    Write-Host "Guests to Delete: $($guestsToDelete.Count)" -ForegroundColor Red
    Write-Host ("=" * 80) -ForegroundColor Red
    Write-Host ""

    # Show what will be deleted
    $guestsToDelete | ForEach-Object {
        Write-Host "  • $($_.DisplayName) <$($_.Email)>" -ForegroundColor Yellow
    }

    # Confirm deletion
    if (-not $WhatIfPreference -and (Confirm-Deletion -Count $guestsToDelete.Count)) {
        Write-Host ""
        Write-GuestLog "Starting deletion..." -Level "Info"

        $deleted = 0
        $failed = 0
        $logEntries = @()

        foreach ($guest in $guestsToDelete) {
            if ($PSCmdlet.ShouldProcess($guest.Email, "Delete guest user")) {
                try {
                    Remove-MgUser -UserId $guest.Id -ErrorAction Stop
                    Write-GuestLog "Deleted: $($guest.DisplayName) <$($guest.Email)>" -Level "Success"
                    $deleted++

                    $logEntries += [PSCustomObject]@{
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        Action = "Deleted"
                        DisplayName = $guest.DisplayName
                        Email = $guest.Email
                        UserId = $guest.Id
                        DeletedBy = (Get-MgContext).Account
                        Status = "Success"
                    }
                } catch {
                    Write-GuestLog "Failed to delete $($guest.Email): $_" -Level "Error"
                    $failed++

                    $logEntries += [PSCustomObject]@{
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        Action = "Delete Failed"
                        DisplayName = $guest.DisplayName
                        Email = $guest.Email
                        UserId = $guest.Id
                        DeletedBy = (Get-MgContext).Account
                        Status = "Failed: $_"
                    }
                }
            }
        }

        # Save deletion log
        $logPath = "GuestDeletion_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $logEntries | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8

        Write-Host ""
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host "Deletion Summary" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Deleted: $deleted" -ForegroundColor Green
        if ($failed -gt 0) {
            Write-Host "  Failed: $failed" -ForegroundColor Red
        }
        Write-Host "  Log saved to: $logPath" -ForegroundColor Gray
    } elseif ($WhatIfPreference) {
        Write-Host ""
        Write-GuestLog "WhatIf: Would delete $($guestsToDelete.Count) guest(s)" -Level "Warning"
    } else {
        Write-GuestLog "Deletion cancelled" -Level "Info"
    }
}

# Final summary
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-GuestLog "Operation completed" -Level "Success"
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

# Disconnect
Disconnect-MgGraph | Out-Null

#endregion
