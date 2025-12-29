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
    Exports DNS records from Windows DNS Server.

.DESCRIPTION
    Retrieves and exports DNS records:
    - All zones or specific zone
    - Filter by record type (A, CNAME, MX, etc.)
    - Export to CSV for documentation

.PARAMETER ZoneName
    DNS zone name (default: all zones)

.PARAMETER RecordType
    Filter by record type (A, AAAA, CNAME, MX, NS, PTR, SRV, TXT)

.PARAMETER ExportPath
    CSV export path

.EXAMPLE
    .\Get-DNSRecords.ps1
    .\Get-DNSRecords.ps1 -ZoneName "contoso.com" -RecordType "A"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ZoneName,

    [Parameter(Mandatory=$false)]
    [ValidateSet("A", "AAAA", "CNAME", "MX", "NS", "PTR", "SRV", "TXT", "All")]
    [string]$RecordType = "All",

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "DNSRecords_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Import-Module DnsServer

Write-Host "Retrieving DNS Records..." -ForegroundColor Cyan

# Get zones
if ($ZoneName) {
    $zones = @(Get-DnsServerZone -Name $ZoneName)
} else {
    $zones = Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated }
}

Write-Host "Found $($zones.Count) zone(s)" -ForegroundColor White

$allRecords = @()

foreach ($zone in $zones) {
    Write-Host "`nProcessing zone: $($zone.ZoneName)" -ForegroundColor Yellow

    # Get records
    if ($RecordType -eq "All") {
        $records = Get-DnsServerResourceRecord -ZoneName $zone.ZoneName
    } else {
        $records = Get-DnsServerResourceRecord -ZoneName $zone.ZoneName -RRType $RecordType
    }

    Write-Host "  Found $($records.Count) record(s)" -ForegroundColor Gray

    foreach ($record in $records) {
        $recordData = switch ($record.RecordType) {
            "A"     { $record.RecordData.IPv4Address.ToString() }
            "AAAA"  { $record.RecordData.IPv6Address.ToString() }
            "CNAME" { $record.RecordData.HostNameAlias }
            "MX"    { "$($record.RecordData.Preference) $($record.RecordData.MailExchange)" }
            "NS"    { $record.RecordData.NameServer }
            "PTR"   { $record.RecordData.PtrDomainName }
            "SRV"   { "$($record.RecordData.Priority) $($record.RecordData.Weight) $($record.RecordData.Port) $($record.RecordData.DomainName)" }
            "TXT"   { $record.RecordData.DescriptiveText -join "; " }
            default { $record.RecordData.ToString() }
        }

        $allRecords += [PSCustomObject]@{
            Zone = $zone.ZoneName
            Name = $record.HostName
            Type = $record.RecordType
            Data = $recordData
            TTL = $record.TimeToLive
            Timestamp = $record.Timestamp
        }
    }
}

# Export
Write-Host "`nTotal records found: $($allRecords.Count)" -ForegroundColor Green
$allRecords | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "Records exported to: $ExportPath" -ForegroundColor Green

# Summary
$summary = $allRecords | Group-Object Type | Sort-Object Count -Descending
Write-Host "`nRecords by Type:" -ForegroundColor Cyan
$summary | Format-Table Name, Count -AutoSize
