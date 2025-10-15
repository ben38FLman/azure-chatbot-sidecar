@description('Name of the Application Gateway')
@minLength(1)
@maxLength(80)
param applicationGatewayName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Virtual Network Name')
@minLength(1)
@maxLength(64)
param virtualNetworkName string

@description('Subnet Name for Application Gateway')
@minLength(1)
@maxLength(80)
param subnetName string

@description('Public IP Name for Application Gateway')
@minLength(1)
@maxLength(80)
param publicIPName string

// Variables for consistent naming and configuration
var appGwIPConfigName = '${applicationGatewayName}-ipconfig'
var appGwFrontendPortName = '${applicationGatewayName}-frontend-port'
var appGwFrontendIPConfigName = '${applicationGatewayName}-frontend-ip'
var appGwHttpListenerName = '${applicationGatewayName}-listener'
var appGwBackendPoolName = '${applicationGatewayName}-backend-pool'
var appGwBackendHttpSettingsName = '${applicationGatewayName}-backend-http-settings'
var appGwRequestRoutingRuleName = '${applicationGatewayName}-routing-rule'

// Public IP for Application Gateway
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: publicIPName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${applicationGatewayName}-${uniqueString(resourceGroup().id)}')
    }
  }
}

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.10.1.0/24'
        }
      }
    ]
  }
}

// Application Gateway
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-06-01' = {
  name: applicationGatewayName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 1
      maxCapacity: 10
    }
    gatewayIPConfigurations: [
      {
        name: appGwIPConfigName
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: appGwFrontendIPConfigName
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: appGwFrontendPortName
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: appGwBackendPoolName
        properties: {
          backendAddresses: []
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: appGwBackendHttpSettingsName
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: appGwHttpListenerName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, appGwFrontendIPConfigName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, appGwFrontendPortName)
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: appGwRequestRoutingRuleName
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, appGwHttpListenerName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, appGwBackendPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, appGwBackendHttpSettingsName)
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

@description('Application Gateway Resource ID')
output applicationGatewayId string = applicationGateway.id

@description('Application Gateway Name')
output applicationGatewayName string = applicationGateway.name

@description('Public IP Address')
output publicIPAddress string = publicIP.properties.ipAddress

@description('Application Gateway FQDN')
output applicationGatewayFQDN string = publicIP.properties.dnsSettings.fqdn
