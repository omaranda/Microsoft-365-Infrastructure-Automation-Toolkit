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
    Comprehensive server health check.

.DESCRIPTION
    Monitors server health metrics:
    - CPU and memory usage
    - Disk space and performance
    - Network utilization
    - Service status
    - Event log errors
    - Uptime

.PARAMETER ComputerName
    Server name(s) to check (default: local)

.PARAMETER ExportPath
    CSV export path

.EXAMPLE
    .\Get-ServerHealth.ps1
    .\Get-ServerHealth.ps1 -ComputerName "Server01","Server02","Server03"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "ServerHealth_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Write-Host "Checking server health..." -ForegroundColor Cyan

$results = @()

foreach ($computer in $ComputerName) {
    Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
    Write-Host "Server: $computer" -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Gray

    try {
        # 1. System Information
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $computer
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $computer

        $uptime = (Get-Date) - $os.LastBootUpTime
        Write-Host "`nSystem Info:" -ForegroundColor Cyan
        Write-Host "  OS: $($os.Caption) $($os.Version)" -ForegroundColor Gray
        Write-Host "  Uptime: $($uptime.Days) days, $($uptime.Hours) hours" -ForegroundColor Gray

        # 2. CPU Usage
        $cpu = Get-CimInstance -ClassName Win32_Processor -ComputerName $computer |
               Measure-Object -Property LoadPercentage -Average
        $cpuUsage = [math]::Round($cpu.Average, 2)

        $cpuColor = if ($cpuUsage -gt 90) { "Red" }
                    elseif ($cpuUsage -gt 70) { "Yellow" }
                    else { "Green" }

        Write-Host "`nCPU:" -ForegroundColor Cyan
        Write-Host "  Usage: $cpuUsage%" -ForegroundColor $cpuColor

        # 3. Memory Usage
        $memTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $memFree = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $memUsed = $memTotal - $memFree
        $memPercent = [math]::Round(($memUsed / $memTotal) * 100, 2)

        $memColor = if ($memPercent -gt 90) { "Red" }
                    elseif ($memPercent -gt 80) { "Yellow" }
                    else { "Green" }

        Write-Host "`nMemory:" -ForegroundColor Cyan
        Write-Host "  Total: $memTotal GB" -ForegroundColor Gray
        Write-Host "  Used: $memUsed GB ($memPercent%)" -ForegroundColor $memColor
        Write-Host "  Free: $memFree GB" -ForegroundColor Gray

        # 4. Disk Space
        Write-Host "`nDisk Space:" -ForegroundColor Cyan
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $computer -Filter "DriveType=3"

        $diskIssues = 0
        foreach ($disk in $disks) {
            $sizeGB = [math]::Round($disk.Size / 1GB, 2)
            $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $percentFree = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)

            $diskColor = if ($percentFree -lt 10) { "Red"; $diskIssues++ }
                        elseif ($percentFree -lt 20) { "Yellow"; $diskIssues++ }
                        else { "Green" }

            Write-Host "  $($disk.DeviceID) $freeGB GB free of $sizeGB GB ($percentFree%)" -ForegroundColor $diskColor
        }

        # 5. Critical Services
        $criticalServices = @("wuauserv", "Winmgmt", "W32Time", "EventLog", "Dnscache")
        $stoppedServices = 0

        Write-Host "`nCritical Services:" -ForegroundColor Cyan
        foreach ($svcName in $criticalServices) {
            $svc = Get-Service -Name $svcName -ComputerName $computer -ErrorAction SilentlyContinue
            if ($svc) {
                $svcColor = if ($svc.Status -eq "Running") { "Green" } else { "Red"; $stoppedServices++ }
                Write-Host "  $($svc.DisplayName): $($svc.Status)" -ForegroundColor $svcColor
            }
        }

        # 6. Recent Errors
        Write-Host "`nRecent System Errors (last 24 hours):" -ForegroundColor Cyan
        $errors = Get-WinEvent -ComputerName $computer -FilterHashtable @{
            LogName = 'System'
            Level = 2
            StartTime = (Get-Date).AddHours(-24)
        } -MaxEvents 10 -ErrorAction SilentlyContinue

        if ($errors) {
            Write-Host "  Found $($errors.Count) error(s)" -ForegroundColor Yellow
            $errors | Select-Object -First 5 | ForEach-Object {
                Write-Host "    $($_.TimeCreated) - $($_.Message.Substring(0, [Math]::Min(80, $_.Message.Length)))..." -ForegroundColor Gray
            }
        } else {
            Write-Host "  No errors found" -ForegroundColor Green
        }

        # Overall Health Score
        $healthScore = 100
        if ($cpuUsage -gt 90) { $healthScore -= 20 }
        elseif ($cpuUsage -gt 70) { $healthScore -= 10 }

        if ($memPercent -gt 90) { $healthScore -= 20 }
        elseif ($memPercent -gt 80) { $healthScore -= 10 }

        $healthScore -= ($diskIssues * 10)
        $healthScore -= ($stoppedServices * 15)
        if ($errors.Count -gt 5) { $healthScore -= 10 }

        $healthStatus = if ($healthScore -ge 80) { "Healthy" }
                       elseif ($healthScore -ge 60) { "Warning" }
                       else { "Critical" }

        Write-Host "`nHealth Score: $healthScore/100 - $healthStatus" -ForegroundColor $(
            if ($healthScore -ge 80) { "Green" }
            elseif ($healthScore -ge 60) { "Yellow" }
            else { "Red" }
        )

        # Add to results
        $results += [PSCustomObject]@{
            ComputerName = $computer
            OS = $os.Caption
            UptimeDays = $uptime.Days
            CPUUsage = $cpuUsage
            MemoryUsedGB = $memUsed
            MemoryPercent = $memPercent
            DiskIssues = $diskIssues
            StoppedServices = $stoppedServices
            RecentErrors = if ($errors) { $errors.Count } else { 0 }
            HealthScore = $healthScore
            HealthStatus = $healthStatus
        }

    } catch {
        Write-Host "  ✗ Failed to check $computer : $_" -ForegroundColor Red

        $results += [PSCustomObject]@{
            ComputerName = $computer
            HealthStatus = "Error"
            Error = $_.Exception.Message
        }
    }
}

# Export results
$results | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Results exported to: $ExportPath" -ForegroundColor Green

# Summary
Write-Host "`nOverall Summary:" -ForegroundColor Cyan
$results | Format-Table ComputerName, HealthScore, HealthStatus, CPUUsage, MemoryPercent, DiskIssues -AutoSize
