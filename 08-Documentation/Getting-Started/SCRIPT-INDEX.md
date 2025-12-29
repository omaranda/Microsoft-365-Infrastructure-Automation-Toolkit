# PowerShell Script Index

Quick reference guide for all available scripts organized by task category.

## 🔍 How to Use This Index

Each script listing includes:
- **Script Name** - The PowerShell file name
- **Purpose** - What the script does
- **Key Parameters** - Most important parameters
- **Example** - Quick usage example

---

## 01. Active Directory Management

### Get-ADUserReport.ps1
**Location:** `01-Infrastructure/ActiveDirectory/`
**Purpose:** Generate comprehensive AD user reports
**Key Parameters:**
- `-ExportPath` - CSV export location
- `-IncludeDisabled` - Include disabled accounts

**Example:**
```powershell
./01-Infrastructure/ActiveDirectory/Get-ADUserReport.ps1 -IncludeDisabled
```

### New-BulkADUsers.ps1
**Location:** `01-Infrastructure/ActiveDirectory/`
**Purpose:** Bulk create AD users from CSV
**Key Parameters:**
- `-CSVPath` - Input CSV file (required)
- `-DefaultPassword` - Default password for accounts

**Example:**
```powershell
./01-Infrastructure/ActiveDirectory/New-BulkADUsers.ps1 -CSVPath "users.csv" -DefaultPassword (ConvertTo-SecureString "Welcome123!" -AsPlainText -Force)
```

---

## 02. Group Policy

### Get-GPOReport.ps1
**Location:** `01-Infrastructure/GroupPolicy/`
**Purpose:** Generate comprehensive GPO reports
**Key Parameters:**
- `-ExportPath` - HTML report location

**Example:**
```powershell
./01-Infrastructure/GroupPolicy/Get-GPOReport.ps1
```

---

## 03. Exchange Online

### Get-MailboxForwardingRules.ps1
**Location:** `02-Cloud-Hybrid/Microsoft365/`
**Purpose:** List all mailboxes with forwarding rules
**Key Parameters:**
- `-ExportToCSV` - Export to CSV
- `-CSVPath` - CSV export location

**Example:**
```powershell
./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1 -ExportToCSV
```

### Remove-MailboxForwardingRules.ps1
**Location:** `02-Cloud-Hybrid/Microsoft365/`
**Purpose:** Remove specific forwarding rules by name
**Key Parameters:**
- `-RuleName` - Rule name (supports wildcards)
- `-Mailbox` - Specific mailbox
- `-RemoveSMTPForwarding` - Remove SMTP forwarding
- `-WhatIf` - Preview changes

**Example:**
```powershell
./02-Cloud-Hybrid/Microsoft365/Remove-MailboxForwardingRules.ps1 -RuleName "*gmail*" -WhatIf
```

---

## 04. Azure AD / Entra ID

### Get-InactiveUsers-SharePoint-Teams.ps1
**Location:** `02-Cloud-Hybrid/AzureAD/`
**Purpose:** Find inactive users, upload to SharePoint, send Teams message
**Key Parameters:**
- `-InactiveDays` - Days threshold (default: 90)
- `-TeamsRecipientEmail` - Email for Teams notification (required)
- `-SharePointSiteUrl` - SharePoint site URL

**Example:**
```powershell
./02-Cloud-Hybrid/AzureAD/Get-InactiveUsers-SharePoint-Teams.ps1 -TeamsRecipientEmail "admin@domain.com"
```

### Sync-ADConnect.ps1
**Location:** `02-Cloud-Hybrid/AzureAD/`
**Purpose:** Force Azure AD Connect synchronization
**Key Parameters:**
- `-SyncType` - Delta or Full (default: Delta)
- `-Wait` - Wait for sync completion

**Example:**
```powershell
./02-Cloud-Hybrid/AzureAD/Sync-ADConnect.ps1 -SyncType Delta -Wait
```

### Set-ConditionalAccessPolicy.ps1
**Location:** `02-Cloud-Hybrid/AzureAD/`
**Purpose:** Create/update Conditional Access policies
**Key Parameters:**
- `-PolicyName` - Policy name (required)
- `-RequireMFA` - Require MFA
- `-RequireCompliantDevice` - Require compliant device

**Example:**
```powershell
./02-Cloud-Hybrid/AzureAD/Set-ConditionalAccessPolicy.ps1 -PolicyName "Require MFA for Admins" -RequireMFA
```

---

## 05. Intune / Device Management

### Get-IntuneNonCompliantDevices.ps1
**Location:** `02-Cloud-Hybrid/Intune/`
**Purpose:** Report on non-compliant Intune devices
**Key Parameters:**
- `-EmailReport` - Send email report
- `-EmailTo` - Email recipients
- `-UseGraphEmail` - Use Graph API for email

**Example:**
```powershell
./02-Cloud-Hybrid/Intune/Get-IntuneNonCompliantDevices.ps1 -EmailReport -EmailTo "it@domain.com" -UseGraphEmail
```

---

## 06. Security & Encryption

### Enable-BitLocker.ps1
**Location:** `03-Security-Compliance/Encryption/`
**Purpose:** Enable BitLocker encryption with TPM
**Key Parameters:**
- `-DriveLetter` - Drive to encrypt (default: C:)
- `-BackupToAD` - Backup recovery key to AD
- `-SaveRecoveryKey` - Save recovery key to path

**Example:**
```powershell
./03-Security-Compliance/Encryption/Enable-BitLocker.ps1 -DriveLetter "C:" -BackupToAD
```

### Get-SecurityEventLog.ps1
**Location:** `03-Security-Compliance/Auditing/`
**Purpose:** Analyze security event logs
**Key Parameters:**
- `-Hours` - Hours to look back (default: 24)
- `-ExportPath` - CSV export location

**Example:**
```powershell
./03-Security-Compliance/Auditing/Get-SecurityEventLog.ps1 -Hours 48
```

---

## 07. Backup & Recovery

### Start-AzureVMBackup.ps1
**Location:** `04-Backup-DR/Azure-Backup/`
**Purpose:** Initiate on-demand Azure VM backup
**Key Parameters:**
- `-ResourceGroupName` - Resource group (required)
- `-VMName` - VM name or * for all (required)
- `-Wait` - Wait for completion

**Example:**
```powershell
./04-Backup-DR/Azure-Backup/Start-AzureVMBackup.ps1 -ResourceGroupName "RG-Prod" -VMName "VM-SQL01" -Wait
```

---

## 08. License Management

### Set-M365Licenses.ps1
**Location:** `07-Automation/License-Management/`
**Purpose:** Automate M365 license assignment
**Key Parameters:**
- `-CSVPath` - CSV with user/license mappings
- `-LicenseSKU` - License SKU to assign
- `-Department` - Assign to department

**Example:**
```powershell
./07-Automation/License-Management/Set-M365Licenses.ps1 -CSVPath "licenses.csv"
```

---

## 09. Setup & Utilities

### Install-M365Dependencies.ps1
**Location:** Root directory
**Purpose:** Install all required PowerShell modules
**Key Parameters:**
- `-UpdateExisting` - Update installed modules
- `-SkipPnP` - Skip PnP PowerShell installation

**Example:**
```powershell
./Install-M365Dependencies.ps1 -UpdateExisting
```

---

## 📋 Quick Command Reference

### Common Tasks

**Check mailbox forwarding across organization:**
```powershell
./02-Cloud-Hybrid/Microsoft365/Get-MailboxForwardingRules.ps1 -ExportToCSV
```

**Find and report inactive users:**
```powershell
./02-Cloud-Hybrid/AzureAD/Get-InactiveUsers-SharePoint-Teams.ps1 -InactiveDays 90 -TeamsRecipientEmail "admin@domain.com"
```

**Remove suspicious forwarding rules (preview first):**
```powershell
./02-Cloud-Hybrid/Microsoft365/Remove-MailboxForwardingRules.ps1 -RuleName "*external*" -WhatIf
# Then execute if looks good:
./02-Cloud-Hybrid/Microsoft365/Remove-MailboxForwardingRules.ps1 -RuleName "*external*"
```

**Check Intune compliance:**
```powershell
./02-Cloud-Hybrid/Intune/Get-IntuneNonCompliantDevices.ps1 -EmailReport -EmailTo "it@domain.com" -UseGraphEmail
```

**Sync Azure AD:**
```powershell
./02-Cloud-Hybrid/AzureAD/Sync-ADConnect.ps1 -SyncType Delta
```

**Assign licenses in bulk:**
```powershell
./07-Automation/License-Management/Set-M365Licenses.ps1 -LicenseSKU "SPE_E3" -Department "IT"
```

**Analyze security events:**
```powershell
./03-Security-Compliance/Auditing/Get-SecurityEventLog.ps1 -Hours 24
```

---

## 🎯 Scripts by Use Case

### User Onboarding
1. `New-BulkADUsers.ps1` - Create AD accounts
2. `Sync-ADConnect.ps1` - Sync to Azure AD
3. `Set-M365Licenses.ps1` - Assign licenses

### Security Audit
1. `Get-SecurityEventLog.ps1` - Check security events
2. `Get-MailboxForwardingRules.ps1` - Check mail forwarding
3. `Get-IntuneNonCompliantDevices.ps1` - Check device compliance

### Monthly Cleanup
1. `Get-InactiveUsers-SharePoint-Teams.ps1` - Find inactive users
2. `Get-ADUserReport.ps1` - Review all AD accounts
3. `Remove-MailboxForwardingRules.ps1` - Clean up old rules

### Disaster Recovery Test
1. `Start-AzureVMBackup.ps1` - Backup VMs
2. Test restore procedures
3. Document results

---

## 📖 Additional Resources

- **[README.md](README.md)** - Main documentation and setup guide
- **[Setup-M365-MacOS.md](Setup-M365-MacOS.md)** - macOS setup instructions
- **[GETTING-STARTED.md](GETTING-STARTED.md)** - Quick start guide
