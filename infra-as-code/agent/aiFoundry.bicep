targetScope = 'resourceGroup'

param uniqueSuffix string
param agentSubnetResourceId string
param privateEndpointSubnetResourceId string
param aiFoundryPortalUserPrincipalId string

var aiFoundryName = 'aif${uniqueSuffix}'

/*** EXISTING RESOURCES ***/

resource cognitiveServicesLinkedPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink.cognitiveservices.azure.com'
}

resource aiFoundryLinkedPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink.services.ai.azure.com'
}

resource azureOpenAiLinkedPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink.openai.azure.com'
}

// Cognitive Services User Role
resource cognitiveServicesUserRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  scope: subscription()
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: 'log-workload'
}

/*** NEW RESOURCES ***/

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: aiFoundryName
  location: resourceGroup().location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: aiFoundryName
    allowProjectManagement: true // Azure AI Foundry hub
    //defaultProject: 'projchat'
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
        subnetArmId: agentSubnetResourceId  // Report this, schema issue and IP address range issue
        useMicrosoftManagedNetwork: false
      }
    ]
  }

  resource model 'deployments' = {
    name: 'gpt-4o'
    sku: {
      capacity: 18
      name: 'GlobalStandard'
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: 'gpt-4o'
        version: '2024-08-06'
      }
    }
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
}

// Role assignments

resource cognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aiFoundry.id, cognitiveServicesUserRole.id, aiFoundryPortalUserPrincipalId)
  scope: aiFoundry
  properties: {
    roleDefinitionId: cognitiveServicesUserRole.id
    principalId: aiFoundryPortalUserPrincipalId
    principalType: 'User'
  }
}

// Private endpoints

resource aiFoundryPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-aifoundry'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
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
            privateDnsZoneId: cognitiveServicesLinkedPrivateDnsZone.id
          }
        }
        {
          name: 'azureopenai'
          properties: {
            privateDnsZoneId: azureOpenAiLinkedPrivateDnsZone.id
          }
        }
        {
          name: 'cognitiveservices'
          properties: {
            privateDnsZoneId: cognitiveServicesLinkedPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

// Azure diagnostics

resource azureDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: aiFoundry
  properties: {
    workspaceId: logAnalyticsWorkspace.id
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

output aiFoundryName string = aiFoundry.name
