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
    Monitors print queues and printer status.

.DESCRIPTION
    Reports on print servers:
    - Printer status
    - Print queue jobs
    - Stuck or error jobs
    - Printer statistics

.PARAMETER PrintServer
    Print server name (default: local)

.PARAMETER ClearStuckJobs
    Clear jobs in error state

.EXAMPLE
    .\Get-PrintQueue.ps1
    .\Get-PrintQueue.ps1 -PrintServer "PrintSrv01" -ClearStuckJobs
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$PrintServer = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false)]
    [switch]$ClearStuckJobs
)

Write-Host "Checking print queues on $PrintServer..." -ForegroundColor Cyan

# Get printers
$printers = Get-Printer -ComputerName $PrintServer

Write-Host "Found $($printers.Count) printer(s)" -ForegroundColor White

$printerStatus = @()
$allJobs = @()

foreach ($printer in $printers) {
    # Get printer status
    $status = if ($printer.PrinterStatus -eq 0) { "OK" }
              elseif ($printer.PrinterStatus -eq 3) { "Offline" }
              elseif ($printer.PrinterStatus -eq 4) { "Error" }
              else { "Unknown" }

    $printerStatus += [PSCustomObject]@{
        PrinterName = $printer.Name
        Status = $status
        JobCount = $printer.JobCount
        PortName = $printer.PortName
        DriverName = $printer.DriverName
        Shared = $printer.Shared
        ShareName = $printer.ShareName
    }

    # Get print jobs
    $jobs = Get-PrintJob -ComputerName $PrintServer -PrinterName $printer.Name -ErrorAction SilentlyContinue

    foreach ($job in $jobs) {
        $jobStatus = switch ($job.JobStatus) {
            "Normal" { "Printing" }
            "Paused" { "Paused" }
            "Error" { "Error" }
            "Deleting" { "Deleting" }
            "Spooling" { "Spooling" }
            "Printed" { "Printed" }
            default { $job.JobStatus }
        }

        $allJobs += [PSCustomObject]@{
            PrinterName = $printer.Name
            JobId = $job.Id
            DocumentName = $job.DocumentName
            UserName = $job.UserName
            Status = $jobStatus
            TotalPages = $job.TotalPages
            PagesPrinted = $job.PagesPrinted
            Size = [math]::Round($job.Size / 1KB, 2)
            SubmittedTime = $job.SubmittedTime
        }
    }
}

# Display printer status
Write-Host "`nPrinter Status:" -ForegroundColor Cyan
$printerStatus | Format-Table -AutoSize

# Display jobs
if ($allJobs.Count -gt 0) {
    Write-Host "`nActive Print Jobs: $($allJobs.Count)" -ForegroundColor Yellow
    $allJobs | Format-Table -AutoSize

    # Check for stuck jobs
    $stuckJobs = $allJobs | Where-Object { $_.Status -eq "Error" -or $_.Status -eq "Paused" }

    if ($stuckJobs.Count -gt 0) {
        Write-Host "`nWARNING: Found $($stuckJobs.Count) stuck job(s)" -ForegroundColor Red
        $stuckJobs | Format-Table PrinterName, JobId, DocumentName, UserName, Status -AutoSize

        if ($ClearStuckJobs) {
            foreach ($job in $stuckJobs) {
                if ($PSCmdlet.ShouldProcess("Job $($job.JobId) on $($job.PrinterName)", "Remove stuck print job")) {
                    try {
                        Remove-PrintJob -ComputerName $PrintServer -PrinterName $job.PrinterName -ID $job.JobId
                        Write-Host "  [REMOVED] Job $($job.JobId) from $($job.PrinterName)" -ForegroundColor Green
                    } catch {
                        Write-Host "  [ERROR] Failed to remove job: $_" -ForegroundColor Red
                    }
                }
            }
        }
    }
} else {
    Write-Host "`nNo active print jobs" -ForegroundColor Green
}

# Export
$printerStatus | Export-Csv -Path "PrinterStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
if ($allJobs.Count -gt 0) {
    $allJobs | Export-Csv -Path "PrintJobs_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
}
