/*
  Deploy Azure AI Studio hub, projects, and a managed online endpoint
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params 
param applicationInsightsName string
param containerRegistryName string
param keyVaultName string
param aiStudioStorageAccountName string

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

param openAiResourceName string
param yourPrincipalId string

// ---- Existing resources ----

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-08-01-preview' existing = {
  name: containerRegistryName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource aiStudioStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: aiStudioStorageAccountName
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiResourceName
}

@description('Built-in Role: [Cognitive Services OpenAI User](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#cognitive-services-openai-user)')
resource cognitiveServicesOpenAiUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  scope: subscription()
}

@description('Built-in Role: [Storage Blob Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)')
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: subscription()
}

@description('Built-in Role: [Storage File Data Privileged Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-file-data-privileged-contributor)')
resource storageFileDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
  scope: subscription()
}

@description('Built-in Role: [Azure Machine Learning Workspace Connection Secrets Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)')
resource amlWorkspaceSecretsReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ea01e6af-a1c1-4350-9563-ad00f8c72ec5'
  scope: subscription()
}

// ---- Required permissions for AI Studio (Hub) ---- //

// This architecture uses system managed identity for Azure AI Studio (Hub), Azure AI Studio projects, and for the managed
// online endpoint. Because they are system managed identities, when those resources are deployed, the necessary role
// assignments are automatically created. If you opt to use user-assigned managed identities, you will need to create the
// following role assignments with the managed identities.

// Azure AI Studio -> Contributor on parent resource group
// Azure AI Studio -> AI Administrator on self
// Azure AI Studio -> Storage Blob Data Contributor to the storage account
// Azure AI Studio -> Storage File Data Privileged Contributor to the storage account
// Azure AI Studio -> Key Vault Administrator to the Key Vault

// Each project created needs its own identies assigned similarly

// Azure AI Studio Project -> Reader to the storage account
// Azure AI Studio Project -> Storage Account Contributor to the storage account
// Azure AI Studio Project -> Storage Blob Data Contributor to the storage account
// Azure AI Studio Project -> Storage File Data Privileged Contributor to the storage account
// Azure AI Studio Project -> Storage Table Data Contributor to the storage account
// Azure AI Studio Project -> Key Vault Administrator to the Key Vault
// Azure AI Studio Project -> Contributor to the Container Registry
// Azure AI Studio Project -> Contributor to Application Insights

// Each deployment under the project needs its own identities assigned as such
// Endpoint -> AzureML Metrics Writer to the Azure AI Studio Project
// Endpoint -> AzureML Machine Learning Workspace Connection Secrets Reader to the Azure AI Studio Project
// Endpoint -> AcrPull to the Container Registry
// Endpoint -> Storage Blob Data Contributor to the storage account

/*

// TODO: Evaluate if AI Services should be a resource we add to this architecture (Why, why not?)
@description('Azure AI Service service agreggation point.')
resource azureAIServices 'Microsoft.CognitiveServices/accounts@2024-06-01-preview' = {
  name: 'aischat'
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    disableLocalAuth: true
    raiMonitorConfig: null
    apiProperties: {}
    restrictOutboundNetworkAccess: false
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      bypass: 'None'
      virtualNetworkRules: []
    }
    dynamicThrottlingEnabled: false
    allowedFqdnList: []
    restore: false
    customSubDomainName: 'ck0002'
    amlWorkspace: null
    publicNetworkAccess: 'Enabled'
  }
}


@description('Azure Diagnostics: Machine Learning Workspace - audit')
resource aiServiceDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: aiServices
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}
*/

// To light up the Azure AI portal experience, the user themsleves need a few data plane permissions. To simulate that for this implementation
// we will assign the user that is running this deployment the following roles:

@description('Assign your user the ability to manage files in storage. This is needed to use the Prompt flow editor in Azure AI Studio.')
resource storageFileDataContributorForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiStudioStorageAccount
  name: guid(aiStudioStorageAccount.id, yourPrincipalId, storageFileDataContributorRole.id)
  properties: {
    roleDefinitionId: storageFileDataContributorRole.id
    principalType: 'User'
    principalId: yourPrincipalId
  }
}

@description('Assign your user the ability to manage Prompt flow state files from blob storage. This is needed to execute the Prompt flow from within in Azure AI Studio.')
resource blobStorageContributorForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiStudioStorageAccount
  name: guid(aiStudioStorageAccount.id, yourPrincipalId, storageBlobDataContributorRole.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'User'
    principalId: yourPrincipalId
  }
}

@description('Assign your user the ability to invoke models in Azure OpenAI. This is needed to execute the Prompt flow from within in Azure AI Studio.')
resource cognitiveServicesOpenAiUserForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAiAccount
  name: guid(openAiAccount.id, yourPrincipalId, cognitiveServicesOpenAiUserRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRole.id
    principalType: 'User'
    principalId: yourPrincipalId
  }
}

@description('A hub provides the hosting environment for this AI workload. It provides security, governance controls, and shared configurations.')
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: 'aihub-${baseName}'
  location: location
  kind: 'Hub'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'  // This resource's identity is automatically assigned priviledge access to ACR, Storage, Key Vault, and Application Insights.
  }
  properties: {
    friendlyName: 'Azure OpenAI Chat Hub'
    description: 'Hub to support the Microsoft Learn Azure OpenAI basic chat implementation. https://learn.microsoft.com/azure/architecture/ai-ml/architecture/basic-openai-e2e-chat'
    publicNetworkAccess: 'Enabled'  // Production readiness change. The "Baseline" architecture adds ingress and egress network control over this "Basic" implementation.
    ipAllowlist: []
    serverlessComputeSettings: null
    enableServiceSideCMKEncryption: false
    managedNetwork: {
      isolationMode: 'Disabled'  // Production readiness change. The "Baseline" architecture adds ingress and egress network control over this "Basic" implementation.
    }
    allowRoleAssignmentOnRG: false // Require role assignments at the resource level.
    v1LegacyMode: false
    workspaceHubConfig: {
      defaultWorkspaceResourceGroup: resourceGroup().id  // Setting this to the same resource group as the workspace
    }

    // Default settings for projects
    storageAccount: aiStudioStorageAccount.id
    containerRegistry: containerRegistry.id
    systemDatastoresAuthMode: 'identity'
    enableSoftwareBillOfMaterials: true
    enableDataIsolation: true
    keyVault: keyVault.id
    applicationInsights: applicationInsights.id
    hbiWorkspace: false
    imageBuildCompute: null
  }

  resource aoaiConnection 'connections' = {
    name: 'aoai'
    properties: {
      authType: 'AAD'
      category: 'AzureOpenAI'
      isSharedToAll: true
      useWorkspaceManagedIdentity: true
      peRequirement: 'NotRequired'
      sharedUserList: []
      metadata: {
        ApiType: 'Azure'
        ResourceId: openAiAccount.id
      }
      target: openAiAccount.properties.endpoint
    }
  }

  /*resource aiServicesConnection 'connections' = {
    name: 'aiservices'
    properties: {
      authType: 'AAD'
      category: 'AIServices'
      isSharedToAll: true
      useWorkspaceManagedIdentity: true
      peRequirement: 'NotRequired'
      sharedUserList: []
      metadata: {
        ApiType: 'Azure'
        ResourceId: aiServices.id
      }
      target: aiServices.properties.endpoint
    }
  }*/
}

@description('Azure Diagnostics: Machine Learning Workspace - audit')
resource aiHubDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: aiHub
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// ---- Chat project ----
 
@description('This is a container for the chat project.')
resource chatProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: 'aiproj-chat'
  location: location
  kind: 'Project'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'  // This resource's identity is automatically assigned priviledge access to ACR, Storage, Key Vault, and Application Insights.
  }
  properties: {
    friendlyName: 'Chat with Wikipedia project'
    description: 'Project to contain the "Chat with Wikipedia" example Prompt flow that is used as part of the Microsoft Learn Azure OpenAI basic chat implementation. https://learn.microsoft.com/azure/architecture/ai-ml/architecture/basic-openai-e2e-chat'
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    hubResourceId: aiHub.id
  }

  resource endpoint 'onlineEndpoints' = {
    name: 'ept-chat-${baseName}'
    location: location
    kind: 'Managed'
    identity: {
      type: 'SystemAssigned' // This resource's identity is automatically assigned AcrPull access to ACR, Storage Blob Data Contributor, and AML Metrics Writer on the project. It is also assigned two additional permissions below.
    }
    properties: {
      description: 'This is the /score endpoint for the "Chat with Wikipedia" example Prompt flow deployment. Called by the UI hosted in Web Apps.'
      authMode: 'Key' // Ideally this should be based on Microsoft Entra ID access. This sample however uses a key stored in Key Vault.
      publicNetworkAccess: 'Enabled' // This sample uses identity as the perimeter. Production scenarios should layer in network perimeter control as well.
    }

    // TODO: Noticed that traffic goes back to 0% if this is template redeployed after the Prompt flow
    // deplopyment is complete. How can we stop that?
    // TODO: Verify that traffic goes to 100% on initial deploy (I think it does, but need to be sure)
  }

  // NOTE: Change over baseline, Prompt Flow in the portal an simply use serverless compute for the Azure AI Studio prompt flow testing, don't pre-provision compute for that.
  // Meaniing we no longer have a 'computes' (ComputeInstance) here.  Tradeoff. The Serverless offering has limited flexibility and access, but requires no management.
}

@description('Assign the online endpoint the ability to interact with the secrets of the parent project. This is needed to execute the Prompt flow from the managed endpoint.')
resource projectSecretsReaderForOnlineEndpointRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: chatProject
  name: guid(chatProject.id, chatProject::endpoint.id, amlWorkspaceSecretsReaderRole.id)
  properties: {
    roleDefinitionId: amlWorkspaceSecretsReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject::endpoint.identity.principalId
  }
}

@description('Assign the online endpoint the ability to invoke models in Azure OpenAI. This is needed to execute the Prompt flow from the managed endpoint.')
resource projectOpenAIUserForOnlineEndpointRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAiAccount
  name: guid(openAiAccount.id, chatProject::endpoint.id, cognitiveServicesOpenAiUserRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject::endpoint.identity.principalId
  }
}

@description('Azure Diagnostics: AI Studio chat project - allLogs')
resource chatProjectDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: chatProject
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'  // In production, this is probably excessive. Please tune to just the log streams that add value to your workload's operations.
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}


@description('Azure Diagnostics: AI Studio chat project -> endpoint allLogs')
resource chatProjectEndpointDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: chatProject::endpoint
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Production readiness: Client applications that run from compute on Azure should use managed identities instead of
// pre-shared keys. This sample implementation uses a pre-shared key, and should be rewritten to use the managed identity
// provided by Azure Web Apps.
// TODO: Figure out if the key is something that's reliably predictable, if so, just use that instead of creating
//       a copy of it.
@description('Key Vault Secret: The Managed Online Endpoint key to be referenced from the Chat UI app.')
resource managedEndpointPrimaryKeyEntry 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'chatApiKey'
  properties: {
    value: chatProject::endpoint.listKeys().primaryKey // This key is technically already in Key Vault, but it's name is not something that is easy to reference.
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}
