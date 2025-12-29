# Documentation Index

Complete documentation for Microsoft 365 and Infrastructure PowerShell automation tools with Grafana monitoring.

## 📚 Table of Contents

### Quick Start
- [README](README.md) - Main documentation overview
- [Getting Started](Getting-Started/GETTING-STARTED.md) - 5-minute quick start
- [Quick Reference](Getting-Started/QUICK-REFERENCE.md) - One-page command reference
- [Script Index](Getting-Started/SCRIPT-INDEX.md) - All available scripts
- [Scripts Created](Getting-Started/SCRIPTS-CREATED.md) - Complete script list
- [Setup macOS](Getting-Started/Setup-M365-MacOS.md) - macOS environment setup

### Development
- [Setup macOS](Getting-Started/Setup-M365-MacOS.md) - macOS environment setup

---

## 🎯 By Topic

### 📊 Monitoring with Grafana

**Complete monitoring solution with Grafana, Prometheus, Azure Monitor, and Microsoft Graph API**

1. [Grafana Installation](Grafana/01-Grafana-Installation.md)
   - Install Grafana on macOS
   - Basic configuration
   - Plugin installation

2. [Azure Monitor Setup](Grafana/02-Azure-Monitor-Setup.md)
   - Create Azure Service Principal
   - Configure Azure Monitor data source
   - Query Azure metrics

3. [Prometheus + WMI Exporter](Grafana/03-Prometheus-WMI-Setup.md)
   - Install Prometheus
   - Deploy WMI Exporter to Windows servers
   - Configure metrics collection

4. [Microsoft Graph API Integration](Grafana/04-Graph-API-Integration.md)
   - Setup Graph API authentication
   - Create API proxy
   - Query Microsoft 365 data

5. [Dashboard Import](Grafana/05-Dashboard-Import.md)
   - Import pre-built dashboards
   - Customize panels
   - Share dashboards

**Dashboard Templates:**
- [Windows Servers Dashboard](../06-Monitoring/Azure-Monitor/grafana-dashboard-windows-servers.json)

---

### 🏢 Infrastructure Management

#### Active Directory
**Scripts:** `01-Infrastructure/ActiveDirectory/`
- Get-ADUserReport.ps1
- New-BulkADUsers.ps1
- Set-ADGroupMembership.ps1
- Reset-ADPassword.ps1

**Use Cases:**
- Generate user reports
- Bulk user creation
- Group management
- Password resets

#### DNS & DHCP
**Scripts:** `01-Infrastructure/DNS-DHCP/`
- Get-DNSRecords.ps1
- Get-DHCPLeases.ps1

**Use Cases:**
- DNS record auditing
- DHCP scope monitoring
- IP address management

#### File Servers
**Scripts:** `01-Infrastructure/FileServers/`
- Get-FilePermissions.ps1
- Get-FileServerSpace.ps1

**Use Cases:**
- Permission auditing
- Disk space monitoring
- Capacity planning

#### Group Policy
**Scripts:** `01-Infrastructure/GroupPolicy/`
- Get-GPOReport.ps1

**Use Cases:**
- GPO documentation
- Policy auditing

#### Print Services
**Scripts:** `01-Infrastructure/PrintServices/`
- Get-PrintQueue.ps1

**Use Cases:**
- Print queue monitoring
- Clear stuck jobs

---

### ☁️ Cloud & Hybrid

#### Microsoft 365
**Scripts:** `02-Cloud-Hybrid/Microsoft365/`
- Get-MailboxForwardingRules.ps1
- Remove-MailboxForwardingRules.ps1
- Get-TeamsUsage.ps1

**Use Cases:**
- Exchange security auditing
- Mailbox forwarding management
- Teams usage reports

#### Azure AD / Entra ID
**Scripts:** `02-Cloud-Hybrid/AzureAD/`
- Get-InactiveUsers-SharePoint-Teams.ps1
- Sync-ADConnect.ps1
- Set-ConditionalAccessPolicy.ps1

**Use Cases:**
- Inactive user cleanup
- Hybrid identity sync
- Conditional Access management

#### Intune
**Scripts:** `02-Cloud-Hybrid/Intune/`
- Get-IntuneNonCompliantDevices.ps1

**Use Cases:**
- Device compliance monitoring
- Endpoint management

#### Azure Resources
**Scripts:** `02-Cloud-Hybrid/Azure-Resources/`
- Start-AzureVMBackup.ps1

**Use Cases:**
- VM backup management
- Azure resource monitoring

---

### 🔒 Security & Compliance

#### RBAC
**Scripts:** `03-Security-Compliance/RBAC/`
- Get-RoleAssignments.ps1

**Use Cases:**
- Azure role auditing
- Access review

#### Encryption
**Scripts:** `03-Security-Compliance/Encryption/`
- Enable-BitLocker.ps1

**Use Cases:**
- BitLocker deployment
- Encryption management

#### Endpoint Security
**Scripts:** `03-Security-Compliance/Endpoint-Security/`
- Get-DefenderStatus.ps1

**Use Cases:**
- Defender status monitoring
- Security baseline checks

#### Auditing
**Scripts:** `03-Security-Compliance/Auditing/`
- Get-SecurityEventLog.ps1

**Use Cases:**
- Security event analysis
- Compliance reporting
- Incident investigation

---

### 💾 Backup & DR

#### Windows Backup
**Scripts:** `04-Backup-DR/Windows-Backup/`
- Start-WindowsBackup.ps1

**Use Cases:**
- Automated backups
- Backup verification

#### Azure Backup
**Scripts:** `04-Backup-DR/Azure-Backup/`
- Start-AzureVMBackup.ps1

**Use Cases:**
- Azure VM protection
- DR testing

---

### 🌐 Networking

#### Connectivity
**Scripts:** `05-Networking/Connectivity/`
- Test-NetworkConnectivity.ps1

**Use Cases:**
- Network troubleshooting
- Connectivity diagnostics
- Port testing

---

### 📈 Monitoring & Performance

#### Health & Performance
**Scripts:** `06-Monitoring/Health-Performance/`
- Get-ServerHealth.ps1

**Use Cases:**
- Server health checks
- Performance monitoring
- Capacity planning

#### Azure Monitor
**Scripts:** `06-Monitoring/Azure-Monitor/`
- Grafana dashboard templates
- Graph API proxy

**Use Cases:**
- Real-time monitoring
- Metrics visualization
- Alerting

---

### 🤖 Automation

#### User Provisioning
**Scripts:** `07-Automation/User-Provisioning/`
- New-UserWorkflow.ps1

**Use Cases:**
- Automated onboarding
- User lifecycle management

#### License Management
**Scripts:** `07-Automation/License-Management/`
- Set-M365Licenses.ps1

**Use Cases:**
- License automation
- Cost optimization

#### Bulk Operations
**Scripts:** `07-Automation/Bulk-Operations/`
- Reset-BulkPasswords.ps1

**Use Cases:**
- Password resets
- Bulk modifications

---

## 🔍 Search by Task

### Daily Operations
- [Check mailbox forwarding](../02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1)
- [Monitor server health](../06-Monitoring/Health-Performance/Get-ServerHealth.ps1)
- [Check security events](../03-Security-Compliance/Auditing/Get-SecurityEventLog.ps1)
- [Monitor print queues](../01-Infrastructure/PrintServices/Get-PrintQueue.ps1)

### Weekly Tasks
- [Generate AD user reports](../01-Infrastructure/ActiveDirectory/Get-ADUserReport.ps1)
- [Review file server space](../01-Infrastructure/FileServers/Get-FileServerSpace.ps1)
- [Check Defender status](../03-Security-Compliance/Endpoint-Security/Get-DefenderStatus.ps1)
- [Monitor Intune compliance](../02-Cloud-Hybrid/Intune/Get-IntuneNonCompliantDevices.ps1)

### Monthly Tasks
- [Find inactive users](../02-Cloud-Hybrid/AzureAD/Get-InactiveUsers-SharePoint-Teams.ps1)
- [Review RBAC assignments](../03-Security-Compliance/RBAC/Get-RoleAssignments.ps1)
- [Audit file permissions](../01-Infrastructure/FileServers/Get-FilePermissions.ps1)
- [Generate GPO reports](../01-Infrastructure/GroupPolicy/Get-GPOReport.ps1)

### As-Needed
- [Bulk create users](../01-Infrastructure/ActiveDirectory/New-BulkADUsers.ps1)
- [Reset passwords](../07-Automation/Bulk-Operations/Reset-BulkPasswords.ps1)
- [Manage group memberships](../01-Infrastructure/ActiveDirectory/Set-ADGroupMembership.ps1)
- [Assign licenses](../07-Automation/License-Management/Set-M365Licenses.ps1)
- [User onboarding](../07-Automation/User-Provisioning/New-UserWorkflow.ps1)

---

## 📖 How to Use This Documentation

### For New Users
1. Start with [Getting Started](Getting-Started/GETTING-STARTED.md)
2. Review [Quick Reference](Getting-Started/QUICK-REFERENCE.md)
3. Explore scripts in [Script Index](Getting-Started/SCRIPT-INDEX.md)

### For Monitoring Setup
1. Follow [Grafana Installation](Grafana/01-Grafana-Installation.md)
2. Configure data sources:
   - [Azure Monitor](Grafana/02-Azure-Monitor-Setup.md)
   - [Prometheus](Grafana/03-Prometheus-WMI-Setup.md)
   - [Graph API](Grafana/04-Graph-API-Integration.md)
3. [Import Dashboards](Grafana/05-Dashboard-Import.md)

### For Developers
- Check [Scripts Created](Getting-Started/SCRIPTS-CREATED.md) for full inventory
- Review [Script Index](Getting-Started/SCRIPT-INDEX.md) for all available scripts

---

## 🆘 Getting Help

1. **Script-specific help:**
   ```powershell
   Get-Help ./script.ps1 -Full
   ```

2. **View parameters:**
   ```powershell
   Get-Help ./script.ps1 -Parameter *
   ```

3. **Check documentation:**
   - This INDEX for navigation
   - README for overview
   - Getting Started guides for quick reference

---

## 📊 Statistics

- **Total Scripts:** 29
- **Documentation Files:** 15+
- **Categories:** 8
- **Monitoring Solutions:** 4 (Grafana, Prometheus, Azure Monitor, Graph API)
- **Dashboard Templates:** Multiple

---

## 🔗 Quick Links

### Installation
- [Install PowerShell](Getting-Started/Setup-M365-MacOS.md#prerequisites)
- [Install Dependencies](../Install-M365Dependencies.ps1)
- [Install Grafana](Grafana/01-Grafana-Installation.md)

### Most Popular
- [Mailbox Forwarding](Getting-Started/SCRIPT-INDEX.md#exchange-online)
- [Server Health](Getting-Started/SCRIPT-INDEX.md#monitoring)
- [Inactive Users](Getting-Started/SCRIPT-INDEX.md#azure-ad--entra-id)
- [Security Events](Getting-Started/SCRIPT-INDEX.md#security--encryption)

### Monitoring
- [Grafana Setup](Grafana/01-Grafana-Installation.md)
- [Windows Servers Dashboard](../06-Monitoring/Azure-Monitor/grafana-dashboard-windows-servers.json)
- [Azure Monitor](Grafana/02-Azure-Monitor-Setup.md)

---

**Last Updated:** December 2025
**Version:** 1.0
