# New Scripts Reference Guide

This document covers the new automation scripts added to the toolkit for Microsoft 365, Intune, and Azure AD management.

---

## Table of Contents

1. [Intune Device Inventory](#1-intune-device-inventory)
2. [User Onboarding Automation](#2-user-onboarding-automation)
3. [Android Enrollment Configuration](#3-android-enrollment-configuration)
4. [Quiet Hours Policy](#4-quiet-hours-policy)
5. [Guest User Management](#5-guest-user-management)
6. [License Cleanup](#6-license-cleanup)
7. [Silent User Removal](#7-silent-user-removal)

---

## 1. Intune Device Inventory

**Script:** `02-Cloud-Hybrid/Intune/Get-IntuneDeviceInventory.ps1`

Retrieves a complete inventory of all Intune-managed devices including device name, serial number, notes, OS, and user information.

### Features
- Collects device name, serial number, notes field, OS version
- Shows user assignment and compliance state
- Filters by operating system (Windows, iOS, Android, macOS)
- Exports to CSV with timestamps
- Summary statistics by OS, manufacturer, compliance

### Usage

```powershell
# Basic inventory of all devices
./Get-IntuneDeviceInventory.ps1

# Filter by operating system
./Get-IntuneDeviceInventory.ps1 -FilterOS "Windows"
./Get-IntuneDeviceInventory.ps1 -FilterOS "macOS"

# Export with all properties
./Get-IntuneDeviceInventory.ps1 -IncludeAllProperties

# Custom export path
./Get-IntuneDeviceInventory.ps1 -ExportPath "C:\Reports\devices.csv"
```

### Output Fields

| Field | Description |
|-------|-------------|
| DeviceName | Device hostname |
| SerialNumber | Hardware serial number |
| Notes | Device notes field from Intune |
| OperatingSystem | OS type (Windows, iOS, etc.) |
| OSVersion | Full OS version |
| UserDisplayName | Assigned user's name |
| UserPrincipalName | Assigned user's email |
| LastSyncDateTime | Last Intune sync time |
| ComplianceState | Compliant/Non-compliant |

---

## 2. User Onboarding Automation

**Script:** `07-Automation/User-Provisioning/New-UserOnboarding.ps1`

Complete end-to-end user onboarding workflow with 9 automated steps.

### Features
- Creates Active Directory account
- Adds to department-based security groups
- Creates home folder with permissions
- Waits for Azure AD sync
- Assigns Microsoft 365 licenses
- Configures Teams access
- Sends welcome email (optional)
- Logs all activities to CSV
- Notifies manager and IT team (optional)

### Usage

```powershell
# Basic onboarding
./New-UserOnboarding.ps1 -FirstName "John" -LastName "Doe" -Department "IT" -LicenseSKU "SPE_E3"

# Full onboarding with all options
./New-UserOnboarding.ps1 `
    -FirstName "Jane" `
    -LastName "Smith" `
    -Department "Sales" `
    -Title "Sales Manager" `
    -Manager "jsmith" `
    -Office "New York" `
    -PhoneNumber "555-1234" `
    -LicenseSKU "SPE_E5" `
    -Groups "VPN-Users","Remote-Workers" `
    -SendWelcomeEmail `
    -NotifyManager `
    -NotifyIT

# Preview without making changes
./New-UserOnboarding.ps1 -FirstName "Bob" -LastName "Test" -Department "IT" -WhatIf

# Cloud-only (skip AD)
./New-UserOnboarding.ps1 -FirstName "Alice" -LastName "Cloud" -Department "IT" -SkipAD
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| FirstName | Yes | User's first name |
| LastName | Yes | User's last name |
| Department | Yes | IT, Sales, Marketing, Finance, HR, etc. |
| Username | No | Auto-generated if not provided |
| Email | No | Auto-generated if not provided |
| Title | No | Job title |
| Manager | No | Manager's username |
| LicenseSKU | No | SPE_E3, SPE_E5, O365_BUSINESS_PREMIUM |
| Groups | No | Additional security groups |
| SendWelcomeEmail | No | Send credentials to user |
| NotifyManager | No | Notify user's manager |
| SkipAD | No | Skip AD creation (cloud-only) |

### Department Default Groups

| Department | Default Groups |
|------------|----------------|
| IT | IT-Team, VPN-Users, Remote-Desktop-Users |
| Sales | Sales-Team, CRM-Users |
| Marketing | Marketing-Team, Design-Tools-Users |
| Finance | Finance-Team, Accounting-Software-Users |
| HR | HR-Team, HRIS-Users |
| Engineering | Engineering-Team, Dev-Tools-Users |

---

## 3. Android Enrollment Configuration

**Script:** `02-Cloud-Hybrid/Intune/New-AndroidEnrollmentConfiguration.ps1`

**Template:** `02-Cloud-Hybrid/Intune/android-roles-template.json`

**Documentation:** `02-Cloud-Hybrid/Intune/README-AndroidEnrollment.md`

Configure Android device enrollment with role-based app deployment. Assign different apps to different roles (e.g., WhatsApp only for executives, AudioMoth only for field team).

### Features
- Role-based app assignments
- Required apps (auto-install)
- Available apps (user choice)
- Blocked apps (prevent installation)
- Creates Azure AD groups for each role
- App configuration policies
- Customizable via JSON template

### Pre-Configured Roles

| Role | Required Apps | Blocked Apps |
|------|---------------|--------------|
| **Executive** | Teams, Outlook, WhatsApp Business, Power BI | - |
| **Field Team** | Teams, Outlook, AudioMoth, Field Service | WhatsApp, Facebook |
| **Sales** | Teams, Outlook, Dynamics 365, LinkedIn Sales | - |
| **IT** | Teams, Outlook, Remote Desktop, Authenticator | - |
| **General** | Teams, Outlook, Word, Excel, OneDrive | - |

### Usage

```powershell
# Create groups and assign apps
./New-AndroidEnrollmentConfiguration.ps1 -CreateGroups -AssignApps

# Use custom role definitions
./New-AndroidEnrollmentConfiguration.ps1 -RoleDefinitionFile "./my-roles.json" -CreateGroups -AssignApps

# Preview without applying
./New-AndroidEnrollmentConfiguration.ps1 -CreateGroups -AssignApps -WhatIf

# Export current configuration
./New-AndroidEnrollmentConfiguration.ps1 -ExportConfiguration
```

### Custom Role Configuration

Edit `android-roles-template.json`:

```json
{
  "CustomRole": {
    "GroupName": "Android-Custom-Team",
    "Description": "Custom team description",
    "RequiredApps": [
      {
        "Name": "Microsoft Teams",
        "PackageId": "com.microsoft.teams",
        "ConfigPolicy": true
      }
    ],
    "AvailableApps": [],
    "BlockedApps": [
      {
        "Name": "Facebook",
        "PackageId": "com.facebook.katana"
      }
    ]
  }
}
```

### Common App Package IDs

| App | Package ID |
|-----|------------|
| Microsoft Teams | com.microsoft.teams |
| Microsoft Outlook | com.microsoft.office.outlook |
| WhatsApp Business | com.whatsapp.w4b |
| WhatsApp | com.whatsapp |
| AudioMoth | org.openacousticdevices.audiomoth |
| LinkedIn | com.linkedin.android |
| Remote Desktop | com.microsoft.rdc.androidx |

---

## 4. Quiet Hours Policy

**Script:** `02-Cloud-Hybrid/Intune/Set-QuietHoursPolicy.ps1`

**Template:** `02-Cloud-Hybrid/Intune/timezone-config-template.json`

**Documentation:** `02-Cloud-Hybrid/Intune/README-QuietHours.md`

Prevent users from receiving notifications outside working hours with time zone-aware policies.

### Features
- Time zone-aware quiet hours
- Supports multiple regions (Mexico, Europe, etc.)
- Configures Teams, Outlook, Windows, iOS, Android
- Creates Azure AD groups per time zone
- Messages still delivered (just no notifications)
- Weekend quiet time support

### Pre-Configured Time Zones

| Region | Group Name | Quiet Hours |
|--------|------------|-------------|
| Mexico | QuietHours-Mexico-TimeZone | 18:00-09:00 (UTC-6) |
| Europe Central | QuietHours-Europe-CET | 18:00-09:00 (UTC+1) |
| Europe UK | QuietHours-Europe-UK | 18:00-09:00 (UTC+0) |
| Americas East | QuietHours-Americas-EST | 18:00-09:00 (UTC-5) |

### Usage

```powershell
# Create groups and apply policies
./Set-QuietHoursPolicy.ps1 -CreateGroups -ApplyPolicies

# Custom working hours
./Set-QuietHoursPolicy.ps1 -WorkingHoursStart "08:00" -WorkingHoursEnd "17:00" -CreateGroups -ApplyPolicies

# Use custom time zone config
./Set-QuietHoursPolicy.ps1 -TimeZoneConfig "./my-timezones.json" -CreateGroups -ApplyPolicies

# Preview without applying
./Set-QuietHoursPolicy.ps1 -CreateGroups -ApplyPolicies -WhatIf

# Export configuration
./Set-QuietHoursPolicy.ps1 -ExportConfiguration
```

### Adding Users to Time Zone Groups

```powershell
# Single user
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"
$group = Get-MgGroup -Filter "displayName eq 'QuietHours-Mexico-TimeZone'"
$user = Get-MgUser -Filter "userPrincipalName eq 'juan@contoso.com'"
New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id

# Multiple users
$usersToAdd = @("user1@contoso.com", "user2@contoso.com")
foreach ($email in $usersToAdd) {
    $user = Get-MgUser -Filter "userPrincipalName eq '$email'"
    New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id
}
```

---

## 5. Guest User Management

**Script:** `02-Cloud-Hybrid/AzureAD/Remove-GuestUsers.ps1`

List and remove guest users from Azure AD with filtering and interactive selection.

### Features
- List all guest users with details
- Interactive selection mode
- Filter by domain (gmail.com, etc.)
- Find stale guests (no sign-in for X days)
- Exclude partner domains from deletion
- Delete specific guests by email
- Delete from CSV file
- Export guest list to CSV
- WhatIf support for preview

### Usage

```powershell
# List all guests (no deletion)
./Remove-GuestUsers.ps1 -ListOnly

# Export to CSV for review
./Remove-GuestUsers.ps1 -ListOnly -ExportPath "guests.csv"

# Interactive selection mode
./Remove-GuestUsers.ps1 -Interactive

# Delete specific guests
./Remove-GuestUsers.ps1 -DeleteByEmail "guest1@gmail.com","guest2@outlook.com"

# Delete all Gmail guests
./Remove-GuestUsers.ps1 -FilterDomain "gmail.com" -DeleteAll

# Find stale guests (180+ days)
./Remove-GuestUsers.ps1 -StaleGuests -StaleDays 180 -Interactive

# Delete all except partners
./Remove-GuestUsers.ps1 -DeleteAll -ExcludeDomains "partner.com","vendor.com"

# Delete from CSV
./Remove-GuestUsers.ps1 -DeleteFromCSV "guests-to-remove.csv"

# Preview deletion
./Remove-GuestUsers.ps1 -DeleteAll -WhatIf
```

### Adding Guest Users Silently

```powershell
# Add guest without sending invitation email
Connect-MgGraph -Scopes "User.Invite.All"

New-MgInvitation `
    -InvitedUserEmailAddress "guest@external.com" `
    -InvitedUserDisplayName "Guest Name" `
    -InviteRedirectUrl "https://myapps.microsoft.com" `
    -SendInvitationMessage:$false
```

---

## 6. License Cleanup

**Script:** `07-Automation/License-Management/Remove-UnusedLicenses.ps1`

Identify and reclaim unused Microsoft 365 licenses from inactive or disabled accounts.

### Features
- License usage summary (assigned vs available)
- Find disabled accounts with licenses
- Find inactive users (no sign-in for X days)
- Interactive selection for removal
- Filter by specific SKU
- Export report to CSV
- Audit logging of all changes

### Usage

```powershell
# Show license usage summary
./Remove-UnusedLicenses.ps1 -ListOnly

# Show inactive users with licenses
./Remove-UnusedLicenses.ps1 -ShowInactiveUsers -InactiveDays 90

# Export report
./Remove-UnusedLicenses.ps1 -ListOnly -ExportPath "license-report.csv"

# Interactive mode
./Remove-UnusedLicenses.ps1 -Interactive

# Remove licenses from disabled accounts
./Remove-UnusedLicenses.ps1 -RemoveFromDisabled

# Remove licenses from inactive users
./Remove-UnusedLicenses.ps1 -RemoveFromInactive -InactiveDays 180

# Filter by specific license
./Remove-UnusedLicenses.ps1 -ShowInactiveUsers -SkuPartNumber "O365_BUSINESS_PREMIUM"

# Preview changes
./Remove-UnusedLicenses.ps1 -RemoveFromInactive -WhatIf
```

### License SKU Names

| SKU Part Number | Friendly Name |
|-----------------|---------------|
| O365_BUSINESS_PREMIUM | Microsoft 365 Business Premium |
| O365_BUSINESS_ESSENTIALS | Microsoft 365 Business Basic |
| SPE_E3 | Microsoft 365 E3 |
| SPE_E5 | Microsoft 365 E5 |
| ENTERPRISEPACK | Office 365 E3 |
| EXCHANGESTANDARD | Exchange Online Plan 1 |

---

## 7. Silent User Removal

**Script:** `07-Automation/User-Provisioning/Remove-UserSilent.ps1`

Remove users completely without sending any notifications - reclaims licenses, blocks access, and deletes account.

### Features
- Blocks sign-in immediately
- Revokes all active sessions/tokens
- Removes from all groups
- Reclaims all licenses
- Deletes user account
- **NO notifications sent**
- Backup user data to CSV
- Audit logging

### Usage

```powershell
# Delete user silently (reclaims license)
./Remove-UserSilent.ps1 -UserEmail "john.doe@contoso.com"

# Full cleanup with session revocation
./Remove-UserSilent.ps1 -UserEmail "john.doe@contoso.com" -RevokeTokens -RemoveFromGroups

# Block only (don't delete - for investigation)
./Remove-UserSilent.ps1 -UserEmail "john.doe@contoso.com" -BlockOnly

# Remove multiple users
./Remove-UserSilent.ps1 -UserEmails "user1@contoso.com","user2@contoso.com" -Force

# Remove from CSV with backup
./Remove-UserSilent.ps1 -FromCSV "users-to-remove.csv" -BackupToCSV

# Preview without deleting
./Remove-UserSilent.ps1 -UserEmail "john.doe@contoso.com" -WhatIf
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| -UserEmail | Single user to remove |
| -UserEmails | Multiple users to remove |
| -FromCSV | CSV file with users (Email column) |
| -BlockOnly | Block sign-in but don't delete |
| -RevokeTokens | Revoke all active sessions |
| -RemoveFromGroups | Remove from all groups first |
| -KeepLicense | Don't remove licenses (not recommended) |
| -BackupToCSV | Export user data before deletion |
| -Force | Skip confirmation prompts |
| -WhatIf | Preview without making changes |

### Actions Performed

1. ✓ Block sign-in immediately
2. ✓ Revoke all sessions (if -RevokeTokens)
3. ✓ Remove from all groups (if -RemoveFromGroups)
4. ✓ Remove all licenses (reclaim them)
5. ✓ Delete user account permanently
6. 🔇 **NO notifications sent to anyone**

---

## Quick Reference Card

### Prerequisites

```powershell
# Install Microsoft Graph modules
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Or use the dependency installer
./Install-M365Dependencies.ps1
```

### Common Operations

| Task | Command |
|------|---------|
| List Intune devices | `./Get-IntuneDeviceInventory.ps1` |
| Onboard new user | `./New-UserOnboarding.ps1 -FirstName "John" -LastName "Doe" -Department "IT"` |
| Setup Android enrollment | `./New-AndroidEnrollmentConfiguration.ps1 -CreateGroups -AssignApps` |
| Configure quiet hours | `./Set-QuietHoursPolicy.ps1 -CreateGroups -ApplyPolicies` |
| List guest users | `./Remove-GuestUsers.ps1 -ListOnly` |
| Check license usage | `./Remove-UnusedLicenses.ps1 -ListOnly` |
| Remove user silently | `./Remove-UserSilent.ps1 -UserEmail "user@contoso.com"` |

### Add Guest User Silently

```powershell
Connect-MgGraph -Scopes "User.Invite.All"
New-MgInvitation -InvitedUserEmailAddress "guest@external.com" -InvitedUserDisplayName "Guest Name" -InviteRedirectUrl "https://myapps.microsoft.com" -SendInvitationMessage:$false
```

### Add User to Group

```powershell
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"
$group = Get-MgGroup -Filter "displayName eq 'GroupName'"
$user = Get-MgUser -Filter "userPrincipalName eq 'user@contoso.com'"
New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id
```

---

## Script Locations

```
my-ms-tools/
├── 02-Cloud-Hybrid/
│   ├── AzureAD/
│   │   └── Remove-GuestUsers.ps1
│   └── Intune/
│       ├── Get-IntuneDeviceInventory.ps1
│       ├── New-AndroidEnrollmentConfiguration.ps1
│       ├── Set-QuietHoursPolicy.ps1
│       ├── android-roles-template.json
│       ├── timezone-config-template.json
│       ├── README-AndroidEnrollment.md
│       └── README-QuietHours.md
└── 07-Automation/
    ├── License-Management/
    │   └── Remove-UnusedLicenses.ps1
    └── User-Provisioning/
        ├── New-UserOnboarding.ps1
        └── Remove-UserSilent.ps1
```

---

## Support

For issues with these scripts:

1. Run with `-WhatIf` to preview changes
2. Check required permissions (Global Admin or specific admin roles)
3. Verify Microsoft Graph modules are installed
4. Review script help: `Get-Help ./script.ps1 -Full`
