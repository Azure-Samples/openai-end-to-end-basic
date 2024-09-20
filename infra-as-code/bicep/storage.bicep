/*
  Deploy storage account with private endpoint and private DNS zone
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params 
param logWorkspaceName string

// variables
var mlStorageName = 'stml${baseName}'


// ---- Existing resources ----
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

// ---- Storage resources ----
resource mlStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: mlStorageName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    allowCrossTenantReplication: false
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

// Enable Machine Learning Storage Account blob diagnostic settings
resource mlStorageBlobDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${mlStorage.name}-blobdiagnosticSettings'
  scope: mlStorage::Blob
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

// Enable Machine Learning Storage Account file diagnostic settings
resource mlStorageFileDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${mlStorage.name}-filediagnosticSettings'
  scope: mlStorage::File
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

@description('The name of the ML storage account.')
output mlDeployStorageName string = mlStorage.name
