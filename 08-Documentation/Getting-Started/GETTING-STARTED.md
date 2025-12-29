# Getting Started with ms-tools

Quick start guide to begin using the Microsoft 365 and Infrastructure PowerShell automation tools.

## ⚡ 5-Minute Quick Start

### 1. Install PowerShell (macOS)
```bash
brew install --cask powershell
pwsh --version  # Verify installation
```

### 2. Launch PowerShell and Install Dependencies
```bash
pwsh
```

Then inside PowerShell:
```powershell
cd /Users/omiranda/Documents/GitHub/ms-tools
./Install-M365Dependencies.ps1
```

### 3. Run Your First Script

**Check Exchange Online forwarding rules:**
```powershell
./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1
```

**Find inactive users:**
```powershell
./02-Cloud-Hybrid/AzureAD/Get-InactiveUsers-SharePoint-Teams.ps1 -TeamsRecipientEmail "your.email@domain.com"
```

## 📚 Documentation Overview

| Document | Purpose |
|----------|---------|
| **[README.md](README.md)** | Main documentation with full task coverage |
| **[SCRIPT-INDEX.md](SCRIPT-INDEX.md)** | Quick reference for all scripts |
| **[Setup-M365-MacOS.md](Setup-M365-MacOS.md)** | Detailed macOS setup instructions |
| **[08-Documentation/DIRECTORY-STRUCTURE.txt](08-Documentation/DIRECTORY-STRUCTURE.txt)** | Complete folder structure |

## 🎯 Common Use Cases

### Security Audit
```powershell
# 1. Check for unauthorized forwarding rules
./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1 -ExportToCSV

# 2. Review security events
./03-Security-Compliance/Auditing/Get-SecurityEventLog.ps1 -Hours 48

# 3. Check device compliance
./02-Cloud-Hybrid/Intune/Get-IntuneNonCompliantDevices.ps1
```

### Monthly Cleanup
```powershell
# 1. Find inactive users (90+ days)
./02-Cloud-Hybrid/AzureAD/Get-InactiveUsers-SharePoint-Teams.ps1 -TeamsRecipientEmail "admin@domain.com"

# 2. Generate AD user report
./01-Infrastructure/ActiveDirectory/Get-ADUserReport.ps1

# 3. Review and remove old forwarding rules
./02-Cloud-Hybrid/Microsoft365/Remove-MailboxForwardingRules.ps1 -RuleName "*old*" -WhatIf
```

### User Onboarding
```powershell
# 1. Create AD users from CSV
./01-Infrastructure/ActiveDirectory/New-BulkADUsers.ps1 -CSVPath "newusers.csv"

# 2. Sync to Azure AD
./02-Cloud-Hybrid/AzureAD/Sync-ADConnect.ps1

# 3. Assign Microsoft 365 licenses
./07-Automation/License-Management/Set-M365Licenses.ps1 -CSVPath "licenses.csv"
```

### Backup & DR
```powershell
# Backup Azure VMs
./04-Backup-DR/Azure-Backup/Start-AzureVMBackup.ps1 -ResourceGroupName "RG-Prod" -VMName "*"
```

## 🗂️ Repository Structure

```
ms-tools/
├── 01-Infrastructure/          # AD, DNS, File Servers, GPO
├── 02-Cloud-Hybrid/           # M365, Azure AD, Intune
├── 03-Security-Compliance/    # BitLocker, Auditing, RBAC
├── 04-Backup-DR/              # Backup and recovery
├── 05-Networking/             # VPN, Firewall, Connectivity
├── 06-Monitoring/             # Health, Performance, Alerts
├── 07-Automation/             # License mgmt, Provisioning
└── 08-Documentation/          # Templates and guides
```

## ✅ Current Scripts (13 Implemented)

### Active Directory (2)
- ✅ Get-ADUserReport.ps1
- ✅ New-BulkADUsers.ps1

### Group Policy (1)
- ✅ Get-GPOReport.ps1

### Microsoft 365 (2)
- ✅ Get-MailboxForwardingRules.ps1
- ✅ Remove-MailboxForwardingRules.ps1

### Azure AD (3)
- ✅ Get-InactiveUsers-SharePoint-Teams.ps1
- ✅ Sync-ADConnect.ps1
- ✅ Set-ConditionalAccessPolicy.ps1

### Intune (1)
- ✅ Get-IntuneNonCompliantDevices.ps1

### Security (2)
- ✅ Enable-BitLocker.ps1
- ✅ Get-SecurityEventLog.ps1

### Backup (1)
- ✅ Start-AzureVMBackup.ps1

### Automation (1)
- ✅ Set-M365Licenses.ps1

## 🔐 Required Permissions

Different scripts need different permissions:

### For Active Directory Scripts
- Domain Admin or delegated AD permissions

### For Microsoft 365 Scripts
- Global Administrator, OR
- Specific role admins (Exchange Admin, User Admin, etc.)

### For Azure Scripts
- Contributor or Owner on resource groups/subscriptions

## ⚠️ Best Practices

1. **Always test with `-WhatIf` first** (where available)
   ```powershell
   ./script.ps1 -WhatIf  # Preview changes
   ./script.ps1          # Execute
   ```

2. **Check help before running**
   ```powershell
   Get-Help ./script.ps1 -Full
   ```

3. **Export reports before making changes**
   ```powershell
   ./Get-Something.ps1 -ExportPath "backup_$(Get-Date -Format 'yyyyMMdd').csv"
   ```

4. **Monitor results**
   - Check CSV exports
   - Review console output
   - Verify changes in admin portals

## 🆘 Troubleshooting

### Module Installation Errors
```powershell
Install-Module -Name ModuleName -Scope CurrentUser -Force -AllowClobber
```

### Authentication Issues
- Ensure you have appropriate admin roles
- Try disconnecting and reconnecting:
```powershell
Disconnect-MgGraph
Connect-MgGraph
```

### Script Execution Policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Common Errors
For solutions check the script help and Microsoft documentation:
- Parameter not found errors
- Graph API 400 errors
- Module conflicts
- WhatIf parameter issues

## 🚀 Next Steps

1. ✅ Install PowerShell and dependencies
2. 📖 Read [README.md](README.md) for full documentation
3. 🔍 Browse [SCRIPT-INDEX.md](SCRIPT-INDEX.md) for specific scripts
4. ▶️ Run scripts for your use case
5. 📝 Customize scripts for your environment

## 📞 Getting Help

1. **Script-specific help:**
   ```powershell
   Get-Help ./script.ps1 -Examples
   ```

2. **View all parameters:**
   ```powershell
   Get-Help ./script.ps1 -Parameter *
   ```

3. **Check documentation:**
   - README.md for overview
   - SCRIPT-INDEX.md for quick reference
   - Setup-M365-MacOS.md for macOS setup

---

**Ready to automate? Pick a script from [SCRIPT-INDEX.md](SCRIPT-INDEX.md) and get started!**
