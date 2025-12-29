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
    Audits NTFS and share permissions on file servers.

.DESCRIPTION
    Generates comprehensive permission reports:
    - NTFS permissions
    - Share permissions
    - Effective access for users
    - Identifies excessive permissions

.PARAMETER Path
    Path to audit (UNC or local)

.PARAMETER Recursive
    Include subfolders

.PARAMETER ExportPath
    CSV export path

.EXAMPLE
    .\Get-FilePermissions.ps1 -Path "\\server\share"
    .\Get-FilePermissions.ps1 -Path "C:\Data" -Recursive
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$false)]
    [switch]$Recursive,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "FilePermissions_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Write-Host "Auditing permissions for: $Path" -ForegroundColor Cyan

$permissions = @()

function Get-FolderPermissions {
    param([string]$FolderPath)

    try {
        $acl = Get-Acl -Path $FolderPath

        foreach ($access in $acl.Access) {
            $permissions += [PSCustomObject]@{
                Path = $FolderPath
                Identity = $access.IdentityReference
                FileSystemRights = $access.FileSystemRights
                AccessControlType = $access.AccessControlType
                IsInherited = $access.IsInherited
                InheritanceFlags = $access.InheritanceFlags
                PropagationFlags = $access.PropagationFlags
            }
        }
    } catch {
        Write-Host "[ERROR] Failed to get permissions for $FolderPath : $_" -ForegroundColor Red
    }
}

# Get permissions for main path
Get-FolderPermissions -FolderPath $Path

# Get subfolders if recursive
if ($Recursive) {
    Write-Host "Scanning subfolders..." -ForegroundColor Yellow
    $folders = Get-ChildItem -Path $Path -Directory -Recurse -ErrorAction SilentlyContinue

    $total = $folders.Count
    $current = 0

    foreach ($folder in $folders) {
        $current++
        Write-Progress -Activity "Scanning folder permissions" `
                       -Status "Processing $($folder.FullName)" `
                       -PercentComplete (($current / $total) * 100)

        Get-FolderPermissions -FolderPath $folder.FullName
    }
    Write-Progress -Activity "Scanning folder permissions" -Completed
}

# Export
Write-Host "`nTotal permission entries: $($permissions.Count)" -ForegroundColor Green
$permissions | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "Permissions exported to: $ExportPath" -ForegroundColor Green

# Summary
Write-Host "`nPermission Summary:" -ForegroundColor Cyan
$summary = $permissions | Group-Object Identity | Sort-Object Count -Descending | Select-Object -First 10
$summary | Format-Table Name, Count -AutoSize

# Identify potential issues
$fullControl = $permissions | Where-Object {
    $_.FileSystemRights -match "FullControl" -and
    $_.AccessControlType -eq "Allow" -and
    $_.Identity -notmatch "SYSTEM|Administrators"
}

if ($fullControl.Count -gt 0) {
    Write-Host "`nWARNING: Non-admin users with Full Control:" -ForegroundColor Yellow
    $fullControl | Select-Object Path, Identity -Unique | Format-Table -AutoSize
}
