/*
  Deploy a web app with a managed identity and diagnostics
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params
param keyVaultName string
param logWorkspaceName string

// variables
var appName = 'app-${baseName}'

// ---- Existing resources ----

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

// Built-in Azure RBAC role that is applied to a Key Vault to grant secrets content read permissions.
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
  scope: subscription()
}

resource chatProject 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' existing = {
  name: 'aiproj-chat'

  resource scoreEndpoint 'onlineEndpoints' existing = {
    name: 'ept-chat-${baseName}'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName

  resource chatApiKey 'secrets' existing = {
    name: 'chatApiKey'
  }
}

// ---- Web App resources ----

// Managed Identity for App Service
resource appServiceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${appName}'
  location: location
}

// Grant the App Service managed identity key vault secrets role permissions
module appServiceSecretsUserRoleAssignmentModule './modules/keyvaultRoleAssignment.bicep' = {
  name: 'appServiceSecretsUserRoleAssignmentDeploy'
  params: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: appServiceManagedIdentity.properties.principalId
    keyVaultName: keyVaultName
  }
}

// App service plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${appName}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'B2'
    capacity: 1
  }
  properties: {
    zoneRedundant: false
    reserved: true
  }
  kind: 'linux'
}

// Web App
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'app'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appServiceManagedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: false
    keyVaultReferenceIdentity: appServiceManagedIdentity.id
    hostNamesDisabled: false
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      vnetRouteAllEnabled: true
      http20Enabled: true
      alwaysOn: true
      linuxFxVersion: 'DOTNETCORE|8.0'
      netFrameworkVersion: null
      windowsFxVersion: null
    }
  }
  dependsOn: [
    appServiceSecretsUserRoleAssignmentModule
  ]
}

// App Settings
resource appsettings 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'appsettings'
  parent: webApp
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    chatApiKey: '@Microsoft.KeyVault(SecretUri=${keyVault::chatApiKey.properties.secretUri})'
    chatApiEndpoint: chatProject::scoreEndpoint.properties.scoringUri
    chatInputName: 'question'
    chatOutputName: 'answer'
    keyVaultReferenceIdentity: appServiceManagedIdentity.id
  }
}

//Web App diagnostic settings
resource webAppDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: webApp
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        categoryGroup: null
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// create application insights resource
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appinsights-${appName}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
    RetentionInDays: 90
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}
