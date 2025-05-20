targetScope = 'resourceGroup'

param existingAiFoundryName string
param existingCosmosDbAccountName string
param existingStorageAccountName string
param existingAISearchAccountName string

/*** EXISTING RESOURCES ***/

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = {
  name: existingCosmosDbAccountName

  resource writer 'sqlRoleDefinitions' existing = {
    name: '00000000-0000-0000-0000-000000000002'
  }

  resource projectToCosmos 'sqlRoleAssignments' = {
    name: guid(aiFoundry::project.id, cosmosDbAccount::writer.id, cosmosDbAccount.id)
    properties: {
      roleDefinitionId: cosmosDbAccount::writer.id
      principalId: aiFoundry::project.identity.principalId
      scope: cosmosDbAccount.id
    }
  }
}

resource agentStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: existingStorageAccountName
}

resource azureAiSearchService 'Microsoft.Search/searchServices@2025-02-01-preview' existing = {
  name: existingAISearchAccountName
}

/*** NEW RESOURCES ***/

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing  = {
  name: existingAiFoundryName

  resource model 'deployments' existing = {
    name: 'gpt-4o'
  }

  resource project 'projects' = {
    name: 'projchat'
    location: resourceGroup().location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      description: 'Project description'
      displayName: 'ProjectDisplayName'
    }

    // Create project connection to CosmosDB (thread storage), dependency for Azure AI Agent Service
    resource threadStorageConnection 'connections' = {
      name: cosmosDbAccount.name
      properties: {
        authType: 'AAD'
        category: 'CosmosDb'
        target: cosmosDbAccount.properties.documentEndpoint
        metadata: {
          ApiType: 'Azure'
          ResourceId: cosmosDbAccount.id
          location: cosmosDbAccount.location
        }
      }
      dependsOn: [
        projectDbCosmosDbOperatorAssignment
      ]
    }

    // Create project connection to Azure Storage Account, dependency for Azure AI Agent Service
    resource storageConnection 'connections' = {
      name: agentStorageAccount.name
      properties: {
        authType: 'AAD'
        category: 'AzureStorageAccount'
        target: agentStorageAccount.properties.primaryEndpoints.blob
        metadata: {
          ApiType: 'Azure'
          ResourceId: agentStorageAccount.id
          location: agentStorageAccount.location
        }
      }
      dependsOn: [
        projectBlobDataOwnerAssignment
        projectBlobDataOwnerConditionalAssignment
      ]
    }

    // Create project connection to Azure AI Search, dependency for Azure AI Agent Service
    resource aiSearchConnection 'connections' = {
      name: azureAiSearchService.name
      properties: {
        category: 'CognitiveSearch'
        target: azureAiSearchService.properties.endpoint //'https://${azureAiSearchService.name}.search.windows.net'
        authType: 'AAD'
        metadata: {
          ApiType: 'Azure'
          ResourceId: azureAiSearchService.id
          location: azureAiSearchService.location
        }
      }
      dependsOn: [
        projectAISearchIndexDataContributorAssignment
        projectAISearchContributorAssignment
      ]
    }

    /*
    resource projectAgentCapability 'capabilityHosts' = {
      name: 'projchat-capabilities'
      properties: {
        capabilityHostKind: 'Agents'
        storageConnections: [storageConnection.name]
        threadStorageConnections: [threadStorageConnection.name]
        vectorStoreConnections: [agentSearchConnection.name]
      }
      dependsOn: [
        //agent
        storageBlobDataOwnerAssignment
        roleAssignmentSubnet
        roleAssignmentSubnet2
        roleAssignmentVnet
        roleAssignmentVnet2
      ]
    }*/
  }
}

// Role assignments

resource projectDbCosmosDbOperatorAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, '230815da-be43-4aae-9cb4-875f7bd000aa', cosmosDbAccount.id)
  scope: cosmosDbAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '230815da-be43-4aae-9cb4-875f7bd000aa'
    )
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectBlobDataOwnerAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b', agentStorageAccount.id)
  scope: agentStorageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign Storage Blob Data Owner role
resource projectBlobDataOwnerConditionalAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b', agentStorageAccount.id)
  scope: agentStorageAccount
  
  properties: {
    principalId: aiFoundry::project.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalType: 'ServicePrincipal'
    conditionVersion: '2.0'
    condition: '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read\'})  AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action\'}) AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write\'}) ) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase \'${aiFoundry::project.properties.internalId}\' AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase \'*-azureml-agent\'))'
  }
}

resource projectAISearchContributorAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, '7ca78c08-252a-4471-8644-bb5ff32d4ba0', azureAiSearchService.id)
  scope: azureAiSearchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0') // Search Contributor
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectAISearchIndexDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, '8ebe5a00-799e-43f5-93ac-243d3dce84a7', azureAiSearchService.id)
  scope: azureAiSearchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7') // Search Index Data Contributor
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


