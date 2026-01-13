# Microsoft 365 & Infrastructure Automation Toolkit

Complete PowerShell automation toolkit with Grafana monitoring for Microsoft infrastructure.

## 🚀 Quick Start

```bash
# 1. Install PowerShell (macOS)
brew install --cask powershell
pwsh

# 2. Install dependencies
cd /path/to/ms-tools
./Install-M365Dependencies.ps1

# 3. Start using scripts!
./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1
```

## 📚 Documentation

**Complete documentation is in the `/08-Documentation` folder:**

- **[📖 Documentation Index](08-Documentation/INDEX.md)** - Complete navigation guide
- **[🚀 Getting Started](08-Documentation/Getting-Started/GETTING-STARTED.md)** - 5-minute quick start
- **[⚡ Quick Reference](08-Documentation/Getting-Started/QUICK-REFERENCE.md)** - One-page command guide
- **[📋 Script Index](08-Documentation/Getting-Started/SCRIPT-INDEX.md)** - All available scripts

## 📊 Grafana Monitoring Setup

**Complete monitoring solution included:**

1. [Install Grafana](08-Documentation/Grafana/01-Grafana-Installation.md)
2. [Setup Azure Monitor](08-Documentation/Grafana/02-Azure-Monitor-Setup.md)
3. [Configure Prometheus + WMI Exporter](08-Documentation/Grafana/03-Prometheus-WMI-Setup.md)
4. [Integrate Microsoft Graph API](08-Documentation/Grafana/04-Graph-API-Integration.md)
5. [Import Dashboards](08-Documentation/Grafana/05-Dashboard-Import.md)

**Pre-built dashboards included** for Windows servers, Azure resources, and Microsoft 365.

## 🗂️ What's Included

### 29 PowerShell Scripts

- **10 Infrastructure scripts** - AD, DNS, DHCP, File Servers, GPO
- **8 Cloud & Hybrid scripts** - M365, Azure AD, Intune, Azure
- **4 Security & Compliance scripts** - RBAC, Encryption, Defender, Auditing
- **2 Backup & DR scripts**
- **1 Networking script**
- **1 Monitoring script**
- **3 Automation scripts**

### Monitoring Solution

- Grafana dashboards
- Prometheus metrics
- Azure Monitor integration
- Microsoft Graph API integration
- WMI Exporter for Windows

### Complete Documentation

- Installation guides
- Configuration tutorials
- Best practices
- Troubleshooting guides
- Script references

## 🎯 Common Use Cases

### Security Audit
```powershell
# Check mailbox forwarding
./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1 -ExportToCSV

# Analyze security events
./03-Security-Compliance/Auditing/Get-SecurityEventLog.ps1 -Hours 48

# Check Defender status
./03-Security-Compliance/Endpoint-Security/Get-DefenderStatus.ps1
```

### Infrastructure Health
```powershell
# Server health check
./06-Monitoring/Health-Performance/Get-ServerHealth.ps1

# Disk space analysis
./01-Infrastructure/FileServers/Get-FileServerSpace.ps1 -Path "C:\Data"

# Network diagnostics
./05-Networking/Connectivity/Test-NetworkConnectivity.ps1 -Target "server.com"
```

### User Management
```powershell
# Find inactive users
./02-Cloud-Hybrid/AzureAD/Get-InactiveUsers-SharePoint-Teams.ps1 -TeamsRecipientEmail "admin@domain.com"

# Bulk password reset
./07-Automation/Bulk-Operations/Reset-BulkPasswords.ps1 -CSVPath "users.csv" -WhatIf

# User onboarding workflow
./07-Automation/User-Provisioning/New-UserWorkflow.ps1 -FirstName "John" -LastName "Doe" ...
```

## 📁 Repository Structure

```
ms-tools/
├── 01-Infrastructure/          # Windows Server & AD scripts
├── 02-Cloud-Hybrid/           # Microsoft 365 & Azure scripts
├── 03-Security-Compliance/    # Security & compliance scripts
├── 04-Backup-DR/              # Backup & disaster recovery
├── 05-Networking/             # Network diagnostics
├── 06-Monitoring/             # Monitoring & dashboards
├── 07-Automation/             # Automation workflows
├── 08-Documentation/          # Complete documentation
│   ├── Getting-Started/       # Quick start guides
│   ├── Grafana/              # Monitoring setup
│   └── INDEX.md              # Documentation index
└── Install-M365Dependencies.ps1
```

## 🔐 Requirements

### For PowerShell Scripts
- PowerShell 7+ (macOS, Windows, Linux)
- Appropriate admin permissions
- Microsoft 365 / Azure subscription

### For Grafana Monitoring
- Grafana 9.0+
- Prometheus
- WMI Exporter (Windows servers)
- Azure Service Principal
- Microsoft Graph API access

## 💻 Platform Support

- ✅ **macOS** - Full support (primary development platform)
- ✅ **Windows** - Full support for all scripts
- ✅ **Linux** - PowerShell scripts supported, monitoring tools supported

## 🎓 Learning Resources

- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Microsoft Graph API](https://docs.microsoft.com/graph/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)

## 🤝 Contributing

This is an internal tool repository. For improvements:

1. Test changes thoroughly
2. Update documentation
3. Follow existing script patterns
4. Add help documentation

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

Copyright 2025 Microsoft 365 & Infrastructure Management Tools

## 🆘 Support

For issues or questions:

1. Check [Documentation Index](08-Documentation/INDEX.md)
2. Review script help: `Get-Help ./script.ps1 -Full`

---

**Ready to get started?** Check out the [Getting Started Guide](08-Documentation/Getting-Started/GETTING-STARTED.md)!
