targetScope = 'resourceGroup'

/*** NEW RESOURCES ***/

resource egressRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'udr-internet-to-firewall'
  location: resourceGroup().location
  properties: {
    disableBgpRoutePropagation: true
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-workload'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-agents-egress'
        properties: {
          addressPrefix: '192.168.0.0/24'
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: true
          routeTable: {
            id: egressRouteTable.id  // This subnet will only have egress traffic if your agents reach outside of your virtual network, route through the firewall just in case
          }
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: '192.168.1.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: false
          routeTable: {
            id: egressRouteTable.id  // This subnet probably won't have egress traffic, but route through the firewall just in case
          }
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '192.168.2.0/26'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: []
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '192.168.2.64/26'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: []
        }
      }
    ]
    enableDdosProtection: false
  }

  resource agentSubnet 'subnets' existing = {
    name: 'agent'
  }

  resource privateEndpointSubnet 'subnets' existing = {
    name: 'private-endpoints'
  }
}

// Create and link Private DNS Zones used in this workload

resource cognitiveServicesPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.cognitiveservices.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'cognitiveservices'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource aiFoundryPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.services.ai.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'aifoundry'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource azureOpenAiPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'azureopenai'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource aiSearchPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.search.windows.net'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'aisearch'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource blobStoragePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'blobstorage'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource cosmosDbPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks' = {
    name: 'cosmosdb'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: virtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

/*** OUTPUTS ***/

output virtualNetworkAgentSubnetResourceId string = virtualNetwork::agentSubnet.id
output virtualNetworkPrivateEndpointSubnetResourceId string = virtualNetwork::privateEndpointSubnet.id
