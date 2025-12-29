/*
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
*/

const express = require('express');
const axios = require('axios');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Microsoft Graph API configuration
const TENANT_ID = process.env.TENANT_ID;
const CLIENT_ID = process.env.CLIENT_ID;
const CLIENT_SECRET = process.env.CLIENT_SECRET;
const GRAPH_API_ENDPOINT = 'https://graph.microsoft.com/v1.0';
const TOKEN_ENDPOINT = `https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token`;

// Token cache
let accessToken = null;
let tokenExpiry = null;

// Middleware
app.use(cors());
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

/**
 * Get access token from Azure AD
 */
async function getAccessToken() {
  // Return cached token if still valid
  if (accessToken && tokenExpiry && Date.now() < tokenExpiry) {
    return accessToken;
  }

  try {
    const params = new URLSearchParams();
    params.append('client_id', CLIENT_ID);
    params.append('client_secret', CLIENT_SECRET);
    params.append('scope', 'https://graph.microsoft.com/.default');
    params.append('grant_type', 'client_credentials');

    const response = await axios.post(TOKEN_ENDPOINT, params, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    accessToken = response.data.access_token;
    // Set expiry to 5 minutes before actual expiry
    tokenExpiry = Date.now() + (response.data.expires_in - 300) * 1000;

    console.log('Access token obtained successfully');
    return accessToken;
  } catch (error) {
    console.error('Error getting access token:', error.response?.data || error.message);
    throw new Error('Failed to obtain access token');
  }
}

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

/**
 * Root endpoint - Grafana datasource test
 */
app.get('/', (req, res) => {
  res.json({ message: 'Microsoft Graph API Proxy is running' });
});

/**
 * Grafana JSON datasource - Search endpoint
 */
app.post('/search', (req, res) => {
  // Return available metrics
  const metrics = [
    'users.count',
    'users.active',
    'teams.count',
    'teams.activeUsers',
    'sharepoint.sites',
    'exchange.mailboxes',
    'onedrive.usage',
    'licenses.assigned',
    'licenses.available'
  ];
  res.json(metrics);
});

/**
 * Grafana JSON datasource - Query endpoint
 */
app.post('/query', async (req, res) => {
  try {
    const { targets, range } = req.body;
    const token = await getAccessToken();
    const results = [];

    for (const target of targets) {
      let data = [];

      switch (target.target) {
        case 'users.count':
          data = await getUserCount(token);
          break;
        case 'users.active':
          data = await getActiveUsers(token, range);
          break;
        case 'teams.count':
          data = await getTeamsCount(token);
          break;
        case 'teams.activeUsers':
          data = await getTeamsActiveUsers(token, range);
          break;
        case 'licenses.assigned':
          data = await getLicenses(token);
          break;
        default:
          data = [{ target: target.target, datapoints: [] }];
      }

      results.push(...data);
    }

    res.json(results);
  } catch (error) {
    console.error('Query error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Get total user count
 */
async function getUserCount(token) {
  try {
    const response = await axios.get(`${GRAPH_API_ENDPOINT}/users/$count`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'ConsistencyLevel': 'eventual'
      }
    });

    return [{
      target: 'users.count',
      datapoints: [[response.data, Date.now()]]
    }];
  } catch (error) {
    console.error('Error getting user count:', error.message);
    return [{ target: 'users.count', datapoints: [[0, Date.now()]] }];
  }
}

/**
 * Get active users (signed in within last 30 days)
 */
async function getActiveUsers(token, range) {
  try {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

    const response = await axios.get(`${GRAPH_API_ENDPOINT}/users`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'ConsistencyLevel': 'eventual'
      },
      params: {
        $filter: `signInActivity/lastSignInDateTime ge ${thirtyDaysAgo}`,
        $count: true,
        $top: 1
      }
    });

    const count = response.data['@odata.count'] || 0;

    return [{
      target: 'users.active',
      datapoints: [[count, Date.now()]]
    }];
  } catch (error) {
    console.error('Error getting active users:', error.message);
    return [{ target: 'users.active', datapoints: [[0, Date.now()]] }];
  }
}

/**
 * Get Teams count
 */
async function getTeamsCount(token) {
  try {
    const response = await axios.get(`${GRAPH_API_ENDPOINT}/groups/$count`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'ConsistencyLevel': 'eventual'
      },
      params: {
        $filter: "resourceProvisioningOptions/Any(x:x eq 'Team')"
      }
    });

    return [{
      target: 'teams.count',
      datapoints: [[response.data, Date.now()]]
    }];
  } catch (error) {
    console.error('Error getting Teams count:', error.message);
    return [{ target: 'teams.count', datapoints: [[0, Date.now()]] }];
  }
}

/**
 * Get Teams active users (from reports)
 */
async function getTeamsActiveUsers(token, range) {
  try {
    const response = await axios.get(
      `${GRAPH_API_ENDPOINT}/reports/getTeamsUserActivityUserDetail(period='D30')`,
      {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      }
    );

    // Parse CSV response
    const lines = response.data.split('\n');
    const activeUsers = lines.length - 2; // Subtract header and empty line

    return [{
      target: 'teams.activeUsers',
      datapoints: [[activeUsers, Date.now()]]
    }];
  } catch (error) {
    console.error('Error getting Teams active users:', error.message);
    return [{ target: 'teams.activeUsers', datapoints: [[0, Date.now()]] }];
  }
}

/**
 * Get license information
 */
async function getLicenses(token) {
  try {
    const response = await axios.get(`${GRAPH_API_ENDPOINT}/subscribedSkus`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    const totalAssigned = response.data.value.reduce((sum, sku) =>
      sum + sku.consumedUnits, 0
    );

    return [{
      target: 'licenses.assigned',
      datapoints: [[totalAssigned, Date.now()]]
    }];
  } catch (error) {
    console.error('Error getting licenses:', error.message);
    return [{ target: 'licenses.assigned', datapoints: [[0, Date.now()]] }];
  }
}

/**
 * Direct Graph API proxy endpoint
 */
app.get('/api/graph/*', async (req, res) => {
  try {
    const token = await getAccessToken();
    const graphPath = req.path.replace('/api/graph/', '');
    const graphUrl = `${GRAPH_API_ENDPOINT}/${graphPath}`;

    const response = await axios.get(graphUrl, {
      headers: {
        'Authorization': `Bearer ${token}`
      },
      params: req.query
    });

    res.json(response.data);
  } catch (error) {
    console.error('Graph API proxy error:', error.response?.data || error.message);
    res.status(error.response?.status || 500).json({
      error: error.response?.data || error.message
    });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Microsoft Graph API Proxy listening on port ${PORT}`);
  console.log(`Tenant ID: ${TENANT_ID ? 'Configured' : 'NOT CONFIGURED'}`);
  console.log(`Client ID: ${CLIENT_ID ? 'Configured' : 'NOT CONFIGURED'}`);
  console.log(`Client Secret: ${CLIENT_SECRET ? 'Configured' : 'NOT CONFIGURED'}`);
});
