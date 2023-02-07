param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string

var vnetCidrAzureHub = format('10.{0}.0.0/16', networkAddrB)
var subnetFirewall = format('10.{0}.0', networkAddrB)
var subnetCidrFirewall = format('{0}.0/24', subnetFirewall)
var subnetA = format('10.{0}.1', networkAddrB)
var subnetB = format('10.{0}.2', networkAddrB)
var subnetCidrAzureHubA = format('{0}.0/24', subnetA)
var subnetCidrAzureHubB = format('{0}.0/24', subnetB)
param dnsLabelPrefix string

var nsgName = format('winsrv-nsg-{0}', networkAddrB)
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

var nameRouteTable = format('routetable-{0}', networkAddrB)
resource routeTable 'Microsoft.Network/routeTables@2019-11-01' = {
  name: nameRouteTable
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

var subnetNameAzureHubA = 'default-azurehub-a'
resource subnetAzureHubA 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: subnetNameAzureHubA
  parent: virtualNetworkAzureHub
  properties: {
    addressPrefix: subnetCidrAzureHubA
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

var subnetNameAzureHubB = 'default-azurehub-b'
resource subnetAzureHubB 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: subnetNameAzureHubB
  parent: virtualNetworkAzureHub
  properties: {
    addressPrefix: subnetCidrAzureHubB
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

// Azure Firewall
var ipgroupNameWorkload = format('ipgroup-workload-{0}-{1}', uniqueString(resourceGroup().id), networkAddrB)
resource ipgroupWorkload 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: ipgroupNameWorkload
  location: location
  properties: {
    ipAddresses: [
      subnetCidrAzureHubA
    ]
  }
}
var ipgroupNameInfra = format('ipgroup-infra-{0}-{1}', uniqueString(resourceGroup().id), networkAddrB)
resource ipgroupInfra 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: ipgroupNameInfra
  location: location
  properties: {
    ipAddresses: [
      subnetCidrAzureHubB
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
  location: location
  properties: {
    threatIntelMode: 'Alert'
  }
}

var dnatRuleCollectionGroupName = format('{0}/DefaultDnatRuleCollectionGroup', nameFirewallPolicy)
resource dnatRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-05-01' = {
  name: dnatRuleCollectionGroupName
  dependsOn: [
    firewallPolicy
  ]
  properties: {
    priority: 400
    ruleCollections: [
      {
        name: 'CliToVMsRDP'
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        action: {
          type: 'DNAT'
        }
        rules: [
          {
            ruleType: 'NatRule'
            destinationAddresses: [
              publicIPAddressHubFirewalls[0].properties.ipAddress
            ]
            destinationPorts: [
              '4000'
            ]
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              clientIp
            ]
            //translatedAddress: networkInterfaceWinAzureHubA.properties.ipConfigurations[0].properties.privateIPAddress
            translatedAddress: format('{0}.4', subnetA)
            translatedPort: '3389'
          }
          {
            ruleType: 'NatRule'
            destinationAddresses: [
              publicIPAddressHubFirewalls[0].properties.ipAddress
            ]
            destinationPorts: [
              '4001'
            ]
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              clientIp
            ]
            //translatedAddress: networkInterfaceWinAzureHubA.properties.ipConfigurations[0].properties.privateIPAddress
            translatedAddress: format('{0}.4', subnetB)
            translatedPort: '3389'
          }
        ]
      }
    ]
  }
}

var nwRuleCollectionGroupName = format('{0}/DefaultNetworkRuleCollectionGroup', nameFirewallPolicy)
resource nwRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-05-01' = {
  name: nwRuleCollectionGroupName
  dependsOn: [
    dnatRuleCollectionGroup
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
              ipgroupInfra.id
              ipgroupWorkload.id
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
              ipgroupInfra.id
              ipgroupWorkload.id
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
              ipgroupInfra.id
              ipgroupWorkload.id
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
    ipgroupInfra
    ipgroupWorkload
    dnatRuleCollectionGroup
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

param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string

// subnet A VM
var pipNameWinAzureHubA = format('winsrv-hub-a-pip-{0}', networkAddrB)
resource publicIPAddressWinAzureHubA 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipNameWinAzureHubA
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmNameWinAzureHubA)
    }
  }
}

var nicNameWinAzureHubA = format('nicwinazurehuba{0}', networkAddrB)
resource networkInterfaceWinAzureHubA 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameWinAzureHubA
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-win-azurehub-a{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetAzureHubA.id
          }
          publicIPAddress: {
            id: publicIPAddressWinAzureHubA.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkAzureHub
  ]
}

var storageNameWinAzureHubA = format('waha{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountWinAzureHubA 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinAzureHubA
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWinAzureHubA = format('winahuba{0}', networkAddrB)
resource vmWinAzureHubA 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameWinAzureHubA
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameWinAzureHubA
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
          id: resourceId('Microsoft.Network/networkInterfaces', nicNameWinAzureHubA)
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountWinAzureHubA.id).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    networkInterfaceWinAzureHubA
  ]
}

resource extensionBaseA 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmWinAzureHubA.name)
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

// subnet B VM
var pipNameWinAzureHubB = format('winsrv-hub-b-pip-{0}', networkAddrB)
resource publicIPAddressWinAzureHubB 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipNameWinAzureHubB
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmNameWinAzureHubB)
    }
  }
}

var nicNameWinAzureHubB = format('nicwinazurehubb{0}', networkAddrB)
resource networkInterfaceWinAzureHubB 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameWinAzureHubB
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-win-azurehub-b{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetAzureHubB.id
          }
          publicIPAddress: {
            id: publicIPAddressWinAzureHubB.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkAzureHub
  ]
}

var storageNameWinAzureHubB = format('wahb{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountWinAzureHubB 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinAzureHubB
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWinAzureHubB = format('winahubb{0}', networkAddrB)
resource vmWinAzureHubB 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameWinAzureHubB
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameWinAzureHubB
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
          id: resourceId('Microsoft.Network/networkInterfaces', nicNameWinAzureHubB)
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountWinAzureHubB.id).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    networkInterfaceWinAzureHubB
    vmWinAzureHubA
  ]
}

resource extensionBaseB 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmWinAzureHubB.name)
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
