# Setting Up Microsoft 365 PowerShell on macOS

## Prerequisites

### 1. Install PowerShell Core

PowerShell Core (PowerShell 7+) is required for running Microsoft 365 scripts on macOS.

**Option A: Using Homebrew (Recommended)**
```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install PowerShell
brew install --cask powershell
```

**Option B: Direct Download**
- Download from: https://github.com/PowerShell/PowerShell/releases
- Choose the `.pkg` file for macOS
- Install the package

**Verify Installation:**
```bash
pwsh --version
```

### 2. Launch PowerShell
```bash
pwsh
```

### 3. Install Exchange Online Management Module

Once in PowerShell, run:
```powershell
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
```

### 4. Install Other Microsoft 365 Modules (Optional)

**For Azure AD/Entra ID Management:**
```powershell
Install-Module -Name Microsoft.Graph -Scope CurrentUser
```

**For SharePoint Online:**
```powershell
Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
```

**For Teams:**
```powershell
Install-Module -Name MicrosoftTeams -Scope CurrentUser
```

**For Security & Compliance:**
```powershell
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
# (Same module as Exchange Online)
```

## Connecting to Microsoft 365 Services

### Exchange Online
```powershell
Connect-ExchangeOnline -UserPrincipalName admin@yourdomain.com
```

### Microsoft Graph (Azure AD/Entra ID)
```powershell
Connect-MgGraph -Scopes "User.Read.All", "Group.ReadWrite.All"
```

### SharePoint Online
```powershell
Connect-SPOService -Url https://yourdomain-admin.sharepoint.com
```

### Teams
```powershell
Connect-MicrosoftTeams
```

### Security & Compliance Center
```powershell
Connect-IPPSSession -UserPrincipalName admin@yourdomain.com
```

## Important Notes for macOS

1. **No "Run as Administrator"**: macOS doesn't have a direct equivalent to Windows "Run as Administrator". You may need to use `sudo` for some operations, but typically M365 modules don't require it.

2. **Execution Policy**: macOS PowerShell has less restrictive execution policies by default, but you can check with:
   ```powershell
   Get-ExecutionPolicy
   ```

   If needed, set it to RemoteSigned:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Authentication**: Modern authentication (MFA) is supported. A browser window will open for authentication.

4. **Permissions Required**: You need appropriate admin roles in Microsoft 365:
   - Global Administrator (full access)
   - Exchange Administrator (Exchange Online)
   - SharePoint Administrator (SharePoint Online)
   - Teams Administrator (Microsoft Teams)

## Quick Start Commands

```bash
# 1. Open Terminal
# 2. Launch PowerShell
pwsh

# 3. Connect to Exchange Online
Connect-ExchangeOnline

# 4. Run your script
./Get-MailboxForwardingRules.ps1

# 5. When done, disconnect
Disconnect-ExchangeOnline -Confirm:$false
```

## Troubleshooting

### Module Installation Issues
If you get permission errors:
```powershell
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
```

### TLS Issues
If you encounter TLS/SSL errors:
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### Clear Cached Credentials
```bash
# Remove stored credentials
rm -rf ~/.local/share/powershell/
```

## Additional Resources

- PowerShell Documentation: https://docs.microsoft.com/powershell/
- Exchange Online PowerShell: https://docs.microsoft.com/powershell/exchange/
- Microsoft Graph PowerShell: https://docs.microsoft.com/graph/powershell/
