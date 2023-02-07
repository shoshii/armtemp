param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string

var vnetCidrAzureHub = format('10.{0}.0.0/16', networkAddrB)
var subnetFirewall = format('10.{0}.0', networkAddrB)
var subnetCidrFirewall = format('{0}.0/24', subnetFirewall)
var subnetCidrGateway = format('10.{0}.1.0/24', networkAddrB)
var subnetCidrBastion = format('10.{0}.2.0/24', networkAddrB)
var subnetCidrDefault = format('10.{0}.3.0/24', networkAddrB)

var vnetCidrAzureSpoke = format('10.{0}.0.0/16', int(networkAddrB) + 1)
var subnetCidrAzureSpoke = format('10.{0}.0.0/24', int(networkAddrB) + 1)

var vnetCidrOnprem = format('172.{0}.0.0/16', networkAddrB)
var subnetCidrOnprem = format('172.{0}.0.0/24', networkAddrB)

param dnsLabelPrefix string

var nsgName = format('common-nsg-{0}', networkAddrB)
param clientIp string
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
resource subnetAzureHubFirewall 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: subnetNameFirewall
  parent: virtualNetworkAzureHub
  properties: {
    addressPrefix: subnetCidrFirewall
  }
}

var subnetGwName = 'GatewaySubnet'
resource gwSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: virtualNetworkAzureHub
  name: subnetGwName
  properties: {
    addressPrefix: subnetCidrGateway
  }
  dependsOn: [
    subnetAzureHubFirewall
  ]
}

var subnetBastionName = 'AzureBastionSubnet'
resource subnetBastion 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: virtualNetworkAzureHub
  name: subnetBastionName
  properties: {
    addressPrefix: subnetCidrBastion
  }
  dependsOn: [
    gwSubnet
  ]
}

var subnetNameDefault = format('azure-hub-default{0}', networkAddrB)
resource subnetAzureHubDefault 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: virtualNetworkAzureHub
  name: subnetNameDefault
  properties: {
    addressPrefix: subnetCidrDefault
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
  dependsOn: [
    subnetBastion
  ]
}

// route tables are assumed to be attached on subnets manually
// to be attached on GatewaySubnet
var nameRouteTableOnprem = format('routetable-onprem-to-spoke{0}', networkAddrB)
resource routeTableOnprem 'Microsoft.Network/routeTables@2019-11-01' = {
  name: nameRouteTableOnprem
  location: location
  properties: {
    routes: [
      {
        name: format('route-{0}-onprem-to-spoke', networkAddrB)
        properties: {
          addressPrefix: vnetCidrAzureSpoke
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: format('{0}.4', subnetFirewall)
        }
      }
    ]
    disableBgpRoutePropagation: true
  }
}

// to be attached on SpokeSubnet
var nameRouteTableSpoke = format('routetable-spoke-to-onprem{0}', networkAddrB)
resource routeTableSpoke 'Microsoft.Network/routeTables@2019-11-01' = {
  name: nameRouteTableSpoke
  location: location
  properties: {
    routes: [
      {
        name: format('route-{0}-spoke-to-onpremvm', networkAddrB)
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

var vnetNameOnprem = format('onprem-net-{0}', networkAddrB)
resource virtualNetworkOnprem 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: vnetNameOnprem
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidrOnprem
      ]
    }
  }
}

var subnetNameOnprem = 'default-onprem'
resource subnetOnprem 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: subnetNameOnprem
  parent: virtualNetworkOnprem
  properties: {
    addressPrefix: subnetCidrOnprem
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

var vnetNameAzureSpoke = format('azure-spokenet-{0}', networkAddrB)
resource virtualNetworkAzureSpoke 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: vnetNameAzureSpoke
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidrAzureSpoke
      ]
    }
  }
}

var subnetNameAzureSpoke = 'default-azurespoke'
resource subnetAzureSpoke 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: subnetNameAzureSpoke
  parent: virtualNetworkAzureSpoke
  properties: {
    addressPrefix: subnetCidrAzureSpoke
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    serviceEndpoints: [
      {
        service: 'Microsoft.AzureCosmosDB'
      }
    ]
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// VPN Gataway
var gwPipName = format('gateway-ip-{0}', networkAddrB) 
resource gwPublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: gwPipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('shogohoshiis2svpn{0}', networkAddrB)
    }
  }
}

var azureNetworkGatewayName = format('azure-network-gateway-{0}', networkAddrB)
resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: azureNetworkGatewayName
  location: location
  dependsOn: [
    virtualNetworkAzureHub
  ]
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfigvngw{0}', networkAddrB)
        properties: {
          subnet: {
            id: gwSubnet.id
          }
          publicIPAddress: {
            id: gwPublicIPAddress.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    sku: {
      name: 'VpnGw2'
      tier: 'VpnGw2'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
  }
}

// local network gateway
var onpremNetworkGatewayName = format('onprem-network-gateway-{0}', networkAddrB)
resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2019-11-01' = {
  name: onpremNetworkGatewayName
  location: location
  dependsOn: [
    firewall
  ]
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        subnetCidrOnprem
      ]
    }
    gatewayIpAddress: publicIPAddressWinOnprem.properties.ipAddress
  }
}

@description('shared key used for local network gateway and onpremise router')
@secure()
param sharedKeyForVPN string
resource vpnVnetConnection 'Microsoft.Network/connections@2020-11-01' = {
  name: format('connection-vpn-local-gateway{0}', networkAddrB)
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: virtualNetworkGateway.id
      properties:{}
    }
    localNetworkGateway2: {
      id: localNetworkGateway.id
      properties:{}
    }
    connectionType: 'IPsec'
    routingWeight: 10
    sharedKey: sharedKeyForVPN
  }
}

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

var pipNameHubFirewall = format('hub-firewall-pip-{0}', networkAddrB)
resource publicIPAddressHubFirewalls 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for idx in range(0, 3): {
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
//var firewallIpConfigurations = firewallIpConfigurationPrimal
var nameFirewall = format('hubfirewall{0}', networkAddrB)
var nameFirewallPolicy = format('{0}-policy', nameFirewall)
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2021-05-01' = {
  name: nameFirewallPolicy
  dependsOn: [
    virtualNetworkGateway
  ]
  location: location
  properties: {
    threatIntelMode: 'Alert'
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
        priority: 1250
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
    ]
  }
}

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
        name: 'global-rule-url-arc'
        priority: 1000
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
        priority: 1202
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

resource firewall 'Microsoft.Network/azureFirewalls@2021-05-01' = {
  name: nameFirewall
  location: location
  dependsOn: [
    virtualNetworkAzureHub
    ipgroupAzureSpoke
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

// Bastion
var pipNameBastionHost = format('pip-bastion-host{0}', networkAddrB)
resource publicIPAddressBastionHost 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipNameBastionHost
  location: location
  dependsOn: [
    firewall
  ]
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

var bastionHostName = format('bastionhost-{0}', networkAddrB)
resource bastionHost 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: bastionHostName
  location: location
  dependsOn: [
    virtualNetworkAzureHub
  ]
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfbastion{0}', networkAddrB)
        properties: {
          subnet: {
            id: subnetBastion.id
          }
          publicIPAddress: {
            id: publicIPAddressBastionHost.id
          }
        }
      }
    ]
  }
}

// vnet peering between hub and spoke
resource peeringSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: format('{0}/peering_{1}_{2}', virtualNetworkAzureHub.name, virtualNetworkAzureHub.name, virtualNetworkAzureSpoke.name)
  dependsOn: [
    bastionHost
  ]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: virtualNetworkAzureSpoke.id
    }
  }
}
resource peeringHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-07-01' = {
  name: format('{0}/peering_{1}_{2}', virtualNetworkAzureSpoke.name, virtualNetworkAzureSpoke.name, virtualNetworkAzureHub.name)
  dependsOn: [
    bastionHost
  ]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: virtualNetworkAzureHub.id
    }
  }
}

param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string

// VMs in spoke network ===================================================================
// Windows Server VM in spoke
var nicNameWinAzureSpoke = format('nicwinazurespoke{0}', networkAddrB)
resource networkInterfaceWinAzureSpoke 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameWinAzureSpoke
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-win-azurespoke{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetAzureSpoke.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkAzureSpoke
  ]
}

var storageNameWinAzureSpoke = format('was{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountWinAzureSpoke 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinAzureSpoke
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWinAzureSpoke = format('winazspoke{0}', networkAddrB)
resource vmWinAzureSpoke 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameWinAzureSpoke
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameWinAzureSpoke
      adminUsername: adminUserName
      adminPassword: adminUserPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-gensecond'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceWinAzureSpoke.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountWinAzureSpoke.id).primaryEndpoints.blob
      }
    }
  }
}

resource extensionBaseA 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmWinAzureSpoke.name)
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/shoshii/armtemp/master/tmpls/bin/script_win.ps1'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File script_win.ps1'
    }
  }
}

// Data Science VM in spoke
var nicNameDsAzureSpoke = format('nicdsvmazurespoke{0}', networkAddrB)
resource networkInterfaceDsAzureSpoke 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameDsAzureSpoke
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-dsvm-azurespoke{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetAzureSpoke.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkAzureSpoke
    vmWinAzureSpoke
  ]
}

var storageNameDsAzureSpoke = format('das{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountDsAzureSpoke 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameDsAzureSpoke
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameDsAzureSpoke = format('dsazspoke{0}', networkAddrB)
resource vmDsAzureSpoke 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameDsAzureSpoke
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameDsAzureSpoke
      adminUsername: adminUserName
      adminPassword: adminUserPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoft-dsvm'
        offer: 'dsvm-win-2019'
        sku: 'winserver-2019'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceDsAzureSpoke.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountDsAzureSpoke.id).primaryEndpoints.blob
      }
    }
  }
}

resource extensionBaseDsAzureSpoke 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmDsAzureSpoke.name)
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/shoshii/armtemp/master/tmpls/bin/script_dsvm.ps1'
      ]
      commandToExecute: format('powershell.exe -ExecutionPolicy Unrestricted -File script_dsvm.ps1 {0}', adminUserName)
    }
  }
}

// Ubuntu VM in spoke
var nicNameUbuntuAzureSpoke = format('nicubuntuazurespoke{0}', networkAddrB)
resource networkInterfaceUbuntuAzureSpoke 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameUbuntuAzureSpoke
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-ubuntu-azurespoke{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetAzureSpoke.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkAzureSpoke
    vmDsAzureSpoke
  ]
}

param adminPublicKey string
var vmNameUbuntuAzureSpoke = format('ubuazspoke{0}', networkAddrB)
resource vmUbuntuAzureSpoke 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameUbuntuAzureSpoke
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameUbuntuAzureSpoke
      adminUsername: adminUserName
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: format('/home/{0}/.ssh/authorized_keys', adminUserName)
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceUbuntuAzureSpoke.id
        }
      ]
    }
  }
}

resource extensionBaseUbuntuAzureSpoke 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmUbuntuAzureSpoke.name)
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/shoshii/armtemp/master/tmpls/bin/deploy_ubuntu.sh'
      ]
      commandToExecute: 'sh deploy_ubuntu.sh'
    }
  }
}

// VMs in hub network ===================================================================
// VM in hub
var nicNameWinAzureHub = format('nicwinazurehub{0}', networkAddrB)
resource networkInterfaceWinAzureHub 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameWinAzureHub
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-win-azurehub{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetAzureHubDefault.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkAzureHub
    firewall
    networkInterfaceWinAzureSpoke
  ]
}

var storageNameWinAzureHub = format('wah{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountWinAzureHub 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinAzureHub
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWinAzureHub = format('winazhub{0}', networkAddrB)
resource vmWinAzureHub 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameWinAzureHub
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameWinAzureHub
      adminUsername: adminUserName
      adminPassword: adminUserPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-gensecond'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceWinAzureHub.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountWinAzureHub.id).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    vmWinAzureSpoke
  ]
}

resource extensionBaseAzureHub 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmWinAzureHub.name)
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/shoshii/armtemp/master/tmpls/bin/script_win.ps1'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File script_win.ps1'
    }
  }
}

// VMs in onpremise ===================================================================
// windows server VM in onpremise
var pipNameWinOnprem = format('winsrv-onprem-pip-{0}', networkAddrB)
resource publicIPAddressWinOnprem 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipNameWinOnprem
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmNameWinOnprem)
    }
  }
}

var nicNameWinOnprem = format('nicwinonprem{0}', networkAddrB)
resource networkInterfaceWinOnprem 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameWinOnprem
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-win-onprem{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetOnprem.id
          }
          publicIPAddress: {
            id: publicIPAddressWinOnprem.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkOnprem
  ]
}

var storageNameWinOnprem = format('won{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountWinOnprem 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinOnprem
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWinOnprem = format('winonprem{0}', networkAddrB)
resource vmWinOnprem 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameWinOnprem
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameWinOnprem
      adminUsername: adminUserName
      adminPassword: adminUserPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-gensecond'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceWinOnprem.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountWinOnprem.id).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    vmWinAzureHub
  ]
}

resource extensionBaseB 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmWinOnprem.name)
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/shoshii/armtemp/master/tmpls/bin/script_win.ps1'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File script_win.ps1'
    }
  }
}

// data science machine VM in onpremise
var pipNameDsOnprem = format('dsvm-onprem-pip-{0}', networkAddrB)
resource publicIPAddressDsOnprem 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipNameDsOnprem
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmNameDsOnprem)
    }
  }
}

var nicNameDsOnprem = format('nicdsvmonprem{0}', networkAddrB)
resource networkInterfaceDsOnprem 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameDsOnprem
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-dsvm-onprem{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetOnprem.id
          }
          publicIPAddress: {
            id: publicIPAddressDsOnprem.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkOnprem
    networkInterfaceWinOnprem
  ]
}

var storageNameDsOnprem = format('don{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountDsOnprem 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameDsOnprem
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameDsOnprem = format('dsonprem{0}', networkAddrB)
resource vmDsOnprem 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameDsOnprem
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameDsOnprem
      adminUsername: adminUserName
      adminPassword: adminUserPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoft-dsvm'
        offer: 'dsvm-win-2019'
        sku: 'winserver-2019'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceDsOnprem.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountDsOnprem.id).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    vmWinOnprem
  ]
}

resource extensionBaseDsOnprem 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmDsOnprem.name)
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/shoshii/armtemp/master/tmpls/bin/script_dsvm.ps1'
      ]
      commandToExecute: format('powershell.exe -ExecutionPolicy Unrestricted -File script_dsvm.ps1 {0}', adminUserName)
    }
  }
}

// Ubuntu VM in onpremise
var nicNameUbuntuOnprem = format('nicubuntuonprem{0}', networkAddrB)
resource networkInterfaceUbuntuOnprem 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameUbuntuOnprem
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-ubuntu-onprem{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetOnprem.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkOnprem
    vmDsOnprem
  ]
}

var vmNameUbuntuOnprem = format('ubuonprem{0}', networkAddrB)
resource vmUbuntuOnprem 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameUbuntuOnprem
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameUbuntuOnprem
      adminUsername: adminUserName
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: format('/home/{0}/.ssh/authorized_keys', adminUserName)
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceUbuntuOnprem.id
        }
      ]
    }
  }
}

resource extensionBaseUbuntuOnprem 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmUbuntuOnprem.name)
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/shoshii/armtemp/master/tmpls/bin/deploy_ubuntu.sh'
      ]
      commandToExecute: 'sh deploy_ubuntu.sh'
    }
  }
}


// cosmos
var accountName = format('sql{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
var primaryRegion = location
param secondaryRegion string = 'westus'

@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'

@maxValue(2147483647)
@minValue(10)
@description('Max stale requests. Required for BoundedStaleness. Valid ranges, Single Region: 10 to 1000000. Multi Region: 100000 to 1000000.')
param maxStalenessPrefix int = 100000

@maxValue(86400)
@minValue(5)
@description('Max lag time (minutes). Required for BoundedStaleness. Valid ranges, Single Region: 5 to 84600. Multi Region: 300 to 86400.')
param maxIntervalInSeconds int = 300

@allowed([
  true
  false
])
@description('Enable automatic failover for regions')
param automaticFailover bool = true

@description('The name for the database')
param databaseName string = 'myDatabase'

@description('The name for the container')
param containerName string = 'myContainer'

@maxValue(1000000)
@minValue(400)
@description('The throughput for the container')
param throughput int = 4000

var consistencyPolicy = {
  Eventual: {
    defaultConsistencyLevel: 'Eventual'
  }
  ConsistentPrefix: {
    defaultConsistencyLevel: 'ConsistentPrefix'
  }
  Session: {
    defaultConsistencyLevel: 'Session'
  }
  BoundedStaleness: {
    defaultConsistencyLevel: 'BoundedStaleness'
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
  }
  Strong: {
    defaultConsistencyLevel: 'Strong'
  }
}

var locations = [
  {
    locationName: primaryRegion
    failoverPriority: 0
    isZoneRedundant: false
  }
  {
    locationName: secondaryRegion
    failoverPriority: 1
    isZoneRedundant: false
  }
]

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: toLower(accountName)
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
    locations: locations
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: automaticFailover
    isVirtualNetworkFilterEnabled: true
    virtualNetworkRules: [
      {
        id: subnetAzureSpoke.id
      }
    ]
  }
}
resource sqlDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  name: '${cosmosDbAccount.name}/${databaseName}'
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource sqlContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  name: '${sqlDb.name}/${containerName}'
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/name'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
      }
    }
    options: {
      throughput: throughput
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: format('prvendpoint-cosmos{0}', networkAddrB)
  location: location
  dependsOn: [
    firewall
  ]
  properties: {
    subnet: {
      id: subnetAzureSpoke.id
    }
    privateLinkServiceConnections: [
      {
        name: format('connection-to-cosmos-sql', networkAddrB)
        properties: {
          privateLinkServiceId: cosmosDbAccount.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }
}
