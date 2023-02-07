param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string

param vnetCidrAzureHub string = format('10.{0}.0.0/16', networkAddrB)
param subnetCidrAzureHubCentral string = format('10.{0}.0.0/24', networkAddrB)
param subnetCidrAzureHubA string = format('10.{0}.1.0/24', networkAddrB)
param subnetCidrAzureHubB string = format('10.{0}.2.0/24', networkAddrB)
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

var subnetNameAzureHubCentral = 'default-azurehub-central'
resource subnetAzureHubCentral 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: subnetNameAzureHubCentral
  parent: virtualNetworkAzureHub
  properties: {
    addressPrefix: subnetCidrAzureHubCentral
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
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

// central VM
var pipNameWinAzureHubCentral = format('winsrv-hub-central-pip-{0}', networkAddrB)
resource publicIPAddressWinAzureHubCentral 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipNameWinAzureHubCentral
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmNameWinAzureHubCentral)
    }
  }
}

var nicNameWinAzureHubCentral = format('nicwinazurehubcentral{0}', networkAddrB)
resource networkInterfaceWinAzureHubCentral 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameWinAzureHubCentral
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-win-azurehub-central{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetAzureHubCentral.id
          }
          publicIPAddress: {
            id: publicIPAddressWinAzureHubCentral.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetworkAzureHub
  ]
}

var storageNameWinAzureHubCentral = format('wahc{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountWinAzureHubCentral 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinAzureHubCentral
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWinAzureHubCentral = format('winahubcent{0}', networkAddrB)
param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string
resource vmWinAzureHubCentral 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameWinAzureHubCentral
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameWinAzureHubCentral
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
          id: resourceId('Microsoft.Network/networkInterfaces', nicNameWinAzureHubCentral)
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountWinAzureHubCentral.id).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    networkInterfaceWinAzureHubCentral
  ]
}

resource extensionBase 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmWinAzureHubCentral.name)
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

var storageNameWinAzureHubB = format('winahubb{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccountWinAzureHubB 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinAzureHubB
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWinAzureHubB = format('wahb{0}', networkAddrB)
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
