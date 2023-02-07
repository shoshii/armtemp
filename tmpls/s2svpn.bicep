
param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string

var azureNwCidr = format('10.{0}.0.0/16', networkAddrB)
var azureNwGwCidr = format('10.{0}.0.0/24', networkAddrB)
var azureNwSubnet2Cidr = format('10.{0}.1.0/24', networkAddrB)
var onpremNwCidr = format('172.{0}.0.0/16', networkAddrB)
var onpremNwGwCidr = format('172.{0}.0.0/24', networkAddrB)
var onpremNwSubnet2Cidr = format('172.{0}.1.0/24', networkAddrB)

// Azure Network
var azureNwName = format('azure-network-{0}', networkAddrB)
resource azureVirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: azureNwName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        azureNwCidr
      ]
    }
  }
}

var gwSubnetName = 'GatewaySubnet'
resource gwSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: azureVirtualNetwork
  name: gwSubnetName
  properties: {
    addressPrefix: azureNwGwCidr
  }
}

var azureSubnetName = 'Subnet-2'
resource azureSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: azureVirtualNetwork
  name: azureSubnetName
  properties: {
    addressPrefix: azureNwSubnet2Cidr
    networkSecurityGroup: {
      id: networkSecurityGroup.id
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
    azureVirtualNetwork
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

// onpremise Network
var onpremNwName = format('onprem-network-{0}', networkAddrB)
resource onpremVirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: onpremNwName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        onpremNwCidr
      ]
    }
  }
}

var onpremGwSubnetName = 'GatewaySubnet'
resource onpremGwSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: onpremVirtualNetwork
  name: onpremGwSubnetName
  properties: {
    addressPrefix: onpremNwGwCidr
  }
}

var onpremSubnetName = 'Subnet-2'
resource onpremSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: onpremVirtualNetwork
  name: onpremSubnetName
  properties: {
    addressPrefix: onpremNwSubnet2Cidr
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

var onpremNetworkGatewayName = format('onprem-network-gateway-{0}', networkAddrB)
resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2019-11-01' = {
  name: onpremNetworkGatewayName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        onpremNwCidr
      ]
    }
    gatewayIpAddress: vmPublicIPAddressWinOnprem.properties.ipAddress
  }
}

// DSVM in Azure network
param dnsLabelPrefix string
var vmPipName = format('dsvm-pip-{0}', networkAddrB)
resource vmPublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: vmPipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmName)
    }
  }
}

var nsgName = format('azurenw-vm-nsg-{0}', networkAddrB)
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

var nicName = format('nicDsvm{0}', networkAddrB)
resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfignic{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: azureSubnet.id
          }
          publicIPAddress: {
            id: vmPublicIPAddress.id
          }
        }
      }
    ]
  }
  dependsOn:[
    azureVirtualNetwork
  ]
}

var storageName = format('ds{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmName = format('dsvm-azurenetwork-{0}', networkAddrB)
param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string
resource dsVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'dsvm'
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
          storageAccountType: 'Standard_LRS'
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
          id: networkInterface.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccount.id).primaryEndpoints.blob
      }
    }
  }
}

// WindowsServer VM in Azure network
var winVmPipName = format('winvm-pip-{0}', networkAddrB)
resource vmPublicIPAddressWin 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: winVmPipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmNameWin)
    }
  }
}

var winVmNicName = format('nicWinVm{0}', networkAddrB)
resource networkInterfaceWinVm 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: winVmNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfignicwinvm{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: azureSubnet.id
          }
          publicIPAddress: {
            id: vmPublicIPAddressWin.id
          }
        }
      }
    ]
  }
  dependsOn:[
    azureVirtualNetwork
  ]
}

var storageNameWinVm = format('w{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountWinVm 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinVm
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWin = format('winvm-azurenetwork-{0}', networkAddrB)
resource windowsVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameWin
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'winvm'
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
          id: networkInterfaceWinVm.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountWinVm.id).primaryEndpoints.blob
      }
    }
  }
}

resource extensionWinAzure 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionWinAzure', windowsVM.name)
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


// Ubuntu VM
var pipNameUbuntu = format('ubuntuvm-azurenetwork-pip-{0}', networkAddrB)
resource publicIPAddressUbuntu 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipNameUbuntu
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmNameUbuntu)
    }
  }
}



var nicNameUbuntu = format('nicubuntuvm{0}', networkAddrB)
resource networkInterfaceUbuntu 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameUbuntu
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfigubuntu{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: azureSubnet.id
          }
          publicIPAddress: {
            id: publicIPAddressUbuntu.id
          }
        }
      }
    ]
  }
  dependsOn:[
    azureVirtualNetwork
  ]
}

var vmNameUbuntu = format('ubuntuvm-azurenetwork-{0}', networkAddrB)
param vmSizeUbuntu string = 'Standard_D2s_v3'
param adminPublicKey string
resource ubuntuVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameUbuntu
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSizeUbuntu
    }
    osProfile: {
      computerName: vmNameUbuntu
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
          id: networkInterfaceUbuntu.id
        }
      ]
    }
  }
}

resource extensionBase 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', ubuntuVM.name)
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

// WindowsServer VM in Onpremise network
var winVmPipNameOnprem = format('winvm-onprem-pip-{0}', networkAddrB)
resource vmPublicIPAddressWinOnprem 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: winVmPipNameOnprem
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmNameWinOnprem)
    }
  }
}

var winVmNicNameOnprem = format('nicWinVmOnprem{0}', networkAddrB)
resource networkInterfaceWinVmOnprem 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: winVmNicNameOnprem
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfignicwinvmonprem{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: onpremSubnet.id
          }
          publicIPAddress: {
            id: vmPublicIPAddressWinOnprem.id
          }
        }
      }
    ]
  }
  dependsOn:[
    onpremVirtualNetwork
  ]
}

var storageNameWinVmOnprem = format('wvo{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountWinVmOnprem 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinVmOnprem
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWinOnprem = format('winvm-onprem-{0}', networkAddrB)
resource windowsVMOnprem 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameWinOnprem
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'winvmonprem'
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
          id: networkInterfaceWinVmOnprem.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountWinVmOnprem.id).primaryEndpoints.blob
      }
    }
  }
}

resource extensionWinOnprem 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionWinOnprem', windowsVMOnprem.name)
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
