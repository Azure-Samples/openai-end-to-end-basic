/*
  Deploy machine learning workspace, private endpoints and compute resources
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params 
param applicationInsightsName string
param containerRegistryName string
param keyVaultName string
param mlStorageAccountName string
param logWorkspaceName string
param openAiResourceName string
param yourPrincipalId string

// ---- Variables ----
var workspaceName = 'mlw-${baseName}'

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

resource mlStorage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: mlStorageAccountName
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiResourceName
}

// ---- RBAC built-in role definitions and role assignments ----
@description('Built-in Role: [Storage Blob Data Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader)')
resource storageBlobDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: subscription()
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

@description('Built-in Role: [Storage Table Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)')
resource storageTableDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  scope: subscription()
}

@description('Built-in Role: [Storage Account Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)')
resource storageAccountContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  scope: subscription()
}

@description('Built-in Role: [Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)')
resource readerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  scope: subscription()
}

@description('Built-in Role: [AcrPull](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#acrpull)')
resource containerRegistryPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  scope: subscription()
}

@description('Built-in Role: [AcrPush](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#acrpush)')
resource containerRegistryPushRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8311e382-0749-4cb8-b61a-304f252e45ec'
  scope: subscription()
}

@description('Built-in Role: [Azure AI Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)')
resource azureAIAdministratorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b78c5d69-af96-48a3-bf8d-a8b4d589de94'
  scope: subscription()
}

@description('Built-in Role: [Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor)')
resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  scope: subscription()
}

@description('Built-in Role: [Key Vault Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator)')
resource keyVaultAdministratorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  scope: subscription()
}
/*
@description('Built-in Role: [Azure Machine Learning Workspace Connection Secrets Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)')
resource machineLearningConnectionSecretsReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ea01e6af-a1c1-4350-9563-ad00f8c72ec5'
  scope: subscription()
}*/

// ---- New Resources ----

/*
@description('User managed identity that represents the AI Hub workspace.')
resource aiHubManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-aihub'
  location: location
}
*/

/*
@description('User managed identity that represents the AI Hub chat project.')
resource aiHubChatProjectManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-aihub-chatproject'
  location: location
}

@description('User managed identity that represents the Azure Machine Learning workspace.')
resource azureMachineLearningWorkspaceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-amlworkspace'
  location: location
}

@description('User managed identity that represents the Azure Machine Learning workspace\'s managed online endpoint.')
resource azureMachineLearningOnlineEndpointManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-amlonlineendpoint'
  location: location
}

@description('User managed identity that represents the Azure Machine Learning workspace\'s compute instance.')
resource azureMachineLearningInstanceComputeManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-amlinstancecompute'
  location: location
}*/

// ---- Azure Machine Learning Workspace role assignments ----
// Source: https://learn.microsoft.com/azure/machine-learning/how-to-identity-based-service-authentication#user-assigned-managed-identity

// AMLW -> Resource Group (control plane for all resources)

/*
@description('Assign AML Workspace\'s ID: Contributor to parent resource group.')
resource workspaceContributorToResourceGroupRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, azureMachineLearningWorkspaceManagedIdentity.name, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningWorkspaceManagedIdentity.properties.principalId
  }
}*/

// ---- Required permissions for AI Studio (Hub) ---- //

// This architecture uses system managed identity for Azure AI Studio (Hub) and for Azure AI Studio projects.
// Because of this, when those resources are deployed, the necessary role assignments are automatically created.
// If you opt to use user-assigned managed identities, you will need to create the following role assignments on
// with managed identities.

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



// The following permissions are granted to the Azure AI Studio (Hub) managed identity.

// Azure AI Hub's managed identity needs to be set as a contributor on a resource group. This resource group is used when users
// are interacting with the portal to add new projects.
/*   DO THESE GET AUTOMATICALLY CREATED!? 
@description('Assign Azure AI Studio\'s Managed Identity: Contributor to parent resource group. This is used when projects are created in the future (through the portal) to drop project resources into the resource group')
resource aiHubContributorToResourceGroupRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, aiHub.id, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalType: 'ServicePrincipal'
    principalId: aiHub.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s Managed Identity: AI Administorator to self.')
resource aiHubAzureAIAdministratorToSelfRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiHub
  name: guid(resourceGroup().id, aiHub.id, contributorRole.id)
  properties: {
    roleDefinitionId: azureAIAdministratorRole.id
    principalType: 'ServicePrincipal'
    principalId: aiHub.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s Managed Identity: Storage Blob Data Contributor to the studio\'s storage account.')
resource storageBlobDataContributorHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, aiHub.id, storageBlobDataContributorRole.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: aiHub.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s Managed Identity: Storage File Data Privileged Contributor to the studio\'s storage account.')
resource storageFileDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, aiHub.id, storageFileDataContributorRole.id)
  properties: {
    roleDefinitionId: storageFileDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: aiHub.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s Managed Identity: Key Vault Administrator to Key Vault instance.')
resource keyVaultAdministratorForHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, aiHub.id, keyVaultAdministratorRole.id)
  properties: {
    roleDefinitionId: keyVaultAdministratorRole.id
    principalType: 'ServicePrincipal'
    principalId: aiHub.identity.principalId
  }
}

// ---- Required permissions for the AI Studio (Hub) chat project ---- //

// The following permissions are granted to the managed identities for projects that are managed by the hub. If the project 
// is created via the portal, this role assignments are automatically created.

@description('Assign Azure AI Studio\'s chat project\'s identity: Key Vault Administrator to Key Vault instance.')
resource keyVaultAdministratorForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, chatProject.id, keyVaultAdministratorRole.id)
  properties: {
    roleDefinitionId: keyVaultAdministratorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s chat project\'s identity: Reader to the studio\'s storage account.')
resource readerForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, chatProject.id, readerRole.id)
  properties: {
    roleDefinitionId: readerRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s chat project\'s identity: Storage Account Contributor to the studio\'s storage account.')
resource storageAccountContributorForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, chatProject.id, storageAccountContributorRole.id)
  properties: {
    roleDefinitionId: storageAccountContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s chat project\'s identity: Storage Blob Data Contributor to the studio\'s storage account.')
resource storageBlobDataContributorForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, chatProject.id, storageBlobDataContributorRole.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s chat project\'s identity: Storage File Data Privileged Contributor to the studio\'s storage account.')
resource storageFileDataContributorForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, chatProject.id, storageFileDataContributorRole.id)
  properties: {
    roleDefinitionId: storageFileDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s chat project\'s identity: Storage Table Data Contributor to the studio\'s storage account.')
resource storageTableDataContributorForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, chatProject.id, storageTableDataContributorRole.id)
  properties: {
    roleDefinitionId: storageTableDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s chat project\'s identity: Contributor to the studio\'s container registry.')
resource containerRegistryContributorForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(mlStorage.id, chatProject.id, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('Assign Azure AI Studio\'s chat project\'s identity: Contributor to the studio\'s application insights instance.')
resource applicationInsightsContributorForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: applicationInsights
  name: guid(mlStorage.id, chatProject.id, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

AUTOMATIC TEST */

// TODO: Resource Group: ME: Azure AI Inference Deployment Operator




// AMLW ->Give Endpoint identity access to read workspace connection secrets

/*
@description('Assign AML Workspace Azure Machine Learning Workspace Connection Secrets Reader to the endpoint managed identity.')
resource onlineEndpointSecretsReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: machineLearning
  name: guid(machineLearning.id, azureMachineLearningOnlineEndpointManagedIdentity.name, machineLearningConnectionSecretsReaderRole.id)

  properties: {
    roleDefinitionId: machineLearningConnectionSecretsReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningOnlineEndpointManagedIdentity.properties.principalId
  }
}*/


// AMLW -> ML Storage data plane (blobs and files)
/*
@description('Assign AML Workspace\'s ID: Storage Blob Data Contributor to workload\'s storage account.')
resource storageBlobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, azureMachineLearningWorkspaceManagedIdentity.name, storageBlobDataContributorRole.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningWorkspaceManagedIdentity.properties.principalId
  }
}


@description('Assign AML Workspace\'s ID: Storage File Data Privileged Contributor to workload\'s storage account.')
resource storageFileDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, azureMachineLearningWorkspaceManagedIdentity.name, storageFileDataContributor.id)
  properties: {
    roleDefinitionId: storageFileDataContributor.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningWorkspaceManagedIdentity.properties.principalId
  }
}
*/

// Azure AI Studio -> Key Vault data plane (secrets)



/*
// AMLW -> Azure Container Registry data plane (push and pull)

@description('Assign AML Workspace\'s ID: AcrPush to workload\'s container registry.')
resource containerRegistryPushRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, azureMachineLearningWorkspaceManagedIdentity.name, containerRegistryPushRole.id)
  properties: {
    roleDefinitionId: containerRegistryPushRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningWorkspaceManagedIdentity.properties.principalId
  }
}

// ---- Azure Machine Learning Workspace managed online endpoint role assignments ----
// Source: https://learn.microsoft.com/azure/machine-learning/how-to-access-resources-from-endpoints-managed-identities#give-access-permission-to-the-managed-identity

@description('Assign AML Workspace\'s Managed Online Endpoint: AcrPull to workload\'s container registry.')
resource onlineEndpointContainerRegistryPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, azureMachineLearningOnlineEndpointManagedIdentity.name, containerRegistryPullRole.id)
  properties: {
    roleDefinitionId: containerRegistryPullRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningOnlineEndpointManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s Managed Online Endpoint: Storage Blob Data Reader to workload\'s ml storage account.')
resource onlineEndpointBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, azureMachineLearningOnlineEndpointManagedIdentity.name, storageBlobDataReaderRole.id)
  properties: {
    roleDefinitionId: storageBlobDataReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningOnlineEndpointManagedIdentity.properties.principalId
  }
}
  */

// ---- Azure Machine Learning Workspace compute instance role assignments ----
// Source: https://learn.microsoft.com/azure/machine-learning/how-to-identity-based-service-authentication#pull-docker-base-image-to-machine-learning-compute-cluster-for-training-as-is
/*
@description('Assign AML Workspace\'s Managed Online Endpoint: Cognitive Services OpenAI User to OpenAI service.')
resource cognitiveServicesOpenAiUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAiAccount
  name: guid(openAiAccount.id, azureMachineLearningOnlineEndpointManagedIdentity.name, cognitiveServicesOpenAiUserRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningOnlineEndpointManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s Managed Online Endpoint: AcrPull to workload\'s container registry.')
resource computeInstanceContainerRegistryPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, azureMachineLearningInstanceComputeManagedIdentity.name, containerRegistryPullRole.id)
  properties: {
    roleDefinitionId: containerRegistryPullRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningInstanceComputeManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s Managed Online Endpoint: Storage Blob Data Reader to workload\'s ml storage account.')
resource computeInstanceBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, azureMachineLearningInstanceComputeManagedIdentity.name, storageBlobDataReaderRole.id)
  properties: {
    roleDefinitionId: storageBlobDataReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningInstanceComputeManagedIdentity.properties.principalId
  }
}*/

// ---- Azure AI hub (studio) resources ----
/*
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

// Any users that need to access Prompt flow files, need the ability to manage files in the file share. Ideally they would only have access to
// the file shares that are related to their projects.
@description('Assign your user the ability to manage files in storage. This is needed to use the Prompt flow editor in Azure AI Studio.')
resource storageFileDataContributorForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, yourPrincipalId, storageFileDataContributorRole.id)
  properties: {
    roleDefinitionId: storageFileDataContributorRole.id
    principalType: 'User'
    principalId: yourPrincipalId
  }
}

@description('Assign your user the ability to manage files in storage. This is needed to execute the Prompt flow from within in Azure AI Studio.')
resource cognitiveServicesOpenAiUserForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(mlStorage.id, yourPrincipalId, cognitiveServicesOpenAiUserRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRole.id
    principalType: 'User'
    principalId: yourPrincipalId
  }
}

// TODO: Evaluate if AI Services should be a resource we add to this architecture

@description('A hub provides the hosting environment for this AI workload. It provides security, governance controls, and shared configurations.')
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: 'aih-${baseName}'
  location: location
  kind: 'Hub'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'  // This resource's identity is assigned priviledge access to ACR, Storage, Key Vault, and Application Insights.
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
    allowRoleAssignmentOnRG: false // Do role assignments at the resource level.
    v1LegacyMode: false
    workspaceHubConfig: {
      defaultWorkspaceResourceGroup: resourceGroup().id  // Setting this to the same resource group as the workspace
    }

    // Default settings for projects
    storageAccount: mlStorage.id
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
  name: 'aiproj-chat-${baseName}'
  location: location
  kind: 'Project'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'  // This resource's identity is assigned priviledge access to ACR, Storage, Key Vault, and Application Insights.
  }
  properties: {
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    hubResourceId: aiHub.id
  }
}

@description('Azure Diagnostics: Machine Learning Workspace - audit')
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

// ---- Machine Learning Workspace assets ----
/*
@description('The Azure Machine Learning Workspace.')
resource machineLearning 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${azureMachineLearningWorkspaceManagedIdentity.id}': {}
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: workspaceName
    description: 'Azure Machine Learning workspace for this solution. Using platform-managed virtual network. Outbound access fully restricted.'
    hbiWorkspace: false
    primaryUserAssignedIdentity: azureMachineLearningWorkspaceManagedIdentity.id

    // dependent resources
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
    keyVault: keyVault.id
    storageAccount: mlStorage.id

    // configuration for workspaces with private link endpoint
    imageBuildCompute: null
    publicNetworkAccess: 'Enabled'
    v1LegacyMode: false
  }
  dependsOn: [
    // Role assignments: https://learn.microsoft.com/azure/machine-learning/how-to-identity-based-service-authentication#user-assigned-managed-identity
    workspaceContributorToResourceGroupRoleAssignment
    storageBlobDataContributorRoleAssignment
    storageFileDataContributorRoleAssignment
    keyVaultAdministratorRoleAssignment
    containerRegistryPushRoleAssignment
  ]
  
  @description('Managed online endpoint for the /score API.')
  resource onlineEndpoint 'onlineEndpoints' = {
    name: 'ept-${baseName}'
    location: location
    kind: 'Managed'
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${azureMachineLearningOnlineEndpointManagedIdentity.id}': {}
      }
    }
    properties: {
      authMode: 'Key'  // Ideally this should be based on Microsoft Entra ID access. This sample however uses a key stored in Key Vault.
      description: 'Managed online endpoint for the /score API, to be used by the Chat UI app.'
      publicNetworkAccess: 'Enabled'  // This sample uses identity as the perimeter. Production scenarios should layer in network perimeter control as well.
    }
    dependsOn: [
      // Role requirements for the online endpoint: https://learn.microsoft.com/azure/machine-learning/how-to-access-resources-from-endpoints-managed-identities#give-access-permission-to-the-managed-identity
      cognitiveServicesOpenAiUserRoleAssignment
      onlineEndpointContainerRegistryPullRoleAssignment
      onlineEndpointBlobDataReaderRoleAssignment
      onlineEndpointSecretsReaderRoleAssignment 
    ]
  }

  @description('Azure Machine Learning Compute Instance - Ideal for development and testing from the Azure Machine Learning Studio.')
  resource instanceCompute 'computes' = {
    name: 'amli-${baseName}'
    location: location
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${azureMachineLearningInstanceComputeManagedIdentity.id}': {}
      }
    }
    properties: {
      computeType: 'ComputeInstance'
      computeLocation: location
      description: 'Machine Learning compute instance'
      disableLocalAuth: true
      properties: {
        customServices: null
        enableNodePublicIp: true
        personalComputeInstanceSettings: null
        schedules: {
          computeStartStop: []
        }
        setupScripts: null
        applicationSharingPolicy: 'Personal'
        computeInstanceAuthorizationType: 'personal'
        sshSettings: {
          sshPublicAccess: 'Disabled'
        }
        vmSize: 'STANDARD_DS3_V2'
      }
    }
    dependsOn: [
      // Role requirements for compute instance: https://learn.microsoft.com/azure/machine-learning/how-to-identity-based-service-authentication#pull-docker-base-image-to-machine-learning-compute-cluster-for-training-as-is
      computeInstanceContainerRegistryPullRoleAssignment
      computeInstanceBlobDataReaderRoleAssignment
    ]
  }
}

@description('Azure Diagnostics: Machine Learning Workspace - audit')
resource machineLearningDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: machineLearning
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'audit'
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

@description('Azure Diagnostics: Online Endpoint - allLogs')
resource endpointDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: machineLearning::onlineEndpoint
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
/*
@description('Key Vault Secret: The Managed Online Endpoint key to be referenced from the Chat UI app.')
resource managedEndpointPrimaryKeyEntry 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'chatApiKey'
  properties: {
    value: machineLearning::onlineEndpoint.listKeys().primaryKey // In a production system, use Azure RBAC instead of pre-shared secrets
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

output machineLearningId string = machineLearning.id*/
