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
    Tests network connectivity and diagnoses issues.

.DESCRIPTION
    Comprehensive network diagnostics:
    - Ping tests
    - Port connectivity tests
    - DNS resolution
    - Traceroute
    - Network path analysis

.PARAMETER Target
    Target host or IP address

.PARAMETER Ports
    Ports to test (default: 80, 443, 3389, 445)

.PARAMETER IncludeTraceroute
    Include traceroute to target

.EXAMPLE
    .\Test-NetworkConnectivity.ps1 -Target "google.com"
    .\Test-NetworkConnectivity.ps1 -Target "192.168.1.1" -Ports 80,443,3389 -IncludeTraceroute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Target,

    [Parameter(Mandatory=$false)]
    [int[]]$Ports = @(80, 443, 3389, 445, 53, 25),

    [Parameter(Mandatory=$false)]
    [switch]$IncludeTraceroute
)

Write-Host "Testing network connectivity to $Target..." -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray

# 1. DNS Resolution
Write-Host "`n[1] DNS Resolution:" -ForegroundColor Yellow
try {
    $dnsResult = Resolve-DnsName -Name $Target -ErrorAction Stop
    Write-Host "  ✓ DNS resolved successfully" -ForegroundColor Green
    foreach ($record in $dnsResult) {
        Write-Host "    $($record.Name) -> $($record.IPAddress)" -ForegroundColor Gray
    }
    $resolvedIP = $dnsResult[0].IPAddress
} catch {
    Write-Host "  ✗ DNS resolution failed: $_" -ForegroundColor Red
    exit 1
}

# 2. Ping Test
Write-Host "`n[2] Ping Test:" -ForegroundColor Yellow
try {
    $pingResult = Test-Connection -ComputerName $Target -Count 4 -ErrorAction Stop
    $avgLatency = ($pingResult | Measure-Object -Property ResponseTime -Average).Average

    Write-Host "  ✓ Ping successful" -ForegroundColor Green
    Write-Host "    Packets: Sent = 4, Received = $($pingResult.Count), Lost = $(4 - $pingResult.Count)" -ForegroundColor Gray
    Write-Host "    Average latency: $([math]::Round($avgLatency, 2)) ms" -ForegroundColor Gray
} catch {
    Write-Host "  ✗ Ping failed: $_" -ForegroundColor Red
}

# 3. Port Connectivity
Write-Host "`n[3] Port Connectivity:" -ForegroundColor Yellow
$portResults = @()

foreach ($port in $Ports) {
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($Target, $port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)

        if ($wait) {
            $tcpClient.EndConnect($connect)
            Write-Host "  ✓ Port $port : OPEN" -ForegroundColor Green
            $portStatus = "Open"
        } else {
            Write-Host "  ✗ Port $port : CLOSED/FILTERED" -ForegroundColor Red
            $portStatus = "Closed"
        }

        $tcpClient.Close()
    } catch {
        Write-Host "  ✗ Port $port : CLOSED" -ForegroundColor Red
        $portStatus = "Closed"
    }

    $portResults += [PSCustomObject]@{
        Target = $Target
        Port = $port
        Status = $portStatus
    }
}

# 4. Traceroute
if ($IncludeTraceroute) {
    Write-Host "`n[4] Traceroute:" -ForegroundColor Yellow
    try {
        $tracert = Test-NetConnection -ComputerName $Target -TraceRoute

        Write-Host "  Hops to $Target :" -ForegroundColor Gray
        for ($i = 0; $i -lt $tracert.TraceRoute.Count; $i++) {
            Write-Host "    $($i + 1). $($tracert.TraceRoute[$i])" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  ✗ Traceroute failed: $_" -ForegroundColor Red
    }
}

# 5. Network Route
Write-Host "`n[5] Network Route:" -ForegroundColor Yellow
try {
    $route = Find-NetRoute -RemoteIPAddress $resolvedIP | Select-Object -First 1
    Write-Host "  Interface: $($route.InterfaceAlias)" -ForegroundColor Gray
    Write-Host "  Next Hop: $($route.NextHop)" -ForegroundColor Gray
    Write-Host "  Route Metric: $($route.RouteMetric)" -ForegroundColor Gray
} catch {
    Write-Host "  ⚠ Could not determine route" -ForegroundColor Yellow
}

# Summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Connectivity Summary" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray

$openPorts = ($portResults | Where-Object { $_.Status -eq "Open" }).Count
Write-Host "Open Ports: $openPorts / $($Ports.Count)" -ForegroundColor $(if ($openPorts -gt 0) { "Green" } else { "Yellow" })

# Export results
$portResults | Export-Csv -Path "ConnectivityTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
Write-Host "`nResults exported to CSV" -ForegroundColor Green
