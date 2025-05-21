targetScope = 'resourceGroup'

param uniqueSuffix string
param debugUserPrincipalId string
param privateEndpointSubnetResourceId string

/*** EXISTING RESOURCES ***/

resource storageBlobDataOwnerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  scope: subscription()
}

resource blobStorageLinkedPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink.blob.core.windows.net'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: 'log-workload'
}

/*** NEW RESOURCES ***/

resource agentStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: 'stg${uniqueSuffix}'
  location: resourceGroup().location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    allowSharedKeyAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
      resourceAccessRules: []
    }
  }

  resource blob 'blobServices' existing = {
    name: 'default'
  }
}

// Role assignments

resource debugUserBlobDataOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(debugUserPrincipalId, storageBlobDataOwnerRole.id, agentStorageAccount.id)
  scope: agentStorageAccount
  properties: {
    principalId: debugUserPrincipalId
    roleDefinitionId: storageBlobDataOwnerRole.id
    principalType: 'User'
  }
}


// Private endpoints

resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-aiagentstorage'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'storage'
        properties: {
          privateLinkServiceId: agentStorageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }

  resource dnsGroup 'privateDnsZoneGroups' = {
    name: 'storage'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'storage'
          properties: {
            privateDnsZoneId: blobStorageLinkedPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

// Azure diagnostics

resource azureDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: agentStorageAccount::blob
  properties: {
    workspaceId: logAnalyticsWorkspace.id
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
  }
}

/*** OUTPUTS ***/

output storageAccountName string = agentStorageAccount.name
