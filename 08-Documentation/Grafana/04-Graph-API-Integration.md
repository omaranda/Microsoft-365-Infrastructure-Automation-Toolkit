# Microsoft Graph API Integration with Grafana

Step-by-step guide to integrate Microsoft Graph API with Grafana for monitoring Microsoft 365 data.

## Overview

Microsoft Graph API allows you to query data from:
- User sign-in activity
- Microsoft 365 usage reports
- Azure AD audit logs
- Teams usage
- OneDrive/SharePoint activity
- License usage

## Prerequisites

- Grafana with JSON API plugin installed
- Azure AD App Registration with appropriate permissions
- Microsoft 365 tenant

## Step 1: Install JSON API Data Source Plugin

```bash
# Install the JSON API data source
grafana-cli plugins install marcusolsson-json-datasource

# Restart Grafana
brew services restart grafana
```

Verify in Grafana:
1. Go to **Configuration** → **Plugins**
2. Search for "JSON API"
3. Should be installed and enabled

## Step 2: Create Azure AD App Registration

### Using Azure Portal

1. **Go to Azure Portal** → **Azure Active Directory** → **App registrations**

2. **Create New Registration:**
   - Click **New registration**
   - Name: `Grafana-Graph-API`
   - Supported account types: **Accounts in this organizational directory only**
   - Redirect URI: Leave blank
   - Click **Register**

3. **Note Application Details:**
   - **Application (client) ID**: Copy this
   - **Directory (tenant) ID**: Copy this

4. **Create Client Secret:**
   - Go to **Certificates & secrets**
   - Click **New client secret**
   - Description: `Grafana Access`
   - Expires: 24 months (recommended)
   - Click **Add**
   - **Copy the secret value** immediately

5. **Configure API Permissions:**
   - Go to **API permissions**
   - Click **Add a permission**
   - Select **Microsoft Graph**
   - Select **Application permissions** (not Delegated)

   **Required Permissions:**
   - `Reports.Read.All` - Read all usage reports
   - `AuditLog.Read.All` - Read audit logs
   - `User.Read.All` - Read all users
   - `Directory.Read.All` - Read directory data

   - Click **Add permissions**
   - Click **Grant admin consent for [Your Organization]**
   - Click **Yes** to confirm

## Step 3: Create API Proxy Script

Since Graph API requires OAuth authentication, we need a simple proxy.

Create `/Users/omiranda/Documents/GitHub/ms-tools/06-Monitoring/Azure-Monitor/graph-api-proxy.js`:

```javascript
const express = require('express');
const axios = require('axios');
const app = express();

// Configuration
const config = {
    tenantId: 'YOUR_TENANT_ID',
    clientId: 'YOUR_CLIENT_ID',
    clientSecret: 'YOUR_CLIENT_SECRET'
};

let accessToken = null;
let tokenExpiry = null;

// Get access token
async function getAccessToken() {
    if (accessToken && tokenExpiry && Date.now() < tokenExpiry) {
        return accessToken;
    }

    try {
        const response = await axios.post(
            `https://login.microsoftonline.com/${config.tenantId}/oauth2/v2.0/token`,
            new URLSearchParams({
                client_id: config.clientId,
                client_secret: config.clientSecret,
                scope: 'https://graph.microsoft.com/.default',
                grant_type: 'client_credentials'
            })
        );

        accessToken = response.data.access_token;
        tokenExpiry = Date.now() + (response.data.expires_in * 1000);
        return accessToken;
    } catch (error) {
        console.error('Error getting access token:', error);
        throw error;
    }
}

// Proxy endpoint for Microsoft Graph
app.get('/api/graph/*', async (req, res) => {
    try {
        const token = await getAccessToken();
        const graphPath = req.path.replace('/api/graph/', '');
        const graphUrl = `https://graph.microsoft.com/v1.0/${graphPath}`;

        const response = await axios.get(graphUrl, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            params: req.query
        });

        res.json(response.data);
    } catch (error) {
        console.error('Graph API Error:', error.response?.data || error.message);
        res.status(error.response?.status || 500).json({
            error: error.response?.data || error.message
        });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

const PORT = 3001;
app.listen(PORT, () => {
    console.log(`Graph API Proxy running on http://localhost:${PORT}`);
});
```

**Install dependencies and run:**

```bash
# Install Node.js if not installed
brew install node

# Create project
cd /Users/omiranda/Documents/GitHub/ms-tools/06-Monitoring/Azure-Monitor
npm init -y
npm install express axios

# Update the config in graph-api-proxy.js with your values

# Run the proxy
node graph-api-proxy.js
```

**Run as service (optional):**

```bash
# Install PM2 for process management
npm install -g pm2

# Start proxy
pm2 start graph-api-proxy.js --name graph-api-proxy

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
```

## Step 4: Configure JSON API Data Source in Grafana

1. **Open Grafana** → **Configuration** → **Data sources**

2. **Add data source** → Select **JSON API**

3. **Configure:**
   - Name: `Microsoft Graph API`
   - URL: `http://localhost:3001/api/graph`
   - Access: `Server (default)`

4. **Save & Test**

## Step 5: Example Graph API Queries

### Active User Count

**Endpoint:** `/users/$count`
**Query Parameters:**
```
$filter=accountEnabled eq true
```

**JSONPath for value:** `$`

### Sign-in Activity (Last 30 Days)

**Endpoint:** `/reports/getOffice365ActiveUserCounts(period='D30')`

**JSONPath:** `$.value[*]`

### Microsoft Teams Usage

**Endpoint:** `/reports/getTeamsUserActivityCounts(period='D30')`

### OneDrive Usage

**Endpoint:** `/reports/getOneDriveUsageAccountCounts(period='D30')`

### License Assignments

**Endpoint:** `/subscribedSkus`

**JSONPath:** `$.value[*]`

## Step 6: Create Grafana Panels with Graph API Data

### Panel 1: Active Users Count

1. Create new dashboard
2. Add panel
3. Data source: `Microsoft Graph API`
4. Query URL: `users/$count?$filter=accountEnabled eq true`
5. Visualization: **Stat**
6. Transform: Use the count value

### Panel 2: Sign-in Activity Graph

1. Add panel
2. Query URL: `reports/getOffice365ActiveUserCounts(period='D30')`
3. Parse response to extract time series data
4. Visualization: **Time series**

### Panel 3: License Usage

```
Query: subscribedSkus
JSONPath: $.value[*]

Fields:
- skuPartNumber (License name)
- consumedUnits (Used licenses)
- prepaidUnits.enabled (Total licenses)
```

## Common Graph API Endpoints for Monitoring

### User Activity
```
# Active users
GET /reports/getOffice365ActiveUserDetail(period='D7')

# User sign-ins
GET /auditLogs/signIns?$top=100&$orderby=createdDateTime desc

# Failed sign-ins
GET /auditLogs/signIns?$filter=status/errorCode ne 0&$top=100
```

### Microsoft 365 Usage
```
# Microsoft 365 activations
GET /reports/getOffice365ActivationsUserDetail

# Email activity
GET /reports/getEmailActivityUserDetail(period='D7')

# Teams activity
GET /reports/getTeamsUserActivityUserDetail(period='D7')

# SharePoint activity
GET /reports/getSharePointActivityUserDetail(period='D7')
```

### Security & Compliance
```
# Risky users
GET /identityProtection/riskyUsers

# Conditional Access policies
GET /identity/conditionalAccess/policies

# MFA registrations
GET /reports/authenticationMethods/userRegistrationDetails
```

### License & Subscriptions
```
# Subscribed SKUs
GET /subscribedSkus

# Service plans
GET /servicePlans

# License details per user
GET /users/{user-id}/licenseDetails
```

## Advanced: Custom Graph API Queries

### PowerShell Script to Generate Graph Data

Create a script that queries Graph API and outputs JSON for Grafana:

```powershell
# get-graph-data.ps1
param(
    [string]$Metric = "activeusers"
)

$tenantId = "YOUR_TENANT_ID"
$clientId = "YOUR_CLIENT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"

# Get access token
$tokenBody = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $clientId
    Client_Secret = $clientSecret
}

$tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method POST -Body $tokenBody

$headers = @{
    "Authorization" = "Bearer $($tokenResponse.access_token)"
    "Content-Type"  = "application/json"
}

# Query based on metric
switch ($Metric) {
    "activeusers" {
        $uri = "https://graph.microsoft.com/v1.0/users/`$count?`$filter=accountEnabled eq true"
        $result = Invoke-RestMethod -Uri $uri -Headers $headers
        @{ value = $result } | ConvertTo-Json
    }
    "licenses" {
        $uri = "https://graph.microsoft.com/v1.0/subscribedSkus"
        $result = Invoke-RestMethod -Uri $uri -Headers $headers
        $result | ConvertTo-Json -Depth 10
    }
}
```

## Troubleshooting

### "Forbidden" or "Access Denied"

- Verify API permissions are granted
- Ensure admin consent was provided
- Check the token has correct scopes

### "Invalid Client Secret"

- Client secret may have expired
- Generate new secret in Azure Portal
- Update proxy configuration

### No Data Returned

```bash
# Test the proxy directly
curl http://localhost:3001/api/graph/users/\$count

# Check proxy logs
pm2 logs graph-api-proxy

# Test Graph API directly
# Use Graph Explorer: https://developer.microsoft.com/graph/graph-explorer
```

### Rate Limiting

Microsoft Graph has rate limits:
- Be mindful of query frequency
- Use `$top` and `$skip` for pagination
- Cache frequently accessed data in the proxy

## Security Best Practices

1. **Store credentials securely** - Use environment variables
2. **Limit API permissions** - Only request what you need
3. **Rotate secrets regularly** - Update client secrets every 6-12 months
4. **Monitor API usage** - Check Azure AD audit logs
5. **Use HTTPS** - Always use HTTPS for the proxy in production

## Next Steps

✅ Microsoft Graph API integrated
➡️ Import pre-built dashboards: [05-Dashboard-Import.md](05-Dashboard-Import.md)
