targetScope = 'resourceGroup'

@description('The region in which this architecture is deployed. Should match the region of the resource group.')
@minLength(1)
param location string = resourceGroup().location

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The name of the workload\'s existing Log Analytics workspace.')
@minLength(4)
param logAnalyticsWorkspaceName string

@description('Your principal ID. Allows you to access the Azure AI Foundry portal for post-deployment verification of functionality.')
@maxLength(36)
@minLength(36)
param aiFoundryPortalUserPrincipalId string

var aiFoundryName = 'aif${baseName}'

// ---- Existing resources ----

@description('Existing: Built-in Cognitive Services User role.')
resource cognitiveServicesUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  scope: subscription()
}

@description('Existing: Log sink for Azure Diagnostics.')
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
}

// ---- New resources ----

@description('Deploy Azure AI Foundry (account) with Azure AI Agent service capability.')
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: aiFoundryName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: aiFoundryName
    allowProjectManagement: true // Azure AI Foundry account
    disableLocalAuth: true
    networkAcls: {
      bypass: 'AzureServices'
      ipRules: []
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled'
  }

  @description('Models are managed at the account level. Deploy the GPT model that will be used for the Azure AI Agent logic.')
  resource model 'deployments' = {
    name: 'gpt-4o'
    sku: {
      capacity: 20
      name: 'GlobalStandard'
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: 'gpt-4o'
        version: '2024-08-06'
      }
      versionUpgradeOption: 'NoAutoUpgrade' // Production deployments should not auto-upgrade models.  Testing compatibility is important.
    }
  }
}

// Role assignments

@description('Assign yourself to have access to the Azure AI Foundry portal.')
resource cognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry.id, cognitiveServicesUserRole.id, aiFoundryPortalUserPrincipalId)
  scope: aiFoundry
  properties: {
    roleDefinitionId: cognitiveServicesUserRole.id
    principalId: aiFoundryPortalUserPrincipalId
    principalType: 'User'
  }
}

// Azure diagnostics

@description('Enable logging on the Azure AI Foundry account.')
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

// ---- Outputs ----

@description('The name of the Azure AI Foundry account.')
output aiFoundryName string = aiFoundry.name
