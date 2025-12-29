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
    Reports on Microsoft Teams usage and activity.

.DESCRIPTION
    Analyzes Teams usage across the organization:
    - Active users and teams
    - Meeting statistics
    - Channel activity
    - Storage usage
    - External collaboration

.PARAMETER Days
    Number of days to analyze (default: 30)

.PARAMETER ExportPath
    CSV export path

.EXAMPLE
    .\Get-TeamsUsage.ps1
    .\Get-TeamsUsage.ps1 -Days 90 -ExportPath "C:\Reports\Teams.csv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$Days = 30,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "TeamsUsage_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Import-Module Microsoft.Graph.Reports
Import-Module Microsoft.Graph.Teams

Connect-MgGraph -Scopes "Reports.Read.All", "Team.ReadBasic.All"

Write-Host "Analyzing Microsoft Teams usage (last $Days days)..." -ForegroundColor Cyan

# Get Teams activity reports
Write-Host "`nRetrieving Teams activity data..." -ForegroundColor Yellow

try {
    # Get user activity
    $period = "D$Days"
    $userActivity = Get-MgReportTeamsUserActivityUserDetail -Period $period

    # Get device usage
    $deviceUsage = Get-MgReportTeamsDeviceUsageUserDetail -Period $period

    # Parse CSV data
    $activityData = $userActivity | ConvertFrom-Csv
    $deviceData = $deviceUsage | ConvertFrom-Csv

    Write-Host "Found data for $($activityData.Count) user(s)" -ForegroundColor White

    # Analyze activity
    $report = @()

    foreach ($user in $activityData) {
        $device = $deviceData | Where-Object { $_.'User Principal Name' -eq $user.'User Principal Name' }

        $report += [PSCustomObject]@{
            UserPrincipalName = $user.'User Principal Name'
            DisplayName = $user.'Display Name'
            LastActivityDate = $user.'Last Activity Date'
            TeamChatMessages = [int]$user.'Team Chat Message Count'
            PrivateChatMessages = [int]$user.'Private Chat Message Count'
            Calls = [int]$user.'Call Count'
            Meetings = [int]$user.'Meeting Count'
            HasTeamsLicense = $user.'Is Licensed'
            Windows = if ($device) { $device.'Used Windows' } else { "No" }
            Mac = if ($device) { $device.'Used Mac' } else { "No" }
            Web = if ($device) { $device.'Used Web' } else { "No" }
            iOS = if ($device) { $device.'Used iOS' } else { "No" }
            Android = if ($device) { $device.'Used Android Phone' } else { "No" }
        }
    }

    # Export
    $report | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "Report exported to: $ExportPath" -ForegroundColor Green

    # Summary statistics
    Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
    Write-Host "Teams Usage Summary" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray

    $activeUsers = ($report | Where-Object { $_.LastActivityDate -ne $null }).Count
    $totalMessages = ($report | Measure-Object -Property TeamChatMessages, PrivateChatMessages -Sum).Sum
    $totalCalls = ($report | Measure-Object -Property Calls -Sum).Sum
    $totalMeetings = ($report | Measure-Object -Property Meetings -Sum).Sum

    Write-Host "Active Users: $activeUsers / $($report.Count)" -ForegroundColor White
    Write-Host "Total Messages: $totalMessages" -ForegroundColor White
    Write-Host "Total Calls: $totalCalls" -ForegroundColor White
    Write-Host "Total Meetings: $totalMeetings" -ForegroundColor White

    # Device usage
    Write-Host "`nDevice Usage:" -ForegroundColor Cyan
    $windowsUsers = ($report | Where-Object { $_.Windows -eq "Yes" }).Count
    $macUsers = ($report | Where-Object { $_.Mac -eq "Yes" }).Count
    $webUsers = ($report | Where-Object { $_.Web -eq "Yes" }).Count
    $mobileUsers = ($report | Where-Object { $_.iOS -eq "Yes" -or $_.Android -eq "Yes" }).Count

    Write-Host "  Windows: $windowsUsers" -ForegroundColor Gray
    Write-Host "  Mac: $macUsers" -ForegroundColor Gray
    Write-Host "  Web: $webUsers" -ForegroundColor Gray
    Write-Host "  Mobile: $mobileUsers" -ForegroundColor Gray

    # Top users
    Write-Host "`nTop 10 Most Active Users (by messages):" -ForegroundColor Cyan
    $report | Sort-Object { [int]$_.TeamChatMessages + [int]$_.PrivateChatMessages } -Descending |
              Select-Object -First 10 |
              Format-Table DisplayName, TeamChatMessages, PrivateChatMessages, Calls, Meetings -AutoSize

    # Get team information
    Write-Host "`nRetrieving Teams..." -ForegroundColor Yellow
    $teams = Get-MgTeam -All
    Write-Host "Total Teams: $($teams.Count)" -ForegroundColor White

    $teamsInfo = @()
    foreach ($team in $teams | Select-Object -First 20) {
        $channels = Get-MgTeamChannel -TeamId $team.Id
        $members = Get-MgTeamMember -TeamId $team.Id

        $teamsInfo += [PSCustomObject]@{
            DisplayName = $team.DisplayName
            Description = $team.Description
            Visibility = $team.Visibility
            Channels = $channels.Count
            Members = $members.Count
        }
    }

    Write-Host "`nTop 20 Teams:" -ForegroundColor Cyan
    $teamsInfo | Format-Table DisplayName, Visibility, Channels, Members -AutoSize

} catch {
    Write-Error "Failed to retrieve Teams data: $_"
}

Disconnect-MgGraph
Write-Host "`nAnalysis complete!" -ForegroundColor Green
