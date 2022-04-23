
param location string = resourceGroup().location
param azureNwIpRange string = '10.3.0.0/16'
param azureNwGwIpRange string = '10.3.0.0/24'
param azureNwSubnet2IpRange string = '10.3.1.0/24'
param azureNwName string = 'azure-network'
param gwSubnetName string = 'GatewaySubnet'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: azureNwName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        azureNwIpRange
      ]
    }
    subnets: [
      {
        name: gwSubnetName
        properties: {
          addressPrefix: azureNwGwIpRange
        }
      }
      {
        name: 'Subnet-2'
        properties: {
          addressPrefix: azureNwSubnet2IpRange
        }
      }
    ]
  }
}

param gwPipName string = 'gateway-ip'
resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: gwPipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: 'dnsnameshogohoshii'
    }
  }
}

resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: 'network-gateway'
  location: location
  dependsOn: [
    publicIPAddress
    virtualNetwork
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'name'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', azureNwName, gwSubnetName)
          }
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses/', gwPipName)
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
