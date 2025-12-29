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
    Analyzes disk space usage on file servers.

.DESCRIPTION
    Reports on disk space:
    - Drive utilization
    - Folder sizes
    - Growth trends
    - Low space warnings

.PARAMETER ComputerName
    Server name (default: local)

.PARAMETER Path
    Path to analyze folder sizes

.PARAMETER TopFolders
    Number of largest folders to display

.EXAMPLE
    .\Get-FileServerSpace.ps1
    .\Get-FileServerSpace.ps1 -ComputerName "FileServer01" -Path "C:\Data" -TopFolders 20
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false)]
    [string]$Path,

    [Parameter(Mandatory=$false)]
    [int]$TopFolders = 10
)

Write-Host "Analyzing disk space on $ComputerName..." -ForegroundColor Cyan

# Get disk information
$disks = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName -Filter "DriveType=3"

Write-Host "`nDisk Space Summary:" -ForegroundColor Cyan
$diskInfo = @()

foreach ($disk in $disks) {
    $sizeGB = [math]::Round($disk.Size / 1GB, 2)
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedGB = $sizeGB - $freeGB
    $percentFree = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)

    $status = if ($percentFree -lt 10) { "CRITICAL" }
              elseif ($percentFree -lt 20) { "WARNING" }
              else { "OK" }

    $diskInfo += [PSCustomObject]@{
        Drive = $disk.DeviceID
        Label = $disk.VolumeName
        SizeGB = $sizeGB
        UsedGB = $usedGB
        FreeGB = $freeGB
        PercentFree = $percentFree
        Status = $status
    }

    $color = switch ($status) {
        "CRITICAL" { "Red" }
        "WARNING" { "Yellow" }
        default { "Green" }
    }

    Write-Host "  $($disk.DeviceID) - $sizeGB GB ($freeGB GB free, $percentFree%)" -ForegroundColor $color
}

# Export disk info
$diskInfo | Export-Csv -Path "DiskSpace_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation

# Analyze folder sizes if path specified
if ($Path) {
    Write-Host "`nAnalyzing folder sizes in $Path..." -ForegroundColor Yellow

    $folders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
    $folderSizes = @()

    foreach ($folder in $folders) {
        try {
            $size = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum

            $sizeGB = [math]::Round($size / 1GB, 2)

            $folderSizes += [PSCustomObject]@{
                FolderName = $folder.Name
                FullPath = $folder.FullName
                SizeGB = $sizeGB
                FileCount = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
                Created = $folder.CreationTime
                Modified = $folder.LastWriteTime
            }
        } catch {
            Write-Host "  [ERROR] Failed to analyze $($folder.Name)" -ForegroundColor Red
        }
    }

    # Display top folders
    Write-Host "`nTop $TopFolders Largest Folders:" -ForegroundColor Cyan
    $folderSizes | Sort-Object SizeGB -Descending | Select-Object -First $TopFolders | Format-Table -AutoSize

    # Export folder sizes
    $folderSizes | Export-Csv -Path "FolderSizes_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
}

# Warnings
$critical = $diskInfo | Where-Object { $_.Status -eq "CRITICAL" }
if ($critical) {
    Write-Host "`nCRITICAL: Low disk space detected!" -ForegroundColor Red
    $critical | Format-Table -AutoSize
}
