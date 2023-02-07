
param location string = resourceGroup().location
@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string
param adxVnetCidr string = format('10.{0}.1.0/24', networkAddrB)
param adxSubnetCidr string = format('10.{0}.1.0/24', networkAddrB)

param dnsLabelPrefix string

// ADX parameters and variables
var clusterName = format('kusto{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
var dataManagementPublicIpName = format('dm-pip-{0}', networkAddrB)
var enginePublicIpName = format('engine-pip-{0}', networkAddrB)
var skuName = 'Standard_D12_v2'
var skuTier = 'Standard'
var routeTableName = format('azureDataExplorerRt{0}', networkAddrB)

resource routeTable 'Microsoft.Network/routeTables@2019-11-01' = {
  name: routeTableName
  location: location
}

resource dmPublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: dataManagementPublicIpName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: format('adxdm{0}-{1}', dnsLabelPrefix, dataManagementPublicIpName)
    }
  }
}
resource enginePublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: enginePublicIpName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: format('adxengine{0}-{1}', dnsLabelPrefix, enginePublicIpName)
    }
  }
}

resource dataExplorerCluster 'Microsoft.Kusto/Clusters@2020-09-18' = {
  name: clusterName
  sku: {
    name: skuName
    tier: skuTier
  }
  location: location
  dependsOn: [
    virtualNetwork
  ]
  properties: {
    virtualNetworkConfiguration: {
      subnetId: adxSubnet.id
      enginePublicIpId: enginePublicIPAddress.id
      dataManagementPublicIpId: dmPublicIPAddress.id
    }
  }
}

var adxNsgName = format('adx-nsg-{0}', networkAddrB)
resource adxNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: adxNsgName
  location: location
}

var adxVnetName = format('adx-network-{0}', networkAddrB)
resource adxVirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: adxVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        adxVnetCidr
      ]
    }
  }
}

var adxSubnetName = format('adxsubnet{0}', networkAddrB)
resource adxSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: adxSubnetName
  parent: adxVirtualNetwork
  properties: {
    addressPrefix: adxSubnetCidr
    networkSecurityGroup: {
      id: adxNetworkSecurityGroup.id
    }
    routeTable: {
      id: routeTable.id
    }
    delegations: [
      {
        name: format('AzureDataExplorer-del-{0}', networkAddrB)
        properties: {
          serviceName: 'Microsoft.Kusto/clusters'
        }
      }
    ]
  }
}

// DSVM
param vnetCidr string = format('10.{0}.0.0/16', int(networkAddrB) + 1)
param subnetCidr string = format('10.{0}.0.0/24', int(networkAddrB) + 1)
var pipName = format('dsvm-pip-adx-{0}', networkAddrB)
resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: pipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('pip{0}-{1}', dnsLabelPrefix, vmName)
    }
  }
}

var nsgName = format('dsvm-nsg-{0}', networkAddrB)
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

var nicName = format('nicDsvm{0}', networkAddrB)
resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfignicdsvm{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: defaultSubnet.id
          }
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
  }
  dependsOn:[
    virtualNetwork
  ]
}

var storageName = format('{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmName = format('dsvm-{0}', networkAddrB)
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
        storageUri:  reference(storageaccount.id).primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    networkInterface
  ]
}
