param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string

var vnetCidrAzureHub = format('10.{0}.0.0/16', networkAddrB)
var subnetFirewall = format('10.{0}.0', networkAddrB)
var subnetCidrFirewall = format('{0}.0/24', subnetFirewall)
var subnetCidrDefault = format('10.{0}.1.0/24', networkAddrB)

param dnsLabelPrefix string

var nsgName = format('common-nsg-{0}', networkAddrB)
param clientIp string

// adx params ------------------------------------------------------------------------------------------------

@description('CIDR range for the public subnet..')
param subnetCidrAdx string = format('10.{0}.0.0/20', int(networkAddrB) + 1)

@description('The name of the public subnet to create.')
param adxPublicSubnetName string = 'public-subnet'

@description('CIDR range for the vnet.')
param vnetCidrAdx string = format('10.{0}.0.0/16', int(networkAddrB) + 1)

@description('The name of the virtual network to create.')
param adxVnetName string = format('dataexlorer-vnet-{0}', networkAddrB)

@description('The name of the Azure Data Explorer Cluster to create.')
param clusterName string = format('vnet{0}{1}', networkAddrB, uniqueString(resourceGroup().id))

// adx -------------------------------------------------------------------------------
resource networkSecurityGroupAdx 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: format('nsg-adx{0}', networkAddrB)
  location: location
  properties: {
    securityRules: [
      {
        name: 'adx-internal-inbound'
        properties: {
          description: 'Required for worker nodes communication within a cluster.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'adx-management-inbound'
        properties: {
          description: 'allow access from Data Management to a cluster.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureDataExplorerManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'adx-monitor-inbound'
        properties: {
          description: 'allow access from Health Monitoring to a cluster.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '20.43.89.90'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 102
          direction: 'Inbound'
        }
      }
      {
        name: 'adx-loadbalancer-inbound'
        properties: {
          description: 'allow access from Load Balancer to a cluster.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '80'
          ]
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 103
          direction: 'Inbound'
        }
      }
      {
        name: 'allowHttpsfromClient'
        properties: {
          description: 'allow Https and ssh from client'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '80'
            '22'
          ]
          sourceAddressPrefix: clientIp
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
      {
        name: 'adx-storage-outbound'
        properties: {
          description: 'allow access from a cluster to Storage.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-datalake-outbound'
        properties: {
          description: 'allow access from a cluster to AzureDataLake.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureDataLake'
          access: 'Allow'
          priority: 111
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-eventhub-outbound'
        properties: {
          description: 'allow access from a cluster to EventHub.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '5671'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          priority: 112
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-AzureMonitor-outbound'
        properties: {
          description: 'allow access from a cluster to AzureMonitor.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 113
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-AzureActiveDirectory-outbound'
        properties: {
          description: 'allow access from a cluster to AzureActiveDirectory.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureActiveDirectory'
          access: 'Allow'
          priority: 114
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-AzureKeyVault-outbound'
        properties: {
          description: 'allow access from a cluster to AzureKeyVault.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          priority: 115
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-internet-outbound'
        properties: {
          description: 'allow access from a cluster to *.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '80'
            '3306'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 116
          direction: 'Outbound'
        }
      }
    ]
  }
}

// to be attached adx subnet
var routesFw = array({
  name: format('route-{0}-adx-to-internet', networkAddrB)
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: format('{0}.4', subnetFirewall)
  }
})
param monitorIps array
param managementIps array
var routesMonitors = [for (monitorIp, idx) in monitorIps: {
  name: format('route-{0}-adx-to-monitors-{1}', networkAddrB, idx)
  properties: {
    addressPrefix: monitorIp
    nextHopType: 'Internet'
  }
}]
var routesManagements = [for (managementIp, idx) in managementIps: {
  name: format('route-{0}-adx-to-managements-{1}', networkAddrB, idx)
  properties: {
    addressPrefix: managementIp
    nextHopType: 'Internet'
  }
}]
var routesCli = array({
  name: format('route-{0}-adx-to-client', networkAddrB)
  properties: {
    addressPrefix: format('{0}/32', clientIp)
    nextHopType: 'Internet'
  }
})
resource routeTableAdx 'Microsoft.Network/routeTables@2019-11-01' = {
  name: format('routetable-adx{0}-subnet', networkAddrB)
  location: location
  properties: {
    routes: concat(routesFw, routesMonitors, routesManagements, routesCli)
    disableBgpRoutePropagation: true
  }
}

resource virtualNetworkAdxSpoke 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  location: location
  name: adxVnetName
  properties: {
    dhcpOptions: {
      dnsServers: [
        format('{0}.4', subnetFirewall)
      ]
    }
    addressSpace: {
      addressPrefixes: [
        vnetCidrAdx
      ]
    }
  }
}

resource adxPublicSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-05-01' = {
  name: adxPublicSubnetName
  parent: virtualNetworkAdxSpoke
  properties: {
    addressPrefix: subnetCidrAdx
    networkSecurityGroup: {
      id: networkSecurityGroupAdx.id
    }
    delegations: [
      {
        name: format('dataexlorer-del-public{0}', networkAddrB)
        properties: {
          serviceName: 'Microsoft.Kusto/clusters'
        }
      }
    ]
  }
}

resource publicIPAddressDataManagement 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: format('pip-adx-dm{0}', networkAddrB)
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}
resource publicIPAddressEngine 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: format('pip-adx-engine{0}', networkAddrB)
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// other resources ---------------------------------------------------------------------
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allowRDPfromClient'
        properties: {
          description: 'allow RDP from client'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: clientIp
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
      {
        name: 'allowSSHfromClient'
        properties: {
          description: 'allow SSH from client'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: clientIp
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 310
          direction: 'Inbound'
        }
      }
      {
        name: 'allowHttpInbound'
        properties: {
          description: 'allow http inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 320
          direction: 'Inbound'
        }
      }
    ]
  }
}

// vnet & subnet settings
var vnetNameAzureHub = format('azure-hubnet-{0}', networkAddrB)
resource virtualNetworkAzureHub 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: vnetNameAzureHub
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidrAzureHub
      ]
    }
  }
}

var subnetNameFirewall = 'AzureFirewallSubnet'
resource subnetAzureHubFirewall 'Microsoft.Network/virtualNetworks/subnets@2020-05-01' = {
  name: subnetNameFirewall
  parent: virtualNetworkAzureHub
  properties: {
    addressPrefix: subnetCidrFirewall
  }
}

var subnetNameDefault = format('azure-hub-default{0}', networkAddrB)
resource subnetAzureHubDefault 'Microsoft.Network/virtualNetworks/subnets@2020-05-01' = {
  parent: virtualNetworkAzureHub
  name: subnetNameDefault
  properties: {
    addressPrefix: subnetCidrDefault
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
  dependsOn: [
    subnetAzureHubFirewall
  ]
}



// Azure Firewall

var nameFirewall = format('hubfirewall{0}', networkAddrB)
var nameFirewallPolicy = format('{0}-policy', nameFirewall)
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2020-05-01' = {
  name: nameFirewallPolicy
  dependsOn: [
    subnetAzureHubFirewall
  ]
  location: location
  properties: {
    threatIntelMode: 'Alert'
    dnsSettings: {
      enableProxy: true
    }
  }
}


var ipgroupNameAdx = format('ipgroup-adx-pub-{0}-{1}', uniqueString(resourceGroup().id), networkAddrB)
resource ipgroupAdx 'Microsoft.Network/ipGroups@2020-05-01' = {
  name: ipgroupNameAdx
  location: location
  properties: {
    ipAddresses: [
      subnetCidrAdx
    ]
  }
}
var nwRuleCollectionGroupName = format('{0}/DefaultNetworkRuleCollectionGroup', nameFirewallPolicy)
resource nwRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-05-01' = {
  name: nwRuleCollectionGroupName
  dependsOn: [
    firewallPolicy
  ]
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        name: 'adx-nrc'
        priority: 220
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'eventhub'
            ipProtocols: [
              'UDP'
              'TCP'
            ]
            destinationAddresses: [
              'EventHub'
            ]
            sourceIpGroups: [
              ipgroupAdx.id
            ]
            destinationPorts: [
              '443'
              '5671'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'monitor'
            ipProtocols: [
              'TCP'
            ]
            destinationAddresses: [
              'AzureMonitor'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'aad'
            ipProtocols: [
              'TCP'
            ]
            destinationAddresses: [
              'AzureActiveDirectory'
            ]
            sourceIpGroups: [
              ipgroupAdx.id
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'keyvault'
            ipProtocols: [
              'TCP'
            ]
            destinationAddresses: [
              'AzureKeyVault'
            ]
            sourceIpGroups: [
              ipgroupAdx.id
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'storage'
            ipProtocols: [
              'TCP'
            ]
            destinationAddresses: [
              'Storage'
              'AzureDataLake'
            ]
            sourceIpGroups: [
              ipgroupAdx.id
            ]
            destinationPorts: [
              '443'
            ]
          }
        ]
      }
    ]
  }
}

param certificatioAuthOutboundFqdns array

var appRuleCollectionGroupName = format('{0}/DefaultApplicationRuleCollectionGroup', nameFirewallPolicy)
resource appRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-05-01' = {
  name: appRuleCollectionGroupName
  dependsOn: [
    nwRuleCollectionGroup
  ]
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        name: 'adx-rule-arc'
        priority: 310
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'certificate-authority-rule'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            targetFqdns: certificatioAuthOutboundFqdns
            //terminateTLS: false
            sourceIpGroups: [
              ipgroupAdx.id
            ]
          }
        ]
      }
    ]
  }
}


var pipNameHubFirewall = format('hub-firewall-pip-{0}', networkAddrB)
resource publicIPAddressHubFirewalls 'Microsoft.Network/publicIPAddresses@2020-05-01' = [for idx in range(0, 3): {
  name: format('{0}-{1}', pipNameHubFirewall, idx)
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}-{2}', dnsLabelPrefix, pipNameHubFirewall, idx)
    }
  }
}]
var firewallIpConfigurationPrimal = array({
  name: format('ipconfigfirewall{0}{1}', networkAddrB, 0)
  properties: {
    subnet: {
      id: subnetAzureHubFirewall.id
    }
    publicIPAddress: {
      id: publicIPAddressHubFirewalls[0].id
    }
  }
})
var firewallIpConfigurationOthers = [for idx in range(1, 2): {
  name: format('ipconfigfirewall{0}{1}', networkAddrB, idx)
  properties: {
    subnet: null
    publicIPAddress: {
      id: publicIPAddressHubFirewalls[idx].id
    }
  }
}]
var firewallIpConfigurations = concat(firewallIpConfigurationPrimal, firewallIpConfigurationOthers)
resource firewall 'Microsoft.Network/azureFirewalls@2020-05-01' = {
  name: nameFirewall
  location: location
  dependsOn: [
    virtualNetworkAzureHub
    ipgroupAdx
    nwRuleCollectionGroup
    appRuleCollectionGroup
  ]
  properties: {
    ipConfigurations: firewallIpConfigurations
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
}

// vnet peering between hub and adx spoke
resource peeringHubToAdx 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: format('{0}/peering_{1}_{2}', virtualNetworkAzureHub.name, virtualNetworkAzureHub.name, virtualNetworkAdxSpoke.name)
  dependsOn: [
    firewall
  ]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: virtualNetworkAdxSpoke.id
    }
  }
}
resource peeringAdxToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: format('{0}/peering_{1}_{2}', virtualNetworkAdxSpoke.name, virtualNetworkAdxSpoke.name, virtualNetworkAzureHub.name)
  dependsOn: [
    peeringHubToAdx
  ]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: virtualNetworkAzureHub.id
    }
  }
}
