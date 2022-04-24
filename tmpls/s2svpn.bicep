
param location string = resourceGroup().location
param networkAddrB string = '253'
var azureNwCidr = format('10.{0}.0.0/16', networkAddrB)
var azureNwGwCidr = format('10.{0}.0.0/24', networkAddrB)
var azureNwSubnet2Cidr = format('10.{0}.1.0/24', networkAddrB)
var azureNwName = format('azure-network-{0}', networkAddrB)

// Azure Network
resource azureVirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: azureNwName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        azureNwCidr
      ]
    }
  }
}

var gwSubnetName = 'GatewaySubnet'
resource gwSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: azureVirtualNetwork
  name: gwSubnetName
  properties: {
    addressPrefix: azureNwGwCidr
  }
}

var azureSubnetName = 'Subnet-2'
resource azureSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: azureVirtualNetwork
  name: azureSubnetName
  properties: {
    addressPrefix: azureNwSubnet2Cidr
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

// VPN Gataway
var gwPipName = format('gateway-ip-{0}', networkAddrB) 
resource gwPublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: gwPipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('shogohoshiis2svpn{0}', networkAddrB)
    }
  }
}

var azureNetworkGatewayName = format('azure-network-gateway-{0}', networkAddrB)
resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: azureNetworkGatewayName
  location: location
  dependsOn: [
    azureVirtualNetwork
  ]
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfigvngw{0}', networkAddrB)
        properties: {
          subnet: {
            id: gwSubnet.id
          }
          publicIPAddress: {
            id: gwPublicIPAddress.id
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

// VM in Azure network
var dnsLabelPrefix = format('shogohoshiidnsprefix{0}', networkAddrB)
var vmPipName = format('dsvm-pip-{0}', networkAddrB)
resource vmPublicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: vmPipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: format('{0}-{1}', dnsLabelPrefix, vmName)
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

var nicName = format('nicDsvm{0}', networkAddrB)
resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: format('ipconfignic{0}', networkAddrB)
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: azureSubnet.id
          }
          publicIPAddress: {
            id: vmPublicIPAddress.id
          }
        }
      }
    ]
  }
  dependsOn:[
    azureVirtualNetwork
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

var vmName = format('dsvm-azurenetwork-{0}', networkAddrB)
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
          id: networkInterface.id
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
}

