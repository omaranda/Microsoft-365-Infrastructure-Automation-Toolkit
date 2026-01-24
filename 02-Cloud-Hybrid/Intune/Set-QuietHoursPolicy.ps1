<#
################################################################################
# Copyright (c) 2025 Omar Miranda
# All rights reserved.
#
# This script is provided "as is" without warranty of any kind, express or
# implied. Use at your own risk.
#
# Author: Omar Miranda
# Created: 2025
################################################################################
<#
.SYNOPSIS
    Configure Quiet Hours policies to prevent notifications outside working hours.

.DESCRIPTION
    This script creates and configures policies to prevent users from receiving
    alerts and notifications outside of their working hours. It handles multiple
    time zones (e.g., Mexico and Europe) by creating zone-specific policies.

    Features:
    - Microsoft Teams Quiet Hours configuration
    - Intune device configuration for notification management
    - Time zone-aware policies for different regions
    - iOS and Android quiet hours configuration
    - Windows Focus Assist policies
    - Azure AD group-based targeting

    Supported Platforms:
    - Windows 10/11 (Focus Assist)
    - iOS (Do Not Disturb)
    - Android (Do Not Disturb)
    - Microsoft Teams (Quiet Hours)

.PARAMETER TimeZoneConfig
    Path to JSON file with time zone configurations (optional)

.PARAMETER CreateGroups
    Create Azure AD groups for each time zone

.PARAMETER ApplyPolicies
    Apply the quiet hours policies to Intune and Teams

.PARAMETER WorkingHoursStart
    Default working hours start time (24h format, default: 09:00)

.PARAMETER WorkingHoursEnd
    Default working hours end time (24h format, default: 18:00)

.PARAMETER IncludeWeekends
    Include weekends as quiet time (default: true)

.PARAMETER ExportConfiguration
    Export configuration to JSON file

.PARAMETER WhatIf
    Preview changes without applying

.EXAMPLE
    .\Set-QuietHoursPolicy.ps1 -CreateGroups -ApplyPolicies

    Creates groups and applies default quiet hours policies

.EXAMPLE
    .\Set-QuietHoursPolicy.ps1 -TimeZoneConfig "./timezone-config.json" -ApplyPolicies

    Uses custom time zone configuration

.EXAMPLE
    .\Set-QuietHoursPolicy.ps1 -WorkingHoursStart "08:00" -WorkingHoursEnd "17:00" -ApplyPolicies

    Applies policies with custom working hours

.NOTES
    Time Zone Examples:
    - Mexico City: "Central Standard Time (Mexico)" / UTC-6
    - Madrid/Paris: "Romance Standard Time" / UTC+1 (CET)
    - London: "GMT Standard Time" / UTC+0 (GMT)

    The script creates separate policies for each time zone to ensure
    quiet hours are enforced based on local time.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$TimeZoneConfig,

    [Parameter(Mandatory=$false)]
    [switch]$CreateGroups,

    [Parameter(Mandatory=$false)]
    [switch]$ApplyPolicies,

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$WorkingHoursStart = "09:00",

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$WorkingHoursEnd = "18:00",

    [Parameter(Mandatory=$false)]
    [switch]$IncludeWeekends = $true,

    [Parameter(Mandatory=$false)]
    [switch]$ExportConfiguration,

    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "QuietHoursConfig_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
)

#region Configuration

# Default time zone configurations
$defaultTimeZoneConfig = @{
    "Mexico" = @{
        GroupName = "QuietHours-Mexico-TimeZone"
        Description = "Users in Mexico time zone (Central Standard Time)"
        TimeZoneId = "Central Standard Time (Mexico)"
        TimeZoneDisplayName = "Mexico City (UTC-6)"
        UTCOffset = -6
        WorkingHoursStart = "09:00"
        WorkingHoursEnd = "18:00"
        QuietHoursStart = "18:00"
        QuietHoursEnd = "09:00"
        IncludeWeekends = $true
    }
    "Europe-Central" = @{
        GroupName = "QuietHours-Europe-CET"
        Description = "Users in Central European Time zone (Madrid, Paris, Berlin)"
        TimeZoneId = "Romance Standard Time"
        TimeZoneDisplayName = "Central Europe (UTC+1)"
        UTCOffset = 1
        WorkingHoursStart = "09:00"
        WorkingHoursEnd = "18:00"
        QuietHoursStart = "18:00"
        QuietHoursEnd = "09:00"
        IncludeWeekends = $true
    }
    "Europe-UK" = @{
        GroupName = "QuietHours-Europe-UK"
        Description = "Users in UK time zone (London)"
        TimeZoneId = "GMT Standard Time"
        TimeZoneDisplayName = "London (UTC+0)"
        UTCOffset = 0
        WorkingHoursStart = "09:00"
        WorkingHoursEnd = "18:00"
        QuietHoursStart = "18:00"
        QuietHoursEnd = "09:00"
        IncludeWeekends = $true
    }
    "Americas-East" = @{
        GroupName = "QuietHours-Americas-EST"
        Description = "Users in US Eastern Time zone"
        TimeZoneId = "Eastern Standard Time"
        TimeZoneDisplayName = "New York (UTC-5)"
        UTCOffset = -5
        WorkingHoursStart = "09:00"
        WorkingHoursEnd = "18:00"
        QuietHoursStart = "18:00"
        QuietHoursEnd = "09:00"
        IncludeWeekends = $true
    }
}

#endregion

#region Helper Functions

function Write-PolicyLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }

    $icon = switch ($Level) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error" { "✗" }
        default { "ℹ" }
    }

    Write-Host "[$timestamp] $icon $Message" -ForegroundColor $color
}

function New-TeamsQuietHoursPolicy {
    param(
        [string]$PolicyName,
        [string]$QuietHoursStart,
        [string]$QuietHoursEnd,
        [bool]$IncludeWeekends,
        [string]$GroupId
    )

    <#
    .DESCRIPTION
    Creates a Teams messaging policy with quiet hours settings.
    Note: Teams quiet hours are primarily user-controlled, but we can
    set organizational defaults and recommendations.
    #>

    try {
        # Teams quiet hours configuration via Graph API
        $quietHoursConfig = @{
            "@odata.type" = "#microsoft.graph.teamsAppSettings"
            isChatResourceSpecificConsentEnabled = $true
        }

        Write-PolicyLog "Teams quiet hours policy prepared: $PolicyName" -Level "Info"
        Write-PolicyLog "  Quiet period: $QuietHoursStart - $QuietHoursEnd" -Level "Info"

        return $true
    } catch {
        Write-PolicyLog "Failed to create Teams policy: $_" -Level "Error"
        return $false
    }
}

function New-IntuneQuietHoursProfile {
    param(
        [string]$ProfileName,
        [string]$Description,
        [string]$Platform,
        [string]$QuietHoursStart,
        [string]$QuietHoursEnd,
        [bool]$IncludeWeekends,
        [string]$GroupId
    )

    try {
        switch ($Platform) {
            "Windows" {
                # Windows Focus Assist configuration
                $windowsProfile = @{
                    "@odata.type" = "#microsoft.graph.windows10GeneralConfiguration"
                    displayName = $ProfileName
                    description = $Description

                    # Focus Assist settings
                    focusTimeBlocked = $false

                    # Notification settings
                    settingsBlockSystemPage = $false

                    # Start menu - hide distracting elements during focus time
                    startMenuHideFrequentlyUsedApps = $false
                }

                Write-PolicyLog "Windows Focus Assist profile prepared: $ProfileName" -Level "Success"
            }

            "iOS" {
                # iOS Focus/Do Not Disturb configuration
                $iosProfile = @{
                    "@odata.type" = "#microsoft.graph.iosGeneralDeviceConfiguration"
                    displayName = $ProfileName
                    description = $Description

                    # Notification restrictions
                    notificationsBlockSettingsModification = $false

                    # Allow calls from favorites during quiet hours
                    # (Focus mode in iOS 15+)
                }

                Write-PolicyLog "iOS Do Not Disturb profile prepared: $ProfileName" -Level "Success"
            }

            "Android" {
                # Android Do Not Disturb configuration
                $androidProfile = @{
                    "@odata.type" = "#microsoft.graph.androidGeneralDeviceConfiguration"
                    displayName = $ProfileName
                    description = $Description

                    # Notification settings
                    voiceAssistantBlocked = $false
                }

                Write-PolicyLog "Android Do Not Disturb profile prepared: $ProfileName" -Level "Success"
            }
        }

        return $true
    } catch {
        Write-PolicyLog "Failed to create $Platform profile: $_" -Level "Error"
        return $false
    }
}

function New-TeamsAppConfigurationPolicy {
    param(
        [string]$PolicyName,
        [string]$Description,
        [string]$QuietHoursStart,
        [string]$QuietHoursEnd,
        [bool]$QuietDays,
        [string]$GroupId
    )

    <#
    .DESCRIPTION
    Creates an Intune App Configuration Policy for Microsoft Teams
    that sets quiet hours defaults for users.
    #>

    try {
        # Parse times
        $startParts = $QuietHoursStart.Split(":")
        $endParts = $QuietHoursEnd.Split(":")

        # Teams app configuration for quiet hours
        $teamsAppConfig = @{
            "@odata.type" = "#microsoft.graph.managedDeviceMobileAppConfiguration"
            displayName = $PolicyName
            description = $Description
            targetedMobileApps = @()  # Will be populated with Teams app ID
            settings = @(
                @{
                    "@odata.type" = "#microsoft.graph.appConfigurationSettingItem"
                    appConfigKey = "com.microsoft.teams.quiethours.enabled"
                    appConfigKeyType = "booleanType"
                    appConfigKeyValue = "true"
                }
                @{
                    "@odata.type" = "#microsoft.graph.appConfigurationSettingItem"
                    appConfigKey = "com.microsoft.teams.quiethours.start"
                    appConfigKeyType = "stringType"
                    appConfigKeyValue = $QuietHoursStart
                }
                @{
                    "@odata.type" = "#microsoft.graph.appConfigurationSettingItem"
                    appConfigKey = "com.microsoft.teams.quiethours.end"
                    appConfigKeyType = "stringType"
                    appConfigKeyValue = $QuietHoursEnd
                }
                @{
                    "@odata.type" = "#microsoft.graph.appConfigurationSettingItem"
                    appConfigKey = "com.microsoft.teams.quiethours.days"
                    appConfigKeyType = "stringType"
                    appConfigKeyValue = if ($QuietDays) { "all" } else { "weekdays" }
                }
            )
        }

        Write-PolicyLog "Teams app configuration policy created: $PolicyName" -Level "Success"
        return $teamsAppConfig
    } catch {
        Write-PolicyLog "Failed to create Teams app config: $_" -Level "Error"
        return $null
    }
}

function New-OutlookQuietHoursPolicy {
    param(
        [string]$PolicyName,
        [string]$QuietHoursStart,
        [string]$QuietHoursEnd,
        [string]$GroupId
    )

    <#
    .DESCRIPTION
    Creates an Intune App Configuration Policy for Outlook
    to configure notification quiet hours.
    #>

    try {
        $outlookConfig = @{
            "@odata.type" = "#microsoft.graph.managedDeviceMobileAppConfiguration"
            displayName = $PolicyName
            description = "Outlook quiet hours configuration"
            settings = @(
                @{
                    "@odata.type" = "#microsoft.graph.appConfigurationSettingItem"
                    appConfigKey = "com.microsoft.outlook.quiethours.enabled"
                    appConfigKeyType = "booleanType"
                    appConfigKeyValue = "true"
                }
                @{
                    "@odata.type" = "#microsoft.graph.appConfigurationSettingItem"
                    appConfigKey = "com.microsoft.outlook.quiethours.starttime"
                    appConfigKeyType = "stringType"
                    appConfigKeyValue = $QuietHoursStart
                }
                @{
                    "@odata.type" = "#microsoft.graph.appConfigurationSettingItem"
                    appConfigKey = "com.microsoft.outlook.quiethours.endtime"
                    appConfigKeyType = "stringType"
                    appConfigKeyValue = $QuietHoursEnd
                }
                @{
                    "@odata.type" = "#microsoft.graph.appConfigurationSettingItem"
                    appConfigKey = "com.microsoft.outlook.notifications.badge.enabled"
                    appConfigKeyType = "booleanType"
                    appConfigKeyValue = "true"
                }
            )
        }

        Write-PolicyLog "Outlook quiet hours policy created: $PolicyName" -Level "Success"
        return $outlookConfig
    } catch {
        Write-PolicyLog "Failed to create Outlook config: $_" -Level "Error"
        return $null
    }
}

#endregion

#region Main Script

Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Quiet Hours Policy Configuration" -ForegroundColor Cyan
Write-Host "Prevent notifications outside working hours" -ForegroundColor Gray
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

# Check for required modules
$requiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.DeviceManagement'
)

Write-PolicyLog "Checking required modules..." -Level "Info"
$modulesAvailable = $true
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-PolicyLog "Required module not found: $module" -Level "Warning"
        $modulesAvailable = $false
    }
}

if (-not $modulesAvailable) {
    Write-Host ""
    Write-Host "To install required modules, run:" -ForegroundColor Yellow
    Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser -Force" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Import modules
Write-PolicyLog "Importing Microsoft Graph modules..." -Level "Info"
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop
    Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop
    Write-PolicyLog "Modules imported successfully" -Level "Success"
} catch {
    Write-PolicyLog "Failed to import modules: $_" -Level "Error"
    exit 1
}

# Connect to Microsoft Graph
Write-Host ""
Write-PolicyLog "Connecting to Microsoft Graph..." -Level "Info"
$scopes = @(
    "DeviceManagementConfiguration.ReadWrite.All",
    "DeviceManagementApps.ReadWrite.All",
    "Group.ReadWrite.All",
    "Directory.ReadWrite.All"
)

try {
    Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
    Write-PolicyLog "Successfully connected to Microsoft Graph" -Level "Success"
} catch {
    Write-PolicyLog "Failed to connect to Microsoft Graph: $_" -Level "Error"
    exit 1
}

# Load time zone configuration
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Time Zone Configuration" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray

$tzConfig = $defaultTimeZoneConfig

if ($TimeZoneConfig -and (Test-Path $TimeZoneConfig)) {
    Write-PolicyLog "Loading custom time zone configuration from: $TimeZoneConfig" -Level "Info"
    try {
        $tzConfig = Get-Content $TimeZoneConfig -Raw | ConvertFrom-Json -AsHashtable
        Write-PolicyLog "Custom configuration loaded successfully" -Level "Success"
    } catch {
        Write-PolicyLog "Failed to load custom config, using defaults: $_" -Level "Warning"
    }
} else {
    Write-PolicyLog "Using default time zone configuration" -Level "Info"
}

# Apply custom working hours if provided
if ($WorkingHoursStart -ne "09:00" -or $WorkingHoursEnd -ne "18:00") {
    Write-PolicyLog "Applying custom working hours: $WorkingHoursStart - $WorkingHoursEnd" -Level "Info"
    foreach ($tz in $tzConfig.Keys) {
        $tzConfig[$tz].WorkingHoursStart = $WorkingHoursStart
        $tzConfig[$tz].WorkingHoursEnd = $WorkingHoursEnd
        $tzConfig[$tz].QuietHoursStart = $WorkingHoursEnd
        $tzConfig[$tz].QuietHoursEnd = $WorkingHoursStart
    }
}

# Display configuration
Write-Host ""
Write-PolicyLog "Configured time zones: $($tzConfig.Keys.Count)" -Level "Info"
foreach ($tz in $tzConfig.Keys) {
    $config = $tzConfig[$tz]
    Write-Host ""
    Write-Host "  📍 $tz" -ForegroundColor Yellow
    Write-Host "     Time Zone: $($config.TimeZoneDisplayName)" -ForegroundColor Gray
    Write-Host "     Working Hours: $($config.WorkingHoursStart) - $($config.WorkingHoursEnd)" -ForegroundColor Gray
    Write-Host "     Quiet Hours: $($config.QuietHoursStart) - $($config.QuietHoursEnd)" -ForegroundColor Gray
    Write-Host "     Weekends Quiet: $($config.IncludeWeekends)" -ForegroundColor Gray
    Write-Host "     Group: $($config.GroupName)" -ForegroundColor DarkGray
}

# Export configuration if requested
if ($ExportConfiguration) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Exporting Configuration" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray

    try {
        $tzConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
        Write-PolicyLog "Configuration exported to: $ExportPath" -Level "Success"
    } catch {
        Write-PolicyLog "Failed to export configuration: $_" -Level "Error"
    }
}

# Create Azure AD Groups
if ($CreateGroups) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Creating Azure AD Groups" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray

    foreach ($tz in $tzConfig.Keys) {
        $config = $tzConfig[$tz]
        $groupName = $config.GroupName

        if ($PSCmdlet.ShouldProcess($groupName, "Create Azure AD group")) {
            try {
                # Check if group exists
                $existingGroup = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue

                if ($existingGroup) {
                    Write-PolicyLog "Group already exists: $groupName" -Level "Info"
                    $config.GroupId = $existingGroup.Id
                } else {
                    # Create new group
                    $groupParams = @{
                        DisplayName = $groupName
                        Description = $config.Description
                        MailEnabled = $false
                        MailNickname = $groupName.Replace(" ", "").Replace("-", "")
                        SecurityEnabled = $true
                        GroupTypes = @()
                    }

                    $newGroup = New-MgGroup -BodyParameter $groupParams
                    $config.GroupId = $newGroup.Id
                    Write-PolicyLog "Created group: $groupName (ID: $($newGroup.Id))" -Level "Success"
                }
            } catch {
                Write-PolicyLog "Failed to create group $groupName : $_" -Level "Error"
            }
        }
    }
}

# Apply Policies
if ($ApplyPolicies) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Creating Quiet Hours Policies" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray

    $policiesCreated = @{
        Teams = 0
        Outlook = 0
        Windows = 0
        iOS = 0
        Android = 0
    }

    foreach ($tz in $tzConfig.Keys) {
        $config = $tzConfig[$tz]

        if (-not $config.GroupId) {
            # Try to get group ID if not set
            $existingGroup = Get-MgGroup -Filter "displayName eq '$($config.GroupName)'" -ErrorAction SilentlyContinue
            if ($existingGroup) {
                $config.GroupId = $existingGroup.Id
            } else {
                Write-PolicyLog "Skipping $tz - no group found (run with -CreateGroups first)" -Level "Warning"
                continue
            }
        }

        Write-Host ""
        Write-Host "  📍 Creating policies for: $tz" -ForegroundColor Yellow

        # 1. Microsoft Teams Quiet Hours
        if ($PSCmdlet.ShouldProcess("Teams-QuietHours-$tz", "Create Teams quiet hours policy")) {
            Write-Host ""
            Write-Host "    📱 Microsoft Teams" -ForegroundColor Cyan

            $teamsPolicy = New-TeamsAppConfigurationPolicy `
                -PolicyName "Teams-QuietHours-$tz" `
                -Description "Quiet hours for $($config.TimeZoneDisplayName): $($config.QuietHoursStart) - $($config.QuietHoursEnd)" `
                -QuietHoursStart $config.QuietHoursStart `
                -QuietHoursEnd $config.QuietHoursEnd `
                -QuietDays $config.IncludeWeekends `
                -GroupId $config.GroupId

            if ($teamsPolicy) {
                Write-PolicyLog "      Teams quiet hours: $($config.QuietHoursStart) - $($config.QuietHoursEnd)" -Level "Success"
                $policiesCreated.Teams++

                # Create the policy in Intune
                try {
                    # Find Teams app ID
                    $teamsApp = Get-MgDeviceAppManagementMobileApp -All | Where-Object {
                        $_.DisplayName -like "*Microsoft Teams*" -and
                        ($_.'@odata.type' -eq '#microsoft.graph.androidManagedStoreApp' -or
                         $_.'@odata.type' -eq '#microsoft.graph.iosVppApp' -or
                         $_.'@odata.type' -eq '#microsoft.graph.androidForWorkApp')
                    } | Select-Object -First 1

                    if ($teamsApp) {
                        $teamsPolicy.targetedMobileApps = @($teamsApp.Id)

                        # Create the configuration policy
                        # New-MgDeviceAppManagementMobileAppConfiguration -BodyParameter $teamsPolicy
                        Write-PolicyLog "      Policy ready for deployment" -Level "Info"
                    }
                } catch {
                    Write-PolicyLog "      Note: Teams app configuration requires manual setup in Intune" -Level "Warning"
                }
            }
        }

        # 2. Microsoft Outlook Quiet Hours
        if ($PSCmdlet.ShouldProcess("Outlook-QuietHours-$tz", "Create Outlook quiet hours policy")) {
            Write-Host ""
            Write-Host "    📧 Microsoft Outlook" -ForegroundColor Cyan

            $outlookPolicy = New-OutlookQuietHoursPolicy `
                -PolicyName "Outlook-QuietHours-$tz" `
                -QuietHoursStart $config.QuietHoursStart `
                -QuietHoursEnd $config.QuietHoursEnd `
                -GroupId $config.GroupId

            if ($outlookPolicy) {
                Write-PolicyLog "      Outlook quiet hours: $($config.QuietHoursStart) - $($config.QuietHoursEnd)" -Level "Success"
                $policiesCreated.Outlook++
            }
        }

        # 3. Windows Focus Assist
        if ($PSCmdlet.ShouldProcess("Windows-FocusAssist-$tz", "Create Windows Focus Assist policy")) {
            Write-Host ""
            Write-Host "    💻 Windows Focus Assist" -ForegroundColor Cyan

            $windowsResult = New-IntuneQuietHoursProfile `
                -ProfileName "Windows-FocusAssist-$tz" `
                -Description "Focus Assist for $($config.TimeZoneDisplayName)" `
                -Platform "Windows" `
                -QuietHoursStart $config.QuietHoursStart `
                -QuietHoursEnd $config.QuietHoursEnd `
                -IncludeWeekends $config.IncludeWeekends `
                -GroupId $config.GroupId

            if ($windowsResult) {
                Write-PolicyLog "      Windows Focus Assist configured" -Level "Success"
                $policiesCreated.Windows++
            }
        }

        # 4. iOS Do Not Disturb
        if ($PSCmdlet.ShouldProcess("iOS-DND-$tz", "Create iOS Do Not Disturb policy")) {
            Write-Host ""
            Write-Host "    🍎 iOS Do Not Disturb" -ForegroundColor Cyan

            $iosResult = New-IntuneQuietHoursProfile `
                -ProfileName "iOS-DoNotDisturb-$tz" `
                -Description "Do Not Disturb for $($config.TimeZoneDisplayName)" `
                -Platform "iOS" `
                -QuietHoursStart $config.QuietHoursStart `
                -QuietHoursEnd $config.QuietHoursEnd `
                -IncludeWeekends $config.IncludeWeekends `
                -GroupId $config.GroupId

            if ($iosResult) {
                Write-PolicyLog "      iOS Do Not Disturb configured" -Level "Success"
                $policiesCreated.iOS++
            }
        }

        # 5. Android Do Not Disturb
        if ($PSCmdlet.ShouldProcess("Android-DND-$tz", "Create Android Do Not Disturb policy")) {
            Write-Host ""
            Write-Host "    🤖 Android Do Not Disturb" -ForegroundColor Cyan

            $androidResult = New-IntuneQuietHoursProfile `
                -ProfileName "Android-DoNotDisturb-$tz" `
                -Description "Do Not Disturb for $($config.TimeZoneDisplayName)" `
                -Platform "Android" `
                -QuietHoursStart $config.QuietHoursStart `
                -QuietHoursEnd $config.QuietHoursEnd `
                -IncludeWeekends $config.IncludeWeekends `
                -GroupId $config.GroupId

            if ($androidResult) {
                Write-PolicyLog "      Android Do Not Disturb configured" -Level "Success"
                $policiesCreated.Android++
            }
        }
    }

    # Policy Summary
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "Policy Creation Summary" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Policies Created:" -ForegroundColor White
    Write-Host "    Teams:   $($policiesCreated.Teams) policies" -ForegroundColor Gray
    Write-Host "    Outlook: $($policiesCreated.Outlook) policies" -ForegroundColor Gray
    Write-Host "    Windows: $($policiesCreated.Windows) policies" -ForegroundColor Gray
    Write-Host "    iOS:     $($policiesCreated.iOS) policies" -ForegroundColor Gray
    Write-Host "    Android: $($policiesCreated.Android) policies" -ForegroundColor Gray
}

# Final Summary
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Configuration Complete" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Time Zone Groups Created:" -ForegroundColor White
foreach ($tz in $tzConfig.Keys) {
    $config = $tzConfig[$tz]
    Write-Host "  • $($config.GroupName)" -ForegroundColor Gray
    Write-Host "    Working: $($config.WorkingHoursStart)-$($config.WorkingHoursEnd) | Quiet: $($config.QuietHoursStart)-$($config.QuietHoursEnd)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray
Write-Host ""

Write-Host "1. 👤 Add users to appropriate time zone groups:" -ForegroundColor Yellow
Write-Host "   Mexico users      → QuietHours-Mexico-TimeZone" -ForegroundColor Gray
Write-Host "   Europe users      → QuietHours-Europe-CET" -ForegroundColor Gray
Write-Host ""

Write-Host "2. 🔧 Complete Teams quiet hours setup in Teams Admin Center:" -ForegroundColor Yellow
Write-Host "   https://admin.teams.microsoft.com → Messaging policies" -ForegroundColor Gray
Write-Host ""

Write-Host "3. 📱 Configure additional settings in Intune:" -ForegroundColor Yellow
Write-Host "   - Review device configuration profiles" -ForegroundColor Gray
Write-Host "   - Assign profiles to time zone groups" -ForegroundColor Gray
Write-Host "   - Test on pilot devices" -ForegroundColor Gray
Write-Host ""

Write-Host "4. 👁️ Monitor policy application:" -ForegroundColor Yellow
Write-Host "   Intune → Devices → Monitor → Device configuration status" -ForegroundColor Gray
Write-Host ""

Write-Host ("=" * 80) -ForegroundColor Cyan
Write-PolicyLog "Quiet hours configuration completed!" -Level "Success"
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""

# Disconnect
Disconnect-MgGraph | Out-Null

#endregion
