/*
  Deploy storage account that will be connected to Azure AI Foundry. It is used by
  Azure AI Foundry to store Prompt flow files, traces, and other assets.
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

// variables
var aiFoundryStorageAccountName = 'stml${baseName}'

// ---- Existing resources ----
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

// ---- Storage resources ----
resource aiFoundryStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: aiFoundryStorageAccountName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    allowedCopyScope: 'AAD'
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    isSftpEnabled: false
    isHnsEnabled: false
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    isLocalUserEnabled: false
    routingPreference: {
      publishInternetEndpoints: true
      publishMicrosoftEndpoints: true
      routingChoice: 'MicrosoftRouting'
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Account'
        }
        table: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    supportsHttpsTrafficOnly: true
  }

  resource blob 'blobServices' = {
    name: 'default'
    properties: {
      cors: {
        corsRules: [
          {
            allowedOrigins: [
              'https://mlworkspace.azure.ai'
              'https://ml.azure.com'
              'https://*.ml.azure.com'
              'https://ai.azure.com'
              'https://*.ai.azure.com'
            ]
            allowedMethods: [
              'GET'
              'HEAD'
              'PUT'
              'DELETE'
              'OPTIONS'
              'POST'
              'PATCH'
            ]
            maxAgeInSeconds: 1800
            exposedHeaders: [
              '*'
            ]
            allowedHeaders: [
              '*'
            ]
          }
        ]
      }
      deleteRetentionPolicy: {
        allowPermanentDelete: false
        enabled: false
      }
    }
    
  }

  resource file 'fileServices' = {
    name: 'default'
    properties: {
      cors: {
        corsRules: [
          {
            allowedOrigins: [
              'https://mlworkspace.azure.ai'
              'https://ml.azure.com'
              'https://*.ml.azure.com'
              'https://ai.azure.com'
              'https://*.ai.azure.com'
            ]
            allowedMethods: [
              'GET'
              'HEAD'
              'PUT'
              'DELETE'
              'OPTIONS'
              'POST'
              'PATCH'
            ]
            maxAgeInSeconds: 1800
            exposedHeaders: [
              '*'
            ]
            allowedHeaders: [
              '*'
            ]
          }
        ]
      }
      shareDeleteRetentionPolicy: {
        days: 7
        enabled: true
      }
    }
  }
}

@description('Azure AI Foundry\'s blob storage account diagnostic settings.')
resource aiStudioStorageAccountBlobDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: aiFoundryStorageAccount::blob
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
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

@description('Azure AI Foundry\'s file storage account diagnostic settings.')
resource aiStudioStorageAccountFileDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: aiFoundryStorageAccount::file
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
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

@description('The name of the AI Foundry storage account.')
output aiFoundryStorageAccountName string = aiFoundryStorageAccount.name
