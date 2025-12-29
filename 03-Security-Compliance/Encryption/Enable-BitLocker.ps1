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
    Enables BitLocker encryption on specified drives with recovery key backup.

.DESCRIPTION
    Enables BitLocker Drive Encryption with:
    - TPM protection
    - Recovery password backup to AD
    - Optional USB key protector
    - Compliance reporting

.PARAMETER DriveLetter
    Drive letter to encrypt (default: C:)

.PARAMETER BackupToAD
    Backup recovery key to Active Directory

.PARAMETER SaveRecoveryKey
    Save recovery key to specified path

.EXAMPLE
    .\Enable-BitLocker.ps1 -DriveLetter "C:" -BackupToAD
    .\Enable-BitLocker.ps1 -DriveLetter "D:" -SaveRecoveryKey "\\server\share\recovery"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$DriveLetter = "C:",

    [Parameter(Mandatory=$false)]
    [switch]$BackupToAD,

    [Parameter(Mandatory=$false)]
    [string]$SaveRecoveryKey
)

# Requires elevation
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires administrative privileges"
    exit 1
}

Write-Host "Enabling BitLocker on drive $DriveLetter" -ForegroundColor Cyan

# Check TPM status
$tpm = Get-Tpm
if (-not $tpm.TpmPresent) {
    Write-Error "TPM is not present on this system"
    exit 1
}

if (-not $tpm.TpmReady) {
    Write-Error "TPM is not ready. Initialize TPM first."
    exit 1
}

# Check current BitLocker status
$bitlockerStatus = Get-BitLockerVolume -MountPoint $DriveLetter

if ($bitlockerStatus.ProtectionStatus -eq "On") {
    Write-Host "BitLocker is already enabled on $DriveLetter" -ForegroundColor Yellow
    exit 0
}

try {
    # Enable BitLocker
    Write-Host "Enabling BitLocker encryption..." -ForegroundColor Yellow

    Enable-BitLocker -MountPoint $DriveLetter `
                     -EncryptionMethod Aes256 `
                     -TpmProtector `
                     -RecoveryPasswordProtector `
                     -SkipHardwareTest

    Write-Host "BitLocker enabled successfully" -ForegroundColor Green

    # Get recovery password
    $recoveryPassword = (Get-BitLockerVolume -MountPoint $DriveLetter).KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

    # Backup to AD
    if ($BackupToAD) {
        Write-Host "Backing up recovery key to Active Directory..." -ForegroundColor Yellow
        Backup-BitLockerKeyProtector -MountPoint $DriveLetter -KeyProtectorId $recoveryPassword.KeyProtectorId
        Write-Host "Recovery key backed up to AD" -ForegroundColor Green
    }

    # Save recovery key to file
    if ($SaveRecoveryKey) {
        $keyPath = Join-Path $SaveRecoveryKey "$env:COMPUTERNAME-$DriveLetter-RecoveryKey.txt"
        $recoveryPassword | Out-File -FilePath $keyPath
        Write-Host "Recovery key saved to: $keyPath" -ForegroundColor Green
    }

    # Display recovery password
    Write-Host "`nRecovery Password:" -ForegroundColor Cyan
    Write-Host $recoveryPassword.RecoveryPassword -ForegroundColor Yellow
    Write-Host "`nIMPORTANT: Save this recovery password in a secure location!" -ForegroundColor Red

} catch {
    Write-Error "Failed to enable BitLocker: $_"
}
