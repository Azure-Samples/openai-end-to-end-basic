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
var aiStudioStorageAccountName = 'stml${baseName}'

// ---- Existing resources ----
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

// ---- Storage resources ----
resource aiStudioStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: aiStudioStorageAccountName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    allowedCopyScope: 'AAD'
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
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
    }
    supportsHttpsTrafficOnly: true
  }
  resource Blob 'blobServices' existing = {
    name: 'default'
  }
  resource File 'fileServices' existing = {
    name: 'default'
  }
}

@description('Azure AI Foundry\'s blob storage account diagnostic settings.')
resource aiStudioStorageAccountBlobDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: aiStudioStorageAccount::Blob
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
  scope: aiStudioStorageAccount::File
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

@description('The name of the ML storage account.')
output aiStudioStorageAccountName string = aiStudioStorageAccount.name
