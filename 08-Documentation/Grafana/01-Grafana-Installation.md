# Grafana Installation Guide

Complete step-by-step guide to install Grafana on macOS for monitoring Microsoft infrastructure.

## Prerequisites

- macOS with Homebrew installed
- Administrative access
- Internet connection

## Step 1: Install Grafana

### Using Homebrew (Recommended)

```bash
# Update Homebrew
brew update

# Install Grafana
brew install grafana

# Start Grafana service
brew services start grafana
```

### Verify Installation

```bash
# Check Grafana status
brew services list | grep grafana

# Test Grafana is running
curl http://localhost:3000
```

## Step 2: Access Grafana

1. Open your browser and navigate to:
   ```
   http://localhost:3000
   ```

2. **Default credentials:**
   - Username: `admin`
   - Password: `admin`

3. You'll be prompted to change the password on first login

## Step 3: Configure Grafana

### Update Grafana Configuration

Edit the Grafana configuration file:

```bash
# Open configuration file
nano /opt/homebrew/etc/grafana/grafana.ini
```

### Key Configuration Options

```ini
[server]
# HTTP port
http_port = 3000

# Domain name
domain = localhost

# Root URL
root_url = http://localhost:3000

[security]
# Set to true if using HTTPS
admin_user = admin
admin_password = your_secure_password

[auth]
# Enable anonymous access (optional)
disable_login_form = false

[users]
# Allow users to sign up
allow_sign_up = false

[analytics]
# Disable reporting to grafana.com
reporting_enabled = false

[log]
# Log level
level = info
```

### Restart Grafana After Configuration

```bash
brew services restart grafana
```

## Step 4: Install Grafana CLI Plugins

### Azure Monitor Plugin

```bash
grafana-cli plugins install grafana-azure-monitor-datasource
```

### Prometheus Plugin (usually pre-installed)

```bash
# Verify Prometheus plugin is available
grafana-cli plugins ls
```

### JSON API Plugin (for Microsoft Graph API)

```bash
grafana-cli plugins install marcusolsson-json-datasource
```

### Restart Grafana

```bash
brew services restart grafana
```

## Step 5: Verify Plugin Installation

1. Log into Grafana: http://localhost:3000
2. Go to **Configuration** (⚙️) → **Plugins**
3. Verify installed plugins:
   - Azure Monitor
   - Prometheus
   - JSON API

## Step 6: Configure Data Sources

We'll configure data sources in the next guides:
- [02-Azure-Monitor-Setup.md](02-Azure-Monitor-Setup.md)
- [03-Prometheus-WMI-Setup.md](03-Prometheus-WMI-Setup.md)
- [04-Graph-API-Integration.md](04-Graph-API-Integration.md)

## Grafana Directory Structure

```
/opt/homebrew/etc/grafana/
├── grafana.ini              # Main configuration
├── provisioning/
│   ├── dashboards/         # Dashboard provisioning
│   ├── datasources/        # Datasource provisioning
│   ├── notifiers/          # Alert notifiers
│   └── plugins/            # Plugin configurations
└── grafana.db              # SQLite database (if using default)

/opt/homebrew/var/log/grafana/
└── grafana.log             # Grafana logs
```

## Useful Commands

### Service Management

```bash
# Start Grafana
brew services start grafana

# Stop Grafana
brew services stop grafana

# Restart Grafana
brew services restart grafana

# Check status
brew services info grafana
```

### View Logs

```bash
# Real-time log viewing
tail -f /opt/homebrew/var/log/grafana/grafana.log

# View last 100 lines
tail -n 100 /opt/homebrew/var/log/grafana/grafana.log
```

### Backup Grafana

```bash
# Backup Grafana database and configuration
cp /opt/homebrew/var/lib/grafana/grafana.db ~/grafana-backup-$(date +%Y%m%d).db
cp /opt/homebrew/etc/grafana/grafana.ini ~/grafana-config-backup-$(date +%Y%m%d).ini
```

## Troubleshooting

### Grafana Won't Start

```bash
# Check logs
tail -n 50 /opt/homebrew/var/log/grafana/grafana.log

# Check if port 3000 is already in use
lsof -i :3000

# Kill process using port 3000
kill -9 $(lsof -t -i:3000)

# Restart Grafana
brew services restart grafana
```

### Plugin Installation Issues

```bash
# Check plugin directory
ls -la /opt/homebrew/var/lib/grafana/plugins/

# Reinstall plugin
grafana-cli plugins uninstall grafana-azure-monitor-datasource
grafana-cli plugins install grafana-azure-monitor-datasource

# Restart Grafana
brew services restart grafana
```

### Reset Admin Password

```bash
# Stop Grafana
brew services stop grafana

# Reset password
grafana-cli admin reset-admin-password newpassword

# Start Grafana
brew services start grafana
```

## Security Best Practices

1. **Change default admin password** immediately
2. **Disable anonymous access** in production
3. **Use HTTPS** for production deployments
4. **Restrict network access** to Grafana port
5. **Regular backups** of Grafana database
6. **Keep Grafana updated** regularly

```bash
# Update Grafana
brew upgrade grafana
brew services restart grafana
```

## Next Steps

1. ✅ Grafana installed and running
2. ➡️ Configure Azure Monitor data source: [02-Azure-Monitor-Setup.md](02-Azure-Monitor-Setup.md)
3. ➡️ Setup Prometheus with WMI Exporter: [03-Prometheus-WMI-Setup.md](03-Prometheus-WMI-Setup.md)
4. ➡️ Integrate Microsoft Graph API: [04-Graph-API-Integration.md](04-Graph-API-Integration.md)
5. ➡️ Import pre-built dashboards: [05-Dashboard-Import.md](05-Dashboard-Import.md)

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Grafana Community Forums](https://community.grafana.com/)
- [Grafana Plugins](https://grafana.com/grafana/plugins/)
