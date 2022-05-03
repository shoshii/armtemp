param clientIp string

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string

@description('Specifies whether to deploy Azure Databricks workspace with secure cluster connectivity (SCC) enabled or not (No Public IP)')
param disablePublicIp bool = false

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The name of the network security group to create.')
var nsgName = format('databricks-nsg-{0}', networkAddrB)

@description('The pricing tier of workspace.')
@allowed([
  'trial'
  'standard'
  'premium'
])
param pricingTier string = 'premium'

@description('CIDR range for the private subnet.')
param privateSubnetCidr string = format('10.{0}.0.0/18', networkAddrB)

@description('The name of the private subnet to create.')
param privateSubnetName string = 'private-subnet'

@description('CIDR range for the public subnet..')
param publicSubnetCidr string = format('10.{0}.64.0/18', networkAddrB)

@description('The name of the public subnet to create.')
param publicSubnetName string = 'public-subnet'

@description('CIDR range for the vnet.')
param vnetCidr string = format('10.{0}.0.0/16', networkAddrB)

@description('The name of the virtual network to create.')
var vnetName = format('databricks-vnet-{0}', networkAddrB)

@description('The name of the Azure Databricks workspace to create.')
param workspaceName string

var managedResourceGroupName = 'databricks-rg-${workspaceName}-${uniqueString(workspaceName, resourceGroup().id)}'

resource managedResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: managedResourceGroupName
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  location: location
  name: nsgName
  properties: {
    securityRules: [
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-worker-inbound'
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
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-databricks-webapp'
        properties: {
          description: 'Required for workers communication with Databricks Webapp.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureDatabricks'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-sql'
        properties: {
          description: 'Required for workers communication with Azure SQL services.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3306'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Sql'
          access: 'Allow'
          priority: 101
          direction: 'Outbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-storage'
        properties: {
          description: 'Required for workers communication with Azure Storage services.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 102
          direction: 'Outbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-worker-outbound'
        properties: {
          description: 'Required for worker nodes communication within a cluster.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 103
          direction: 'Outbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-eventhub'
        properties: {
          description: 'Required for worker communication with Azure Eventhub services.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '9093'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          priority: 104
          direction: 'Outbound'
        }
      }
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
    ]
  }
}

resource vnetDbrSpoke 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  location: location
  name: vnetName
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }
  }
}

resource dbrPublicSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: publicSubnetName
  parent: vnetDbrSpoke
  properties: {
    addressPrefix: publicSubnetCidr
    networkSecurityGroup: {
      id: nsg.id
    }
    delegations: [
      {
        name: 'databricks-del-public'
        properties: {
          serviceName: 'Microsoft.Databricks/workspaces'
        }
      }
    ]
  }
}

resource dbrPrivateSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: privateSubnetName
  parent: vnetDbrSpoke
  properties: {
    addressPrefix: privateSubnetCidr
    networkSecurityGroup: {
      id: nsg.id
    }
    delegations: [
      {
        name: 'databricks-del-private'
        properties: {
          serviceName: 'Microsoft.Databricks/workspaces'
        }
      }
    ]
  }
}

resource ws 'Microsoft.Databricks/workspaces@2018-04-01' = {
  name: workspaceName
  location: location
  sku: {
    name: pricingTier
  }
  properties: {
    managedResourceGroupId: managedResourceGroup.id
    parameters: {
      customVirtualNetworkId: {
        value: vnetDbrSpoke.id
      }
      customPublicSubnetName: {
        value: publicSubnetName
      }
      customPrivateSubnetName: {
        value: privateSubnetName
      }
      enableNoPublicIp: {
        value: disablePublicIp
      }
    }
  }
}

var storageGen2Name = format('adlsgen2fordbr{0}', networkAddrB)
resource storageGen2account 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageGen2Name
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

// VM in databricks public network
var dnsLabelPrefix = format('shogohoshiidnsprefixdbr{0}', networkAddrB)
var vmPipNamePublic = format('dsvm-dbr-pub-pip-{0}', networkAddrB)
resource vmPublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: vmPipNamePublic
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmPubName)
    }
  }
}

var nicNamePub = format('nicDsvmPub{0}', networkAddrB)
resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNamePub
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfignicpubvm{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: dbrPublicSubnet.id
          }
          publicIPAddress: {
            id: vmPublicIPAddress.id
          }
        }
      }
    ]
  }
  dependsOn:[
    vnetDbrSpoke
  ]
}

var nicNamePrivate = format('nicDsvmPrivate{0}', networkAddrB)
resource networkInterfacePrivateVM 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNamePrivate
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfignicprivatevm{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: dbrPrivateSubnet.id
          }
        }
      }
    ]
  }
  dependsOn:[
    vnetDbrSpoke
  ]
}


var storageNameVMPub = format('storagedbrvmpublic{0}', networkAddrB)
resource storageaccountVMPub 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameVMPub
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmPubName = format('dsvm-dbr-pub-{0}', networkAddrB)
param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string
resource windowsPublicVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmPubName
  location: location
  dependsOn: [
    ws
  ]
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
        storageUri:  reference(storageaccountVMPub.id).primaryEndpoints.blob
      }
    }
  }
}


var storageNameVMPrivate = format('storagedbrvmprivate{0}', networkAddrB)
resource storageaccountVMPrivate 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameVMPrivate
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmPrvName = format('dsvm-dbr-private-{0}', networkAddrB)
resource windowsPrivateVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmPrvName
  location: location
  dependsOn: [
    windowsPublicVM
  ]
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
          id: networkInterfacePrivateVM.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri:  reference(storageaccountVMPrivate.id).primaryEndpoints.blob
      }
    }
  }
}
