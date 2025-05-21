targetScope = 'resourceGroup'

/*** EXISTING RESOURCES ***/

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: 'log-workload'
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-workload'

  resource firewallMgmtSubnet 'subnets' existing = {
    name: 'AzureFirewallManagementSubnet'
  }

  resource firewall 'subnets' existing = {
    name: 'AzureFirewallSubnet'
  }


}

/*** NEW RESOURCE ***/

// Create the public IPs used for egress traffic from this workload and FW management

resource publicIpForAzureFirewallEgress 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-firewall-egress-00'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource publicIpForAzureFirewallManagement 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-firewall-mgmt-00'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource azureFirewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: 'fwp-workload'
  location: resourceGroup().location
  properties: {
    sku: {
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
  }

  resource applicationRules 'ruleCollectionGroups' = {
    name: 'DefaultApplicationRuleCollectionGroup'
    properties: {
      priority: 300
      ruleCollections: [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'agent-egress'
          priority: 1000
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'allowallhttps'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              fqdnTags: []
              webCategories: []
              targetFqdns: ['*']
              targetUrls: []
              terminateTLS: false
              sourceAddresses: ['*']
              destinationAddresses: []
              httpHeadersToInsert: []
            }
          ]
        }
      ]
    }
  }
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: 'afwworkload'
  location: resourceGroup().location
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
    additionalProperties: {}
    managementIpConfiguration: {
      name: publicIpForAzureFirewallManagement.name
      properties: {
        publicIPAddress: {
          id: publicIpForAzureFirewallManagement.id
        }
        subnet: {
          id: virtualNetwork::firewallMgmtSubnet.id
        }
      }
    }
    ipConfigurations: [
      {
        name: publicIpForAzureFirewallEgress.name
        properties: {
          publicIPAddress: {
            id: publicIpForAzureFirewallEgress.id
          }
          subnet: {
            id: virtualNetwork::firewall.id
          }
        }
        
      }
    ]
    firewallPolicy: {
      id: azureFirewallPolicy.id
    }
  }
}

resource egressRouteTable 'Microsoft.Network/routeTables@2024-05-01' existing = {
  name: 'udr-internet-to-firewall'

  resource internetToFirewall 'routes' = {
    name: 'internet-to-firewall'
    properties: {
      addressPrefix: '0.0.0.0/0'
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
    }
  }
}

// Azure diagnostics

resource azureDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: azureFirewall
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWNetworkRule'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWApplicationRule'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWNatRule'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWThreatIntel'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWIdpsSignature'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWDnsQuery'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWFqdnResolveFailure'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWFatFlow'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWFlowTrace'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWApplicationRuleAggregation'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWNetworkRuleAggregation'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AZFWNatRuleAggregation'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}
