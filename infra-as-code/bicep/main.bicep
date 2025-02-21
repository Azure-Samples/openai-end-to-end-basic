@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('Your principal ID. Used for a few role assignments.')
@minLength(36)
@maxLength(36)
param yourPrincipalId string

@sys.description('Set Parameter to true to Opt-out of deployment telemetry.')
param parTelemetryOptOut bool = false

// Customer Usage Attribution Id
var varCuaid = '6aa4564a-a8b7-4ced-8e57-1043a41f4747'

// ---- Log Analytics workspace ----
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${baseName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Deploy Azure Storage account
module storageModule 'storage.bicep' = {
  name: 'storageDeploy'
  params: {
    location: location
    baseName: baseName
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy Azure Key Vault
module keyVaultModule 'keyvault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    location: location
    baseName: baseName
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy Azure Container Registry
module acrModule 'acr.bicep' = {
  name: 'acrDeploy'
  params: {
    location: location
    baseName: baseName
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy application insights and log analytics workspace
module appInsightsModule 'applicationinsights.bicep' = {
  name: 'appInsightsDeploy'
  params: {
    location: location
    baseName: baseName
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy Azure OpenAI service
module openaiModule 'openai.bicep' = {
  name: 'openaiDeploy'
  params: {
    location: location
    baseName: baseName
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy Azure AI Foundry hub, projects, and managed online endpoints.
module aiStudio 'machinelearning.bicep' = {
  name: 'aiStudio'
  params: {
    location: location
    baseName: baseName
    applicationInsightsName: appInsightsModule.outputs.applicationInsightsName
    keyVaultName: keyVaultModule.outputs.keyVaultName
    aiStudioStorageAccountName: storageModule.outputs.aiStudioStorageAccountName
    containerRegistryName: 'cr${baseName}'
    yourPrincipalId: yourPrincipalId
    logWorkspaceName: logWorkspace.name
    openAiResourceName: openaiModule.outputs.openAiResourceName
  }
}

// Deploy the web apps for the front end demo UI
module webappModule 'webapp.bicep' = {
  name: 'webappDeploy'
  params: {
    location: location
    baseName: baseName
    keyVaultName: keyVaultModule.outputs.keyVaultName
    logWorkspaceName: logWorkspace.name
  }
  dependsOn: [
    aiStudio
  ]
}

// Optional Deployment for Customer Usage Attribution
module modCustomerUsageAttribution 'customerUsageAttribution/cuaIdResourceGroup.bicep' = if (!parTelemetryOptOut) {
  #disable-next-line no-loc-expr-outside-params //Only to ensure telemetry data is stored in same location as deployment. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information //Only to ensure telemetry data is stored in same location as deployment. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information
  name: 'pid-${varCuaid}-${uniqueString(resourceGroup().location)}'
  params: {}
}
