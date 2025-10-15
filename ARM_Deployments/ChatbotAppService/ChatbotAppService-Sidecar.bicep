@description('Name of the App Service for the chatbot')
@minLength(1)
@maxLength(60)
param appServiceName string

@description('Name of the App Service Plan')
@minLength(1)
@maxLength(40)
param appServicePlanName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('The SKU of the App Service Plan - Must be P3MV3 or higher for AI sidecar')
@allowed([
  'P1v3'
  'P2v3'
  'P3v3'
  'P1mv3'
  'P2mv3'
  'P3mv3'
])
param appServicePlanSku string = 'P2mv3'

@description('Environment (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

// Variables for resource naming and configuration
var appInsightsName = '${appServiceName}-insights'
var logAnalyticsWorkspaceName = take('${appServiceName}-logs', 63)

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// App Service Plan with Premium tier for AI sidecar support
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
    tier: 'PremiumV3'
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux App Service Plan
  }
}

// App Service configured for Node.js with AI sidecar support
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      appSettings: [
        // Application Insights
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        // Environment configuration
        {
          name: 'NODE_ENV'
          value: environment
        }
        {
          name: 'PORT'
          value: '8080'
        }
        // AI Sidecar Configuration (Phi-4 sidecar will be available at localhost:11434)
        {
          name: 'AI_SIDECAR_ENDPOINT'
          value: 'http://localhost:11434/v1/chat/completions'
        }
        {
          name: 'AI_MODEL_NAME'
          value: 'phi-4'
        }
        // Performance settings
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
        // Node.js startup optimization
        {
          name: 'NODE_OPTIONS'
          value: '--max-old-space-size=2048'
        }
      ]
      alwaysOn: true // Required for Premium plans
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      remoteDebuggingEnabled: false
      use32BitWorkerProcess: false
    }
    httpsOnly: true
    clientAffinityEnabled: false
  }
}

// Outputs
@description('App Service URL')
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'

@description('App Service Name')
output appServiceName string = appService.name

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights Connection String')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('App Service Plan Resource ID')
output appServicePlanId string = appServicePlan.id

@description('Instructions for adding AI Sidecar')
output sidecarInstructions string = 'After deployment, add Phi-4 sidecar extension via Azure Portal: App Service > Deployment > Deployment Center > Containers > Add > Sidecar extension > AI: phi-4-q4-gguf'