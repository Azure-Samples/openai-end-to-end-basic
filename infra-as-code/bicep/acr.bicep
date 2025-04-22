/*
  Deploy container registry, used by the Prompt flow project in Azure AI Foundry to store the built docker image.
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Premium'

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

//variables
var acrName = 'cr${baseName}'

// ---- Existing resources ----

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource acrResource 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Allow'
      ipRules: []
    }
    anonymousPullEnabled: false
    networkRuleBypassOptions: 'None'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
    dataEndpointEnabled: true
    metadataSearch: 'Disabled'
  }
}

//ACR diagnostic settings
resource acrResourceDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: acrResource
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'ContainerRegistryLoginEvents'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    logAnalyticsDestinationType: null
  }
}

@description('Output the login server property for later use')
output loginServer string = acrResource.properties.loginServer
