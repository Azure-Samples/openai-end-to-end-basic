targetScope = 'resourceGroup'

// Ref: https://github.com/azure-ai-foundry/foundry-samples/blob/main/samples/microsoft/infrastructure-setup/15-private-network-standard-agent-setup/modules-network-secured/cosmos-container-role-assignments.bicep

param uniqueSuffix string
param userPrincipalId string

// Step 1: Create log sink for the workload
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'log-workload'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    workspaceCapping: {
      dailyQuotaGb: 20
    }
  }
}

// Step 2: Establish the private network for the workload
module deployVirtualNetwork 'network.bicep' = {
  name: 'deployVirtualNetwork'
  scope: resourceGroup()
  params: {}
}

// Step 3: Control egress traffic through an Azure Firewall
module deployAzureFirewall 'azure-firewall.bicep' = {
  name: 'deployAzureFirewall'
  scope: resourceGroup()
  params: {}
}

// Step 4: Deploy the Azure AI Agent dependencies
module deployAIAgentServiceDependencies 'ai-agent-service-dependencies.bicep' = {
  name: 'deployAIAgentServiceDependencies'
  scope: resourceGroup()
  params: {
    uniqueSuffix: uniqueSuffix
    userPrincipalId: userPrincipalId
    privateEndpointSubnetResourceId: deployVirtualNetwork.outputs.virtualNetworkPrivateEndpointSubnetResourceId
  }
  dependsOn: [
    deployAzureFirewall  // Makes sure that egress traffic is controlled before workload resources start being deployed
  ]
}

// Step 5: Deploy Azure AI Foundry (without any projects)
module deployAzureAIFoundry 'ai-foundry.bicep' = {
  name: 'deployAzureAIFoundry'
  params: {
    agentSubnetResourceId: deployVirtualNetwork.outputs.virtualNetworkAgentSubnetResourceId
    aiFoundryPortalUserPrincipalId: userPrincipalId
    privateEndpointSubnetResourceId: deployVirtualNetwork.outputs.virtualNetworkPrivateEndpointSubnetResourceId
    uniqueSuffix: uniqueSuffix
  }
}

// Step 6: Deploy Azure AI Foundry Project (with CosmosDB, Storage Account, and AI Search connections)
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
