targetScope = 'resourceGroup'

param privateEndpointSubnetResourceId string

/*** EXISTING RESOURCES ***/

resource aiSearchLinkedPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink.search.windows.net'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: 'log-workload'
}

/*** NEW RESOURCES ***/

resource azureAiSearchService 'Microsoft.Search/searchServices@2025-02-01-preview' = {
  name: 'aisAgent'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'standard'
  }
  properties: {
    disableLocalAuth: true
    authOptions: null
    hostingMode: 'default'
    partitionCount: 1
    replicaCount: 1
    semanticSearch: 'disabled'
    publicNetworkAccess: 'disabled'
    networkRuleSet: {
      bypass: 'None'
      ipRules: []
    }
  }
}

resource azureDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: azureAiSearchService
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'OperationLogs'
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

resource aiSearchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-aisearch'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'aisearch'
        properties: {
          privateLinkServiceId: azureAiSearchService.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }

  resource dnsGroup 'privateDnsZoneGroups' = {
    name: 'aisearch'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'aisearch'
          properties: {
            privateDnsZoneId: aiSearchLinkedPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

output aiSearchName string = azureAiSearchService.name
