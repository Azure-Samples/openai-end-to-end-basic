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

  resource agentDatabase 'sqlDatabases' existing = {
    name: 'enterprise_memory'

    resource userThreadContainer 'containers' existing = {
      name: '${workspaceId}-thread-message-store'
    }

    resource systemThreadContainer 'containers' existing = {
      name: '${workspaceId}-system-thread-message-store'
    }

    resource entityStoreContainer 'containers' existing = {
      name: '${workspaceId}-agent-entity-store'
    }
  }

  resource projectUserThreadContainerWriter 'sqlRoleAssignments' = {
    name: guid(aiFoundry::project.id, cosmosDbAccount::writer.id, cosmosDbAccount::agentDatabase::userThreadContainer.id)
    properties: {
      roleDefinitionId: cosmosDbAccount::writer.id
      principalId: aiFoundry::project.identity.principalId
      scope: cosmosDbAccount::agentDatabase::userThreadContainer.id
    }
    dependsOn: [
      aiFoundry::project::threadStorageConnection
    ]
  }

  resource projectSystemThreadContainerWriter 'sqlRoleAssignments' = {
    name: guid(aiFoundry::project.id, cosmosDbAccount::writer.id, cosmosDbAccount::agentDatabase::systemThreadContainer.id)
    properties: {
      roleDefinitionId: cosmosDbAccount::writer.id
      principalId: aiFoundry::project.identity.principalId
      scope: cosmosDbAccount::agentDatabase::systemThreadContainer.id
    }
    dependsOn: [
      aiFoundry::project::threadStorageConnection
    ]
  }

  resource projectEntityContainerWriter 'sqlRoleAssignments' = {
    name: guid(aiFoundry::project.id, cosmosDbAccount::writer.id, cosmosDbAccount::agentDatabase::entityStoreContainer.id)
    properties: {
      roleDefinitionId: cosmosDbAccount::writer.id
      principalId: aiFoundry::project.identity.principalId
      scope: cosmosDbAccount::agentDatabase::entityStoreContainer.id
    }
    dependsOn: [
      aiFoundry::project::threadStorageConnection
    ]
  }
}

resource agentStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: existingStorageAccountName
}

resource azureAISearchService 'Microsoft.Search/searchServices@2025-02-01-preview' existing = {
  name: existingAISearchAccountName
}

resource azureAISearchServiceContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  scope: subscription()
}

resource azureAISearchIndexDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  scope: subscription()
}

// Storage Blob Data Contributor
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: subscription()
}

// Storage Blob Data Owner Role
resource storageBlobDataOwnerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  scope: subscription()
}

resource cosmosDbOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '230815da-be43-4aae-9cb4-875f7bd000aa'
  scope: subscription()
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
        projectBlobDataContributorAssignment
        projectBlobDataOwnerConditionalAssignment
        threadStorageConnection // Single thread these connections, else conflict errors tend to happen
      ]
    }

    // Create project connection to Azure AI Search, dependency for Azure AI Agent Service
    resource aiSearchConnection 'connections' = {
      name: azureAISearchService.name
      properties: {
        category: 'CognitiveSearch'
        target: azureAISearchService.properties.endpoint //'https://${azureAiSearchService.name}.search.windows.net'
        authType: 'AAD'
        metadata: {
          ApiType: 'Azure'
          ResourceId: azureAISearchService.id
          location: azureAISearchService.location
        }
      }
      dependsOn: [
        projectAISearchIndexDataContributorAssignment
        projectAISearchContributorAssignment
        storageConnection // Single thread these connections, else conflict errors tend to happen
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

var workspaceId = aiFoundry::project.properties.internalId

// Role assignments

resource projectDbCosmosDbOperatorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, cosmosDbOperatorRole.id, cosmosDbAccount.id)
  scope: cosmosDbAccount
  properties: {
    roleDefinitionId: cosmosDbOperatorRole.id
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectBlobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, storageBlobDataContributorRole.id, agentStorageAccount.id)
  scope: agentStorageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


resource projectBlobDataOwnerConditionalAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, storageBlobDataOwnerRole.id, agentStorageAccount.id)
  scope: agentStorageAccount
  
  properties: {
    principalId: aiFoundry::project.identity.principalId
    roleDefinitionId: storageBlobDataOwnerRole.id
    principalType: 'ServicePrincipal'
    conditionVersion: '2.0'
    condition: '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read\'})  AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action\'}) AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write\'}) ) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase \'${workspaceId}\' AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase \'*-azureml-agent\'))'
  }
}

resource projectAISearchContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, azureAISearchServiceContributorRole.id, azureAISearchService.id)
  scope: azureAISearchService
  properties: {
    roleDefinitionId: azureAISearchServiceContributorRole.id
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectAISearchIndexDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, azureAISearchIndexDataContributorRole.id, azureAISearchService.id)
  scope: azureAISearchService
  properties: {
    roleDefinitionId: azureAISearchIndexDataContributorRole.id
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


