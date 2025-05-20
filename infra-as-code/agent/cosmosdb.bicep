targetScope = 'resourceGroup'

param debugUserPrincipalId string
param privateEndpointSubnetResourceId string

/*** EXISTING RESOURCES ***/

resource cosmosDbLinkedPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink.documents.azure.com'
}

// Cosmos DB Account Reader Role
resource cosmosDbAccountReaderRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'fbdf93bf-df7d-467e-a4d2-9458aa1360c8'
  scope: subscription()
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: 'log-workload'
}

/*** NEW RESOURCES ***/

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' = {
  name: 'cdbagentthreadstorage'
  location: resourceGroup().location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    disableLocalAuth: true
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Disabled'
    enableFreeTier: false
    locations: [
      {
        locationName: resourceGroup().location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
  }

  resource writer 'sqlRoleDefinitions' existing = {
    name: '00000000-0000-0000-0000-000000000002'
  }

  resource userToCosmos 'sqlRoleAssignments' = {
    name: guid(debugUserPrincipalId, writer.id, cosmosDbAccount.id)
    properties: {
      roleDefinitionId: cosmosDbAccount::writer.id
      principalId: debugUserPrincipalId
      scope: cosmosDbAccount.id
    }
    dependsOn: [
      assignDebugUserToCosmosAccountReader
    ]
  }
}

resource azureDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: cosmosDbAccount
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'PartitionKeyRUConsumption'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'ControlPlaneRequests'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'DataPlaneRequests5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'DataPlaneRequests15M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Private endpoints

resource cosmosDbPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-cosmosdb'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'cosmosdb'
        properties: {
          privateLinkServiceId: cosmosDbAccount.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }

  resource dnsGroup 'privateDnsZoneGroups' = {
    name: 'cosmosdb'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'cosmosdb'
          properties: {
            privateDnsZoneId: cosmosDbLinkedPrivateDnsZone.id
          }
        }
      ]
    }
  }
}


// Role assignments

resource assignDebugUserToCosmosAccountReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(debugUserPrincipalId, cosmosDbAccountReaderRole.id, cosmosDbAccount.id)
  scope: cosmosDbAccount
  properties: {
    roleDefinitionId: cosmosDbAccountReaderRole.id
    principalId: debugUserPrincipalId
    principalType: 'User'
  }
}

/*** OUTPUTS ***/

output cosmosDbAccountName string = cosmosDbAccount.name
