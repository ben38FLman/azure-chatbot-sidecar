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

@description('The SKU of the App Service Plan')
@allowed([
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
  'P1v3'
  'P2v3'
  'P3v3'
])
param appServicePlanSku string = 'B2'

@description('Docker Registry Server URL')
param dockerRegistryServerUrl string = 'https://index.docker.io'

@description('Docker Registry Server Username (optional for public images)')
param dockerRegistryServerUsername string = ''

@description('Docker Registry Server Password (optional for public images)')
@secure()
param dockerRegistryServerPassword string = ''

@description('Main application Docker image')
param mainAppImage string = 'node:18-alpine'

@description('LLM Sidecar Docker image')
param llmSidecarImage string = 'ollama/ollama:latest'

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
var containerRegistryName = take('cr${replace(appServiceName, '-', '')}${uniqueString(resourceGroup().id)}', 50)

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

// Container Registry (optional - for private images)
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
    }
  }
}

// App Service Plan with Linux support for containers
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
    tier: contains(appServicePlanSku, 'B') ? 'Basic' : contains(appServicePlanSku, 'S') ? 'Standard' : 'PremiumV2'
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux App Service Plan
  }
}

// App Service with multi-container support
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'COMPOSE|${base64(dockerComposeConfig)}'
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
          value: '3000'
        }
        // LLM Configuration
        {
          name: 'LLM_ENDPOINT'
          value: 'http://localhost:11434'
        }
        {
          name: 'LLM_MODEL'
          value: 'tinyllama:latest'
        }
        // Docker Registry Configuration
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: dockerRegistryServerUrl
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: dockerRegistryServerUsername
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: dockerRegistryServerPassword
        }
        // Performance and scaling
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '3000'
        }
      ]
      alwaysOn: appServicePlanSku != 'B1' // AlwaysOn not available on Basic B1
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      remoteDebuggingEnabled: false
    }
    httpsOnly: true
    clientAffinityEnabled: false
  }
}

// Docker Compose configuration for multi-container setup
var dockerComposeConfig = '''
version: '3.8'

services:
  chatbot-app:
    image: ${mainAppImage}
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=${environment}
      - PORT=3000
      - LLM_ENDPOINT=http://ollama-sidecar:11434
      - LLM_MODEL=tinyllama:latest
    depends_on:
      - ollama-sidecar
    restart: unless-stopped
    working_dir: /app
    command: ["sh", "-c", "npm install && npm start"]
    volumes:
      - /home/site/wwwroot:/app

  ollama-sidecar:
    image: ${llmSidecarImage}
    ports:
      - "11434:11434"
    environment:
      - OLLAMA_ORIGINS=*
      - OLLAMA_HOST=0.0.0.0:11434
    volumes:
      - ollama-data:/root/.ollama
    restart: unless-stopped
    command: ["sh", "-c", "ollama serve & sleep 30 && ollama pull tinyllama:latest && wait"]

volumes:
  ollama-data:
'''

// Outputs
@description('App Service URL')
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'

@description('App Service Name')
output appServiceName string = appService.name

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights Connection String')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Container Registry Login Server')
output containerRegistryLoginServer string = containerRegistry.properties.loginServer

@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('App Service Plan Resource ID')
output appServicePlanId string = appServicePlan.id