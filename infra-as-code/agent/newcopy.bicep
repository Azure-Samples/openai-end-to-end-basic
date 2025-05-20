param userPrincipalId string

resource vnetAgents 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-agents4'
  location: 'eastus2'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/24'
      ]
    }
    subnets: [
      {
        name: 'agent'
        properties: {
          addressPrefix: '192.168.0.0/24'
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: true
        }
      }
    ]
  }

  resource agentSubnet 'subnets' existing = {
    name: 'agent'
  }
}

resource cosmosdb 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' = {
  name: 'cdb${name}'
  location: 'eastus2'
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'

    locations: [
      {
        locationName: 'eastus2'
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    enableFreeTier: false
    capacity: {
      totalThroughputLimit: 10
    }
    capacityMode: 'Serverless'
    publicNetworkAccess: 'Enabled'
  }
}


resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: 'ckchatm04'
  location: 'eastus2'
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: 'ckchatm04'  // UPDATE THIS TO BE A UNIQUE VALUE
    allowProjectManagement: true // Azure AI Foundry hub
    defaultProject: 'project-chat'
    networkAcls: {
      bypass: 'None'
      ipRules: []
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled'
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: vnetAgents::agentSubnet.id
      }
    ]
    disableLocalAuth: true
  }

  resource model 'deployments' = {
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: 3
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 3
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

  resource project 'projects' = {
    name: 'project-chat'
    location: 'eastus2'
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      description: 'Project description'
      displayName: 'ProjectDisplayName'
    }

    dependsOn: [
      model
    ]
  }
}

resource cognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry.id, 'CognitiveServicesUser', userPrincipalId)
  scope: aiFoundry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalId: userPrincipalId
    principalType: 'User'
  }
}

/*
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: 'ckchatm03'

  resource project 'projects' existing = {
    name: 'project-chat'

    resource projectAgentCapability 'capabilityHosts' = {
      name: 'ProjectAgents'
      properties: {
        capabilityHostKind: 'Agents'
        aiServicesConnections: null
        storageConnections: null
        threadStorageConnections: null
        vectorStoreConnections: null
      }
    }
  }
}
*/
