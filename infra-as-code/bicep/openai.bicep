@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

@description('Use Azure AI Services as a common gateway to other Azure AI services, such as Azure OpenAI.')
resource azureAiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'ais-${baseName}'
  location: location
  kind: 'AIServices'
  properties: {
    customSubDomainName: 'ais-${baseName}'
    publicNetworkAccess: 'Enabled' // Production readiness change: This sample uses identity as the perimeter. Production scenarios should layer in network perimeter control as well.
    disableLocalAuth: true
  }
  sku: {
    name: 'S0'
  }

  @description('Fairly aggressive filter that attempts to block prompts and completions that are likely unprofessional. Tune to your specific requirements.')
  resource blockingFilter 'raiPolicies' = {
    name: 'blocking-filter'
    properties: {
      basePolicyName: 'Microsoft.DefaultV2'
      mode: 'Default'
      contentFilters: [
        /* PROMPT FILTERS */
        {
          name: 'Hate'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Prompt'
        }
        {
          name: 'Sexual'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Prompt'
        }
        {
          name: 'Selfharm'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Prompt'
        }
        {
          name: 'Violence'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Prompt'
        }
        {
          name: 'Jailbreak'
          blocking: true
          enabled: true
          source: 'Prompt'
        }
        {
          name: 'Indirect Attack'
          blocking: true
          enabled: true
          source: 'Prompt'
        }
        {
          name: 'Profanity'
          blocking: true
          enabled: true
          source: 'Prompt'
        }
        /* COMPLETION FILTERS */
        {
          name: 'Hate'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Completion'
        }
        {
          name: 'Sexual'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Completion'
        }
        {
          name: 'Selfharm'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Completion'
        }
        {
          name: 'Violence'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Completion'
        }
        {
          name: 'Protected Material Text'
          blocking: true
          enabled: true
          source: 'Completion'
        }
        {
          name: 'Protected Material Code'
          blocking: true
          enabled: true
          source: 'Completion'
        }
      ]
    }
  }

  @description('Add a GPT-4o mini deployment.')
  resource gpt4o 'deployments' = {
    name: 'gpt4o'
    sku: {
      name: 'Standard'
      capacity: 4
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: 'gpt-4o-mini'
        version: '2024-07-18' // If your selected region doesn't support this version, please change the version to a supported one.
                              // az cognitiveservices model list -l $LOCATION --query "sort([?model.name == 'gpt-4o-mini' && kind == 'OpenAI'].model.version)" -o tsv
      }
      raiPolicyName: azureAiServices::blockingFilter.name
      versionUpgradeOption: 'OnceNewDefaultVersionAvailable' // Production readiness change: Always be explicit about model versions, use 'NoAutoUpgrade' to prevent version changes.
    }
  }
}

//OpenAI diagnostic settings
resource openAIDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: azureAiServices
  properties: {
    workspaceId: logWorkspace.id
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
    logAnalyticsDestinationType: null
  }
}

// ---- Outputs ----

output azureAiServicesResourceName string = azureAiServices.name
