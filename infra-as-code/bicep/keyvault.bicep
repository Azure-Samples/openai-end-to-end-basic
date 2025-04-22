/*
  Deploy Key Vault. Key Vault is a required dependency for Azure AI Foundry hubs and projects. Both resources keep their
  API keys and connection secrets in here.
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

//variables
var keyVaultName = 'kv-${baseName}'

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    networkAcls: {
      defaultAction: 'Allow'            // Production readiness change: This sample uses identity as the perimeter. Production scenarios should layer in network perimeter control as well.
      bypass: 'AzureServices'           // Required for AppGW communication if firewall is enabled in the future.
      ipRules: []
      virtualNetworkRules: []
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
  name: 'default'
  scope: keyVault
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AzurePolicyEvaluationDetails'
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

@description('The name of the key vault.')
output keyVaultName string = keyVault.name
