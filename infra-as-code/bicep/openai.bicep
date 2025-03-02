@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

//variables
var openaiName = 'oai-${baseName}'

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: openaiName
  location: location
  kind: 'OpenAI'
  properties: {
    customSubDomainName: 'oai-${baseName}'
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
      #disable-next-line BCP037
      basePolicyName: 'Microsoft.Default'
      mode: 'Default'
      contentFilters: [
        /* PROMPT FILTERS */
        {
          #disable-next-line BCP037
          name: 'hate'
          blocking: true
          enabled: true
          source: 'Prompt'
          severityThreshold: 'Low'
        }
        {
          #disable-next-line BCP037
          name: 'sexual'
          blocking: true
          enabled: true
          source: 'Prompt'
          severityThreshold: 'Low'
        }
        {
          #disable-next-line BCP037
          name: 'selfharm'
          blocking: true
          enabled: true
          source: 'Prompt'
          severityThreshold: 'Low'
        }
        {
          #disable-next-line BCP037
          name: 'violence'
          blocking: true
          enabled: true
          source: 'Prompt'
          severityThreshold: 'Low'
        }
        {
          #disable-next-line BCP037
          name: 'jailbreak'
          blocking: true
          enabled: true
          source: 'Prompt'
          severityThreshold: 'Low'
        }
        {
          #disable-next-line BCP037
          name: 'profanity'
          blocking: true
          enabled: true
          source: 'Prompt'
          severityThreshold: 'Low'
        }
        /* COMPLETION FILTERS */
        {
          #disable-next-line BCP037
          name: 'hate'
          blocking: true
          enabled: true
          source: 'Completion'
          severityThreshold: 'Low'
        }
        {
          #disable-next-line BCP037
          name: 'sexual'
          blocking: true
          enabled: true
          source: 'Completion'
          severityThreshold: 'Low'
        }
        {
          #disable-next-line BCP037
          name: 'selfharm'
          blocking: true
          enabled: true
          source: 'Completion'
          severityThreshold: 'Low'
        }
        {
          #disable-next-line BCP037
          name: 'violence'
          blocking: true
          enabled: true
          source: 'Completion'
          severityThreshold: 'Low'
        }
        {
          #disable-next-line BCP037
          name: 'profanity'
          blocking: true
          enabled: true
          source: 'Completion'
          severityThreshold: 'Low'
        }
      ]
    }
  }

  @description('Add a gpt-3.5 turbo deployment.')
  resource gpt35 'deployments' = {
    name: 'gpt35'
    sku: {
      name: 'Standard'
      capacity: 25
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: 'gpt-35-turbo'
        version: '0125' // If your selected region doesn't support this version, please change it.
                        // az cognitiveservices model list -l YOUR_REGION --query "sort([?model.name == 'gpt-35-turbo' && kind == 'OpenAI'].model.version)" -o tsv
      }
      raiPolicyName: openAiAccount::blockingFilter.name
      versionUpgradeOption: 'OnceNewDefaultVersionAvailable' // Production readiness change: Always be explicit about model versions, use 'NoAutoUpgrade' to prevent version changes.
    }
  }
}

//OpenAI diagnostic settings
resource openAIDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${openAiAccount.name}-diagnosticSettings'
  scope: openAiAccount
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
    logAnalyticsDestinationType: null
  }
}

// ---- Outputs ----

output openAiResourceName string = openAiAccount.name
