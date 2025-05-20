targetScope = 'resourceGroup'

param uniqueSuffix string
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

// Step 2: Deploy the Azure AI Agent dependencies
module deployAIAgentServiceDependencies 'ai-agent-service-dependencies.bicep' = {
  name: 'deployAIAgentServiceDependencies'
  scope: resourceGroup()
  params: {
    uniqueSuffix: uniqueSuffix
    userPrincipalId: userPrincipalId
    privateEndpointSubnetResourceId: deployVirtualNetwork.outputs.virtualNetworkPrivateEndpointSubnetResourceId
  }
}

// Step 3: Deploy Azure AI Foundry (without any projects)
module deployAzureAIFoundry 'ai-foundry.bicep' = {
  params: {
    agentSubnetResourceId: deployVirtualNetwork.outputs.virtualNetworkAgentSubnetResourceId
    aiFoundryPortalUserPrincipalId: userPrincipalId
    privateEndpointSubnetResourceId: deployVirtualNetwork.outputs.virtualNetworkPrivateEndpointSubnetResourceId
    uniqueSuffix: uniqueSuffix
  }
}

// Step 4: Deploy Azure AI Foundry Project (with CosmosDB, Storage Account, and AI Search connections)
module deployAzureAIFoundryProject 'ai-foundry-project.bicep' = {
  name: 'deployAzureAIFoundryProject'
  scope: resourceGroup()
  params: {
    existingAiFoundryName: deployAzureAIFoundry.outputs.aiFoundryName
    existingCosmosDbAccountName: deployAIAgentServiceDependencies.outputs.cosmosDbAccountName
    existingStorageAccountName: deployAIAgentServiceDependencies.outputs.storageAccountName
    existingAISearchAccountName: deployAIAgentServiceDependencies.outputs.aiSearchName
  }
}
