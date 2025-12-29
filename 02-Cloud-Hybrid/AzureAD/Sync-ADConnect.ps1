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
    Forces Azure AD Connect synchronization and monitors status.

.DESCRIPTION
    Initiates full or delta sync with Azure AD Connect and provides
    detailed status reporting.

.PARAMETER SyncType
    Type of sync: Delta (default) or Full

.PARAMETER Wait
    Wait for sync to complete before exiting

.EXAMPLE
    .\Sync-ADConnect.ps1
    .\Sync-ADConnect.ps1 -SyncType Full -Wait
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Delta", "Full")]
    [string]$SyncType = "Delta",

    [Parameter(Mandatory=$false)]
    [switch]$Wait
)

Import-Module ADSync

Write-Host "Initiating Azure AD Connect Sync - Type: $SyncType" -ForegroundColor Cyan

# Check current sync status
$syncStatus = Get-ADSyncScheduler
Write-Host "`nCurrent Sync Configuration:" -ForegroundColor White
Write-Host "  Sync Cycle Enabled: $($syncStatus.SyncCycleEnabled)" -ForegroundColor Gray
Write-Host "  Next Sync: $($syncStatus.NextSyncCyclePolicyType) at $($syncStatus.NextSyncCycleStartTimeInUTC)" -ForegroundColor Gray

# Start sync
try {
    if ($SyncType -eq "Full") {
        Start-ADSyncSyncCycle -PolicyType Initial
    } else {
        Start-ADSyncSyncCycle -PolicyType Delta
    }

    Write-Host "`nSync initiated successfully" -ForegroundColor Green

    if ($Wait) {
        Write-Host "`nWaiting for sync to complete..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10

        $timeout = 300 # 5 minutes
        $elapsed = 0

        while ($elapsed -lt $timeout) {
            $connector = Get-ADSyncConnectorRunStatus
            if (-not $connector) {
                Write-Host "Sync completed" -ForegroundColor Green
                break
            }

            Write-Host "  Sync in progress... ($elapsed seconds elapsed)" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            $elapsed += 10
        }

        if ($elapsed -ge $timeout) {
            Write-Host "Sync timeout reached. Check sync status manually." -ForegroundColor Yellow
        }
    }

} catch {
    Write-Error "Failed to initiate sync: $_"
}

# Display final status
Write-Host "`nSync Status:" -ForegroundColor Cyan
Get-ADSyncScheduler | Format-List
