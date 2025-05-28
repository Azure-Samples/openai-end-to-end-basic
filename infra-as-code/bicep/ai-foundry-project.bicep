targetScope = 'resourceGroup'

@description('The region in which this architecture is deployed. Should match the region of the resource group.')
@minLength(1)
param location string = resourceGroup().location

@description('The existing Azure AI Foundry account. This project will become a child resource of this account.')
@minLength(2)
param existingAiFoundryName string

@description('The existing Bing grounding data account that is available to Azure AI Agent agents in this project.')
@minLength(1)
param existingBingAccountName string

@description('The existing Application Insights instance to log token usage in this project.')
@minLength(1)
param existingWebApplicationInsightsResourceName string

// ---- Existing resources ----

#disable-next-line BCP081
resource bingAccount 'Microsoft.Bing/accounts@2025-05-01-preview' existing = {
  name: existingBingAccountName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: existingWebApplicationInsightsResourceName
}

// ---- New resources ----

@description('Existing Azure AI Foundry account. The project will be created as a child resource of this account.')
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing  = {
  name: existingAiFoundryName

  resource project 'projects' = {
    name: 'projchat'
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      description: 'Chat using internet data'
      displayName: 'ChatWithInternetData'
    }

    @description('Connect this project to application insights for visualization of token usage.')
    resource applicationInsightsConnection 'connections' = {
      name:'appInsights-connection'
      properties: {
        authType: 'ApiKey'
        category: 'AppInsights'
        credentials: {
          key: applicationInsights.properties.ConnectionString
        }
        isSharedToAll: false
        target: applicationInsights.id
        metadata: {
          ApiType: 'Azure'
          ResourceId: applicationInsights.id
          location: applicationInsights.location
        }
      }
      dependsOn: []
    }
    
    @description('Create project connection to Bing grounding data. Useful for future agents that get created.')
    resource bingGroundingConnection 'connections' = {
      name: replace(existingBingAccountName, '-', '')
      properties: {
        authType: 'ApiKey'
        target: bingAccount.properties.endpoint
        category: 'GroundingWithBingSearch'
        metadata: {
          type: 'bing_grounding'
          ApiType: 'Azure'
          ResourceId: bingAccount.id
          location: bingAccount.location
        }
        credentials: {
          key: bingAccount.listKeys().key1
        }
        isSharedToAll: false
      }
      dependsOn: [
        applicationInsightsConnection  // Single thread changes to the project, else conflict errors tend to happen
      ]
    }
  }
}

// ---- Outputs ----

output bingSearchConnectionId string = aiFoundry::project::bingGroundingConnection.id
