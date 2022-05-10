param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string
param clientIp string
// hdi params ------------------------------------------------------------------------------------------------

@description('CIDR range for the public subnet..')
param subnetCidrHdi string = format('10.{0}.0.0/20', networkAddrB)

@description('The name of the public subnet to create.')
param hdiPublicSubnetName string = 'public-subnet'

@description('CIDR range for the vnet.')
param vnetCidrHdi string = format('10.{0}.0.0/16', networkAddrB)

@description('The name of the virtual network to create.')
param hdiVnetName string = format('hdinsight-vnet-{0}', networkAddrB)

@description('The name of the Azure Data Explorer Cluster to create.')
param clusterName string = format('hdi{0}{1}',  uniqueString(resourceGroup().id), networkAddrB)

// hdi -------------------------------------------------------------------------------
resource networkSecurityGroupHdi 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: format('nsg-hdi{0}', networkAddrB)
  location: location
  properties: {
    securityRules: [
      {
        name: 'hdi-management-inbound'
        properties: {
          description: 'allow access from Management to a cluster.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'HDInsight'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'hdi-management-outbound'
        properties: {
          description: 'allow access to management'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'HDInsight'
          access: 'Allow'
          priority: 101
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

resource virtualNetworkHdiSpoke 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  location: location
  name: hdiVnetName
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidrHdi
      ]
    }
  }
}

resource hdiPublicSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: hdiPublicSubnetName
  parent: virtualNetworkHdiSpoke
  properties: {
    addressPrefix: subnetCidrHdi
    networkSecurityGroup: {
      id: networkSecurityGroupHdi.id
    }
  }
}

var storageName = format('{0}{1}', uniqueString(resourceGroup().id), networkAddrB)
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

param adminUserName string
@secure()
@minLength(12)
param adminUserPassword string
resource hdi 'Microsoft.HDInsight/clusters@2021-06-01' = {
  name: clusterName
  location: location
  properties: {
    clusterVersion: '4.0'
    osType: 'Linux'
    tier: 'Standard'
    clusterDefinition: {
      kind: 'hadoop'
      configurations: {
        gateway: {
          restAuthCredential: {
            isEnabled: true
            username: adminUserName
            password: adminUserPassword
          }
        }
      }
    }
    storageProfile: {
      storageaccounts: [
        {
          name: replace(replace(concat(reference(storageAccount.id, '2021-08-01').primaryEndpoints.blob), 'https:', ''), '/', '')
          isDefault: true
          container: clusterName
          key: listKeys(storageAccount.id, '2021-08-01').keys[0].value
        }
      ]
    }
    computeProfile: {
      roles: [
        {
          name: 'headnode'
          targetInstanceCount: 2
          hardwareProfile: {
            vmSize: 'standard_e4_v3'
          }
          osProfile: {
            linuxOperatingSystemProfile: {
              username: adminUserName
              password: adminUserPassword
            }
          }
          virtualNetworkProfile: {
            id: virtualNetworkHdiSpoke.id
            subnet: hdiPublicSubnet.id
          }
        }
        {
          name: 'workernode'
          targetInstanceCount: 3
          hardwareProfile: {
            vmSize: 'standard_e8_v3'
          }
          osProfile: {
            linuxOperatingSystemProfile: {
              username: adminUserName
              password: adminUserPassword
            }
          }
          virtualNetworkProfile: {
            id: virtualNetworkHdiSpoke.id
            subnet: hdiPublicSubnet.id
          }
        }
        {
          name: 'zookeepernode'
          targetInstanceCount: 3
          hardwareProfile: {
            vmSize: 'standard_a2_v2'
          }
          osProfile: {
            linuxOperatingSystemProfile: {
              username: adminUserName
              password: adminUserPassword
            }
          }
        }
      ]
    }
  }
}
