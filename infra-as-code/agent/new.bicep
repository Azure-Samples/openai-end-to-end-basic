param name string = 'ckchatm01'
param userPrincipalId string

// Step 0: Create log sink for the workload
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'log-workload'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Step 1: Establish the private network for the workload
module deployVirtualNetwork 'network.bicep' = {
  name: 'deployVirtualNetwork'
  scope: resourceGroup()
  params: {}
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: deployVirtualNetwork.outputs.virtualNetworkName

  resource agentSubnet 'subnets' existing = {
    name: 'agent'
  }

    resource privateEndpointSubnet 'subnets' existing = {
    name: 'private-endpoints'
  }
}

// Step 2a: Deploy storage account for the Azure AI Agent Service (dependency)
module deployAgentStorageAccount 'storage.bicep' = {
  name: 'deployAgentStorageAccount'
  scope: resourceGroup()
  params: {
    uniqueSuffix: name
    privateEndpointSubnetResourceId: virtualNetwork::privateEndpointSubnet.id
  }
}

// Step 2b: Deploy CosmosDB Account for the Azure AI Agent Service (dependency)
module deployCosmosDbAccount 'cosmosdb.bicep' = {
  name: 'deployCosmosDbAccount'
  scope: resourceGroup()
  params: {
    debugUserPrincipalId: userPrincipalId
    privateEndpointSubnetResourceId: virtualNetwork::privateEndpointSubnet.id
  }
}

// Step 2c: Deploy Azure AI Search Service for the Azure AI Agent Service (dependency)
module deployAzureAiSearchService 'aisearch.bicep' = {
  name: 'deployAzureAiSearchService'
  scope: resourceGroup()
  params: {
    privateEndpointSubnetResourceId: virtualNetwork::privateEndpointSubnet.id
  }
}

// Step 3: Deploy Azure AI Foundry (without any projects)
module deployAzureAIFoundry 'aiFoundry.bicep' = {
  params: {
    agentSubnetResourceId: virtualNetwork::agentSubnet.id
    aiFoundryPortalUserPrincipalId: userPrincipalId
    privateEndpointSubnetResourceId: virtualNetwork::privateEndpointSubnet.id
    uniqueSuffix: name
  }
}

// Step 4: Deploy Azure AI Foundry Project (with CosmosDB, Storage Account, and AI Search connections)
module deployAzureAIFoundryProject 'ai-foundry-project.bicep' = {
  name: 'deployAzureAIFoundryProject'
  scope: resourceGroup()
  params: {
    existingAiFoundryName: deployAzureAIFoundry.outputs.aiFoundryName
    existingCosmosDbAccountName: deployCosmosDbAccount.outputs.cosmosDbAccountName
    existingStorageAccountName: deployAgentStorageAccount.outputs.storageAccountName
    existingAISearchAccountName: deployAzureAiSearchService.outputs.aiSearchName
  }
}
