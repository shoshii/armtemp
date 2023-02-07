param location string = resourceGroup().location

@description('ipv4 address class B part; ex. the vnet include resources is created like 10.<nettworkAddrB>.0.0/16')
param networkAddrB string
param clientIp string
// adx params ------------------------------------------------------------------------------------------------

@description('CIDR range for the public subnet..')
param subnetCidrAdx string = format('10.{0}.0.0/20', networkAddrB)

@description('The name of the public subnet to create.')
param adxPublicSubnetName string = 'public-subnet'

@description('CIDR range for the vnet.')
param vnetCidrAdx string = format('10.{0}.0.0/16', networkAddrB)

@description('The name of the virtual network to create.')
param adxVnetName string = format('dataexlorer-vnet-{0}', networkAddrB)

@description('The name of the Azure Data Explorer Cluster to create.')
param clusterName string = format('adx{0}{1}',  uniqueString(resourceGroup().id), networkAddrB)

// adx -------------------------------------------------------------------------------
resource networkSecurityGroupAdx 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: format('nsg-adx{0}', networkAddrB)
  location: location
  properties: {
    securityRules: [
      {
        name: 'adx-internal-inbound'
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
        name: 'adx-management-inbound'
        properties: {
          description: 'allow access from Data Management to a cluster.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureDataExplorerManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'adx-monitor-inbound'
        properties: {
          description: 'allow access from Health Monitoring to a cluster.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '20.43.89.90'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 102
          direction: 'Inbound'
        }
      }
      {
        name: 'adx-loadbalancer-inbound'
        properties: {
          description: 'allow access from Load Balancer to a cluster.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '80'
          ]
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 103
          direction: 'Inbound'
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
        name: 'adx-storage-outbound'
        properties: {
          description: 'allow access from a cluster to Storage.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-datalake-outbound'
        properties: {
          description: 'allow access from a cluster to AzureDataLake.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureDataLake'
          access: 'Allow'
          priority: 111
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-eventhub-outbound'
        properties: {
          description: 'allow access from a cluster to EventHub.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '5671'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          priority: 112
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-AzureMonitor-outbound'
        properties: {
          description: 'allow access from a cluster to AzureMonitor.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 113
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-AzureActiveDirectory-outbound'
        properties: {
          description: 'allow access from a cluster to AzureActiveDirectory.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureActiveDirectory'
          access: 'Allow'
          priority: 114
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-AzureKeyVault-outbound'
        properties: {
          description: 'allow access from a cluster to AzureKeyVault.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          priority: 115
          direction: 'Outbound'
        }
      }
      {
        name: 'adx-internet-outbound'
        properties: {
          description: 'allow access from a cluster to *.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '80'
            '3306'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 116
          direction: 'Outbound'
        }
      }
    ]
  }
}
resource routeTableAdx 'Microsoft.Network/routeTables@2019-11-01' = {
  name: format('routetable-adx{0}', networkAddrB)
  location: location
}
resource virtualNetworkAdxSpoke 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  location: location
  name: adxVnetName
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidrAdx
      ]
    }
  }
}

resource adxPublicSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: adxPublicSubnetName
  parent: virtualNetworkAdxSpoke
  properties: {
    addressPrefix: subnetCidrAdx
    networkSecurityGroup: {
      id: networkSecurityGroupAdx.id
    }
    routeTable: {
      id: routeTableAdx.id
    }
    delegations: [
      {
        name: format('dataexlorer-del-public{0}', networkAddrB)
        properties: {
          serviceName: 'Microsoft.Kusto/clusters'
        }
      }
    ]
  }
}

resource publicIPAddressDataManagement 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: format('pip-adx-dm{0}', networkAddrB)
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}
resource publicIPAddressEngine 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: format('pip-adx-engine{0}', networkAddrB)
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource adx 'Microsoft.Kusto/clusters@2022-02-01' = {
  name: clusterName
  sku: {
    name: 'Standard_D13_v2'
    tier: 'Standard'
  }
  location: location
  properties: {
    virtualNetworkConfiguration: {
      subnetId: adxPublicSubnet.id
      enginePublicIpId: publicIPAddressEngine.id
      dataManagementPublicIpId: publicIPAddressDataManagement.id
    }
  }
}
