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
    Initiates on-demand backup for Azure VMs.

.DESCRIPTION
    Triggers backup jobs for specified Azure VMs and monitors status.

.PARAMETER ResourceGroupName
    Azure Resource Group containing the VMs

.PARAMETER VMName
    Name of the VM to backup (or * for all VMs in RG)

.PARAMETER Wait
    Wait for backup to complete

.EXAMPLE
    .\Start-AzureVMBackup.ps1 -ResourceGroupName "RG-Production" -VMName "VM-SQL01"
    .\Start-AzureVMBackup.ps1 -ResourceGroupName "RG-Production" -VMName "*" -Wait
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$false)]
    [switch]$Wait
)

Import-Module Az.RecoveryServices
Import-Module Az.Compute

# Connect to Azure
if (-not (Get-AzContext)) {
    Write-Host "Connecting to Azure..." -ForegroundColor Cyan
    Connect-AzAccount
}

Write-Host "Initiating Azure VM Backup..." -ForegroundColor Cyan

# Get VMs
if ($VMName -eq "*") {
    $vms = Get-AzVM -ResourceGroupName $ResourceGroupName
} else {
    $vms = @(Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName)
}

$backupJobs = @()

foreach ($vm in $vms) {
    Write-Host "`nProcessing VM: $($vm.Name)" -ForegroundColor Yellow

    try {
        # Get backup vault
        $vault = Get-AzRecoveryServicesVault | Where-Object {
            $backupItem = Get-AzRecoveryServicesBackupItem -VaultId $_.ID -BackupManagementType AzureVM -WorkloadType AzureVM |
                         Where-Object { $_.VirtualMachineId -eq $vm.Id }
            $backupItem -ne $null
        } | Select-Object -First 1

        if (-not $vault) {
            Write-Host "  No backup vault found for $($vm.Name)" -ForegroundColor Red
            continue
        }

        Set-AzRecoveryServicesVaultContext -Vault $vault

        # Get backup item
        $backupItem = Get-AzRecoveryServicesBackupItem -VaultId $vault.ID `
                                                       -BackupManagementType AzureVM `
                                                       -WorkloadType AzureVM |
                     Where-Object { $_.VirtualMachineId -eq $vm.Id }

        if (-not $backupItem) {
            Write-Host "  VM not configured for backup" -ForegroundColor Red
            continue
        }

        # Trigger backup
        $backupJob = Backup-AzRecoveryServicesBackupItem -Item $backupItem
        Write-Host "  Backup initiated: Job ID $($backupJob.JobId)" -ForegroundColor Green

        $backupJobs += @{
            VM = $vm.Name
            JobId = $backupJob.JobId
            Vault = $vault.Name
        }

    } catch {
        Write-Host "  Failed to initiate backup: $_" -ForegroundColor Red
    }
}

if ($Wait -and $backupJobs.Count -gt 0) {
    Write-Host "`nWaiting for backup jobs to complete..." -ForegroundColor Yellow

    foreach ($job in $backupJobs) {
        Write-Host "  Monitoring: $($job.VM)" -ForegroundColor Gray

        $vault = Get-AzRecoveryServicesVault -Name $job.Vault
        Set-AzRecoveryServicesVaultContext -Vault $vault

        Wait-AzRecoveryServicesBackupJob -Job (Get-AzRecoveryServicesBackupJob -JobId $job.JobId)

        $finalJob = Get-AzRecoveryServicesBackupJob -JobId $job.JobId
        Write-Host "    Status: $($finalJob.Status)" -ForegroundColor $(if ($finalJob.Status -eq "Completed") { "Green" } else { "Red" })
    }
}

Write-Host "`nBackup operations completed" -ForegroundColor Green
