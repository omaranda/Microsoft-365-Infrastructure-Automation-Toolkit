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
    Reports on non-compliant Intune-managed devices and emails the results.

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves all Intune-managed devices,
    filters for non-compliant devices, groups them by compliance policy, and exports
    the results to CSV. Optionally emails the report to an IT team.

.PARAMETER EmailReport
    Send the report via email

.PARAMETER EmailTo
    Email address(es) to send the report to (comma-separated)

.PARAMETER EmailFrom
    Email address to send from

.PARAMETER SMTPServer
    SMTP server address (optional if using Microsoft Graph to send email)

.PARAMETER SMTPPort
    SMTP server port (default: 587)

.PARAMETER UseGraphEmail
    Use Microsoft Graph to send email instead of SMTP

.PARAMETER ExportPath
    Path for the CSV export file (default: IntuneNonCompliant_<timestamp>.csv)

.EXAMPLE
    .\Get-IntuneNonCompliantDevices.ps1
    Generates report and exports to CSV only

.EXAMPLE
    .\Get-IntuneNonCompliantDevices.ps1 -EmailReport -EmailTo "it-team@domain.com" -UseGraphEmail
    Generates report and emails it using Microsoft Graph

.EXAMPLE
    .\Get-IntuneNonCompliantDevices.ps1 -EmailReport -EmailTo "admin@domain.com" -EmailFrom "intune@domain.com" -SMTPServer "smtp.office365.com"
    Generates report and emails it using SMTP
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$EmailReport,

    [Parameter(Mandatory=$false)]
    [string[]]$EmailTo,

    [Parameter(Mandatory=$false)]
    [string]$EmailFrom,

    [Parameter(Mandatory=$false)]
    [string]$SMTPServer,

    [Parameter(Mandatory=$false)]
    [int]$SMTPPort = 587,

    [Parameter(Mandatory=$false)]
    [switch]$UseGraphEmail,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "IntuneNonCompliant_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# Validate email parameters
if ($EmailReport) {
    if (-not $EmailTo) {
        Write-Error "When using -EmailReport, you must specify -EmailTo"
        exit 1
    }
    if (-not $UseGraphEmail -and (-not $EmailFrom -or -not $SMTPServer)) {
        Write-Error "When using -EmailReport without -UseGraphEmail, you must specify -EmailFrom and -SMTPServer"
        exit 1
    }
}

# Check if Microsoft.Graph module is installed
$requiredModules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.DeviceManagement', 'Microsoft.Graph.Users', 'Microsoft.Graph.Mail')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module..." -ForegroundColor Yellow
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
    }
}

# Import modules
Write-Host "Importing Microsoft Graph modules..." -ForegroundColor Cyan
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.DeviceManagement
Import-Module Microsoft.Graph.Users

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
$scopes = @(
    "DeviceManagementManagedDevices.Read.All",
    "DeviceManagementConfiguration.Read.All",
    "User.Read.All"
)

if ($UseGraphEmail) {
    $scopes += "Mail.Send"
}

try {
    Connect-MgGraph -Scopes $scopes -NoWelcome
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    exit 1
}

Write-Host "Retrieving all managed devices..." -ForegroundColor Cyan
$allDevices = Get-MgDeviceManagementManagedDevice -All

Write-Host "Found $($allDevices.Count) managed devices" -ForegroundColor White

# Filter for non-compliant devices
Write-Host "Filtering non-compliant devices..." -ForegroundColor Cyan
$nonCompliantDevices = $allDevices | Where-Object {
    $_.ComplianceState -ne "compliant" -and $_.ComplianceState -ne $null
}

Write-Host "Found $($nonCompliantDevices.Count) non-compliant devices" -ForegroundColor Yellow

if ($nonCompliantDevices.Count -eq 0) {
    Write-Host "No non-compliant devices found. Exiting..." -ForegroundColor Green
    Disconnect-MgGraph
    exit 0
}

# Get compliance policies
Write-Host "Retrieving compliance policies..." -ForegroundColor Cyan
$compliancePolicies = Get-MgDeviceManagementDeviceCompliancePolicy -All

# Build the report
Write-Host "Building device report..." -ForegroundColor Cyan
$report = @()
$totalDevices = $nonCompliantDevices.Count
$currentCount = 0

foreach ($device in $nonCompliantDevices) {
    $currentCount++
    Write-Progress -Activity "Processing non-compliant devices" `
                   -Status "Processing $($device.DeviceName)" `
                   -PercentComplete (($currentCount / $totalDevices) * 100)

    # Get user information
    $userName = "Unknown"
    $userEmail = "Unknown"
    if ($device.UserId) {
        try {
            $user = Get-MgUser -UserId $device.UserId -ErrorAction SilentlyContinue
            if ($user) {
                $userName = $user.DisplayName
                $userEmail = $user.UserPrincipalName
            }
        } catch {
            # User not found or no access
        }
    }

    # Get assigned compliance policies
    $assignedPolicies = @()
    try {
        $deviceCompliancePolicyStates = Get-MgDeviceManagementManagedDeviceDeviceCompliancePolicyState -ManagedDeviceId $device.Id -ErrorAction SilentlyContinue
        foreach ($policyState in $deviceCompliancePolicyStates) {
            $policy = $compliancePolicies | Where-Object { $_.Id -eq $policyState.Id }
            if ($policy) {
                $assignedPolicies += "$($policy.DisplayName) (State: $($policyState.State))"
            }
        }
    } catch {
        $assignedPolicies += "Unable to retrieve policies"
    }

    $report += [PSCustomObject]@{
        DeviceName = $device.DeviceName
        User = $userName
        UserEmail = $userEmail
        OS = "$($device.OperatingSystem) $($device.OSVersion)"
        Model = $device.Model
        Manufacturer = $device.Manufacturer
        LastSync = $device.LastSyncDateTime
        ComplianceState = $device.ComplianceState
        ComplianceGracePeriodExpirationDateTime = $device.ComplianceGracePeriodExpirationDateTime
        AssignedPolicies = ($assignedPolicies -join "; ")
        SerialNumber = $device.SerialNumber
        IMEI = $device.Imei
        EnrolledDateTime = $device.EnrolledDateTime
    }
}

Write-Progress -Activity "Processing non-compliant devices" -Completed

# Export to CSV
Write-Host "Exporting to CSV: $ExportPath" -ForegroundColor Cyan
$report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8

# Group by compliance state for summary
$groupedByState = $report | Group-Object -Property ComplianceState
$groupedByOS = $report | Group-Object -Property { $_.OS.Split(' ')[0] }

# Display summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Summary Report" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Total non-compliant devices: $($report.Count)" -ForegroundColor Yellow
Write-Host "`nBy Compliance State:" -ForegroundColor White
foreach ($group in $groupedByState) {
    Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor Yellow
}
Write-Host "`nBy Operating System:" -ForegroundColor White
foreach ($group in $groupedByOS) {
    Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor Yellow
}
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray

# Display detailed report
Write-Host "`nDetailed Report:" -ForegroundColor Cyan
$report | Format-Table DeviceName, User, OS, LastSync, ComplianceState -AutoSize

# Email the report if requested
if ($EmailReport) {
    Write-Host "`nPreparing to send email report..." -ForegroundColor Cyan

    # Create HTML report
    $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #D83B01; }
        h2 { color: #0078D4; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th { background-color: #0078D4; color: white; padding: 10px; text-align: left; }
        td { border: 1px solid #ddd; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .summary { background-color: #FFF4CE; padding: 15px; border-left: 4px solid #D83B01; margin: 20px 0; }
        .footer { margin-top: 30px; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <h1>Intune Non-Compliant Devices Report</h1>
    <p><strong>Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>

    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Non-Compliant Devices:</strong> $($report.Count)</p>
        <h3>By Compliance State:</h3>
        <ul>
"@

    foreach ($group in $groupedByState) {
        $htmlBody += "<li><strong>$($group.Name):</strong> $($group.Count)</li>`n"
    }

    $htmlBody += @"
        </ul>
        <h3>By Operating System:</h3>
        <ul>
"@

    foreach ($group in $groupedByOS) {
        $htmlBody += "<li><strong>$($group.Name):</strong> $($group.Count)</li>`n"
    }

    $htmlBody += @"
        </ul>
    </div>

    <h2>Device Details</h2>
    <table>
        <tr>
            <th>Device Name</th>
            <th>User</th>
            <th>Email</th>
            <th>OS</th>
            <th>Last Sync</th>
            <th>Compliance State</th>
        </tr>
"@

    foreach ($device in $report) {
        $lastSync = if ($device.LastSync) { ([DateTime]$device.LastSync).ToString("yyyy-MM-dd HH:mm") } else { "Never" }
        $htmlBody += @"
        <tr>
            <td>$($device.DeviceName)</td>
            <td>$($device.User)</td>
            <td>$($device.UserEmail)</td>
            <td>$($device.OS)</td>
            <td>$lastSync</td>
            <td>$($device.ComplianceState)</td>
        </tr>
"@
    }

    $htmlBody += @"
    </table>

    <div class="footer">
        <p>Detailed report is attached as CSV file.</p>
        <p>This is an automated report from Intune Device Compliance Monitoring.</p>
    </div>
</body>
</html>
"@

    if ($UseGraphEmail) {
        Write-Host "Sending email via Microsoft Graph..." -ForegroundColor Cyan
        try {
            Import-Module Microsoft.Graph.Mail

            # Read CSV file as base64
            $csvContent = [System.IO.File]::ReadAllBytes($ExportPath)
            $csvBase64 = [System.Convert]::ToBase64String($csvContent)

            # Prepare email message
            $message = @{
                subject = "Intune Non-Compliant Devices Report - $(Get-Date -Format 'yyyy-MM-dd')"
                body = @{
                    contentType = "HTML"
                    content = $htmlBody
                }
                toRecipients = @()
                attachments = @(
                    @{
                        "@odata.type" = "#microsoft.graph.fileAttachment"
                        name = [System.IO.Path]::GetFileName($ExportPath)
                        contentType = "text/csv"
                        contentBytes = $csvBase64
                    }
                )
            }

            foreach ($recipient in $EmailTo) {
                $message.toRecipients += @{
                    emailAddress = @{
                        address = $recipient
                    }
                }
            }

            # Get current user
            $currentUser = Get-MgContext
            $userId = $currentUser.Account

            # Send email
            Send-MgUserMail -UserId $userId -Message $message

            Write-Host "Email sent successfully via Microsoft Graph!" -ForegroundColor Green
        } catch {
            Write-Error "Failed to send email via Microsoft Graph: $_"
        }
    } else {
        Write-Host "Sending email via SMTP..." -ForegroundColor Cyan
        try {
            $emailParams = @{
                From = $EmailFrom
                To = $EmailTo
                Subject = "Intune Non-Compliant Devices Report - $(Get-Date -Format 'yyyy-MM-dd')"
                Body = $htmlBody
                BodyAsHtml = $true
                SmtpServer = $SMTPServer
                Port = $SMTPPort
                Attachments = $ExportPath
                UseSsl = $true
            }

            # Prompt for credentials if using SMTP
            $credential = Get-Credential -Message "Enter SMTP credentials"
            $emailParams.Credential = $credential

            Send-MailMessage @emailParams

            Write-Host "Email sent successfully via SMTP!" -ForegroundColor Green
        } catch {
            Write-Error "Failed to send email via SMTP: $_"
        }
    }
}

# Disconnect
Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Cyan
Disconnect-MgGraph

Write-Host "`nReport saved to: $ExportPath" -ForegroundColor Green
Write-Host "Done!" -ForegroundColor Green
