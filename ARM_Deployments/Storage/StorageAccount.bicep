@description('Name of the storage account (max 24 characters, lowercase)')
@maxLength(24)
param storageAccountName string

@description('Location for the storage account')
param location string = resourceGroup().location

@description('Storage Account replication type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Access tier for blob storage')
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

// Ensure storage account name is compliant
var cleanStorageAccountName = take(toLower(replace(storageAccountName, '-', '')), 24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: cleanStorageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    accessTier: accessTier
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Outputs
@description('Name of the deployed storage account')
output storageAccountName string = storageAccount.name

@description('Resource ID of the storage account')
output storageAccountId string = storageAccount.id

@description('Primary endpoints of the storage account')
output primaryEndpoints object = storageAccount.properties.primaryEndpoints

@description('Access keys for the storage account')
output accessKeys object = listKeys(storageAccount.id, storageAccount.apiVersion)
