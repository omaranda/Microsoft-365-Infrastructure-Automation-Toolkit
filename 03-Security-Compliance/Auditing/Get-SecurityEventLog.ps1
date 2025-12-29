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
    Analyzes Windows Security Event Logs for suspicious activities.

.DESCRIPTION
    Monitors and reports on:
    - Failed login attempts
    - Account lockouts
    - Privilege escalation
    - Unauthorized access attempts
    - Group membership changes

.PARAMETER Hours
    Number of hours to look back (default: 24)

.PARAMETER ExportPath
    Path for CSV export

.EXAMPLE
    .\Get-SecurityEventLog.ps1
    .\Get-SecurityEventLog.ps1 -Hours 48 -ExportPath "C:\Reports\Security.csv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$Hours = 24,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "SecurityEvents_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

$startTime = (Get-Date).AddHours(-$Hours)
Write-Host "Analyzing Security Event Log from $startTime" -ForegroundColor Cyan

$events = @()

# Event IDs to monitor
$criticalEvents = @{
    4625 = "Failed Login"
    4740 = "Account Lockout"
    4720 = "User Account Created"
    4726 = "User Account Deleted"
    4728 = "User Added to Security Group"
    4732 = "User Added to Local Group"
    4756 = "User Added to Universal Security Group"
    4672 = "Special Privileges Assigned"
    4768 = "Kerberos TGT Requested"
    4771 = "Kerberos Pre-Auth Failed"
}

Write-Host "Searching for critical events..." -ForegroundColor Yellow

foreach ($eventId in $criticalEvents.Keys) {
    $eventType = $criticalEvents[$eventId]
    Write-Host "  Checking: $eventType (Event ID $eventId)" -ForegroundColor Gray

    $foundEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        Id = $eventId
        StartTime = $startTime
    } -ErrorAction SilentlyContinue

    if ($foundEvents) {
        foreach ($event in $foundEvents) {
            $events += [PSCustomObject]@{
                Time = $event.TimeCreated
                EventID = $event.Id
                EventType = $eventType
                Computer = $event.MachineName
                User = $event.Properties[5].Value
                Message = $event.Message.Substring(0, [Math]::Min(200, $event.Message.Length))
            }
        }
    }
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total security events found: $($events.Count)" -ForegroundColor White

# Group by event type
$grouped = $events | Group-Object EventType | Sort-Object Count -Descending
foreach ($group in $grouped) {
    Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor Yellow
}

if ($events.Count -gt 0) {
    $events | Sort-Object Time -Descending | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "`nReport exported to: $ExportPath" -ForegroundColor Green

    # Show most recent events
    Write-Host "`nMost Recent Events:" -ForegroundColor Cyan
    $events | Sort-Object Time -Descending | Select-Object -First 10 | Format-Table -AutoSize
}
