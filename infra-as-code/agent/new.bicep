param name string = 'ckchatm01'
param userPrincipalId string

resource vnetWorkload 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${name}'
  location: 'eastus2'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/16'
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
      {
        name: 'private-endpoints'
        properties: {
          addressPrefix: '192.168.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: false
        }
      }
    ]
  }

  resource agentSubnet 'subnets' existing = {
    name: 'agent'
  }

    resource peSubnet 'subnets' existing = {
    name: 'private-endpoints'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: 'stg${name}'
  location: 'eastus2'
  sku: {
    name: 'Standard_LRS'
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

resource cognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry.id, 'CognitiveServicesUser', userPrincipalId)
  scope: aiFoundry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalId: userPrincipalId
    principalType: 'User'
  }
}


resource cosmosdb 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' = {
  name: 'cdb${name}'
  location: 'eastus2'
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
        locationName: 'eastus2'
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
  }

  resource writer 'sqlRoleDefinitions' existing = {
    name: '00000000-0000-0000-0000-000000000002'
  }

  resource projectToCosmos 'sqlRoleAssignments' = {
    name: guid(aiFoundry::project.id, 'CosmosDBDataWriter', cosmosdb.id)
    properties: {
      roleDefinitionId: cosmosdb::writer.id
      principalId: aiFoundry::project.identity.principalId
      scope: cosmosdb.id
    }
    dependsOn: [
      userToCosmosAccountReader
    ]
  }

  resource hubToCosmos 'sqlRoleAssignments' = {
    name: guid(aiFoundry.id, 'CosmosDBDataWriter', cosmosdb.id)
    properties: {
      roleDefinitionId: cosmosdb::writer.id
      principalId: aiFoundry.identity.principalId
      scope: cosmosdb.id
    }
    dependsOn: [
      userToCosmosAccountReader
    ]
  }

  resource userToCosmos 'sqlRoleAssignments' = {
    name: guid(userPrincipalId, 'CosmosDBDataWriter', cosmosdb.id)
    properties: {
      roleDefinitionId: cosmosdb::writer.id
      principalId: userPrincipalId
      scope: cosmosdb.id
    }
    dependsOn: [
      userToCosmosAccountReader
    ]
  }
}

resource searchService 'Microsoft.Search/searchServices@2025-02-01-preview' = {
  name: 'ais${name}'
  location: 'eastus2'
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

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: 'aif${name}'
  location: 'eastus2'
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    //customSubDomainName: null // TODO: setting this at initial creation time does not create the public DNS record. Need to add it after via the portal. Report this.
    customSubDomainName: 'aif${name}'
    allowProjectManagement: true // Azure AI Foundry hub
    defaultProject: 'projchat'
    disableLocalAuth: true
    networkAcls: {
      bypass: 'None'
      ipRules: []
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Disabled'
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: vnetWorkload::agentSubnet.id  // Report this, schema issue and IP address range issue
        useMicrosoftManagedNetwork: false
      }
    ]
  }
  dependsOn: [
    cosmosDbPrivateEndpoint::dnsGroup
    aiSearchPrivateEndpoint::dnsGroup
    storagePrivateEndpoint::dnsGroup
  ]

  // Model must be deployed AFTER DNS is set -- this is probably a bug.
  resource model 'deployments' = {
    name: 'gpt-4o'
    sku: {
      capacity: 10
      name: 'GlobalStandard'
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: 'gpt-4o'
        version: '2024-08-06'
      }
    }
    dependsOn: [
      aiFoundryPrivateEndpoint::dnsGroup
    ]
  }

  // Account connection to Key Vault
  /*resource keyVaultConnection 'connections' = {
    name: 'keyvault'
    properties: {
      authType: 'AAD'
      category: 'KeyVault'
      target: keyVault.properties.vaultUri
      isSharedToAll: true
      metadata: {
        ApiType: 'Azure'
        ResourceId: keyVault.id
        location: keyVault.location
      }
    }
  }*/

  /*
  resource agent 'capabilityHosts' existing = {
    name: '${name}@AML_AiAgentService'
    dependsOn: [
      model
    ]
  } */

  resource project 'projects' = {
    name: 'projchat'
    location: 'eastus2'
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      description: 'Project description'
      displayName: 'ProjectDisplayName'
    }

    //dependsOn: [
     // model
    //]

    // Create project connection to CosmosDB (thread storage)
    resource threadStorageConnection 'connections' = {
      name: 'agentThreadStorage'
      properties: {
        authType: 'AAD'
        category: 'CosmosDb'
        target: cosmosdb.properties.documentEndpoint
        metadata: {
          ApiType: 'Azure'
          ResourceId: cosmosdb.id
          location: cosmosdb.location
        }
      }
      dependsOn: [
        storageConnection
        cosmosdb::hubToCosmos
        cosmosdb::projectToCosmos
      ]
    }

    // Create project connection to Azure Storage Account
    resource storageConnection 'connections' = {
      name: 'agentStorageAccount'
      properties: {
        authType: 'AAD'
        category: 'AzureStorageAccount'
        target: storage.properties.primaryEndpoints.blob
        metadata: {
          ApiType: 'Azure'
          ResourceId: storage.id
          location: storage.location
        }
      }
      dependsOn: [
        agentSearchConnection
      ]
    }

    // Create project connection to Azure AI Search
    resource agentSearchConnection 'connections' = {
      name: 'agentSearchConnection'
      properties: {
        category: 'CognitiveSearch'
        target: searchService.properties.endpoint
        authType: 'AAD'
        metadata: {
          ApiType: 'Azure'
          ResourceId: searchService.id
          location: searchService.location
        }
      }
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

resource aiFoundryPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-aifoundry'
  location: 'eastus2'
  properties: {
    subnet: {
      id: vnetWorkload::peSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'aifoundry'
        properties: {
          privateLinkServiceId: aiFoundry.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }

  resource dnsGroup 'privateDnsZoneGroups' = {
    name: 'aifoundry'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'aifoundry'
          properties: {
            privateDnsZoneId: aiFoundryPrivateDnsZone.id
          }
        }
        {
          name: 'openai'
          properties: {
            privateDnsZoneId: openAiPrivateDnsZone.id
          }
        }
        {
          name: 'cogservices'
          properties: {
            privateDnsZoneId: cognitiveServicesPrivateDnsZone.id
          }
        }
      ]
    }
    dependsOn: [
      aiFoundryPrivateDnsZone::link
      openAiPrivateDnsZone::link
      cognitiveServicesPrivateDnsZone::link
    ]
  }
}

resource aiFoundryPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.services.ai.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'aifoundry-link'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnetWorkload.id
      }
      registrationEnabled: false
    }
  }
}

resource openAiPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'openai-link'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnetWorkload.id
      }
      registrationEnabled: false
    }
  }
}

resource cognitiveServicesPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.cognitiveservices.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'cognitiveServices-link'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnetWorkload.id
      }
      registrationEnabled: false
    }
  }
}

resource aiSearchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-aisearch'
  location: 'eastus2'
  properties: {
    subnet: {
      id: vnetWorkload::peSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'aisearch'
        properties: {
          privateLinkServiceId: searchService.id
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
            privateDnsZoneId: aiSearchPrivateDnsZone.id
          }
        }
      ]
    }
    dependsOn: [
      aiSearchPrivateDnsZone::link
    ]
  }
}

resource aiSearchPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.search.windows.net'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'aisearch-link'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnetWorkload.id
      }
      registrationEnabled: false
    }
  }
}



resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-aistorage'
  location: 'eastus2'
  properties: {
    subnet: {
      id: vnetWorkload::peSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'storage'
        properties: {
          privateLinkServiceId: storage.id
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
            privateDnsZoneId: storagePrivateDnsZone.id
          }
        }
      ]
    }
    dependsOn: [
      storagePrivateDnsZone::link
    ]
  }
}

resource storagePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'storage-link'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnetWorkload.id
      }
      registrationEnabled: false
    }
  }
}

resource cosmosDbPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-cosmosdb'
  location: 'eastus2'
  properties: {
    subnet: {
      id: vnetWorkload::peSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'cosmosdb'
        properties: {
          privateLinkServiceId: cosmosdb.id
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
            privateDnsZoneId: cosmosDbPrivateDnsZone.id
          }
        }
      ]
    }
    dependsOn: [
      cosmosDbPrivateDnsZone::link
    ]
  }
}

resource cosmosDbPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'cosmosdb-link'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnetWorkload.id
      }
      registrationEnabled: false
    }
  }
}

resource projectToCosmosDBOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, 'CosmosDBOperator', cosmosdb.id)
  scope: cosmosdb
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '230815da-be43-4aae-9cb4-875f7bd000aa'
    )
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource userToCosmosAccountReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(userPrincipalId, 'CosmosDBAccountReader', cosmosdb.id)
  scope: cosmosdb
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'fbdf93bf-df7d-467e-a4d2-9458aa1360c8'
    )
    principalId: userPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentVnet 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, 'NetworkContributor', vnetWorkload.id, 'y')
  scope: vnetWorkload
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4d97b98b-1d4f-4787-a291-c67834d212e7'
    ) // Network Contributor Role
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentSubnet 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, 'NetworkContributor', vnetWorkload::agentSubnet.id, 'y')
  scope: vnetWorkload::agentSubnet
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4d97b98b-1d4f-4787-a291-c67834d212e7'
    ) // Network Contributor Role
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentVnet2 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry.id, 'NetworkContributor', vnetWorkload.id)
  scope: vnetWorkload
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4d97b98b-1d4f-4787-a291-c67834d212e7'
    ) // Network Contributor Role
    principalId: aiFoundry.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentSubnet2 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry.id, 'NetworkContributor', vnetWorkload::agentSubnet.id)
  scope: vnetWorkload::agentSubnet
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4d97b98b-1d4f-4787-a291-c67834d212e7'
    ) // Network Contributor Role
    principalId: aiFoundry.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobDataOwnerAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, 'StorageBlobDataOwner', storage.id)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobDataOwnerAssignmentHub 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry.id, 'StorageBlobDataOwner', storage.id)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b') // Storage Blob Data Owner
    principalId: aiFoundry.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aiSearchAssignmentProject 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, 'Search', searchService.id)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0') // Search Contributor
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aiSearchIndexAssignmentProject 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry::project.id, 'Search', searchService.id)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7') // Search Index Data Contributor
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

/* TODO
var conditionStr= '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read\'})  AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action\'}) AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write\'}) ) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase \'${workspaceId}\' AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase \'*-azureml-agent\'))'

// Assign Storage Blob Data Owner role
resource storageBlobDataOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storageBlobDataOwner.id, storage.id)
  properties: {
    principalId: aiProjectPrincipalId
    roleDefinitionId: storageBlobDataOwner.id
    principalType: 'ServicePrincipal'
    conditionVersion: '2.0'
    condition: conditionStr
  }
}*/

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'log-${name}'
  location: 'eastus2'
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: storage::blob
  properties: {
    workspaceId: logAnalytics.id
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

resource cosmosdbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: cosmosdb
  properties: {
    workspaceId: logAnalytics.id
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

resource searchServiceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: searchService
  properties: {
    workspaceId: logAnalytics.id
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

resource aiFoundryDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: aiFoundry
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'Audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'RequestResponse'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AzureOpenAIRequestUsage'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Trace'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}
