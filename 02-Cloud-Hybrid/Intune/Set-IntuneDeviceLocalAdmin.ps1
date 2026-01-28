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
.SYNOPSIS
    Grants local administrator rights to a user on a specific Intune-managed device.

.DESCRIPTION
    This script connects to Microsoft Graph and deploys a PowerShell script via
    Intune that adds a specified user to the local Administrators group on a
    target device identified by its serial number.

    The script will:
    1. Find the device in Intune by serial number
    2. Create a dynamic Azure AD group containing only that device
    3. Create a PowerShell script in Intune to add the user to local admins
    4. Assign the script to the device group

    The user will gain admin rights after the next Intune sync (or you can
    trigger a sync manually).

.PARAMETER SerialNumber
    The serial number of the target device (required)

.PARAMETER UserPrincipalName
    The UPN (email) of the user to grant admin rights (required)

.PARAMETER WhatIf
    Shows what would happen without making changes

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\Set-IntuneDeviceLocalAdmin.ps1 -SerialNumber "G2NCL24" -UserPrincipalName "ama.boakye@biometrio.earth"
    Grants local admin rights to the specified user on the device with serial G2NCL24

.EXAMPLE
    .\Set-IntuneDeviceLocalAdmin.ps1 -SerialNumber "G2NCL24" -UserPrincipalName "ama.boakye@biometrio.earth" -WhatIf
    Shows what would happen without making changes

.NOTES
    Required permissions:
    - DeviceManagementManagedDevices.Read.All
    - DeviceManagementConfiguration.ReadWrite.All
    - DeviceManagementScripts.ReadWrite.All
    - Group.ReadWrite.All
    - User.Read.All
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$SerialNumber,

    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Required modules
$requiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.DeviceManagement',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Users'
)

Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Intune Device Local Admin Assignment" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host ""
Write-Host "Target Device Serial: $SerialNumber" -ForegroundColor White
Write-Host "User to Grant Admin:  $UserPrincipalName" -ForegroundColor White
Write-Host ""

# Check and install required modules
Write-Host "Checking required modules..." -ForegroundColor Cyan
foreach ($module in $requiredModules) {
    Write-Host "  Checking $module..." -ForegroundColor Gray
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "  ⚠ Module not found. Please install Microsoft Graph modules first." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To install required modules, run:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser -Force" -ForegroundColor White
        Write-Host ""
        Write-Host "Or run the dependency installer:" -ForegroundColor Yellow
        Write-Host "  ./Install-M365Dependencies.ps1" -ForegroundColor White
        Write-Host ""
        exit 1
    }
    Write-Host "  ✓ $module found" -ForegroundColor Green
}

# Import modules
Write-Host "`nImporting Microsoft Graph modules..." -ForegroundColor Cyan
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Write-Host "✓ Modules imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import modules: $_" -ForegroundColor Red
    exit 1
}

# Connect to Microsoft Graph
Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan
$scopes = @(
    "DeviceManagementManagedDevices.Read.All",
    "DeviceManagementConfiguration.ReadWrite.All",
    "DeviceManagementScripts.ReadWrite.All",
    "Group.ReadWrite.All",
    "User.Read.All"
)

try {
    Connect-MgGraph -Scopes $scopes -NoWelcome
    Write-Host "✓ Successfully connected to Microsoft Graph" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to connect to Microsoft Graph: $_" -ForegroundColor Red
    exit 1
}

# Step 1: Find the device by serial number
Write-Host "`n" + ("-" * 80) -ForegroundColor Gray
Write-Host "Step 1: Finding device with serial number: $SerialNumber" -ForegroundColor Cyan
Write-Host ("-" * 80) -ForegroundColor Gray

try {
    # Use Graph API directly to get full device properties with filter
    $filterUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=serialNumber eq '$SerialNumber'"
    $response = Invoke-MgGraphRequest -Method GET -Uri $filterUri
    $devices = $response.value

    if ($devices.Count -eq 0) {
        Write-Host "✗ No device found with serial number: $SerialNumber" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please verify:" -ForegroundColor Yellow
        Write-Host "  - The serial number is correct" -ForegroundColor Gray
        Write-Host "  - The device is enrolled in Intune" -ForegroundColor Gray
        Write-Host ""
        Write-Host "You can list all devices with:" -ForegroundColor Yellow
        Write-Host "  .\Get-IntuneDeviceInventory.ps1" -ForegroundColor White
        Disconnect-MgGraph
        exit 1
    }

    if ($devices.Count -gt 1) {
        Write-Host "⚠ Multiple devices found with serial number: $SerialNumber" -ForegroundColor Yellow
        Write-Host "Using the first device found." -ForegroundColor Yellow
    }

    $device = $devices[0]
    Write-Host "✓ Device found:" -ForegroundColor Green
    Write-Host "  Device Name:    $($device.deviceName)" -ForegroundColor Gray
    Write-Host "  Serial Number:  $($device.serialNumber)" -ForegroundColor Gray
    Write-Host "  OS:             $($device.operatingSystem) $($device.osVersion)" -ForegroundColor Gray
    Write-Host "  Azure AD ID:    $($device.azureADDeviceId)" -ForegroundColor Gray
    Write-Host "  Intune ID:      $($device.id)" -ForegroundColor Gray

    # Verify it's a Windows device
    if ($device.operatingSystem -notlike "*Windows*") {
        Write-Host "✗ This script only supports Windows devices." -ForegroundColor Red
        Write-Host "  Device OS: $($device.operatingSystem)" -ForegroundColor Gray
        Disconnect-MgGraph
        exit 1
    }
} catch {
    Write-Host "✗ Failed to search for device: $_" -ForegroundColor Red
    Disconnect-MgGraph
    exit 1
}

# Step 2: Verify the user exists
Write-Host "`n" + ("-" * 80) -ForegroundColor Gray
Write-Host "Step 2: Verifying user: $UserPrincipalName" -ForegroundColor Cyan
Write-Host ("-" * 80) -ForegroundColor Gray

try {
    $user = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop
    Write-Host "✓ User found:" -ForegroundColor Green
    Write-Host "  Display Name: $($user.DisplayName)" -ForegroundColor Gray
    Write-Host "  UPN:          $($user.UserPrincipalName)" -ForegroundColor Gray
    Write-Host "  User ID:      $($user.Id)" -ForegroundColor Gray
} catch {
    Write-Host "✗ User not found: $UserPrincipalName" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Gray
    Disconnect-MgGraph
    exit 1
}

# Confirmation
if (-not $Force -and -not $WhatIfPreference) {
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Yellow
    Write-Host "CONFIRMATION REQUIRED" -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You are about to grant LOCAL ADMINISTRATOR rights to:" -ForegroundColor White
    Write-Host ""
    Write-Host "  User:   $($user.DisplayName) ($UserPrincipalName)" -ForegroundColor Cyan
    Write-Host "  Device: $($device.deviceName) (Serial: $SerialNumber)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This action will:" -ForegroundColor White
    Write-Host "  1. Create a dynamic device group for this device" -ForegroundColor Gray
    Write-Host "  2. Deploy a PowerShell script via Intune" -ForegroundColor Gray
    Write-Host "  3. Add the user to local Administrators on next sync" -ForegroundColor Gray
    Write-Host ""

    $confirmation = Read-Host "Do you want to proceed? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "`nOperation cancelled by user." -ForegroundColor Yellow
        Disconnect-MgGraph
        exit 0
    }
}

if ($WhatIfPreference) {
    Write-Host "`n⚠ WhatIf mode - No changes will be made" -ForegroundColor Yellow
}

# Step 3: Create or find a device group
Write-Host "`n" + ("-" * 80) -ForegroundColor Gray
Write-Host "Step 3: Setting up device group" -ForegroundColor Cyan
Write-Host ("-" * 80) -ForegroundColor Gray

$groupName = "Intune-LocalAdmin-$($device.deviceName)-$($device.serialNumber)"
$groupDescription = "Dynamic group for local admin assignment - Device: $($device.deviceName), Serial: $SerialNumber"

try {
    # Check if group already exists
    $existingGroup = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue

    if ($existingGroup) {
        Write-Host "✓ Device group already exists: $groupName" -ForegroundColor Green
        $deviceGroup = $existingGroup
    } else {
        if ($PSCmdlet.ShouldProcess($groupName, "Create Azure AD dynamic device group")) {
            Write-Host "Creating dynamic device group: $groupName" -ForegroundColor Cyan

            # Create dynamic membership rule based on device ID
            $membershipRule = "(device.deviceId -eq `"$($device.azureADDeviceId)`")"

            $groupParams = @{
                DisplayName = $groupName
                Description = $groupDescription
                MailEnabled = $false
                MailNickname = $groupName.Replace(" ", "")
                SecurityEnabled = $true
                GroupTypes = @("DynamicMembership")
                MembershipRule = $membershipRule
                MembershipRuleProcessingState = "On"
            }

            $deviceGroup = New-MgGroup -BodyParameter $groupParams
            Write-Host "✓ Device group created: $($deviceGroup.DisplayName)" -ForegroundColor Green
            Write-Host "  Group ID: $($deviceGroup.Id)" -ForegroundColor Gray

            # Wait for group to be processed
            Write-Host "  Waiting for dynamic membership to process..." -ForegroundColor Gray
            Start-Sleep -Seconds 10
        }
    }
} catch {
    Write-Host "✗ Failed to create/find device group: $_" -ForegroundColor Red
    Disconnect-MgGraph
    exit 1
}

# Step 4: Create the PowerShell script content
Write-Host "`n" + ("-" * 80) -ForegroundColor Gray
Write-Host "Step 4: Creating PowerShell script for Intune deployment" -ForegroundColor Cyan
Write-Host ("-" * 80) -ForegroundColor Gray

# PowerShell script that will run on the device
$localAdminScript = @"
<#
.SYNOPSIS
    Adds a user to the local Administrators group
.DESCRIPTION
    This script is deployed via Intune to add a specific user to the local
    Administrators group on Windows devices.
    Generated by Set-IntuneDeviceLocalAdmin.ps1
#>

`$UserPrincipalName = "$UserPrincipalName"
`$LogPath = "`$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\LocalAdminAssignment.log"

function Write-Log {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "`$timestamp - `$Message" | Out-File -FilePath `$LogPath -Append -Encoding UTF8
    Write-Output `$Message
}

try {
    Write-Log "Starting local admin assignment for: `$UserPrincipalName"

    # Get the local Administrators group (works for any language)
    `$adminGroup = Get-LocalGroup -SID "S-1-5-32-544"
    Write-Log "Found local Administrators group: `$(`$adminGroup.Name)"

    # Check if user is already a member
    `$members = Get-LocalGroupMember -Group `$adminGroup.Name -ErrorAction SilentlyContinue
    `$existingMember = `$members | Where-Object { `$_.Name -like "*\`$(`$UserPrincipalName.Split('@')[0])*" -or `$_.Name -like "*`$UserPrincipalName*" }

    if (`$existingMember) {
        Write-Log "User is already a member of local Administrators group"
        exit 0
    }

    # Add the Azure AD user to local Administrators
    # Format for Azure AD users: AzureAD\UserPrincipalName
    `$userFormats = @(
        "AzureAD\`$UserPrincipalName",
        "AzureAD\`$(`$UserPrincipalName.Split('@')[0])"
    )

    `$added = `$false
    foreach (`$userFormat in `$userFormats) {
        try {
            Write-Log "Attempting to add user as: `$userFormat"
            Add-LocalGroupMember -Group `$adminGroup.Name -Member `$userFormat -ErrorAction Stop
            Write-Log "Successfully added `$userFormat to local Administrators"
            `$added = `$true
            break
        } catch {
            Write-Log "Failed with format `$userFormat : `$(`$_.Exception.Message)"
        }
    }

    if (-not `$added) {
        Write-Log "ERROR: Failed to add user to local Administrators with any format"
        exit 1
    }

    Write-Log "Local admin assignment completed successfully"
    exit 0

} catch {
    Write-Log "ERROR: `$(`$_.Exception.Message)"
    exit 1
}
"@

Write-Host "✓ PowerShell script content prepared" -ForegroundColor Green
Write-Host "  Script will add user to local Administrators group" -ForegroundColor Gray

# Step 5: Deploy the script via Intune
Write-Host "`n" + ("-" * 80) -ForegroundColor Gray
Write-Host "Step 5: Deploying script to Intune" -ForegroundColor Cyan
Write-Host ("-" * 80) -ForegroundColor Gray

$scriptName = "LocalAdmin-$($device.serialNumber)-$($UserPrincipalName.Split('@')[0])"
$scriptDescription = "Adds $UserPrincipalName as local admin on device $($device.deviceName) (Serial: $SerialNumber)"

try {
    if ($PSCmdlet.ShouldProcess($scriptName, "Create and deploy Intune PowerShell script")) {
        # Convert script to base64
        $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes($localAdminScript)
        $scriptBase64 = [Convert]::ToBase64String($scriptBytes)

        # Create the device management script
        $scriptUri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts"

        $scriptBody = @{
            displayName = $scriptName
            description = $scriptDescription
            scriptContent = $scriptBase64
            runAsAccount = "system"
            enforceSignatureCheck = $false
            runAs32Bit = $false
            fileName = "Set-LocalAdmin.ps1"
        } | ConvertTo-Json

        Write-Host "Creating Intune script: $scriptName" -ForegroundColor Cyan
        $newScript = Invoke-MgGraphRequest -Method POST -Uri $scriptUri -Body $scriptBody -ContentType "application/json"
        Write-Host "✓ Intune script created" -ForegroundColor Green
        Write-Host "  Script ID: $($newScript.id)" -ForegroundColor Gray

        # Assign the script to the device group
        Write-Host "`nAssigning script to device group..." -ForegroundColor Cyan

        $assignmentUri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($newScript.id)/assign"

        $assignmentBody = @{
            deviceManagementScriptGroupAssignments = @(
                @{
                    "@odata.type" = "#microsoft.graph.deviceManagementScriptGroupAssignment"
                    targetGroupId = $deviceGroup.Id
                }
            )
        } | ConvertTo-Json -Depth 5

        Invoke-MgGraphRequest -Method POST -Uri $assignmentUri -Body $assignmentBody -ContentType "application/json"
        Write-Host "✓ Script assigned to device group" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Failed to deploy script: $_" -ForegroundColor Red
    Disconnect-MgGraph
    exit 1
}

# Summary
Write-Host "`n" + ("=" * 80) -ForegroundColor Green
Write-Host "✓ LOCAL ADMIN ASSIGNMENT COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host ("=" * 80) -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor White
Write-Host "  User:        $($user.DisplayName) ($UserPrincipalName)" -ForegroundColor Gray
Write-Host "  Device:      $($device.deviceName)" -ForegroundColor Gray
Write-Host "  Serial:      $SerialNumber" -ForegroundColor Gray
Write-Host "  Group:       $groupName" -ForegroundColor Gray
Write-Host "  Script:      $scriptName" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Wait for dynamic group membership to process (~5-10 minutes)" -ForegroundColor Gray
Write-Host "  2. Wait for next Intune sync on the device, OR" -ForegroundColor Gray
Write-Host "  3. Manually trigger sync from Company Portal or Settings > Accounts" -ForegroundColor Gray
Write-Host ""
Write-Host "To verify the script ran on the device, check:" -ForegroundColor Yellow
Write-Host "  %ProgramData%\Microsoft\IntuneManagementExtension\Logs\LocalAdminAssignment.log" -ForegroundColor Gray
Write-Host ""
Write-Host "To monitor assignment status in Intune:" -ForegroundColor Yellow
Write-Host "  Devices > Scripts > $scriptName > Device status" -ForegroundColor Gray
Write-Host ""

# Disconnect from Microsoft Graph
Write-Host "Disconnecting from Microsoft Graph..." -ForegroundColor Cyan
Disconnect-MgGraph

Write-Host "`n✓ Done!" -ForegroundColor Green
Write-Host ""
