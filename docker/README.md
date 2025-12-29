# Docker Monitoring Stack

Complete Docker-based monitoring solution with Grafana, Prometheus, and Microsoft Graph API integration.

## 🚀 Quick Start

```bash
# 1. Navigate to docker directory
cd /Users/omiranda/Documents/GitHub/ms-tools/docker

# 2. Configure Azure AD credentials
cp graph-api-proxy/.env.example graph-api-proxy/.env
nano graph-api-proxy/.env  # Add your Azure AD credentials

# 3. Start the stack
./monitoring-stack.sh start

# 4. Access Grafana
open http://localhost:3000
# Username: admin
# Password: admin
```

## 📦 What's Included

### Services

| Service | Port | Description |
|---------|------|-------------|
| **Grafana** | 3000 | Main visualization dashboard |
| **Prometheus** | 9090 | Metrics collection and storage |
| **Node Exporter** | 9100 | Docker host metrics |
| **cAdvisor** | 8080 | Container metrics |
| **Graph API Proxy** | 3001 | Microsoft 365 data via Graph API |
| **Alertmanager** | 9093 | Alert routing and management |

### Pre-configured Features

✅ **Auto-provisioned Grafana datasources**
- Prometheus (default)
- Microsoft Graph API (JSON plugin)
- Azure Monitor

✅ **Pre-built dashboards**
- Windows Servers Monitoring
- Docker Container Metrics
- Host System Metrics

✅ **Alert rules**
- High CPU usage (>90% for 5min)
- High memory usage (>90% for 5min)
- Low disk space (<10%)
- Server/container down alerts

✅ **Data persistence**
- Grafana configurations and dashboards
- Prometheus metrics (30-day retention)
- Alert history

## 🔧 Setup Instructions

### Prerequisites

1. **Docker Desktop** (macOS/Windows) or **Docker Engine** (Linux)
   ```bash
   # Install on macOS
   brew install --cask docker
   ```

2. **Docker Compose V2** (included with Docker Desktop)
   ```bash
   # Verify installation
   docker compose version
   ```

### Step 1: Configure Azure AD for Graph API

1. **Create Azure AD App Registration:**
   - Go to [Azure Portal](https://portal.azure.com)
   - Navigate to **Azure Active Directory** → **App registrations** → **New registration**
   - Name: `Grafana-GraphAPI`
   - Click **Register**

2. **Add API Permissions:**
   - Go to **API permissions** → **Add a permission**
   - Select **Microsoft Graph** → **Application permissions**
   - Add these permissions:
     - `User.Read.All`
     - `Group.Read.All`
     - `Reports.Read.All`
     - `Directory.Read.All`
   - Click **Grant admin consent**

3. **Create Client Secret:**
   - Go to **Certificates & secrets** → **New client secret**
   - Description: `Grafana`
   - Copy the secret value (you won't see it again!)

4. **Get Tenant ID and Client ID:**
   - Go to **Overview**
   - Copy **Application (client) ID**
   - Copy **Directory (tenant) ID**

5. **Configure environment:**
   ```bash
   cd docker
   cp graph-api-proxy/.env.example graph-api-proxy/.env
   ```

   Edit `.env` file:
   ```env
   AZURE_TENANT_ID=your-tenant-id-here
   AZURE_CLIENT_ID=your-client-id-here
   AZURE_CLIENT_SECRET=your-client-secret-here
   ```

### Step 2: Configure Windows Servers (Optional)

Edit `prometheus/prometheus.yml` and add your Windows servers:

```yaml
scrape_configs:
  - job_name: 'windows-servers'
    static_configs:
      - targets:
          - '192.168.1.10:9182'  # Server 1
          - '192.168.1.11:9182'  # Server 2
```

**Note:** Windows servers must have WMI Exporter installed. See [WMI Exporter Setup](../08-Documentation/Grafana/03-Prometheus-WMI-Setup.md).

### Step 3: Start the Stack

```bash
./monitoring-stack.sh start
```

This will:
1. Check prerequisites
2. Create `.env` file if needed
3. Copy dashboards to Grafana
4. Start all containers
5. Show access URLs

## 📊 Management Commands

```bash
# Start the stack
./monitoring-stack.sh start

# Stop the stack
./monitoring-stack.sh stop

# Restart the stack
./monitoring-stack.sh restart

# Show status
./monitoring-stack.sh status

# View logs (all services)
./monitoring-stack.sh logs

# View logs (specific service)
./monitoring-stack.sh logs grafana
./monitoring-stack.sh logs prometheus

# Show access URLs
./monitoring-stack.sh urls

# Update to latest versions
./monitoring-stack.sh update

# Backup Grafana data
./monitoring-stack.sh backup

# Restore Grafana data
./monitoring-stack.sh restore backups/grafana-backup-20250129-120000.tar.gz

# Add Windows server
./monitoring-stack.sh add-server 192.168.1.10 server01

# Remove everything (including data)
./monitoring-stack.sh cleanup
```

## 🌐 Accessing Services

After starting the stack:

### Grafana
- **URL:** http://localhost:3000
- **Username:** `admin`
- **Password:** `admin` (change on first login)

### Prometheus
- **URL:** http://localhost:9090
- **Query metrics:** Go to Graph → Enter PromQL query
- **Targets:** Status → Targets (check scrape status)

### Node Exporter
- **URL:** http://localhost:9100/metrics
- **Shows:** Raw metrics from Docker host

### cAdvisor
- **URL:** http://localhost:8080
- **Shows:** Container resource usage

### Graph API Proxy
- **URL:** http://localhost:3001
- **Health:** http://localhost:3001/health
- **Test:** http://localhost:3001/api/graph/users

### Alertmanager
- **URL:** http://localhost:9093
- **Shows:** Active alerts and silences

## 📈 Creating Dashboards

### Import Pre-built Dashboard

1. Open Grafana: http://localhost:3000
2. Click **+** → **Import**
3. Dashboard is auto-loaded from `grafana/dashboards/`

### Import from Grafana.com

1. Go to **+** → **Import**
2. Enter dashboard ID:
   - **14694** - Windows Node Exporter Full
   - **893** - Docker & System Monitoring
   - **10619** - Docker Containers
3. Select **Prometheus** as datasource
4. Click **Import**

### Query Microsoft 365 Data

1. Create new dashboard
2. Add panel
3. Select datasource: **Microsoft Graph API**
4. Query type: **Timeseries**
5. Metric examples:
   - `users.count` - Total users
   - `users.active` - Active users (30 days)
   - `teams.count` - Teams count
   - `licenses.assigned` - Assigned licenses

## 🔔 Configuring Alerts

### Email Alerts

Edit `alertmanager/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'

receivers:
  - name: 'critical-team'
    email_configs:
      - to: 'admin@example.com'
```

Restart Alertmanager:
```bash
docker compose restart alertmanager
```

### Slack/Teams Webhooks

```yaml
receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
```

## 🗂️ Directory Structure

```
docker/
├── docker-compose.yml              # Main compose file
├── monitoring-stack.sh             # Management script
├── .env                            # Environment variables (create from .env.example)
├── prometheus/
│   ├── prometheus.yml              # Prometheus config
│   └── rules/
│       └── alerts.yml              # Alert rules
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml     # Auto-provision datasources
│   │   └── dashboards/
│   │       └── dashboards.yml      # Auto-provision dashboards
│   └── dashboards/                 # Dashboard JSON files
├── graph-api-proxy/
│   ├── Dockerfile                  # Graph API proxy image
│   ├── package.json                # Node.js dependencies
│   ├── server.js                   # Proxy application
│   └── .env.example                # Environment template
├── alertmanager/
│   └── alertmanager.yml            # Alert routing config
└── backups/                        # Grafana backups (created on backup)
```

## 🔧 Troubleshooting

### Grafana shows "No data"

1. Check Prometheus is running:
   ```bash
   curl http://localhost:9090/-/healthy
   ```

2. Check Prometheus targets:
   - Go to http://localhost:9090/targets
   - Ensure all targets are "UP"

3. Check Grafana datasource:
   - Go to Configuration → Data sources
   - Test Prometheus connection

### Graph API returns errors

1. Check container logs:
   ```bash
   ./monitoring-stack.sh logs graph-api-proxy
   ```

2. Verify Azure AD credentials:
   ```bash
   cat graph-api-proxy/.env
   ```

3. Test manually:
   ```bash
   curl http://localhost:3001/health
   ```

### Windows servers not showing data

1. Verify WMI Exporter is installed and running on Windows servers
2. Check firewall allows port 9182
3. Test from Docker host:
   ```bash
   curl http://WINDOWS-SERVER-IP:9182/metrics
   ```

4. Check Prometheus targets:
   - http://localhost:9090/targets
   - Look for `windows-servers` job

### Container won't start

1. Check logs:
   ```bash
   docker compose logs <service-name>
   ```

2. Check ports aren't in use:
   ```bash
   lsof -i :3000  # Grafana
   lsof -i :9090  # Prometheus
   ```

3. Remove and recreate:
   ```bash
   docker compose down
   docker compose up -d
   ```

## 🔄 Updating

```bash
# Pull latest images
./monitoring-stack.sh update

# Or manually
docker compose pull
docker compose up -d --force-recreate
```

## 💾 Backup & Restore

### Backup

```bash
# Automated backup
./monitoring-stack.sh backup

# Manual backup
docker run --rm \
  --volumes-from grafana \
  -v $(pwd)/backups:/backup \
  alpine:latest \
  tar czf /backup/grafana-backup-$(date +%Y%m%d).tar.gz -C /var/lib/grafana .
```

### Restore

```bash
# Using script
./monitoring-stack.sh restore backups/grafana-backup-20250129.tar.gz

# Manual restore
docker compose stop grafana
docker run --rm \
  --volumes-from grafana \
  -v $(pwd)/backups:/backup \
  alpine:latest \
  sh -c "cd /var/lib/grafana && tar xzf /backup/grafana-backup-20250129.tar.gz"
docker compose start grafana
```

## 🚀 Advanced Configuration

### Change Data Retention

Edit `docker-compose.yml`:

```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=60d'  # Change from 30d to 60d
```

### Add More Scrapers

Edit `prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'my-custom-app'
    static_configs:
      - targets: ['app-server:9090']
```

### Custom Grafana Plugins

Edit `docker-compose.yml`:

```yaml
grafana:
  environment:
    - GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel
```

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Microsoft Graph API](https://docs.microsoft.com/graph/)
- [WMI Exporter Setup Guide](../08-Documentation/Grafana/03-Prometheus-WMI-Setup.md)

## 📝 Notes

- **Default password:** Change admin password on first login
- **Data persistence:** All data stored in Docker volumes
- **Security:** Use environment variables for secrets
- **Production:** Use proper SSL/TLS certificates
- **Monitoring:** Set up proper alerting for production use

## 🆘 Getting Help

1. Check logs: `./monitoring-stack.sh logs <service>`
2. Check status: `./monitoring-stack.sh status`
3. Review documentation in [/08-Documentation/Grafana/](../08-Documentation/Grafana/)
4. Test individual components

---

**Copyright © 2025 Omar Miranda**
