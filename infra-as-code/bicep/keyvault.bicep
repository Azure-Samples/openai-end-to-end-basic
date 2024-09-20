/*
  Deploy key vault with private endpoint and private DNS zone
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

param apiKey string
param logWorkspaceName string

//variables
var keyVaultName = 'kv-${baseName}'

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    networkAcls: {
      defaultAction: 'Allow'  // This sample uses identity as the perimeter. Production scenarios should layer in network perimeter control as well.
      bypass: 'AzureServices' // Required for AppGW communication if firewall is enabled in the future.
    }

    tenantId: subscription().tenantId

    enableRbacAuthorization: true       // Using RBAC
    enabledForDeployment: true          // VMs can retrieve certificates
    enabledForTemplateDeployment: true  // ARM can retrieve values

    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    createMode: 'default'               // Creating or updating the key vault (not recovering)
  }
}

//Key Vault diagnostic settings
resource keyVaultDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVault.name}-diagnosticSettings'
  scope: keyVault
  properties: {
    workspaceId: logWorkspace.id
    logs: [
        {
            categoryGroup: 'allLogs'
            enabled: true
            retentionPolicy: {
                enabled: false
                days: 0
            }
        }
    ]
    logAnalyticsDestinationType: null
  }
}

resource apiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'apiKey'
  properties: {
    value: apiKey
  }
}

@description('The name of the key vault.')
output keyVaultName string = keyVault.name
