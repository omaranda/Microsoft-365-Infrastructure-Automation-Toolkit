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
    Removes specific forwarding rules from mailboxes in Microsoft 365.

.DESCRIPTION
    This script connects to Exchange Online and removes:
    - Inbox rules by name that forward messages
    - SMTP forwarding configuration (optional)
    Can target specific mailboxes or scan all mailboxes.

.PARAMETER RuleName
    Name of the inbox rule to remove. Supports wildcards (e.g., "*forward*")

.PARAMETER Mailbox
    Specific mailbox to target. If not specified, scans all mailboxes.

.PARAMETER RemoveSMTPForwarding
    Also remove SMTP forwarding configuration from mailboxes

.PARAMETER WhatIf
    Show what would be removed without actually removing it

.PARAMETER ExportLog
    Export removal log to CSV file

.PARAMETER LogPath
    Path for the log file (default: RuleRemoval_<timestamp>.csv)

.EXAMPLE
    .\Remove-MailboxForwardingRules.ps1 -RuleName "Forward to Gmail"
    Removes the specific rule from all mailboxes

.EXAMPLE
    .\Remove-MailboxForwardingRules.ps1 -RuleName "*forward*" -Mailbox "user@domain.com"
    Removes all rules containing "forward" from specific mailbox

.EXAMPLE
    .\Remove-MailboxForwardingRules.ps1 -RuleName "Auto Forward" -WhatIf
    Shows what would be removed without actually removing

.EXAMPLE
    .\Remove-MailboxForwardingRules.ps1 -Mailbox "user@domain.com" -RemoveSMTPForwarding
    Removes SMTP forwarding from specific mailbox
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$RuleName,

    [Parameter(Mandatory=$false)]
    [string]$Mailbox,

    [Parameter(Mandatory=$false)]
    [switch]$RemoveSMTPForwarding,

    [Parameter(Mandatory=$false)]
    [switch]$ExportLog,

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "RuleRemoval_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# Validate parameters
if (-not $RuleName -and -not $RemoveSMTPForwarding) {
    Write-Error "You must specify either -RuleName or -RemoveSMTPForwarding (or both)"
    exit 1
}

# Check if Exchange Online module is installed
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "ExchangeOnlineManagement module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
}

# Import the module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
try {
    Connect-ExchangeOnline -ShowBanner:$false
} catch {
    Write-Error "Failed to connect to Exchange Online: $_"
    exit 1
}

$removalLog = @()
$totalRemoved = 0

# Get mailboxes to process
if ($Mailbox) {
    Write-Host "Targeting specific mailbox: $Mailbox" -ForegroundColor Cyan
    $mailboxes = @(Get-Mailbox -Identity $Mailbox -ErrorAction Stop)
} else {
    Write-Host "Retrieving all mailboxes..." -ForegroundColor Cyan
    $mailboxes = Get-Mailbox -ResultSize Unlimited
}

$totalMailboxes = $mailboxes.Count
$currentCount = 0

foreach ($mbx in $mailboxes) {
    $currentCount++
    Write-Progress -Activity "Processing mailboxes" `
                   -Status "Checking $($mbx.UserPrincipalName)" `
                   -PercentComplete (($currentCount / $totalMailboxes) * 100)

    # Process inbox rules
    if ($RuleName) {
        $rules = Get-InboxRule -Mailbox $mbx.UserPrincipalName -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -like $RuleName }

        foreach ($rule in $rules) {
            # Check if it's a forwarding rule
            $isForwardingRule = $false
            $forwardingDetails = @()

            if ($rule.ForwardTo) {
                $isForwardingRule = $true
                $forwardingDetails += "ForwardTo: $($rule.ForwardTo -join ', ')"
            }
            if ($rule.ForwardAsAttachmentTo) {
                $isForwardingRule = $true
                $forwardingDetails += "ForwardAsAttachmentTo: $($rule.ForwardAsAttachmentTo -join ', ')"
            }
            if ($rule.RedirectTo) {
                $isForwardingRule = $true
                $forwardingDetails += "RedirectTo: $($rule.RedirectTo -join ', ')"
            }

            if ($isForwardingRule -or -not $RuleName) {
                $action = "Remove inbox rule"
                $status = "Skipped (WhatIf)"

                if ($PSCmdlet.ShouldProcess("$($mbx.UserPrincipalName)", "Remove inbox rule '$($rule.Name)'")) {
                    try {
                        Remove-InboxRule -Mailbox $mbx.UserPrincipalName -Identity $rule.Identity -Confirm:$false
                        Write-Host "[REMOVED] Rule '$($rule.Name)' from $($mbx.UserPrincipalName)" -ForegroundColor Green
                        $status = "Success"
                        $totalRemoved++
                    } catch {
                        Write-Host "[ERROR] Failed to remove rule '$($rule.Name)' from $($mbx.UserPrincipalName): $_" -ForegroundColor Red
                        $status = "Failed: $_"
                    }
                } else {
                    Write-Host "[WHATIF] Would remove rule '$($rule.Name)' from $($mbx.UserPrincipalName)" -ForegroundColor Yellow
                    Write-Host "  Details: $($forwardingDetails -join '; ')" -ForegroundColor Gray
                }

                $removalLog += [PSCustomObject]@{
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    Mailbox = $mbx.UserPrincipalName
                    DisplayName = $mbx.DisplayName
                    Action = $action
                    RuleName = $rule.Name
                    RuleEnabled = $rule.Enabled
                    ForwardingDetails = $forwardingDetails -join '; '
                    Status = $status
                }
            }
        }
    }

    # Process SMTP forwarding
    if ($RemoveSMTPForwarding) {
        $hasSMTPForwarding = $false
        $forwardingAddress = ""

        if ($mbx.ForwardingAddress) {
            $hasSMTPForwarding = $true
            $forwardingAddress = $mbx.ForwardingAddress
        } elseif ($mbx.ForwardingSmtpAddress) {
            $hasSMTPForwarding = $true
            $forwardingAddress = $mbx.ForwardingSmtpAddress
        }

        if ($hasSMTPForwarding) {
            $action = "Remove SMTP forwarding"
            $status = "Skipped (WhatIf)"

            if ($PSCmdlet.ShouldProcess("$($mbx.UserPrincipalName)", "Remove SMTP forwarding to $forwardingAddress")) {
                try {
                    Set-Mailbox -Identity $mbx.UserPrincipalName `
                                -ForwardingAddress $null `
                                -ForwardingSmtpAddress $null `
                                -DeliverToMailboxAndForward $false
                    Write-Host "[REMOVED] SMTP forwarding from $($mbx.UserPrincipalName) -> $forwardingAddress" -ForegroundColor Green
                    $status = "Success"
                    $totalRemoved++
                } catch {
                    Write-Host "[ERROR] Failed to remove SMTP forwarding from $($mbx.UserPrincipalName): $_" -ForegroundColor Red
                    $status = "Failed: $_"
                }
            } else {
                Write-Host "[WHATIF] Would remove SMTP forwarding from $($mbx.UserPrincipalName) -> $forwardingAddress" -ForegroundColor Yellow
            }

            $removalLog += [PSCustomObject]@{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Mailbox = $mbx.UserPrincipalName
                DisplayName = $mbx.DisplayName
                Action = $action
                RuleName = "N/A"
                RuleEnabled = "N/A"
                ForwardingDetails = "Forwarding to: $forwardingAddress"
                Status = $status
            }
        }
    }
}

Write-Progress -Activity "Processing mailboxes" -Completed

# Display summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Summary" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Total mailboxes scanned: $totalMailboxes" -ForegroundColor White

if ($WhatIfPreference) {
    Write-Host "Total rules that would be removed: $($removalLog.Count)" -ForegroundColor Yellow
    Write-Host "(This was a WhatIf run - nothing was actually removed)" -ForegroundColor Yellow
} else {
    Write-Host "Total items removed: $totalRemoved" -ForegroundColor Green
    Write-Host "Total operations logged: $($removalLog.Count)" -ForegroundColor White
}

# Display log
if ($removalLog.Count -gt 0) {
    Write-Host "`nRemoval Log:" -ForegroundColor Cyan
    $removalLog | Format-Table -AutoSize

    # Export log if requested
    if ($ExportLog) {
        $removalLog | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nLog exported to: $LogPath" -ForegroundColor Green
    }
} else {
    Write-Host "`nNo matching forwarding rules found." -ForegroundColor Yellow
}

# Disconnect
Write-Host "`nDisconnecting from Exchange Online..." -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "Done!" -ForegroundColor Green
