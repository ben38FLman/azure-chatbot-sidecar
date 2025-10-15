// User-defined types for better type safety
type AppConfiguration = {
  @description('The base name for the application resources')
  name: string
  
  @description('The deployment environment (e.g., dev, nonprod, prod)')
  environment: string
  
  @description('The Azure region to deploy resources')
  location: string
  
  @description('The App Service Plan SKU')
  sku: 'P1V3' | 'P2V3' | 'P3V3'
  
  @description('Whether to use Linux containers')
  reserved: bool
}

type EnvironmentVariable = {
  @description('Environment variable name')
  name: string
  
  @description('Environment variable value')
  value: string
}

type SidecarConfiguration = {
  @description('Whether to enable the sidecar container')
  enabled: bool
  
  @description('Container image for the sidecar')
  image: string
  
  @description('Name of the sidecar container')
  name: string
  
  @description('Target port for the sidecar container')
  targetPort: string
  
  @description('Environment variables for the sidecar container')
  environmentVariables: EnvironmentVariable[]
}

@description('Configuration for the Azure App Service with Sidecar container support')
param appConfig AppConfiguration = {
  name: 'chatbot-sidecar'
  environment: 'nonprod'
  location: 'eastus'
  sku: 'P1V3'
  reserved: true
}

@description('Sidecar container configuration')
param sidecarConfig SidecarConfiguration = {
  enabled: true
  image: 'mcr.microsoft.com/azure-ai/phi-4-q4-gguf:latest'
  name: 'phi-4-sidecar'
  targetPort: '11434'
  environmentVariables: [
    {
      name: 'OLLAMA_HOST'
      value: '0.0.0.0:11434'
    }
    {
      name: 'OLLAMA_MODELS'
      value: '/app/models'
    }
  ]
}

@description('Application settings for the main container')
param appSettings array = [
  {
    name: 'SIDECAR_ENDPOINT'
    value: 'http://localhost:11434'
  }
  {
    name: 'WEBSITE_NODE_DEFAULT_VERSION'
    value: '18-lts'
  }
  {
    name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
    value: 'true'
  }
]

@description('Tags to apply to all resources')
param tags object = {
  Environment: appConfig.environment
  Project: 'ChatbotSidecar'
  DeployedBy: 'AzureDevOps'
  CostCenter: 'Engineering'
}

// Variables for resource naming
var resourcePrefix = '${appConfig.name}-${appConfig.environment}'
var appServicePlanName = '${resourcePrefix}-plan'
var appServiceName = '${resourcePrefix}-app'
var logAnalyticsName = '${resourcePrefix}-logs'
var appInsightsName = '${resourcePrefix}-insights'

// Log Analytics Workspace for monitoring
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: appConfig.location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights for monitoring
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: appConfig.location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// App Service Plan with Premium V3 for sidecar support
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: appConfig.location
  tags: tags
  sku: {
    name: appConfig.sku
    tier: 'PremiumV3'
    size: appConfig.sku
    family: 'Pv3'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: appConfig.reserved
    isSpot: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    zoneRedundant: false
  }
}

// Main App Service
resource appService 'Microsoft.Web/sites@2024-04-01' = {
  name: appServiceName
  location: appConfig.location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    reserved: true
    httpsOnly: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      use32BitWorkerProcess: false
      webSocketsEnabled: false
      healthCheckPath: '/health'
      appSettings: concat(appSettings, [
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
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_PreemptSdk'
          value: 'Disabled'
        }
      ])
      cors: {
        allowedOrigins: [
          '*'
        ]
        supportCredentials: false
      }
      ipSecurityRestrictions: [
        {
          ipAddress: 'Any'
          action: 'Allow'
          priority: 2147483647
          name: 'Allow all'
          description: 'Allow all access'
        }
      ]
      scmIpSecurityRestrictions: [
        {
          ipAddress: 'Any'
          action: 'Allow'
          priority: 2147483647
          name: 'Allow all'
          description: 'Allow all access'
        }
      ]
      scmIpSecurityRestrictionsUseMain: false
    }
  }
}

// Sidecar container for AI model (Phi-4)
resource sidecarContainer 'Microsoft.Web/sites/sitecontainers@2024-04-01' = if (sidecarConfig.enabled) {
  parent: appService
  name: sidecarConfig.name
  properties: {
    image: sidecarConfig.image
    isMain: false
    authType: 'Anonymous'
    targetPort: sidecarConfig.targetPort
    environmentVariables: sidecarConfig.environmentVariables
    startUpCommand: 'ollama serve'
    volumeMounts: []
  }
}

// App Service diagnostic settings
resource appServiceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appServiceName}-diagnostics'
  scope: appService
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 7
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 7
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 7
        }
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 7
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 7
        }
      }
    ]
  }
}

// Outputs for use in deployment pipelines
@description('The name of the deployed App Service')
output appServiceName string = appService.name

@description('The default hostname of the App Service')
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'

@description('The resource ID of the App Service')
output appServiceResourceId string = appService.id

@description('The name of the App Service Plan')
output appServicePlanName string = appServicePlan.name

@description('The resource ID of the App Service Plan')
output appServicePlanResourceId string = appServicePlan.id

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights Connection String')
@secure()
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = logAnalytics.id

@description('The principal ID of the system assigned managed identity')
output managedIdentityPrincipalId string = appService.identity.principalId

@description('Sidecar container endpoint URL')
output sidecarEndpointUrl string = sidecarConfig.enabled ? 'http://localhost:${sidecarConfig.targetPort}' : 'Not configured'

@description('Health check URL for the application')
output healthCheckUrl string = '${appService.properties.defaultHostName}/health'