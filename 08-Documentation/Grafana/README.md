# Grafana Monitoring Solution

Complete monitoring setup for Microsoft infrastructure using Grafana, Prometheus, Azure Monitor, and Microsoft Graph API.

## 📚 Guide Structure

Follow these guides in order for complete setup:

1. **[Grafana Installation](01-Grafana-Installation.md)**
   - Install Grafana on macOS
   - Configure basic settings
   - Install required plugins

2. **[Azure Monitor Setup](02-Azure-Monitor-Setup.md)**
   - Create Azure Service Principal
   - Configure Azure Monitor data source
   - Query Azure resources

3. **[Prometheus + WMI Exporter Setup](03-Prometheus-WMI-Setup.md)**
   - Install Prometheus
   - Deploy WMI Exporter to Windows servers
   - Configure metrics collection

4. **[Microsoft Graph API Integration](04-Graph-API-Integration.md)**
   - Setup Graph API authentication
   - Create API proxy
   - Query Microsoft 365 data

5. **[Dashboard Import](05-Dashboard-Import.md)**
   - Import pre-built dashboards
   - Customize panels
   - Share dashboards

## 🎯 What You'll Monitor

### Infrastructure
- ✅ Windows Servers (CPU, Memory, Disk, Network)
- ✅ Domain Controllers
- ✅ File Servers
- ✅ Print Servers

### Azure Resources
- ✅ Virtual Machines
- ✅ Storage Accounts
- ✅ SQL Databases
- ✅ App Services

### Microsoft 365
- ✅ User Activity
- ✅ Teams Usage
- ✅ Exchange Mailboxes
- ✅ License Consumption
- ✅ Sign-in Activity

### Security
- ✅ Failed Login Attempts
- ✅ Security Events
- ✅ Defender Status
- ✅ Conditional Access

## ⚡ Quick Start

### Option 1: Docker (Recommended - 5 minutes)

**Complete stack with one command:**

```bash
# Navigate to docker directory
cd /Users/omiranda/Documents/GitHub/ms-tools/docker

# Configure Azure AD credentials (one-time)
cp graph-api-proxy/.env.example graph-api-proxy/.env
nano graph-api-proxy/.env  # Add your credentials

# Start everything
./monitoring-stack.sh start

# Access Grafana
open http://localhost:3000
```

**What you get:**
- ✅ Grafana with all plugins pre-installed
- ✅ Prometheus configured and ready
- ✅ Microsoft Graph API proxy running
- ✅ Dashboards auto-imported
- ✅ Alert rules configured
- ✅ Data persistence

**See:** [Docker Setup Guide](../../docker/README.md)

---

### Option 2: Manual Installation (10 minutes)

```bash
# Install Grafana
brew install grafana
brew services start grafana

# Install Prometheus
brew install prometheus

# Install required plugins
grafana-cli plugins install grafana-azure-monitor-datasource
grafana-cli plugins install marcusolsson-json-datasource

# Restart Grafana
brew services restart grafana
```

### 2. Deploy WMI Exporter (Windows Servers)

```powershell
# Download and install on each Windows server
$url = "https://github.com/prometheus-community/windows_exporter/releases/download/v0.25.1/windows_exporter-0.25.1-amd64.msi"
$output = "C:\Temp\windows_exporter.msi"
Invoke-WebRequest -Uri $url -OutFile $output
msiexec /i $output /qn

# Configure firewall
New-NetFirewallRule -DisplayName "WMI Exporter" -Direction Inbound -LocalPort 9182 -Protocol TCP -Action Allow
```

### 3. Configure Data Sources (5 minutes)

**Azure Monitor:**
- Create Service Principal in Azure
- Add to Grafana: Configuration → Data sources → Azure Monitor

**Prometheus:**
- Add to Grafana: Configuration → Data sources → Prometheus
- URL: http://localhost:9090

**Microsoft Graph API:**
- Setup API proxy (Node.js)
- Add to Grafana: Configuration → Data sources → JSON API

### 4. Import Dashboards (2 minutes)

```bash
# Copy dashboards
cp ../06-Monitoring/Azure-Monitor/*.json /opt/homebrew/etc/grafana/provisioning/dashboards/

# Restart Grafana
brew services restart grafana
```

## 📊 Pre-built Dashboards

### Windows Servers Dashboard
**Panels:**
- CPU Usage (Gauge & Time Series)
- Memory Usage (Gauge & Time Series)
- Disk Free Space (Gauge)
- Network Traffic (Time Series)
- Server Status (Table)

**File:** `grafana-dashboard-windows-servers.json`

### Azure Resources Dashboard
**Panels:**
- VM CPU Percentage
- VM Memory Available
- Storage Account Availability
- SQL Database DTU
- Network In/Out

**Create using:** Azure Monitor data source

### Microsoft 365 Dashboard
**Panels:**
- Active Users Count
- Teams Activity
- License Usage
- Sign-in Success/Failures
- OneDrive Usage

**Create using:** Microsoft Graph API data source

## 🔧 Architecture

### Docker Stack
```
┌─────────────────────────────────────────────────────┐
│                 Docker Host (macOS)                  │
│                                                      │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────┐│
│  │ Grafana  │  │Prometheus  │  │  Graph API Proxy ││
│  │  :3000   │◄─┤   :9090    │  │      :3001       ││
│  └──────────┘  └─────┬──────┘  └──────────────────┘│
│                      │                              │
│  ┌──────────┐  ┌────┴──────┐  ┌──────────────────┐│
│  │cAdvisor  │  │   Node    │  │  Alertmanager    ││
│  │  :8080   │  │ Exporter  │  │      :9093       ││
│  └──────────┘  └───────────┘  └──────────────────┘│
└─────────────────────────────────────────────────────┘
         ▲                              ▲
         │ :9182                        │ Graph API
         │                              │
┌────────┴────────┐          ┌─────────┴──────────┐
│ Windows Servers │          │  Microsoft 365     │
│ (WMI Exporter)  │          │  (Graph API)       │
└─────────────────┘          └────────────────────┘
         ▲
         │ Azure Monitor API
         │
┌────────┴────────┐
│ Azure Resources │
└─────────────────┘
```

### Manual Installation
```
┌─────────────────┐
│  Windows Servers│
│  (WMI Exporter) │
└────────┬────────┘
         │ :9182
         ▼
┌─────────────────┐      ┌─────────────────┐
│   Prometheus    │◄─────┤  Grafana (macOS)│
│   (localhost)   │:9090 │  localhost:3000 │
└─────────────────┘      └────────┬────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
            ┌────────────┐ ┌──────────┐ ┌──────────┐
            │   Azure    │ │  Graph   │ │  JSON    │
            │  Monitor   │ │   API    │ │   API    │
            └────────────┘ └──────────┘ └──────────┘
```

## 🎨 Customization

### Add New Metrics

1. **Windows Metrics:** Enable more WMI Exporter collectors
2. **Azure Metrics:** Add more Azure resource queries
3. **M365 Metrics:** Query additional Graph API endpoints

### Create Custom Dashboards

1. Go to **Create** → **Dashboard**
2. **Add panel**
3. Select data source
4. Configure query
5. Choose visualization
6. **Save dashboard**

### Set Up Alerts

1. Edit panel
2. **Alert** tab
3. Create alert rule
4. Set thresholds
5. Configure notifications

## 🔍 Common Queries

### Prometheus (Windows)
```promql
# CPU Usage
100 - (avg by (instance) (rate(windows_cpu_time_total{mode="idle"}[5m])) * 100)

# Memory Available
windows_os_physical_memory_free_bytes / 1024 / 1024 / 1024

# Disk Free %
100 * (windows_logical_disk_free_bytes / windows_logical_disk_size_bytes)
```

### Azure Monitor
```
# VM CPU
Microsoft.Compute/virtualMachines → Percentage CPU

# Storage Availability
Microsoft.Storage/storageAccounts → Availability
```

### Microsoft Graph API
```
# Active Users
GET /users/$count?$filter=accountEnabled eq true

# Teams Activity
GET /reports/getTeamsUserActivityCounts(period='D30')
```

## 🚨 Troubleshooting

### Grafana Won't Start
```bash
# Check logs
tail -f /opt/homebrew/var/log/grafana/grafana.log

# Restart service
brew services restart grafana
```

### No Data in Panels
1. Check data source connection
2. Verify time range
3. Test query in Explore
4. Check target is up in Prometheus

### WMI Exporter Not Working
```powershell
# Check service
Get-Service windows_exporter

# Test endpoint
Invoke-WebRequest http://localhost:9182/metrics

# Check firewall
Get-NetFirewallRule -DisplayName "WMI Exporter"
```

## 📚 Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [WMI Exporter](https://github.com/prometheus-community/windows_exporter)
- [Azure Monitor](https://docs.microsoft.com/azure/azure-monitor/)
- [Microsoft Graph](https://docs.microsoft.com/graph/)

## 🎯 Next Steps

After setup:

1. ✅ Set up alerting for critical metrics
2. ✅ Create custom dashboards for your needs
3. ✅ Configure backup of Grafana settings
4. ✅ Share dashboards with your team
5. ✅ Integrate with notification channels (email, Teams, Slack)

---

**Ready to monitor?** Start with [01-Grafana-Installation.md](01-Grafana-Installation.md)!
