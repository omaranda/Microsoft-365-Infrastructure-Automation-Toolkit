# Prometheus + WMI Exporter Setup

Complete guide to setup Prometheus and WMI Exporter for monitoring Windows servers.

## Architecture Overview

```
Windows Servers → WMI Exporter (Port 9182) → Prometheus → Grafana
```

## Part 1: Install Prometheus on macOS

### Step 1: Install Prometheus

```bash
# Install Prometheus using Homebrew
brew install prometheus

# Verify installation
prometheus --version
```

### Step 2: Configure Prometheus

Create/edit Prometheus configuration:

```bash
# Edit Prometheus config
nano /opt/homebrew/etc/prometheus.yml
```

**Basic Configuration:**

```yaml
# Prometheus configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'ms-infrastructure'

# Alertmanager configuration (optional)
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Scrape configurations
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Windows servers with WMI Exporter
  - job_name: 'windows-servers'
    scrape_interval: 30s
    static_configs:
      - targets:
          - 'windows-server-01:9182'
          - 'windows-server-02:9182'
          - 'windows-server-03:9182'
        labels:
          environment: 'production'
          role: 'server'

  - job_name: 'windows-workstations'
    scrape_interval: 60s
    static_configs:
      - targets:
          - 'workstation-01:9182'
          - 'workstation-02:9182'
        labels:
          environment: 'production'
          role: 'workstation'

  # Active Directory Domain Controllers
  - job_name: 'domain-controllers'
    scrape_interval: 30s
    static_configs:
      - targets:
          - 'dc01:9182'
          - 'dc02:9182'
        labels:
          environment: 'production'
          role: 'domain-controller'
```

### Step 3: Start Prometheus

```bash
# Start Prometheus service
brew services start prometheus

# Check status
brew services list | grep prometheus

# Access Prometheus UI
open http://localhost:9090
```

### Step 4: Verify Prometheus

1. Open http://localhost:9090
2. Go to **Status** → **Targets**
3. You'll see targets (they'll be down until WMI Exporter is installed)

## Part 2: Install WMI Exporter on Windows Servers

WMI Exporter exposes Windows performance counters as Prometheus metrics.

### Step 1: Download WMI Exporter

On each Windows server:

1. Download from: https://github.com/prometheus-community/windows_exporter/releases
2. Download the latest `windows_exporter-XXX-amd64.msi`

### Step 2: Install WMI Exporter

**PowerShell Installation:**

```powershell
# Download latest version
$url = "https://github.com/prometheus-community/windows_exporter/releases/download/v0.25.1/windows_exporter-0.25.1-amd64.msi"
$output = "C:\Temp\windows_exporter.msi"

# Create temp directory
New-Item -Path "C:\Temp" -ItemType Directory -Force

# Download installer
Invoke-WebRequest -Uri $url -OutFile $output

# Install with default collectors
msiexec /i $output ENABLED_COLLECTORS="cpu,cs,logical_disk,net,os,service,system,memory,process" /qn

# Verify service is running
Get-Service -Name "windows_exporter"
```

**Manual Installation:**

1. Run the MSI installer
2. Select collectors to enable (recommended: cpu, memory, disk, network, os, service)
3. Finish installation
4. Service starts automatically on port 9182

### Step 3: Configure Windows Firewall

```powershell
# Allow WMI Exporter through firewall
New-NetFirewallRule -DisplayName "WMI Exporter" `
                    -Direction Inbound `
                    -LocalPort 9182 `
                    -Protocol TCP `
                    -Action Allow
```

### Step 4: Verify WMI Exporter

Test from the Windows server:

```powershell
# Test locally
Invoke-WebRequest -Uri "http://localhost:9182/metrics"

# Test from another machine
# Open browser: http://SERVER-IP:9182/metrics
```

You should see metrics output like:
```
# HELP windows_cpu_core_frequency_mhz Core frequency in megahertz
# TYPE windows_cpu_core_frequency_mhz gauge
windows_cpu_core_frequency_mhz{core="0,0"} 2400
...
```

## Part 3: Configure Grafana with Prometheus

### Step 1: Add Prometheus Data Source to Grafana

1. **Open Grafana** → http://localhost:3000
2. **Configuration** → **Data sources** → **Add data source**
3. **Select Prometheus**
4. **Configure:**
   - Name: `Prometheus`
   - URL: `http://localhost:9090`
   - Access: `Server (default)`
5. **Click "Save & Test"**

### Step 2: Verify Data

1. Go to **Explore** (compass icon)
2. Select **Prometheus** data source
3. Try this query:
   ```promql
   up{job="windows-servers"}
   ```
4. You should see your Windows servers listed with `value=1` (up)

## Useful WMI Exporter Metrics

### CPU Metrics
```promql
# CPU usage per core
100 - (avg by (instance) (rate(windows_cpu_time_total{mode="idle"}[5m])) * 100)

# Overall CPU usage
100 - (avg(rate(windows_cpu_time_total{mode="idle"}[5m])) * 100)
```

### Memory Metrics
```promql
# Memory usage percentage
100 * (1 - (windows_os_physical_memory_free_bytes / windows_cs_physical_memory_bytes))

# Available memory in GB
windows_os_physical_memory_free_bytes / 1024 / 1024 / 1024
```

### Disk Metrics
```promql
# Disk free percentage
100 * (windows_logical_disk_free_bytes / windows_logical_disk_size_bytes)

# Disk read rate
rate(windows_logical_disk_read_bytes_total[5m])

# Disk write rate
rate(windows_logical_disk_write_bytes_total[5m])
```

### Network Metrics
```promql
# Network bytes received
rate(windows_net_bytes_received_total[5m])

# Network bytes sent
rate(windows_net_bytes_sent_total[5m])
```

### Service Status
```promql
# Check if a service is running (1=running, 0=stopped)
windows_service_status{name="wuauserv",status="running"}
```

### System Uptime
```promql
# System uptime in days
(windows_system_system_up_time) / 86400
```

## Advanced Configuration

### Custom Collectors

Enable specific collectors during installation:

```powershell
# Install with custom collectors
msiexec /i windows_exporter.msi `
  ENABLED_COLLECTORS="cpu,cs,logical_disk,net,os,service,system,memory,process,iis,mssql,ad,dns" `
  /qn
```

**Available Collectors:**
- `cpu` - CPU usage
- `cs` - Computer system info
- `logical_disk` - Disk metrics
- `net` - Network metrics
- `os` - Operating system info
- `service` - Windows services
- `system` - System metrics
- `memory` - Memory metrics
- `process` - Process metrics
- `iis` - IIS web server (if installed)
- `mssql` - SQL Server (if installed)
- `ad` - Active Directory (on domain controllers)
- `dns` - DNS Server (if installed)
- `exchange` - Exchange Server (if installed)

### Prometheus Service Discovery

For dynamic server discovery, use `file_sd_config`:

```yaml
scrape_configs:
  - job_name: 'windows-dynamic'
    file_sd_configs:
      - files:
          - '/opt/homebrew/etc/prometheus/targets/*.json'
        refresh_interval: 5m
```

Create target file `/opt/homebrew/etc/prometheus/targets/windows-servers.json`:

```json
[
  {
    "targets": ["server01:9182", "server02:9182"],
    "labels": {
      "environment": "production",
      "role": "webserver"
    }
  },
  {
    "targets": ["dc01:9182", "dc02:9182"],
    "labels": {
      "environment": "production",
      "role": "domain-controller"
    }
  }
]
```

## Bulk Deployment Script

Deploy WMI Exporter to multiple servers:

```powershell
# deploy-wmi-exporter.ps1
$servers = @("server01", "server02", "server03")
$installerPath = "\\fileserver\share\windows_exporter.msi"

foreach ($server in $servers) {
    Write-Host "Installing on $server..." -ForegroundColor Yellow

    # Copy installer
    Copy-Item -Path $installerPath -Destination "\\$server\C$\Temp\" -Force

    # Install remotely
    Invoke-Command -ComputerName $server -ScriptBlock {
        param($msiPath)

        # Install
        Start-Process msiexec.exe -ArgumentList "/i $msiPath ENABLED_COLLECTORS=`"cpu,cs,logical_disk,net,os,service,system,memory`" /qn" -Wait

        # Configure firewall
        New-NetFirewallRule -DisplayName "WMI Exporter" `
                            -Direction Inbound `
                            -LocalPort 9182 `
                            -Protocol TCP `
                            -Action Allow -ErrorAction SilentlyContinue

        # Verify service
        Get-Service -Name "windows_exporter"
    } -ArgumentList "C:\Temp\windows_exporter.msi"

    Write-Host "  Completed: $server" -ForegroundColor Green
}
```

## Troubleshooting

### WMI Exporter Not Responding

```powershell
# Check service status
Get-Service -Name "windows_exporter"

# Restart service
Restart-Service -Name "windows_exporter"

# Check logs
Get-EventLog -LogName Application -Source "windows_exporter" -Newest 20
```

### Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
tail -f /opt/homebrew/var/log/prometheus.log

# Verify network connectivity
nc -zv WINDOWS-SERVER-IP 9182

# Check Prometheus config syntax
promtool check config /opt/homebrew/etc/prometheus.yml

# Reload Prometheus config
killall -HUP prometheus
```

### High Memory Usage on Windows Server

```powershell
# Limit WMI Exporter collectors to reduce overhead
# Reinstall with fewer collectors
msiexec /i windows_exporter.msi ENABLED_COLLECTORS="cpu,memory,logical_disk" /qn
```

## Next Steps

✅ Prometheus and WMI Exporter configured
➡️ Integrate Microsoft Graph API: [04-Graph-API-Integration.md](04-Graph-API-Integration.md)
➡️ Import dashboards: [05-Dashboard-Import.md](05-Dashboard-Import.md)
