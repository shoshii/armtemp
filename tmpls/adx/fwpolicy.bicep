param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string

var vnetCidrAzureHub = format('10.{0}.0.0/16', networkAddrB)
var subnetFirewall = format('10.{0}.0', networkAddrB)
var subnetCidrAzureSpoke = format('10.{0}.0.0/24', int(networkAddrB) + 1)

var subnetCidrOnprem = format('172.{0}.0.0/24', networkAddrB)

param clientIp string

// adx params ------------------------------------------------------------------------------------------------

@description('CIDR range for the public subnet..')
param subnetCidrAdx string = format('10.{0}.0.0/20', int(networkAddrB) + 2)


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
          description: 'allow Https from client'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '80'
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
resource routeTableAdx 'Microsoft.Network/routeTables@2019-11-01' = {
  name: format('routetable-adx{0}-subnet', networkAddrB)
  location: location
  properties: {
    routes: [
      {
        name: format('route-{0}-adx-to-internet', networkAddrB)
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: format('{0}.4', subnetFirewall)
        }
      }
    ]
    disableBgpRoutePropagation: true
  }
}

// other resources ---------------------------------------------------------------------
// Azure Firewall
var ipgroupNameAzureSpoke = format('ipgroup-spoke-{0}-{1}', uniqueString(resourceGroup().id), networkAddrB)
resource ipgroupAzureSpoke 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: ipgroupNameAzureSpoke
  location: location
  properties: {
    ipAddresses: [
      subnetCidrAzureSpoke
    ]
  }
}
var ipgroupNameAzureHub = format('ipgroup-hub-{0}-{1}', uniqueString(resourceGroup().id), networkAddrB)
resource ipgroupAzureHub 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: ipgroupNameAzureHub
  location: location
  properties: {
    ipAddresses: [
      vnetCidrAzureHub
    ]
  }
}

var ipgroupNameOnprem = format('ipgroup-onprem-{0}-{1}', uniqueString(resourceGroup().id), networkAddrB)
resource ipgroupOnprem 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: ipgroupNameOnprem
  location: location
  properties: {
    ipAddresses: [
      subnetCidrOnprem
    ]
  }
}

var ipgroupNameAdx = format('ipgroup-adx-pub-{0}-{1}', uniqueString(resourceGroup().id), networkAddrB)
resource ipgroupAdx 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: ipgroupNameAdx
  location: location
  properties: {
    ipAddresses: [
      subnetCidrAdx
    ]
  }
}

var nameFirewall = format('hubfirewall{0}', networkAddrB)
var nameFirewallPolicy = format('{0}-policy', nameFirewall)
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2021-05-01' = {
  name: nameFirewallPolicy
  location: location
  properties: {
    threatIntelMode: 'Alert'
    dnsSettings: {
      enableProxy: true
      servers: [
        format('{0}.4', subnetFirewall)
      ]
    }
  }
}

var nwRuleCollectionGroupName = format('{0}/DefaultNetworkRuleCollectionGroup', nameFirewallPolicy)
resource nwRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-05-01' = {
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
        name: 'azure-global-services-nrc'
        priority: 210
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'time-windows'
            ipProtocols: [
              'UDP'
            ]
            destinationAddresses: [
              '13.86.101.172'
            ]
            sourceIpGroups: [
              ipgroupAzureSpoke.id
            ]
            destinationPorts: [
              '123'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'http-onprem-to-spoke'
            ipProtocols: [
              'TCP'
            ]
            destinationAddresses: [
              subnetCidrAzureSpoke
            ]
            sourceIpGroups: [
              ipgroupOnprem.id
            ]
            destinationPorts: [
              '80'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'icmp-onprem-to-spoke'
            ipProtocols: [
              'ICMP'
            ]
            destinationAddresses: [
              vnetCidrAzureHub
              subnetCidrAzureSpoke
              subnetCidrOnprem
            ]
            sourceIpGroups: [
              ipgroupOnprem.id
              ipgroupAzureHub.id
              ipgroupAzureSpoke.id
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
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
        ]
      }
    ]
  }
}

param aadLogin1Fqdn string
param aadLogin2Fqdn string
param aadGraph1Fqdn string
param aadGraph2Fqdn string
param aadGraphPpeFqdn string
param caMsOcspFqdn string
param monitorProdWarmpathFqdn string
param monitorGcsProdFqdn string
param monitorProdDiagnosticsFqdn string
param monitorShoeboxFqdn string
param caDigicertOcspFqdn string
param caDigicertCrlFqdn string
param caMsCrlFqdn string
param caMsFqdn string
param storageFqdn string
param keyVaultFqdn string
var appRuleCollectionGroupName = format('{0}/DefaultApplicationRuleCollectionGroup', nameFirewallPolicy)
resource appRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-05-01' = {
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
            name: 'aad-rule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              aadLogin1Fqdn
              aadLogin2Fqdn
              aadGraph1Fqdn
              aadGraph2Fqdn
              aadGraphPpeFqdn 
            ]
            terminateTLS: false
            sourceIpGroups: [
              ipgroupAdx.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'monitor-rule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              monitorProdWarmpathFqdn
              monitorGcsProdFqdn
              monitorProdDiagnosticsFqdn
              monitorShoeboxFqdn
            ]
            terminateTLS: false
            sourceIpGroups: [
              ipgroupAdx.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'certificate-authority-rule'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            targetFqdns: [
              caMsOcspFqdn
              caDigicertCrlFqdn
              caMsCrlFqdn
              caMsFqdn
              caDigicertOcspFqdn
            ]
            terminateTLS: false
            sourceIpGroups: [
              ipgroupAdx.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'storage-rule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              storageFqdn
            ]
            terminateTLS: false
            sourceIpGroups: [
              ipgroupAdx.id
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'keyvault-rule'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              keyVaultFqdn
            ]
            terminateTLS: false
            sourceIpGroups: [
              ipgroupAdx.id
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        name: 'global-rule-url-arc'
        priority: 320
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'winupdate-rule-01'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            fqdnTags: [
              'WindowsUpdate'
            ]
            terminateTLS: false
            sourceIpGroups: [
              ipgroupAzureSpoke.id
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        name: 'Global-rules-arc'
        priority: 330
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'global-rule-01'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              'www.microsoft.com'
            ]
            terminateTLS: false
            sourceIpGroups: [
              ipgroupAzureSpoke.id
            ]
          }
        ]
      }
    ]
  }
}
