# Quick Reference Guide

One-page reference for the most commonly used scripts.

## 🔥 Most Used Scripts

| Task | Script | Command |
|------|--------|---------|
| **Check mail forwarding** | Get-MailboxForwardingRules | `./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1 -ExportToCSV` |
| **Server health check** | Get-ServerHealth | `./06-Monitoring/Health-Performance/Get-ServerHealth.ps1` |
| **Find inactive users** | Get-InactiveUsers | `./02-Cloud-Hybrid/AzureAD/Get-InactiveUsers-SharePoint-Teams.ps1 -TeamsRecipientEmail "admin@domain.com"` |
| **Security events** | Get-SecurityEventLog | `./03-Security-Compliance/Auditing/Get-SecurityEventLog.ps1 -Hours 24` |
| **AD user report** | Get-ADUserReport | `./01-Infrastructure/ActiveDirectory/Get-ADUserReport.ps1` |

## 📁 Script Locations by Task

### User Management
```
01-Infrastructure/ActiveDirectory/
  ├── Get-ADUserReport.ps1          # Generate user reports
  ├── New-BulkADUsers.ps1            # Bulk create users
  ├── Set-ADGroupMembership.ps1      # Manage groups
  └── Reset-ADPassword.ps1           # Reset passwords
```

### Microsoft 365
```
02-Cloud-Hybrid/Microsoft365/
  ├── Get-MailboxForwardingRules.ps1   # List forwarding
  ├── Remove-MailboxForwardingRules.ps1 # Remove forwarding
  └── Get-TeamsUsage.ps1               # Teams reports
```

### Security
```
03-Security-Compliance/
  ├── Auditing/Get-SecurityEventLog.ps1    # Security events
  ├── Encryption/Enable-BitLocker.ps1      # BitLocker
  ├── Endpoint-Security/Get-DefenderStatus.ps1  # Defender
  └── RBAC/Get-RoleAssignments.ps1         # RBAC audit
```

### Infrastructure
```
01-Infrastructure/
  ├── DNS-DHCP/Get-DNSRecords.ps1        # DNS audit
  ├── DNS-DHCP/Get-DHCPLeases.ps1        # DHCP status
  ├── FileServers/Get-FilePermissions.ps1 # Permission audit
  ├── FileServers/Get-FileServerSpace.ps1 # Disk space
  ├── GroupPolicy/Get-GPOReport.ps1       # GPO report
  └── PrintServices/Get-PrintQueue.ps1    # Print queues
```

## ⚡ Common Workflows

### Daily Security Check
```powershell
# Morning security audit
./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1 -ExportToCSV
./03-Security-Compliance/Auditing/Get-SecurityEventLog.ps1 -Hours 24
./03-Security-Compliance/Endpoint-Security/Get-DefenderStatus.ps1
```

### Weekly Infrastructure Review
```powershell
# Weekly health check
./06-Monitoring/Health-Performance/Get-ServerHealth.ps1
./01-Infrastructure/FileServers/Get-FileServerSpace.ps1 -Path "C:\Data"
./01-Infrastructure/DNS-DHCP/Get-DHCPLeases.ps1
```

### Monthly Cleanup
```powershell
# Find inactive users (90+ days)
./02-Cloud-Hybrid/AzureAD/Get-InactiveUsers-SharePoint-Teams.ps1 -InactiveDays 90 -TeamsRecipientEmail "admin@domain.com"

# Generate AD report
./01-Infrastructure/ActiveDirectory/Get-ADUserReport.ps1 -ExportPath "Monthly_ADUsers.csv"

# Check Intune compliance
./02-Cloud-Hybrid/Intune/Get-IntuneNonCompliantDevices.ps1
```

### User Onboarding
```powershell
# 1. Create user
./07-Automation/User-Provisioning/New-UserWorkflow.ps1 -FirstName "John" -LastName "Doe" -Username "jdoe" -Email "jdoe@domain.com" -Department "IT" -Groups "IT-Team" -LicenseSKU "SPE_E3"

# 2. Or bulk create from CSV
./01-Infrastructure/ActiveDirectory/New-BulkADUsers.ps1 -CSVPath "newusers.csv"

# 3. Assign licenses
./07-Automation/License-Management/Set-M365Licenses.ps1 -CSVPath "licenses.csv"
```

### Incident Response
```powershell
# Security incident investigation
./03-Security-Compliance/Auditing/Get-SecurityEventLog.ps1 -Hours 72
./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1 -ExportToCSV
./05-Networking/Connectivity/Test-NetworkConnectivity.ps1 -Target "suspicious-host.com"
```

## 🔧 Testing Scripts Safely

Always use `-WhatIf` when available:
```powershell
# Preview changes before applying
./Remove-MailboxForwardingRules.ps1 -RuleName "test" -WhatIf
./Reset-BulkPasswords.ps1 -CSVPath "users.csv" -WhatIf
```

## 📊 Parameters Quick Reference

### Common Parameters
- `-ExportPath "path.csv"` - Export location
- `-WhatIf` - Preview mode (no changes)
- `-Verbose` - Detailed output
- `-ComputerName "server"` - Target server
- `-Days 30` - Time period

### CSV Format Examples

**New-BulkADUsers.csv:**
```csv
FirstName,LastName,Username,Email,Department,OU
John,Doe,jdoe,jdoe@domain.com,IT,OU=Users,OU=IT,DC=domain,DC=com
```

**Set-ADGroupMembership.csv:**
```csv
Username,GroupName,Action
jdoe,IT-Team,Add
jsmith,Developers,Add
```

**Reset-BulkPasswords.csv:**
```csv
Username
jdoe
jsmith
```

## 🆘 Troubleshooting Quick Fixes

### Module not found
```powershell
./Install-M365Dependencies.ps1
```

### Permission denied
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Connection failed
```powershell
# Reconnect to services
Connect-MgGraph
Connect-ExchangeOnline
```

## 📚 Documentation

- **Full docs**: [README.md](README.md)
- **All scripts**: [SCRIPT-INDEX.md](SCRIPT-INDEX.md)
- **Getting started**: [GETTING-STARTED.md](GETTING-STARTED.md)
- **macOS setup**: [Setup-M365-MacOS.md](Setup-M365-MacOS.md)
