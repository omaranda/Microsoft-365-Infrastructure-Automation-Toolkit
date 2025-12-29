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
    Lists all mailboxes with forwarding rules in Microsoft 365.

.DESCRIPTION
    This script connects to Exchange Online and identifies all mailboxes that have:
    - SMTP forwarding configured
    - Inbox rules that forward messages
    - Both types of forwarding

.PARAMETER ExportToCSV
    Export results to a CSV file

.PARAMETER CSVPath
    Path for the CSV export file (default: MailboxForwarding_<timestamp>.csv)

.EXAMPLE
    .\Get-MailboxForwardingRules.ps1
    Lists all forwarding rules to console

.EXAMPLE
    .\Get-MailboxForwardingRules.ps1 -ExportToCSV -CSVPath "C:\Reports\forwarding.csv"
    Exports forwarding rules to specified CSV file
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$ExportToCSV,

    [Parameter(Mandatory=$false)]
    [string]$CSVPath = "MailboxForwarding_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

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

Write-Host "Retrieving mailboxes..." -ForegroundColor Cyan
$results = @()

# Get all mailboxes
$mailboxes = Get-Mailbox -ResultSize Unlimited

$totalMailboxes = $mailboxes.Count
$currentCount = 0

foreach ($mailbox in $mailboxes) {
    $currentCount++
    Write-Progress -Activity "Scanning mailboxes for forwarding rules" `
                   -Status "Processing $($mailbox.UserPrincipalName)" `
                   -PercentComplete (($currentCount / $totalMailboxes) * 100)

    # Check SMTP forwarding
    $forwardingSMTP = $null
    $deliverToMailbox = $null

    if ($mailbox.ForwardingAddress) {
        $forwardingSMTP = $mailbox.ForwardingAddress
        $deliverToMailbox = $mailbox.DeliverToMailboxAndForward
    }

    if ($mailbox.ForwardingSmtpAddress) {
        $forwardingSMTP = $mailbox.ForwardingSmtpAddress
        $deliverToMailbox = $mailbox.DeliverToMailboxAndForward
    }

    # Check inbox rules for forwarding
    $inboxRules = Get-InboxRule -Mailbox $mailbox.UserPrincipalName -ErrorAction SilentlyContinue |
                  Where-Object {
                      $_.ForwardTo -or $_.ForwardAsAttachmentTo -or $_.RedirectTo
                  }

    # Add to results if any forwarding is found
    if ($forwardingSMTP -or $inboxRules) {
        foreach ($rule in $inboxRules) {
            $forwardingAddresses = @()

            if ($rule.ForwardTo) {
                $forwardingAddresses += $rule.ForwardTo -join '; '
            }
            if ($rule.ForwardAsAttachmentTo) {
                $forwardingAddresses += $rule.ForwardAsAttachmentTo -join '; '
            }
            if ($rule.RedirectTo) {
                $forwardingAddresses += $rule.RedirectTo -join '; '
            }

            $results += [PSCustomObject]@{
                Mailbox = $mailbox.UserPrincipalName
                DisplayName = $mailbox.DisplayName
                ForwardingType = "Inbox Rule"
                RuleName = $rule.Name
                RuleEnabled = $rule.Enabled
                ForwardingDestination = $forwardingAddresses -join '; '
                DeliverToMailbox = "N/A"
            }
        }

        # Add SMTP forwarding entry
        if ($forwardingSMTP) {
            $results += [PSCustomObject]@{
                Mailbox = $mailbox.UserPrincipalName
                DisplayName = $mailbox.DisplayName
                ForwardingType = "SMTP Forwarding"
                RuleName = "N/A"
                RuleEnabled = "N/A"
                ForwardingDestination = $forwardingSMTP
                DeliverToMailbox = $deliverToMailbox
            }
        }
    }
}

Write-Progress -Activity "Scanning mailboxes for forwarding rules" -Completed

# Display results
Write-Host "`nFound $($results.Count) forwarding rule(s) across $totalMailboxes mailboxes" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Gray

if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize

    # Export to CSV if requested
    if ($ExportToCSV) {
        $results | Export-Csv -Path $CSVPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nResults exported to: $CSVPath" -ForegroundColor Green
    }
} else {
    Write-Host "No forwarding rules found." -ForegroundColor Yellow
}

# Disconnect
Write-Host "`nDisconnecting from Exchange Online..." -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "Done!" -ForegroundColor Green
