param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string

param vnetCidr string = format('10.{0}.0.0/16', networkAddrB)
param subnetCidr string = format('10.{0}.0.0/24', networkAddrB)
param dnsLabelPrefix string
param instanceNum int

var nsgName = format('ds-nsg-{0}', networkAddrB)
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
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

var vnetName = format('azure-network-{0}', networkAddrB)
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }
  }
}

var defaultSubnetName = 'default'
resource defaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: defaultSubnetName
  parent: virtualNetwork
  properties: {
    addressPrefix: subnetCidr
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

var pipName = format('ds-pip-{0}', networkAddrB)
resource publicIPAddresses 'Microsoft.Network/publicIPAddresses@2019-11-01' = [for idx in range(0, instanceNum): {
  name: format('{0}-{1}', pipName, idx)
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}-{2}', dnsLabelPrefix, vmName, idx)
    }
  }
}]

var nicName = format('nicds{0}', networkAddrB)
resource networkInterfaces 'Microsoft.Network/networkInterfaces@2020-11-01' = [for idx in range(0, instanceNum): {
  name: format('{0}-{1}', nicName, idx)
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-dsvm{0}-{1}', networkAddrB, idx)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: defaultSubnet.id
          }
          publicIPAddress: {
            id: publicIPAddresses[idx].id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetwork
  ]
}]

var storageName = format('ws{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccounts 'Microsoft.Storage/storageAccounts@2021-02-01' = [for idx in range(0, instanceNum): {
  name: format('{0}{1}', storageName, idx)
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}]

var vmName = format('ds-{0}', networkAddrB)
param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string
resource dsVM 'Microsoft.Compute/virtualMachines@2020-12-01' = [for idx in range(0, instanceNum): {
  name: format('{0}{1}', vmName, idx)
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: format('{0}{1}', vmName, idx)
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
          id: networkInterfaces[idx].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccounts[idx].id).primaryEndpoints.blob
      }
    }
  }
}]

/*
resource extensionBase 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', windowsVM.name)
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
*/
