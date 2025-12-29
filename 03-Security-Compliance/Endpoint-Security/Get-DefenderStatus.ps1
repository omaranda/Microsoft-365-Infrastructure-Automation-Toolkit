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
    Reports on Windows Defender status across multiple machines.

.DESCRIPTION
    Checks Defender status:
    - Antivirus and antimalware status
    - Definition versions
    - Last scan times
    - Threat detections
    - Real-time protection status

.PARAMETER ComputerName
    Computer name(s) to check (default: local)

.PARAMETER ExportPath
    CSV export path

.EXAMPLE
    .\Get-DefenderStatus.ps1
    .\Get-DefenderStatus.ps1 -ComputerName "PC001","PC002","PC003"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "DefenderStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Write-Host "Checking Windows Defender status..." -ForegroundColor Cyan

$results = @()

foreach ($computer in $ComputerName) {
    Write-Host "`nChecking $computer..." -ForegroundColor Yellow

    try {
        $defenderStatus = Get-MpComputerStatus -CimSession $computer -ErrorAction Stop

        $status = [PSCustomObject]@{
            ComputerName = $computer
            AntivirusEnabled = $defenderStatus.AntivirusEnabled
            AntispywareEnabled = $defenderStatus.AntispywareEnabled
            BehaviorMonitorEnabled = $defenderStatus.BehaviorMonitorEnabled
            RealTimeProtectionEnabled = $defenderStatus.RealTimeProtectionEnabled
            IoavProtectionEnabled = $defenderStatus.IoavProtectionEnabled
            OnAccessProtectionEnabled = $defenderStatus.OnAccessProtectionEnabled
            AntivirusSignatureVersion = $defenderStatus.AntivirusSignatureVersion
            AntispywareSignatureVersion = $defenderStatus.AntispywareSignatureVersion
            AntivirusSignatureLastUpdated = $defenderStatus.AntivirusSignatureLastUpdated
            QuickScanAge = $defenderStatus.QuickScanAge
            FullScanAge = $defenderStatus.FullScanAge
            QuickScanEndTime = $defenderStatus.QuickScanEndTime
            FullScanEndTime = $defenderStatus.FullScanEndTime
            DefenderVersion = $defenderStatus.AMProductVersion
        }

        # Check protection status
        $protectionOK = $status.AntivirusEnabled -and
                       $status.RealTimeProtectionEnabled -and
                       $status.BehaviorMonitorEnabled

        if ($protectionOK) {
            Write-Host "  ✓ Protection enabled" -ForegroundColor Green
        } else {
            Write-Host "  ✗ WARNING: Protection not fully enabled!" -ForegroundColor Red
        }

        # Check signature age
        $signatureAge = (Get-Date) - $status.AntivirusSignatureLastUpdated
        if ($signatureAge.TotalDays -gt 7) {
            Write-Host "  ⚠ WARNING: Signatures are $([math]::Round($signatureAge.TotalDays)) days old" -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ Signatures up to date" -ForegroundColor Green
        }

        $results += $status

    } catch {
        Write-Host "  ✗ Failed to get status: $_" -ForegroundColor Red

        $results += [PSCustomObject]@{
            ComputerName = $computer
            AntivirusEnabled = "Error"
            AntispywareEnabled = "Error"
            RealTimeProtectionEnabled = "Error"
            Error = $_.Exception.Message
        }
    }
}

# Export
$results | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "`nResults exported to: $ExportPath" -ForegroundColor Green

# Summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Windows Defender Summary" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray

$protected = ($results | Where-Object { $_.RealTimeProtectionEnabled -eq $true }).Count
$total = $results.Count

Write-Host "Protected: $protected / $total" -ForegroundColor $(if ($protected -eq $total) { "Green" } else { "Yellow" })

# Display detailed results
$results | Format-Table ComputerName, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated, QuickScanAge, FullScanAge -AutoSize

# Highlight issues
$issues = $results | Where-Object {
    $_.RealTimeProtectionEnabled -eq $false -or
    ((Get-Date) - $_.AntivirusSignatureLastUpdated).TotalDays -gt 7
}

if ($issues.Count -gt 0) {
    Write-Host "`nWARNING: Computers requiring attention:" -ForegroundColor Red
    $issues | Format-Table ComputerName, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated -AutoSize
}
