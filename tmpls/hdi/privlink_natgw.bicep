param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string = '192'
param clientIp string
param dnsLabelPrefix string
// hdi params ------------------------------------------------------------------------------------------------

@description('CIDR range for the public subnet..')
param subnetCidrHdi string = format('10.{0}.0.0/20', networkAddrB)

@description('The name of the public subnet to create.')
param hdiSubnetName string = 'hdi-subnet'

@description('CIDR range for the vnet.')
param vnetCidrHdi string = format('10.{0}.0.0/16', networkAddrB)

@description('The name of the virtual network to create.')
param hdiVnetName string = 'hdi-vnet'

var defaultSubnetName = 'default-subnet'
var subnetCidrDefault = format('10.{0}.16.0/20', networkAddrB)

// hdi -------------------------------------------------------------------------------
resource networkSecurityGroupHdi 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: 'nsg-hdi'
  location: location
  properties: {
    securityRules: [
      {
        name: 'hdi-management-inbound'
        properties: {
          description: 'allow access from Management to a cluster.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'HDInsight'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'hdi-management-outbound'
        properties: {
          description: 'allow access to management'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'HDInsight'
          access: 'Allow'
          priority: 101
          direction: 'Outbound'
        }
      }
      {
        name: 'azure-dns-outbound'
        properties: {
          description: 'allow access to azure dns'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '53'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '168.63.129.16'
          access: 'Allow'
          priority: 102
          direction: 'Outbound'
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
        name: 'allowRDPfromClient'
        properties: {
          description: 'allow RDP from client'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: clientIp
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 310
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
          priority: 320
          direction: 'Inbound'
        }
      }
    ]
  }
}


// need NAT or firewall solotion for outbound cluster to get public ip
// https://docs.microsoft.com/en-us/azure/hdinsight/hdinsight-private-link#NATorFirewall
resource publicIpPrefixes 'Microsoft.Network/publicIPPrefixes@2021-03-01' = {
  name: format('hdi{0}', resourceGroup().name)
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    prefixLength: 28
    publicIPAddressVersion: 'IPv4'
  }
}
resource natGateway 'Microsoft.Network/natGateways@2021-03-01' = {
  name: format('hdi{0}', resourceGroup().name)
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpPrefixes: [
      {
        id: publicIpPrefixes.id
      }
    ]
  }
}


resource virtualNetworkHdiSpoke 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  location: location
  name: hdiVnetName
  dependsOn: [
    natGateway
  ]
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidrHdi
      ]
    }
  }
}

// az network vnet subnet update --name hdi-subnet --resource-group rg519hdi3 --vnet-name hdi-vnet-40 --disable-private-link-service-network-policies true
resource hdiSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: hdiSubnetName
  parent: virtualNetworkHdiSpoke
  properties: {
    addressPrefix: subnetCidrHdi
    networkSecurityGroup: {
      id: networkSecurityGroupHdi.id
    }
    privateLinkServiceNetworkPolicies: 'Disabled'
    privateEndpointNetworkPolicies: 'Disabled'
    natGateway: {
      id: natGateway.id
    }
  }
}

resource defaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: defaultSubnetName
  parent: virtualNetworkHdiSpoke
  dependsOn: [
    hdiSubnet
  ]
  properties: {
    addressPrefix: subnetCidrDefault
    networkSecurityGroup: {
      id: networkSecurityGroupHdi.id
    }
  }
}

var storageName = format('{0}{1}stg', dnsLabelPrefix, resourceGroup().name)
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

var storageNameGen2 = format('{0}{1}gen2', dnsLabelPrefix, resourceGroup().name)
resource storageAccountGen2 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageNameGen2
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

var uMIname = format('{0}{1}uami', dnsLabelPrefix, resourceGroup().name)
resource userAssignedManagedId 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: uMIname
  location: location
}

resource assignedToStorage 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(format('{0}{1}', uniqueString(resourceGroup().id), 'uamionstorage'))
  scope: storageAccountGen2
  properties: {
    //roleDefinitionId: roleDefinitionStorage.id
    roleDefinitionId: format('{0}/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b', subscription().id)
    principalId: userAssignedManagedId.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


// private end points & private link services
resource privateEndpointPrimaryStorageBlob 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: format('pend-hdi-storage-stg-blob{0}', resourceGroup().name)
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', virtualNetworkHdiSpoke.name, hdiSubnet.name)
    }
    privateLinkServiceConnections: [
      {
        name: format('plink-service-stg-blob-{0}-{1}', storageAccount.name, resourceGroup().name)
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource privateEndpointPrimaryStorageGen2Blob 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: format('pend-hdi-storage-gen2-blob{0}', resourceGroup().name)
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', virtualNetworkHdiSpoke.name, hdiSubnet.name)
    }
    privateLinkServiceConnections: [
      {
        name: format('plink-service-gen2-blob-{0}-{1}', storageAccountGen2.name, resourceGroup().name)
        properties: {
          privateLinkServiceId: storageAccountGen2.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}
resource privateEndpointPrimaryStorageGen2Dfs 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: format('pend-hdi-storage-gen2-dfs{0}', resourceGroup().name)
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', virtualNetworkHdiSpoke.name, hdiSubnet.name)
    }
    privateLinkServiceConnections: [
      {
        name: format('plink-service-dfs-{0}-{1}', storageAccountGen2.name, resourceGroup().name)
        properties: {
          privateLinkServiceId: storageAccountGen2.id
          groupIds: [
            'dfs'
          ]
        }
      }
    ]
  }
}

// private DNS zones and vnet links
resource privateDnsZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  //name: format('privatelink{0}.blob.core.windows.net', resourceGroup().name)
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  dependsOn: [
    virtualNetworkHdiSpoke
  ]
}

resource privateDnsZoneDfs 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  //name: format('privatelink{0}.dfs.core.windows.net', resourceGroup().name)
  name: 'privatelink.dfs.core.windows.net'
  location: 'global'
  dependsOn: [
    virtualNetworkHdiSpoke
  ]
}

resource vnetLinkBlob 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: format('{0}/vnetlinkblob{1}', privateDnsZoneBlob.name, resourceGroup().name)
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetworkHdiSpoke.id
    }
    registrationEnabled: false
  }
}

resource vnetLinkDfs 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: format('{0}/vnetlinkdfs{1}', privateDnsZoneDfs.name, resourceGroup().name)
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetworkHdiSpoke.id
    }
    registrationEnabled: false
  }
}

resource privateDnsBlobRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZoneBlob
  name: storageAccount.name
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: first(first(privateEndpointPrimaryStorageBlob.properties.customDnsConfigs).ipAddresses)
      }
    ]
  }
}
resource privateDnsBlobRecordGen2 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZoneBlob
  name: storageAccountGen2.name
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: first(first(privateEndpointPrimaryStorageGen2Blob.properties.customDnsConfigs).ipAddresses)
      }
    ]
  }
}

resource privateDnsDfsRecordGen2 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZoneDfs
  name: storageAccountGen2.name
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: first(first(privateEndpointPrimaryStorageGen2Dfs.properties.customDnsConfigs).ipAddresses)
      }
    ]
  }
}

// virtual machines
param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string


// Ubuntu VM in spoke
resource publicIPAddressHdiSpokeUbu 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: format('pip-ubuntu-hdi-spoke{0}', resourceGroup().name)
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('ubuhdispoke{0}', resourceGroup().name)
    }
  }
}

var nicNameUbuntuHdiSpoke = format('nicubuntuHdiSpoke{0}', resourceGroup().name)
resource networkInterfaceUbuntuHdiSpoke 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameUbuntuHdiSpoke
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-ubuntu-HdiSpoke{0}', resourceGroup().name)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressHdiSpokeUbu.id
          }
          subnet: {
            id: defaultSubnet.id
          }
        }
      }
    ]
  }
}

param adminPublicKey string
var vmNameUbuntuHdiSpoke = format('ubu{0}', resourceGroup().name)
resource vmUbuntuHdiSpoke 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameUbuntuHdiSpoke
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: vmNameUbuntuHdiSpoke
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
          id: networkInterfaceUbuntuHdiSpoke.id
        }
      ]
    }
  }
}
/*
resource extensionBaseUbuntuHdiSpoke 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: format('{0}/extensionBase', vmUbuntuHdiSpoke.name)
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
*/

// Windows Server VM in spoke
resource publicIPAddressHdiSpokeWin 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: format('pip-win-hdi-spoke{0}', resourceGroup().name)
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('winhdispoke{0}', resourceGroup().name)
    }
  }
}

var nicNameWinAzureSpoke = format('nicwinazurespoke{0}', resourceGroup().name)
resource networkInterfaceWinAzureSpoke 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameWinAzureSpoke
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfig-win-azurespoke{0}', resourceGroup().name)
        properties: {
          publicIPAddress: {
            id: publicIPAddressHdiSpokeWin.id
          }
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: defaultSubnet.id
          }
        }
      }
    ]
  }
}

var storageNameWinAzureSpoke = format('was{0}', uniqueString(resourceGroup().id))
resource storageaccountWinAzureSpoke 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageNameWinAzureSpoke
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
}

var vmNameWinAzureSpoke = format('win{0}', resourceGroup().name)
resource vmWinAzureSpoke 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameWinAzureSpoke
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D4s_v3'
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
          storageAccountType: 'Premium_LRS'
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
/*
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
*/
