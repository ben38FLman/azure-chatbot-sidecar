using './ApplicationGateway.bicep'

param applicationGatewayName = 'appgw-benruggiero-nonprod-001'
param location = 'East US'
param virtualNetworkName = 'vnet-benruggiero-nonprod-001'
param subnetName = 'subnet-appgw-001'
param publicIPName = 'pip-appgw-benruggiero-nonprod-001'
