targetScope = 'resourceGroup'

param uniqueSuffix string
param userPrincipalId string
param privateEndpointSubnetResourceId string

// Step 2a: Deploy storage account for the Azure AI Agent Service (dependency)
module deployAgentStorageAccount 'storage.bicep' = {
  name: 'deployAgentStorageAccount'
  scope: resourceGroup()
  params: {
    uniqueSuffix: uniqueSuffix
    debugUserPrincipalId: userPrincipalId
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
  }
}

// Step 2b: Deploy CosmosDB Account for the Azure AI Agent Service (dependency)
module deployCosmosDbAccount 'cosmosdb.bicep' = {
  name: 'deployCosmosDbAccount'
  scope: resourceGroup()
  params: {
    debugUserPrincipalId: userPrincipalId
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
  }
}

// Step 2c: Deploy Azure AI Search Service for the Azure AI Agent Service (dependency)
module deployAzureAiSearchService 'ai-search.bicep' = {
  name: 'deployAzureAiSearchService'
  scope: resourceGroup()
  params: {
    privateEndpointSubnetResourceId: privateEndpointSubnetResourceId
    debugUserPrincipalId: userPrincipalId
  }
}

/*** OUTPUTS ***/

output cosmosDbAccountName string = deployCosmosDbAccount.outputs.cosmosDbAccountName
output storageAccountName string = deployAgentStorageAccount.outputs.storageAccountName
output aiSearchName string = deployAzureAiSearchService.outputs.aiSearchName
