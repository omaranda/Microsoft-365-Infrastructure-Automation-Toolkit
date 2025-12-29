# Azure Monitor Data Source Setup

Step-by-step guide to configure Azure Monitor as a Grafana data source.

## Prerequisites

- Grafana installed and running
- Azure subscription with appropriate permissions
- Azure CLI installed (optional but recommended)

## Step 1: Create Azure Service Principal

You need a Service Principal to authenticate Grafana with Azure Monitor.

### Option A: Using Azure Portal

1. **Register an Application:**
   - Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
   - Click **New registration**
   - Name: `Grafana-Monitor`
   - Click **Register**

2. **Create Client Secret:**
   - In your app registration, go to **Certificates & secrets**
   - Click **New client secret**
   - Description: `Grafana Access`
   - Expiry: Choose appropriate duration
   - Click **Add**
   - **IMPORTANT:** Copy the secret value immediately (you won't see it again)

3. **Note These Values:**
   - **Application (client) ID**: Found on Overview page
   - **Directory (tenant) ID**: Found on Overview page
   - **Client Secret**: The value you just created
   - **Subscription ID**: From your Azure subscription

4. **Assign Permissions:**
   - Go to **Subscriptions** → Select your subscription
   - Click **Access control (IAM)**
   - Click **Add role assignment**
   - Role: **Monitoring Reader**
   - Assign access to: **User, group, or service principal**
   - Select your `Grafana-Monitor` app
   - Click **Save**

### Option B: Using Azure CLI

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "Your-Subscription-Name"

# Create Service Principal
az ad sp create-for-rbac \
  --name "Grafana-Monitor" \
  --role "Monitoring Reader" \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# Output will show:
# {
#   "appId": "xxx",           # This is your Client ID
#   "displayName": "Grafana-Monitor",
#   "password": "xxx",         # This is your Client Secret
#   "tenant": "xxx"            # This is your Tenant ID
# }
```

## Step 2: Configure Azure Monitor in Grafana

1. **Open Grafana** → http://localhost:3000

2. **Go to Configuration:**
   - Click **⚙️ Configuration** (gear icon) → **Data sources**
   - Click **Add data source**

3. **Select Azure Monitor:**
   - Search for "Azure Monitor"
   - Click on **Azure Monitor**

4. **Configure Authentication:**

   **Authentication Method: App Registration**
   - Directory (tenant) ID: `your-tenant-id`
   - Application (client) ID: `your-client-id`
   - Client secret: `your-client-secret`

5. **Configure Subscriptions:**
   - Default Subscription: Select your subscription

6. **Test Connection:**
   - Click **Save & Test**
   - You should see: "Success - Azure Monitor successfully configured"

## Step 3: Verify Data Source

### Test Query

1. Go to **Explore** (compass icon)
2. Select **Azure Monitor** data source
3. Service: **Azure Monitor**
4. Try this test query:
   - Subscription: Your subscription
   - Resource Group: Any resource group
   - Resource: Any VM
   - Metric: `Percentage CPU`

## Azure Monitor Data Source Configuration Options

### Available Services in Azure Monitor

1. **Azure Monitor** - Metrics from Azure resources
2. **Azure Log Analytics** - Log queries
3. **Azure Resource Graph** - Resource inventory queries
4. **Application Insights** - Application telemetry

### Example Metric Queries

#### Virtual Machine CPU Usage
```
Service: Azure Monitor
Subscription: Production
Resource Group: RG-Servers
Resource: VM-WebServer-01
Namespace: Microsoft.Compute/virtualMachines
Metric: Percentage CPU
Aggregation: Average
```

#### Storage Account Availability
```
Service: Azure Monitor
Subscription: Production
Resource Group: RG-Storage
Resource: storageaccount01
Namespace: Microsoft.Storage/storageAccounts
Metric: Availability
Aggregation: Average
```

#### SQL Database DTU Usage
```
Service: Azure Monitor
Subscription: Production
Resource Group: RG-Database
Resource: sql-prod-db
Namespace: Microsoft.Sql/servers/databases
Metric: dtu_consumption_percent
Aggregation: Average
```

## Step 4: Configure Azure Log Analytics (Optional)

If you want to query logs from Log Analytics workspaces:

1. **In the same Azure Monitor data source:**
   - Scroll to **Azure Log Analytics**
   - Same client credentials work

2. **Default Workspace:**
   - Select your default Log Analytics workspace

3. **Test with KQL Query:**
```kusto
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor"
| summarize avg(CounterValue) by Computer
| order by avg_CounterValue desc
```

## Step 5: Multiple Azure Subscriptions

If you monitor multiple Azure subscriptions:

1. **Grant Service Principal Access to Each Subscription:**

```bash
# For each additional subscription
az role assignment create \
  --assignee YOUR_CLIENT_ID \
  --role "Monitoring Reader" \
  --scope /subscriptions/ANOTHER_SUBSCRIPTION_ID
```

2. **In Grafana Queries:**
   - You can select different subscriptions per panel
   - Or create separate data sources for each subscription

## Common Azure Metrics

### Virtual Machines
- `Percentage CPU` - CPU usage
- `Available Memory Bytes` - Available memory
- `Network In Total` - Network ingress
- `Network Out Total` - Network egress
- `Disk Read Bytes` - Disk read throughput
- `Disk Write Bytes` - Disk write throughput

### Storage Accounts
- `Availability` - Storage availability
- `Transactions` - Transaction count
- `Ingress` - Data ingress
- `Egress` - Data egress

### SQL Database
- `dtu_consumption_percent` - DTU usage
- `storage_percent` - Storage usage
- `connection_successful` - Successful connections
- `blocked_by_firewall` - Blocked connections

### App Service
- `Http5xx` - Server errors
- `ResponseTime` - Response time
- `Requests` - Request count
- `CpuPercentage` - CPU usage
- `MemoryPercentage` - Memory usage

## Troubleshooting

### "Unauthorized" Error

```bash
# Verify Service Principal has correct role
az role assignment list --assignee YOUR_CLIENT_ID --output table

# Re-assign role if needed
az role assignment create \
  --assignee YOUR_CLIENT_ID \
  --role "Monitoring Reader" \
  --scope /subscriptions/YOUR_SUBSCRIPTION_ID
```

### "Resource Not Found"

- Verify subscription ID is correct
- Check resource group and resource names
- Ensure Service Principal has access to that subscription

### No Metrics Showing

- Check time range in Grafana query
- Verify the metric namespace is correct
- Some metrics require specific resource SKUs/tiers

## Security Best Practices

1. **Use separate Service Principal** for Grafana (not personal account)
2. **Minimum permissions** - Only "Monitoring Reader" role
3. **Rotate client secrets** regularly
4. **Use Azure Key Vault** to store secrets in production
5. **Monitor Service Principal usage** in Azure AD logs

## Next Steps

✅ Azure Monitor configured
➡️ Setup Prometheus with WMI Exporter: [03-Prometheus-WMI-Setup.md](03-Prometheus-WMI-Setup.md)
