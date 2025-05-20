targetScope = 'resourceGroup'

param existingAiFoundryName string
param existingAiFoundryProjectName string
param cosmosDbConnectionName string
param storageAccountConnectionName string
param aiSearchConnectionName string

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: existingAiFoundryName

  resource project 'projects' existing = {
    name: existingAiFoundryProjectName
    

  }
}
