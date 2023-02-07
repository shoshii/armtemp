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
var nsgName = format('common-nsg-{0}', networkAddrB)
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
          destinationPortRanges: [
            '80'
            '443'
          ]
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
      id: networkSecurityGroup.id
    }
  }
}

resource adx 'Microsoft.Kusto/clusters@2022-02-01' = {
  name: clusterName
  sku: {
    name: 'Standard_D13_v2'
    tier: 'Standard'
  }
  location: location
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: format('prvendpoint-adx{0}', networkAddrB)
  location: location
  properties: {
    subnet: {
      id: adxPublicSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: format('connection-to-adx{0}', networkAddrB)
        properties: {
          privateLinkServiceId: adx.id
          groupIds: [
            'cluster'
          ]
        }
      }
    ]
  }
}


