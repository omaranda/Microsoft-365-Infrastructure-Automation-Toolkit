# Grafana Dashboard Import Guide

Import pre-configured dashboards for monitoring Microsoft infrastructure.

## Available Dashboards

1. **Windows Servers Monitoring** - CPU, Memory, Disk, Network
2. **Azure Resources** - Azure VMs, Storage, SQL Database
3. **Microsoft 365** - User activity, Teams usage, Licenses
4. **Active Directory** - Domain Controllers, Replication
5. **Security Overview** - Failed logins, Security events

## Method 1: Import from JSON File

### Windows Servers Dashboard

1. **Download the dashboard:**
   - File location: `/Users/omiranda/Documents/GitHub/ms-tools/06-Monitoring/Azure-Monitor/grafana-dashboard-windows-servers.json`

2. **Import in Grafana:**
   - Open Grafana: http://localhost:3000
   - Click **+** (Create) → **Import**
   - Click **Upload JSON file**
   - Select `grafana-dashboard-windows-servers.json`
   - Select **Prometheus** as the data source
   - Click **Import**

3. **Verify Dashboard:**
   - Dashboard should load with all panels
   - Check that data is flowing
   - Adjust time range if needed (top-right)

## Method 2: Import from Grafana.com

### Popular Windows Server Dashboards

```
Dashboard ID: 14694 - Windows Node Exporter Full
Dashboard ID: 12052 - Windows Server Monitoring
Dashboard ID: 10467 - Windows Performance Dashboard
```

**To Import:**
1. Go to **Create** → **Import**
2. Enter Dashboard ID
3. Click **Load**
4. Select **Prometheus** data source
5. Click **Import**

### Azure Monitor Dashboards

```
Dashboard ID: 10532 - Azure Monitor for VMs
Dashboard ID: 12180 - Azure SQL Database
Dashboard ID: 11058 - Azure Storage Account
```

## Method 3: Provision Dashboards Automatically

For automated dashboard deployment, use provisioning:

### Step 1: Create Provisioning Configuration

```bash
# Create provisioning directory
mkdir -p /opt/homebrew/etc/grafana/provisioning/dashboards

# Create dashboard provider config
cat > /opt/homebrew/etc/grafana/provisioning/dashboards/default.yaml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /opt/homebrew/etc/grafana/provisioning/dashboards
EOF
```

### Step 2: Copy Dashboard Files

```bash
# Copy dashboard JSON files to provisioning folder
cp /Users/omiranda/Documents/GitHub/ms-tools/06-Monitoring/Azure-Monitor/*.json \
   /opt/homebrew/etc/grafana/provisioning/dashboards/

# Restart Grafana
brew services restart grafana
```

Dashboards will auto-load on Grafana startup.

## Dashboard Customization

### Update Data Source

If your Prometheus data source has a different name:

1. Open the dashboard
2. Click **Dashboard settings** (⚙️)
3. **Variables** → Edit datasource variable
4. Or edit JSON and find/replace datasource UIDs

### Add Variables

Common variables to add:

```json
{
  "name": "server",
  "type": "query",
  "datasource": "Prometheus",
  "query": "label_values(up{job=\"windows-servers\"}, instance)"
}
```

### Modify Panels

1. Click panel title → **Edit**
2. Modify query, visualization, or thresholds
3. Click **Apply**
4. **Save dashboard** (💾 icon)

## Pre-configured Dashboards Overview

### 1. Windows Servers Monitoring

**Panels:**
- CPU Usage (Gauge)
- Memory Usage (Gauge)
- Disk Free Space (Gauge)
- CPU Usage Over Time (Time Series)
- Available Memory (Time Series)
- Server Status (Table)
- Network Traffic (Time Series)

**Metrics:**
- CPU: `windows_cpu_time_total`
- Memory: `windows_os_physical_memory_free_bytes`
- Disk: `windows_logical_disk_free_bytes`
- Network: `windows_net_bytes_received_total`

### 2. Azure Resources Dashboard

Create `/Users/omiranda/Documents/GitHub/ms-tools/06-Monitoring/Azure-Monitor/grafana-dashboard-azure.json`:

**Panels:**
- VM CPU Percentage
- VM Memory Available
- Storage Account Availability
- SQL Database DTU
- Network In/Out

**Data Source:** Azure Monitor

### 3. Microsoft 365 Dashboard

**Panels:**
- Active Users Count
- Teams Daily Active Users
- Exchange Active Mailboxes
- OneDrive Usage
- License Consumption

**Data Source:** Microsoft Graph API (JSON)

### 4. Security Dashboard

**Panels:**
- Failed Login Attempts (24h)
- Account Lockouts
- Windows Defender Status
- Security Event Timeline
- Top Failed Login Accounts

**Data Source:** Prometheus (from Security Event Log exporter)

## Dashboard Best Practices

### 1. Organization

- **Create folders** for different categories
- Use **tags** for easy searching
- Set **meaningful names** and descriptions

### 2. Performance

- **Limit time range** to avoid excessive queries
- Use **appropriate refresh intervals** (30s-5m)
- **Aggregate data** for long-term views
- Enable **query caching** where possible

### 3. Alerting

Add alerts to critical panels:

1. Edit panel
2. **Alert** tab
3. Create alert rule
4. Set conditions and thresholds
5. Configure notification channels

### 4. Annotations

Mark important events:

```
Configuration → Annotations → Add annotation query
```

Example: Mark deployments, maintenance windows

## Sharing Dashboards

### Export Dashboard

```bash
# Get dashboard JSON via API
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:3000/api/dashboards/uid/windows-servers > dashboard-backup.json
```

### Create Snapshot

1. **Share** button → **Snapshot**
2. Set expiration
3. **Publish to snapshot.raintank.io** (or local)
4. Copy link

### Embed in Webpage

```html
<iframe
  src="http://grafana:3000/d-solo/windows-servers/windows-servers-monitoring?orgId=1&panelId=1"
  width="450"
  height="200"
  frameborder="0">
</iframe>
```

## Troubleshooting

### Dashboard Shows "No Data"

1. **Check data source** is selected correctly
2. **Verify time range** includes data
3. **Test query** in Explore view
4. **Check targets** are up in Prometheus

### Panels Not Updating

1. **Check refresh interval** (top-right)
2. **Verify auto-refresh** is enabled
3. **Check data source** connection
4. **Review query errors** in panel inspector

### Dashboard Won't Import

1. **Check JSON syntax** - use a JSON validator
2. **Verify Grafana version** compatibility
3. **Remove version-specific fields** if needed
4. **Import manually** panel by panel

## Next Steps

✅ All components configured!
✅ Dashboards imported

**Now you can:**
1. Monitor your infrastructure in real-time
2. Set up alerts for critical metrics
3. Create custom dashboards
4. Share dashboards with your team

## Additional Resources

- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/dashboard-management/)
- [Community Dashboards](https://grafana.com/grafana/dashboards/?search=windows)
