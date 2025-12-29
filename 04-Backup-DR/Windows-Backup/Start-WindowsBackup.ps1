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
    Initiates Windows Server Backup.

.DESCRIPTION
    Manages Windows Server Backup:
    - Start backup jobs
    - Monitor backup status
    - Verify backup completion
    - Report on backup history

.PARAMETER BackupTarget
    Backup target path (disk or network)

.PARAMETER Include
    Volumes to include (e.g., "C:", "D:")

.PARAMETER BackupType
    Full or Incremental

.EXAMPLE
    .\Start-WindowsBackup.ps1 -BackupTarget "E:\" -Include "C:","D:" -BackupType Full
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$BackupTarget,

    [Parameter(Mandatory=$false)]
    [string[]]$Include = @("C:"),

    [Parameter(Mandatory=$false)]
    [ValidateSet("Full", "Incremental")]
    [string]$BackupType = "Full"
)

# Check if Windows Server Backup is installed
if (-not (Get-WindowsFeature -Name Windows-Server-Backup).Installed) {
    Write-Error "Windows Server Backup feature is not installed. Install it first: Install-WindowsFeature Windows-Server-Backup"
    exit 1
}

Import-Module WindowsServerBackup

Write-Host "Initiating Windows Server Backup..." -ForegroundColor Cyan
Write-Host "Target: $BackupTarget" -ForegroundColor White
Write-Host "Type: $BackupType" -ForegroundColor White
Write-Host "Volumes: $($Include -join ', ')" -ForegroundColor White

# Create backup policy
$policy = New-WBPolicy

# Add volumes
foreach ($volume in $Include) {
    $vol = Get-WBVolume -VolumePath $volume
    Add-WBVolume -Policy $policy -Volume $vol
    Write-Host "  Added volume: $volume" -ForegroundColor Gray
}

# Set backup target
$backupLocation = New-WBBackupTarget -Path $BackupTarget
Add-WBBackupTarget -Policy $policy -Target $backupLocation

# Set VSS backup method
Set-WBVssBackupOptions -Policy $policy -VssCopyBackup

# Start backup
Write-Host "`nStarting backup..." -ForegroundColor Yellow

try {
    Start-WBBackup -Policy $policy -Async

    Write-Host "Backup job started successfully" -ForegroundColor Green
    Write-Host "Monitoring backup progress..." -ForegroundColor Yellow

    # Monitor progress
    do {
        Start-Sleep -Seconds 10
        $job = Get-WBJob -Previous 1

        if ($job) {
            $progress = $job.JobState
            Write-Host "  Status: $progress" -ForegroundColor Gray
        }
    } while ($job.JobState -eq "Running")

    # Final status
    $finalJob = Get-WBJob -Previous 1

    Write-Host "`nBackup completed!" -ForegroundColor Green
    Write-Host "Status: $($finalJob.JobState)" -ForegroundColor White
    Write-Host "Start Time: $($finalJob.StartTime)" -ForegroundColor Gray
    Write-Host "End Time: $($finalJob.EndTime)" -ForegroundColor Gray

    # Get backup summary
    $summary = Get-WBSummary
    Write-Host "`nBackup Summary:" -ForegroundColor Cyan
    Write-Host "  Last Successful Backup: $($summary.LastSuccessfulBackupTime)" -ForegroundColor Gray
    Write-Host "  Last Backup Target: $($summary.LastBackupTarget)" -ForegroundColor Gray

} catch {
    Write-Error "Backup failed: $_"
    exit 1
}
