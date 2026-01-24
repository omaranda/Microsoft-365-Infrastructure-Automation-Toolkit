# Quiet Hours Policy Configuration

Prevent users from receiving notifications outside their working hours with time zone-aware policies for Microsoft 365 and Intune.

## Overview

This solution addresses the challenge of managing notifications across multiple time zones. When you have users in Mexico and Europe, a message sent at 3 PM in Mexico arrives at 10 PM in Madrid - this script ensures European users won't be disturbed.

### What It Does

1. **Creates time zone groups** - Azure AD groups for each geographic region
2. **Configures quiet hours** - Policies for Teams, Outlook, Windows, iOS, and Android
3. **Respects local time** - 6 PM in Mexico ≠ 6 PM in Europe
4. **Silences notifications** - Messages still deliver, but no alerts during off-hours

### Key Benefits

- ✅ **Work-life balance** - No more evening/weekend interruptions
- ✅ **Messages preserved** - Nothing is blocked, just notification timing
- ✅ **Multi-platform** - Works on phones, tablets, and computers
- ✅ **Flexible hours** - Customize per region or department
- ✅ **Weekend support** - Full day quiet on Saturdays and Sundays

## Quick Start

### Prerequisites

1. **Microsoft 365 subscription** with Intune
2. **PowerShell 7+** with Microsoft Graph modules
3. **Permissions**: Global Admin or Intune Admin + Groups Admin

### Installation

```powershell
# Install required modules
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Basic Usage

```powershell
# Navigate to script directory
cd 02-Cloud-Hybrid/Intune

# Create groups and apply policies
./Set-QuietHoursPolicy.ps1 -CreateGroups -ApplyPolicies

# Preview changes without applying
./Set-QuietHoursPolicy.ps1 -CreateGroups -ApplyPolicies -WhatIf
```

## Time Zone Configuration

### Pre-Configured Regions

| Region | Group Name | Time Zone | Working Hours | Quiet Hours |
|--------|------------|-----------|---------------|-------------|
| **Mexico** | QuietHours-Mexico-TimeZone | UTC-6 (Mexico City) | 09:00-18:00 | 18:00-09:00 |
| **Europe Central** | QuietHours-Europe-CET | UTC+1 (Madrid, Paris, Berlin) | 09:00-18:00 | 18:00-09:00 |
| **Europe UK** | QuietHours-Europe-UK | UTC+0 (London) | 09:00-18:00 | 18:00-09:00 |
| **Americas East** | QuietHours-Americas-EST | UTC-5 (New York) | 09:00-18:00 | 18:00-09:00 |

### Custom Working Hours

```powershell
# Set custom working hours (8 AM to 5 PM)
./Set-QuietHoursPolicy.ps1 -WorkingHoursStart "08:00" -WorkingHoursEnd "17:00" -CreateGroups -ApplyPolicies

# Set extended hours (7 AM to 8 PM)
./Set-QuietHoursPolicy.ps1 -WorkingHoursStart "07:00" -WorkingHoursEnd "20:00" -CreateGroups -ApplyPolicies
```

### Custom Time Zone Configuration

1. Copy the template:
   ```bash
   cp timezone-config-template.json my-timezone-config.json
   ```

2. Edit `my-timezone-config.json`:
   ```json
   {
     "Mexico": {
       "GroupName": "QuietHours-Mexico-TimeZone",
       "Description": "Users in Mexico time zone",
       "TimeZoneId": "Central Standard Time (Mexico)",
       "TimeZoneDisplayName": "Mexico City (UTC-6)",
       "UTCOffset": -6,
       "WorkingHoursStart": "09:00",
       "WorkingHoursEnd": "18:00",
       "QuietHoursStart": "18:00",
       "QuietHoursEnd": "09:00",
       "IncludeWeekends": true
     },
     "Spain": {
       "GroupName": "QuietHours-Spain",
       "Description": "Users in Spain",
       "TimeZoneId": "Romance Standard Time",
       "TimeZoneDisplayName": "Madrid (UTC+1)",
       "UTCOffset": 1,
       "WorkingHoursStart": "09:00",
       "WorkingHoursEnd": "18:00",
       "QuietHoursStart": "18:00",
       "QuietHoursEnd": "09:00",
       "IncludeWeekends": true
     }
   }
   ```

3. Apply custom configuration:
   ```powershell
   ./Set-QuietHoursPolicy.ps1 -TimeZoneConfig "./my-timezone-config.json" -CreateGroups -ApplyPolicies
   ```

## Adding Users to Groups

### Method 1: PowerShell - Single User

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

# Get the group
$group = Get-MgGroup -Filter "displayName eq 'QuietHours-Mexico-TimeZone'"

# Get the user
$user = Get-MgUser -Filter "userPrincipalName eq 'juan.perez@contoso.com'"

# Add user to group
New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id

Write-Host "✓ Added $($user.DisplayName) to Mexico time zone group"
```

### Method 2: PowerShell - Multiple Users

```powershell
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

$group = Get-MgGroup -Filter "displayName eq 'QuietHours-Mexico-TimeZone'"

$usersToAdd = @(
    "juan.perez@contoso.com",
    "maria.garcia@contoso.com",
    "carlos.lopez@contoso.com"
)

foreach ($userEmail in $usersToAdd) {
    $user = Get-MgUser -Filter "userPrincipalName eq '$userEmail'"
    if ($user) {
        New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction SilentlyContinue
        Write-Host "✓ Added $($user.DisplayName)" -ForegroundColor Green
    }
}
```

### Method 3: Import from CSV

Create `mexico-users.csv`:
```csv
UserPrincipalName
juan.perez@contoso.com
maria.garcia@contoso.com
carlos.lopez@contoso.com
```

Run:
```powershell
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

$group = Get-MgGroup -Filter "displayName eq 'QuietHours-Mexico-TimeZone'"
$users = Import-Csv "mexico-users.csv"

foreach ($row in $users) {
    $user = Get-MgUser -Filter "userPrincipalName eq '$($row.UserPrincipalName)'"
    if ($user) {
        New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction SilentlyContinue
        Write-Host "✓ Added $($user.DisplayName)" -ForegroundColor Green
    }
}
```

### Method 4: Azure Portal (Manual)

1. Go to **[Azure Portal](https://portal.azure.com)** → **Azure Active Directory**
2. Click **Groups** → Search for **QuietHours-Mexico-TimeZone**
3. Click the group → **Members** → **Add members**
4. Search for users and click **Select**

### Method 5: Dynamic Group (Automatic)

Create a group that automatically includes users based on their attributes:

```powershell
Connect-MgGraph -Scopes "Group.ReadWrite.All"

$groupParams = @{
    DisplayName = "QuietHours-Mexico-Dynamic"
    Description = "Auto-populated: Users with location in Mexico"
    MailEnabled = $false
    MailNickname = "quiethours-mexico-dynamic"
    SecurityEnabled = $true
    GroupTypes = @("DynamicMembership")
    MembershipRule = '(user.country -eq "Mexico") or (user.officeLocation -contains "Mexico")'
    MembershipRuleProcessingState = "On"
}

New-MgGroup -BodyParameter $groupParams
Write-Host "✓ Dynamic group created - users will be added automatically"
```

**Dynamic Membership Rules Examples:**

| Scenario | Rule |
|----------|------|
| Country = Mexico | `(user.country -eq "Mexico")` |
| Office contains "Mexico" | `(user.officeLocation -contains "Mexico")` |
| Department = Sales in Mexico | `(user.department -eq "Sales") and (user.country -eq "Mexico")` |
| Time zone attribute | `(user.preferredLanguage -eq "es-MX")` |

## Policies Created

The script creates policies for each platform:

### Microsoft Teams

- **Policy Name**: `Teams-QuietHours-{Region}`
- **Effect**: Silences Teams notifications during quiet hours
- **Settings**:
  - Mutes chat notifications
  - Mutes channel notifications
  - Mutes call notifications
  - Badge counts still visible

### Microsoft Outlook

- **Policy Name**: `Outlook-QuietHours-{Region}`
- **Effect**: Silences email notifications during quiet hours
- **Settings**:
  - No new mail alerts
  - No sound notifications
  - Badge counts visible
  - Focused Inbox still sorts mail

### Windows (Focus Assist)

- **Policy Name**: `Windows-FocusAssist-{Region}`
- **Effect**: Enables Focus Assist during quiet hours
- **Settings**:
  - Priority only mode
  - Alarms allowed
  - Notifications queued for later

### iOS (Do Not Disturb)

- **Policy Name**: `iOS-DoNotDisturb-{Region}`
- **Effect**: Enables DND during quiet hours
- **Settings**:
  - Calls silenced
  - Notifications silenced
  - Lock screen hidden

### Android (Do Not Disturb)

- **Policy Name**: `Android-DoNotDisturb-{Region}`
- **Effect**: Enables DND during quiet hours
- **Settings**:
  - Calls silenced
  - Notifications silenced
  - Alarms allowed

## How Quiet Hours Work

### Message Flow

```
Sender (Mexico, 3:00 PM)
         ↓
    Sends message
         ↓
Receiver (Europe, 10:00 PM)
         ↓
    ┌─────────────────┐
    │ Quiet Hours ON  │
    │ (18:00-09:00)   │
    └────────┬────────┘
             ↓
    ┌─────────────────┐
    │ Message arrives │
    │ No notification │
    │ No sound        │
    │ No popup        │
    └────────┬────────┘
             ↓
    Next morning (09:00)
    User sees message
```

### What Happens During Quiet Hours

| Action | Result |
|--------|--------|
| Email arrives | ✅ Delivered, ❌ No notification |
| Teams message | ✅ Delivered, ❌ No notification |
| Teams call | ❌ Goes to voicemail |
| Calendar reminder | ❌ Silenced |
| Urgent message | Depends on settings (see below) |

### Exceptions (Optional)

Configure exceptions for urgent communications:

- **VIP contacts**: Managers, executives always ring through
- **Repeated calls**: If someone calls twice in 3 minutes, ring through
- **Priority messages**: Teams urgent messages can break through

## Parameters Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-TimeZoneConfig` | String | - | Path to custom JSON configuration |
| `-CreateGroups` | Switch | - | Create Azure AD groups for each time zone |
| `-ApplyPolicies` | Switch | - | Apply quiet hours policies to Intune |
| `-WorkingHoursStart` | String | "09:00" | Start of working hours (24h format) |
| `-WorkingHoursEnd` | String | "18:00" | End of working hours (24h format) |
| `-IncludeWeekends` | Switch | $true | Include weekends as quiet time |
| `-ExportConfiguration` | Switch | - | Export configuration to JSON file |
| `-ExportPath` | String | Auto-generated | Path for exported JSON |
| `-WhatIf` | Switch | - | Preview changes without applying |

## Examples

### Example 1: Basic Setup for Mexico and Europe

```powershell
./Set-QuietHoursPolicy.ps1 -CreateGroups -ApplyPolicies
```

### Example 2: Custom Hours (8 AM - 6 PM)

```powershell
./Set-QuietHoursPolicy.ps1 -WorkingHoursStart "08:00" -WorkingHoursEnd "18:00" -CreateGroups -ApplyPolicies
```

### Example 3: Extended Hours for Support Team

```powershell
# Create custom config for 24/7 support
# support-config.json with WorkingHoursStart: "00:00", WorkingHoursEnd: "23:59"
./Set-QuietHoursPolicy.ps1 -TimeZoneConfig "./support-config.json" -ApplyPolicies
```

### Example 4: Export Current Configuration

```powershell
./Set-QuietHoursPolicy.ps1 -ExportConfiguration -ExportPath "./current-config.json"
```

### Example 5: Preview Without Applying

```powershell
./Set-QuietHoursPolicy.ps1 -CreateGroups -ApplyPolicies -WhatIf
```

## Verification

### Check Group Membership

```powershell
$group = Get-MgGroup -Filter "displayName eq 'QuietHours-Mexico-TimeZone'"
Get-MgGroupMember -GroupId $group.Id | ForEach-Object {
    Get-MgUser -UserId $_.Id | Select-Object DisplayName, UserPrincipalName
}
```

### Check Policy Assignment

1. Go to **Microsoft Intune Admin Center**
2. Navigate to **Devices** → **Configuration profiles**
3. Find quiet hours profiles
4. Click **Assignments** to verify groups

### Test Quiet Hours

1. Add a test user to a time zone group
2. Wait for policy sync (up to 1 hour)
3. Send a message during quiet hours
4. Verify no notification received

## Troubleshooting

### Users Still Receiving Notifications

**Possible causes:**
1. User not in the correct group
2. Policy not synced to device
3. User override in app settings

**Solutions:**
```powershell
# Check group membership
$group = Get-MgGroup -Filter "displayName eq 'QuietHours-Mexico-TimeZone'"
$user = Get-MgUser -Filter "userPrincipalName eq 'user@contoso.com'"
Get-MgGroupMember -GroupId $group.Id | Where-Object { $_.Id -eq $user.Id }

# Force device sync (in Intune portal)
# Devices → Select device → Sync
```

### Policies Not Appearing in Intune

**Possible causes:**
1. Insufficient permissions
2. Script run with -WhatIf
3. API errors during creation

**Solutions:**
1. Run with Global Admin account
2. Check script output for errors
3. Re-run without -WhatIf flag

### Wrong Quiet Hours Times

**Possible causes:**
1. User in wrong time zone group
2. Custom config has incorrect values

**Solutions:**
1. Move user to correct group
2. Verify JSON configuration
3. Export and review current config

## Advanced Scenarios

### Different Hours by Department

```json
{
  "Sales-Mexico": {
    "GroupName": "QuietHours-Sales-Mexico",
    "WorkingHoursStart": "08:00",
    "WorkingHoursEnd": "20:00",
    "IncludeWeekends": false
  },
  "Support-Mexico": {
    "GroupName": "QuietHours-Support-Mexico",
    "WorkingHoursStart": "00:00",
    "WorkingHoursEnd": "23:59",
    "IncludeWeekends": false
  }
}
```

### VIP Bypass for Executives

In Teams Admin Center, create a messaging policy that allows:
- Urgent notifications always
- Calls from specific people

### Seasonal Adjustments (Daylight Saving)

Windows time zones handle DST automatically. The policies use:
- `Central Standard Time (Mexico)` - Adjusts for DST
- `Romance Standard Time` - Adjusts for CET/CEST

## Security Considerations

- **Group membership**: Audit regularly
- **Override permissions**: Limit who can change settings
- **Emergency contacts**: Configure bypass for critical communications
- **Compliance**: Document policies for HR and legal

## Files Reference

| File | Description |
|------|-------------|
| `Set-QuietHoursPolicy.ps1` | Main automation script |
| `timezone-config-template.json` | Customizable time zone definitions |
| `README-QuietHours.md` | This documentation |

## Related Scripts

- `New-AndroidEnrollmentConfiguration.ps1` - Android device enrollment
- `Get-IntuneDeviceInventory.ps1` - Device inventory report
- `New-UserOnboarding.ps1` - User provisioning workflow

## Support

For issues:
1. Check the troubleshooting section above
2. Review script output for errors
3. Verify prerequisites are met
4. Test with -WhatIf flag first

---

**Script Location:** `02-Cloud-Hybrid/Intune/Set-QuietHoursPolicy.ps1`
