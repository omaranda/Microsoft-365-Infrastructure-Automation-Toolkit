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
    Reports on DHCP leases and scope utilization.

.DESCRIPTION
    Retrieves DHCP lease information:
    - Active leases by scope
    - Scope utilization percentage
    - Expired and reserved addresses
    - Export to CSV

.PARAMETER ScopeId
    Specific scope ID (default: all scopes)

.PARAMETER ShowExpired
    Include expired leases

.PARAMETER ExportPath
    CSV export path

.EXAMPLE
    .\Get-DHCPLeases.ps1
    .\Get-DHCPLeases.ps1 -ScopeId "192.168.1.0" -ShowExpired
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ScopeId,

    [Parameter(Mandatory=$false)]
    [switch]$ShowExpired,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "DHCPLeases_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Import-Module DhcpServer

Write-Host "Retrieving DHCP Information..." -ForegroundColor Cyan

# Get DHCP server
$dhcpServer = (Get-DhcpServerInDC)[0].DnsName

# Get scopes
if ($ScopeId) {
    $scopes = @(Get-DhcpServerv4Scope -ComputerName $dhcpServer -ScopeId $ScopeId)
} else {
    $scopes = Get-DhcpServerv4Scope -ComputerName $dhcpServer
}

Write-Host "Found $($scopes.Count) scope(s) on $dhcpServer" -ForegroundColor White

$allLeases = @()
$scopeStats = @()

foreach ($scope in $scopes) {
    Write-Host "`nProcessing scope: $($scope.ScopeId) - $($scope.Name)" -ForegroundColor Yellow

    # Get scope statistics
    $stats = Get-DhcpServerv4ScopeStatistics -ComputerName $dhcpServer -ScopeId $scope.ScopeId

    $utilizationPercent = if ($stats.Free -gt 0) {
        [math]::Round(($stats.InUse / ($stats.InUse + $stats.Free)) * 100, 2)
    } else { 100 }

    Write-Host "  In Use: $($stats.InUse) | Free: $($stats.Free) | Utilization: $utilizationPercent%" -ForegroundColor Gray

    $scopeStats += [PSCustomObject]@{
        ScopeId = $scope.ScopeId
        ScopeName = $scope.Name
        StartRange = $scope.StartRange
        EndRange = $scope.EndRange
        SubnetMask = $scope.SubnetMask
        State = $scope.State
        InUse = $stats.InUse
        Free = $stats.Free
        Reserved = $stats.Reserved
        UtilizationPercent = $utilizationPercent
    }

    # Get leases
    $leases = Get-DhcpServerv4Lease -ComputerName $dhcpServer -ScopeId $scope.ScopeId

    if (-not $ShowExpired) {
        $leases = $leases | Where-Object { $_.AddressState -ne "Expired" }
    }

    foreach ($lease in $leases) {
        $allLeases += [PSCustomObject]@{
            ScopeId = $scope.ScopeId
            ScopeName = $scope.Name
            IPAddress = $lease.IPAddress
            ClientId = $lease.ClientId
            HostName = $lease.HostName
            AddressState = $lease.AddressState
            LeaseExpiryTime = $lease.LeaseExpiryTime
            Description = $lease.Description
        }
    }
}

# Display scope statistics
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "DHCP Scope Statistics" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
$scopeStats | Format-Table -AutoSize

# Highlight high utilization
$highUtil = $scopeStats | Where-Object { $_.UtilizationPercent -gt 80 }
if ($highUtil) {
    Write-Host "`nWARNING: Scopes with >80% utilization:" -ForegroundColor Yellow
    $highUtil | Format-Table ScopeId, ScopeName, UtilizationPercent -AutoSize
}

# Export leases
Write-Host "`nTotal active leases: $($allLeases.Count)" -ForegroundColor Green
$allLeases | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "Leases exported to: $ExportPath" -ForegroundColor Green

# Export scope stats
$statsPath = "DHCPScopeStats_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$scopeStats | Export-Csv -Path $statsPath -NoTypeInformation
Write-Host "Scope statistics exported to: $statsPath" -ForegroundColor Green
