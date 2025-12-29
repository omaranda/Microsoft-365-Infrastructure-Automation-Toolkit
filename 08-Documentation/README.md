# Microsoft 365 & Infrastructure PowerShell Scripts

Comprehensive collection of PowerShell automation scripts for Microsoft infrastructure management, organized by functional area.

## 📁 Folder Structure

```
ms-tools/
├── 01-Infrastructure/           # Windows Server & Active Directory
│   ├── ActiveDirectory/        # AD user, group, and OU management
│   ├── DNS-DHCP/              # DNS and DHCP configuration
│   ├── FileServers/           # File server and permissions management
│   ├── GroupPolicy/           # GPO creation and reporting
│   └── PrintServices/         # Print server management
│
├── 02-Cloud-Hybrid/            # Microsoft 365 & Azure
│   ├── Microsoft365/          # Exchange, SharePoint, Teams
│   ├── AzureAD/              # Azure AD and hybrid identity
│   ├── Azure-Resources/       # Azure VMs, storage, networking
│   └── Intune/               # Device management and compliance
│
├── 03-Security-Compliance/     # Security & Compliance
│   ├── RBAC/                 # Role-based access control
│   ├── Encryption/           # BitLocker and data protection
│   ├── Endpoint-Security/    # Defender ATP and endpoint policies
│   └── Auditing/             # Security logs and compliance reporting
│
├── 04-Backup-DR/              # Backup & Disaster Recovery
│   ├── Windows-Backup/       # Windows Server Backup
│   ├── Azure-Backup/         # Azure Backup and Site Recovery
│   └── M365-Backup/          # Microsoft 365 backup solutions
│
├── 05-Networking/             # Networking & Connectivity
│   ├── Connectivity/         # DNS, TCP/IP troubleshooting
│   ├── VPN/                  # VPN configuration
│   └── Firewall/             # Firewall rules management
│
├── 06-Monitoring/             # Monitoring & Performance
│   ├── Health-Performance/   # Server health monitoring
│   ├── Azure-Monitor/        # Azure Monitor and alerts
│   └── Event-Logs/           # Event log analysis
│
├── 07-Automation/             # Automation Scripts
│   ├── User-Provisioning/    # Automated user creation
│   ├── License-Management/   # M365 license automation
│   ├── Bulk-Operations/      # Bulk password resets, moves
│   └── Maintenance/          # Scheduled maintenance tasks
│
└── 08-Documentation/          # Templates and documentation
    └── Templates/            # Script templates and examples
```

## 🚀 Quick Start

### Prerequisites
```bash
# Install PowerShell 7+ (macOS)
brew install --cask powershell

# Launch PowerShell
pwsh

# Install all dependencies
./Install-M365Dependencies.ps1
```

### Environment Setup
See [Setup-M365-MacOS.md](Setup-M365-MacOS.md) for detailed macOS setup instructions.

## 📋 Task Coverage Matrix

### ✅ Core Infrastructure Management

| Task | Script Location | Script Name |
|------|----------------|-------------|
| AD User Management | `01-Infrastructure/ActiveDirectory/` | `Get-ADUserReport.ps1`, `New-BulkADUsers.ps1` |
| Group Policy Management | `01-Infrastructure/GroupPolicy/` | `Get-GPOReport.ps1` |
| DNS/DHCP Administration | `01-Infrastructure/DNS-DHCP/` | *[Scripts to be added]* |
| File Server Permissions | `01-Infrastructure/FileServers/` | *[Scripts to be added]* |
| Print Server Management | `01-Infrastructure/PrintServices/` | *[Scripts to be added]* |

### ✅ Cloud & Hybrid Services

| Task | Script Location | Script Name |
|------|----------------|-------------|
| Exchange Online Forwarding | `02-Cloud-Hybrid/Microsoft365/` | `Get-MailboxForwardingRules.ps1`, `Remove-MailboxForwardingRules.ps1` |
| Inactive User Reports | `02-Cloud-Hybrid/AzureAD/` | `Get-InactiveUsers-SharePoint-Teams.ps1` |
| Azure AD Connect Sync | `02-Cloud-Hybrid/AzureAD/` | `Sync-ADConnect.ps1` |
| Conditional Access Policies | `02-Cloud-Hybrid/AzureAD/` | `Set-ConditionalAccessPolicy.ps1` |
| Intune Compliance | `02-Cloud-Hybrid/Intune/` | `Get-IntuneNonCompliantDevices.ps1` |

### ✅ Security & Compliance

| Task | Script Location | Script Name |
|------|----------------|-------------|
| BitLocker Encryption | `03-Security-Compliance/Encryption/` | `Enable-BitLocker.ps1` |
| Security Event Monitoring | `03-Security-Compliance/Auditing/` | `Get-SecurityEventLog.ps1` |
| RBAC Management | `03-Security-Compliance/RBAC/` | *[Scripts to be added]* |
| Endpoint Security | `03-Security-Compliance/Endpoint-Security/` | *[Scripts to be added]* |

### ✅ Backup & Disaster Recovery

| Task | Script Location | Script Name |
|------|----------------|-------------|
| Azure VM Backup | `04-Backup-DR/Azure-Backup/` | `Start-AzureVMBackup.ps1` |
| Windows Server Backup | `04-Backup-DR/Windows-Backup/` | *[Scripts to be added]* |
| M365 Backup | `04-Backup-DR/M365-Backup/` | *[Scripts to be added]* |

### ✅ Automation & Scripting

| Task | Script Location | Script Name |
|------|----------------|-------------|
| M365 License Management | `07-Automation/License-Management/` | `Set-M365Licenses.ps1` |
| Bulk User Operations | `07-Automation/Bulk-Operations/` | *[Scripts to be added]* |
| User Provisioning | `07-Automation/User-Provisioning/` | *[Scripts to be added]* |

## 🔧 Common Commands

### Active Directory
```powershell
# Generate AD user report
./01-Infrastructure/ActiveDirectory/Get-ADUserReport.ps1 -ExportPath "report.csv"

# Bulk create users from CSV
./01-Infrastructure/ActiveDirectory/New-BulkADUsers.ps1 -CSVPath "users.csv"

# Generate GPO report
./01-Infrastructure/GroupPolicy/Get-GPOReport.ps1
```

### Microsoft 365
```powershell
# Check mailbox forwarding rules
./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1 -ExportToCSV

# Remove suspicious forwarding rules
./02-Cloud-Hybrid/Microsoft365/Remove-MailboxForwardingRules.ps1 -RuleName "*external*" -WhatIf

# Get inactive users
./02-Cloud-Hybrid/AzureAD/Get-InactiveUsers-SharePoint-Teams.ps1 -TeamsRecipientEmail "admin@domain.com"

# Assign licenses in bulk
./07-Automation/License-Management/Set-M365Licenses.ps1 -CSVPath "licenses.csv"
```

### Intune
```powershell
# Get non-compliant devices
./02-Cloud-Hybrid/Intune/Get-IntuneNonCompliantDevices.ps1 -EmailReport -EmailTo "it@domain.com" -UseGraphEmail
```

### Security
```powershell
# Enable BitLocker on drive
./03-Security-Compliance/Encryption/Enable-BitLocker.ps1 -DriveLetter "C:" -BackupToAD

# Analyze security events
./03-Security-Compliance/Auditing/Get-SecurityEventLog.ps1 -Hours 48
```

### Azure
```powershell
# Backup Azure VM
./04-Backup-DR/Azure-Backup/Start-AzureVMBackup.ps1 -ResourceGroupName "RG-Prod" -VMName "VM-SQL01"

# Force AD Connect sync
./02-Cloud-Hybrid/AzureAD/Sync-ADConnect.ps1 -SyncType Delta
```

## 📚 Documentation

- **[Setup-M365-MacOS.md](Setup-M365-MacOS.md)** - macOS environment setup
- **[Install-M365Dependencies.ps1](Install-M365Dependencies.ps1)** - Automated dependency installation

## 🔐 Required Permissions

Different scripts require different permission levels:

### Active Directory Scripts
- Domain Admin or delegated permissions for user/group management
- Group Policy Admin for GPO operations

### Microsoft 365 Scripts
- Global Administrator or specific admin roles:
  - Exchange Administrator (mailbox scripts)
  - User Administrator (user management)
  - Intune Administrator (device management)
  - SharePoint Administrator (SharePoint operations)

### Azure Scripts
- Contributor or Owner role on subscriptions/resource groups
- Backup Operator for backup operations

## ⚠️ Important Notes

1. **Always test with `-WhatIf`** parameter when available before making changes
2. **Backup before bulk operations** - especially for AD and mailbox changes
3. **Monitor logs** after automation to ensure success
4. **Document customizations** made to scripts for your environment

## 🆘 Support

For issues or questions:
1. Check script help: `Get-Help ./script.ps1 -Full`
2. Check Microsoft documentation for specific cmdlets

## 📝 Contributing

When adding new scripts:
1. Follow existing naming conventions
2. Include comprehensive help documentation
3. Add error handling and progress indicators
4. Update this README with new script locations
5. Test on non-production environment first

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](../LICENSE) file for details.

Copyright 2025 Microsoft 365 & Infrastructure Management Tools
