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
    Finds users who haven't signed in for 90+ days, exports to CSV, uploads to SharePoint, and sends Teams message.

.DESCRIPTION
    This script:
    1. Connects to Microsoft Graph
    2. Retrieves all users and filters those inactive for 90+ days
    3. Exports the list to CSV
    4. Uploads the CSV to a specified SharePoint site
    5. Sends a Teams chat message to notify about the report

.PARAMETER InactiveDays
    Number of days to consider a user inactive (default: 90)

.PARAMETER SharePointSiteUrl
    SharePoint site URL (default: biometrioearth site)

.PARAMETER SharePointFolderPath
    Folder path within the SharePoint document library

.PARAMETER TeamsRecipientEmail
    Email address of the user to send Teams message to

.PARAMETER LocalExportPath
    Local path for CSV export (default: InactiveUsers_<timestamp>.csv)

.EXAMPLE
    .\Get-InactiveUsers-SharePoint-Teams.ps1 -TeamsRecipientEmail "admin@domain.com"

.EXAMPLE
    .\Get-InactiveUsers-SharePoint-Teams.ps1 -InactiveDays 60 -TeamsRecipientEmail "manager@domain.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$InactiveDays = 90,

    [Parameter(Mandatory=$false)]
    [string]$SharePointSiteUrl = "https://biometrioearth.sharepoint.com/sites/b.e",

    [Parameter(Mandatory=$false)]
    [string]$SharePointFolderPath = "/Freigegebene Dokumente/biometrio.earth/Technology/IT-Infrastructure/office365/general",

    [Parameter(Mandatory=$true)]
    [string]$TeamsRecipientEmail,

    [Parameter(Mandatory=$false)]
    [string]$LocalExportPath = "InactiveUsers_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# Check if required modules are installed
$requiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Sites',
    'Microsoft.Graph.Files',
    'Microsoft.Graph.Teams',
    'PnP.PowerShell'
)

Write-Host "Checking required modules..." -ForegroundColor Cyan
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        } catch {
            Write-Warning "Failed to install $module. Continuing..."
        }
    }
}

# Import modules
Write-Host "Importing modules..." -ForegroundColor Cyan
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Teams
Import-Module PnP.PowerShell

# Calculate cutoff date
$cutoffDate = (Get-Date).AddDays(-$InactiveDays)
Write-Host "Looking for users inactive since: $($cutoffDate.ToString('yyyy-MM-dd'))" -ForegroundColor White

# Connect to Microsoft Graph
Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan
$scopes = @(
    "User.Read.All",
    "AuditLog.Read.All",
    "Chat.Create",
    "Chat.ReadWrite",
    "Sites.ReadWrite.All",
    "Files.ReadWrite.All"
)

try {
    Connect-MgGraph -Scopes $scopes -NoWelcome
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    exit 1
}

# Get all users with sign-in activity
Write-Host "`nRetrieving all users with sign-in activity..." -ForegroundColor Cyan
try {
    $allUsers = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,SignInActivity,JobTitle,Department,Mail,UserType |
                Select-Object Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,SignInActivity,JobTitle,Department,Mail,UserType

    Write-Host "Retrieved $($allUsers.Count) users" -ForegroundColor White
} catch {
    Write-Error "Failed to retrieve users: $_"
    Disconnect-MgGraph
    exit 1
}

# Filter inactive users
Write-Host "Filtering inactive users..." -ForegroundColor Cyan
$inactiveUsers = @()

$totalUsers = $allUsers.Count
$currentCount = 0

foreach ($user in $allUsers) {
    $currentCount++
    Write-Progress -Activity "Analyzing user activity" `
                   -Status "Processing $($user.UserPrincipalName)" `
                   -PercentComplete (($currentCount / $totalUsers) * 100)

    # Skip guest users if desired (optional)
    # if ($user.UserType -eq "Guest") { continue }

    $lastSignIn = $null
    $lastNonInteractiveSignIn = $null
    $isInactive = $false

    if ($user.SignInActivity) {
        $lastSignIn = $user.SignInActivity.LastSignInDateTime
        $lastNonInteractiveSignIn = $user.SignInActivity.LastNonInteractiveSignInDateTime

        # Determine most recent sign-in
        $mostRecentSignIn = $lastSignIn
        if ($lastNonInteractiveSignIn -and (!$mostRecentSignIn -or $lastNonInteractiveSignIn -gt $mostRecentSignIn)) {
            $mostRecentSignIn = $lastNonInteractiveSignIn
        }

        # Check if inactive
        if ($mostRecentSignIn) {
            if ([DateTime]$mostRecentSignIn -lt $cutoffDate) {
                $isInactive = $true
            }
        } else {
            # No sign-in recorded
            $isInactive = $true
        }
    } else {
        # No sign-in activity at all
        $isInactive = $true
        $mostRecentSignIn = $null
    }

    if ($isInactive) {
        $daysSinceLastSignIn = if ($mostRecentSignIn) {
            ([DateTime]::Now - [DateTime]$mostRecentSignIn).Days
        } else {
            "Never"
        }

        $inactiveUsers += [PSCustomObject]@{
            DisplayName = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            Email = $user.Mail
            AccountEnabled = $user.AccountEnabled
            UserType = $user.UserType
            JobTitle = $user.JobTitle
            Department = $user.Department
            CreatedDate = if ($user.CreatedDateTime) { ([DateTime]$user.CreatedDateTime).ToString("yyyy-MM-dd") } else { "Unknown" }
            LastSignInDate = if ($mostRecentSignIn) { ([DateTime]$mostRecentSignIn).ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
            LastInteractiveSignIn = if ($lastSignIn) { ([DateTime]$lastSignIn).ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
            LastNonInteractiveSignIn = if ($lastNonInteractiveSignIn) { ([DateTime]$lastNonInteractiveSignIn).ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
            DaysSinceLastSignIn = $daysSinceLastSignIn
            InactiveDays = $InactiveDays
        }
    }
}

Write-Progress -Activity "Analyzing user activity" -Completed

# Display results
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Inactive Users Report" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Total users analyzed: $totalUsers" -ForegroundColor White
Write-Host "Inactive users found: $($inactiveUsers.Count)" -ForegroundColor Yellow
Write-Host "Criteria: No sign-in for $InactiveDays+ days" -ForegroundColor White
Write-Host ("=" * 80) -ForegroundColor Gray

if ($inactiveUsers.Count -eq 0) {
    Write-Host "`nNo inactive users found. Exiting..." -ForegroundColor Green
    Disconnect-MgGraph
    exit 0
}

# Group by account status
$enabledCount = ($inactiveUsers | Where-Object { $_.AccountEnabled -eq $true }).Count
$disabledCount = ($inactiveUsers | Where-Object { $_.AccountEnabled -eq $false }).Count

Write-Host "`nBy Account Status:" -ForegroundColor White
Write-Host "  Enabled: $enabledCount" -ForegroundColor $(if ($enabledCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Disabled: $disabledCount" -ForegroundColor Gray

# Group by department
$byDepartment = $inactiveUsers | Group-Object -Property Department | Sort-Object Count -Descending | Select-Object -First 5
if ($byDepartment) {
    Write-Host "`nTop 5 Departments:" -ForegroundColor White
    foreach ($dept in $byDepartment) {
        $deptName = if ($dept.Name) { $dept.Name } else { "(None)" }
        Write-Host "  ${deptName}: $($dept.Count)" -ForegroundColor Yellow
    }
}

# Export to CSV locally
Write-Host "`nExporting to local CSV: $LocalExportPath" -ForegroundColor Cyan
try {
    $inactiveUsers | Export-Csv -Path $LocalExportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Successfully exported to CSV" -ForegroundColor Green
} catch {
    Write-Error "Failed to export CSV: $_"
    Disconnect-MgGraph
    exit 1
}

# Display sample data
Write-Host "`nSample of inactive users:" -ForegroundColor Cyan
$inactiveUsers | Select-Object DisplayName, UserPrincipalName, LastSignInDate, DaysSinceLastSignIn, AccountEnabled -First 10 | Format-Table -AutoSize

# Upload to SharePoint using PnP PowerShell
Write-Host "`nUploading to SharePoint..." -ForegroundColor Cyan
try {
    # Connect to SharePoint site
    Write-Host "Connecting to SharePoint site: $SharePointSiteUrl" -ForegroundColor Cyan
    Connect-PnPOnline -Url $SharePointSiteUrl -Interactive

    # Upload file
    $fileName = [System.IO.Path]::GetFileName($LocalExportPath)
    Write-Host "Uploading file: $fileName" -ForegroundColor Cyan

    $uploadResult = Add-PnPFile -Path $LocalExportPath -Folder $SharePointFolderPath

    # Get the uploaded file URL
    $fileUrl = "$SharePointSiteUrl$SharePointFolderPath/$fileName"

    Write-Host "Successfully uploaded to SharePoint!" -ForegroundColor Green
    Write-Host "File URL: $fileUrl" -ForegroundColor White

    # Disconnect from SharePoint
    Disconnect-PnPOnline
} catch {
    Write-Error "Failed to upload to SharePoint: $_"
    Write-Host "The local file is still available at: $LocalExportPath" -ForegroundColor Yellow
    $fileUrl = $LocalExportPath
}

# Send Teams message
Write-Host "`nSending Teams message to $TeamsRecipientEmail..." -ForegroundColor Cyan
try {
    # Get the recipient user ID
    $recipient = Get-MgUser -Filter "userPrincipalName eq '$TeamsRecipientEmail'" -ErrorAction Stop

    if (-not $recipient) {
        throw "Recipient user not found: $TeamsRecipientEmail"
    }

    # Get current user (sender)
    $currentUser = Get-MgContext
    $sender = Get-MgUser -Filter "userPrincipalName eq '$($currentUser.Account)'"

    if (-not $sender) {
        throw "Could not get current user information"
    }

    $senderId = $sender.Id

    # Create chat message content
    $messageContent = @"
<h3>📊 Inactive Users Report Generated</h3>
<p><strong>Report Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
<p><strong>Criteria:</strong> Users with no sign-in for $InactiveDays+ days</p>
<br/>
<p><strong>Summary:</strong></p>
<ul>
<li>Total users analyzed: $totalUsers</li>
<li>Inactive users found: <strong>$($inactiveUsers.Count)</strong></li>
<li>Enabled accounts: $enabledCount</li>
<li>Disabled accounts: $disabledCount</li>
</ul>
<br/>
<p><strong>Report Location:</strong></p>
<p><a href='$fileUrl'>📎 View Report</a></p>
<br/>
<p><em>This is an automated report from the User Activity Monitoring system.</em></p>
"@

    # Try to find existing chat first
    Write-Host "Searching for existing chat conversation..." -ForegroundColor Cyan
    $chatId = $null

    try {
        $existingChats = Get-MgUserChat -UserId $senderId -All -ErrorAction Stop
        $chat = $existingChats | Where-Object {
            $_.ChatType -eq "oneOnOne" -and
            $_.Members.Count -eq 2 -and
            ($_.Members.AdditionalProperties.userId -contains $recipient.Id)
        } | Select-Object -First 1

        if ($chat) {
            $chatId = $chat.Id
            Write-Host "Found existing chat: $chatId" -ForegroundColor Green
        }
    } catch {
        Write-Host "Could not search existing chats: $_" -ForegroundColor Yellow
    }

    # Create new chat if not found
    if (-not $chatId) {
        Write-Host "Creating new chat conversation..." -ForegroundColor Cyan

        $chatParams = @{
            chatType = "oneOnOne"
            members = @(
                @{
                    "@odata.type" = "#microsoft.graph.aadUserConversationMember"
                    roles = @("owner")
                    "user@odata.bind" = "https://graph.microsoft.com/v1.0/users/$senderId"
                },
                @{
                    "@odata.type" = "#microsoft.graph.aadUserConversationMember"
                    roles = @("owner")
                    "user@odata.bind" = "https://graph.microsoft.com/v1.0/users/$($recipient.Id)"
                }
            )
        }

        try {
            $chat = New-MgChat -BodyParameter $chatParams -ErrorAction Stop
            $chatId = $chat.Id
            Write-Host "Created new chat: $chatId" -ForegroundColor Green
        } catch {
            Write-Error "Failed to create chat: $_"
            throw "Could not create or find chat conversation"
        }
    }

    # Send message to chat
    if ($chatId) {
        Write-Host "Sending message to chat..." -ForegroundColor Cyan

        $messageParams = @{
            Body = @{
                ContentType = "html"
                Content = $messageContent
            }
        }

        New-MgChatMessage -ChatId $chatId -BodyParameter $messageParams -ErrorAction Stop

        Write-Host "Successfully sent Teams message!" -ForegroundColor Green
    } else {
        throw "No valid chat ID available"
    }
} catch {
    Write-Error "Failed to send Teams message: $_"
    Write-Host "You can manually share the report from: $fileUrl" -ForegroundColor Yellow
}

# Cleanup and disconnect
Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Cyan
Disconnect-MgGraph

Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Script Completed Successfully!" -ForegroundColor Green
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Local CSV: $LocalExportPath" -ForegroundColor White
if ($fileUrl -ne $LocalExportPath) {
    Write-Host "SharePoint URL: $fileUrl" -ForegroundColor White
}
Write-Host "Teams message sent to: $TeamsRecipientEmail" -ForegroundColor White
Write-Host ("=" * 80) -ForegroundColor Gray
