param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string

var vnetCidrAzureHub = format('10.{0}.0.0/16', networkAddrB)
var subnetFirewall = format('10.{0}.0', networkAddrB)
var subnetCidrFirewall = format('{0}.0/24', subnetFirewall)
var subnetCidrGateway = format('10.{0}.1.0/24', networkAddrB)
var subnetCidrBastion = format('10.{0}.2.0/24', networkAddrB)

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
}

var subnetBastionName = 'AzureBastionSubnet'
resource subnetBastion 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: virtualNetworkAzureHub
  name: subnetBastionName
  properties: {
    addressPrefix: subnetCidrBastion
  }
}

var nameRouteTableSpoke = format('routetable-spoke{0}', networkAddrB)
resource routeTableSpoke 'Microsoft.Network/routeTables@2019-11-01' = {
  name: nameRouteTableSpoke
  location: location
  properties: {
    routes: [
      {
        name: format('route-{0}-nextfirewall', networkAddrB)
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

// Bastion
var pipNameBastionHost = format('pip-bastion-host{0}', networkAddrB)
resource publicIPAddressBastionHost 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipNameBastionHost
  location: location
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

param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string

// VM in spoke
var pipNameWinAzureSpoke = format('winsrv-spoke-pip-{0}', networkAddrB)
resource publicIPAddressWinAzureSpoke 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipNameWinAzureSpoke
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmNameWinAzureSpoke)
    }
  }
}

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
          publicIPAddress: {
            id: publicIPAddressWinAzureSpoke.id
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
          id: resourceId('Microsoft.Network/networkInterfaces', nicNameWinAzureSpoke)
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
  dependsOn: [
    networkInterfaceWinAzureSpoke
  ]
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

// VM in onpremise
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
          id: resourceId('Microsoft.Network/networkInterfaces', nicNameWinOnprem)
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
    networkInterfaceWinOnprem
    vmWinAzureSpoke
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
