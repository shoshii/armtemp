param location string = resourceGroup().location
param ipRange string
param vnetIpRange string = format('10.{0}.0.0/16', ipRange)
param subnetIpRange string = format('10.{0}.0.0/24', ipRange)
param dnsLabelPrefix string = 'shogohoshiidnsprefix'


param pipName string = format('dsvm-pip-{0}', ipRange)
resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmName)
    }
  }
}

param nsgName string = 'dsvm-nsg'
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

param vnetName string = format('azure-network-{0}', ipRange)
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetIpRange
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: subnetIpRange
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', nsgName)
          }
        }
      }
    ]
  }
  dependsOn: [
    networkSecurityGroup
  ]
}

param nicName string = format('nicDsvm{0}', ipRange)
resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'default')
          }
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', pipName)
          }
        }
      }
    ]
  }
  dependsOn:[
    publicIPAddress
    virtualNetwork
  ]
}

param storageName string = format('{0}{1}', uniqueString(resourceGroup().id), ipRange)
resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

param vmName string = format('dsvm-{0}', ipRange)
param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string
resource windowsVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
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
          id: resourceId('Microsoft.Network/networkInterfaces', nicName)
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(resourceId('Microsoft.Storage/storageAccounts', storageName)).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    networkInterface
    storageaccount
  ]
}
