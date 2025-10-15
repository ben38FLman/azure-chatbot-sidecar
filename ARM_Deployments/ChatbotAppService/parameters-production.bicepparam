using './ChatbotAppService-Sidecar.bicep'

// Production-ready configuration
param appConfig = {
  name: 'chatbot-sidecar'
  environment: 'prod'
  location: 'eastus'
  sku: 'P3V3'
  reserved: true
}

// Production sidecar configuration with optimized settings
param sidecarConfig = {
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
    {
      name: 'OLLAMA_NUM_PARALLEL'
      value: '4'
    }
    {
      name: 'OLLAMA_MAX_LOADED_MODELS'
      value: '2'
    }
  ]
}

// Production application settings
param appSettings = [
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
  {
    name: 'NODE_ENV'
    value: 'production'
  }
  {
    name: 'PORT'
    value: '3000'
  }
  {
    name: 'WEBSITE_TIME_ZONE'
    value: 'UTC'
  }
  {
    name: 'WEBSITE_RUN_FROM_PACKAGE'
    value: '1'
  }
]

// Production tags
param tags = {
  Environment: 'production'
  Project: 'ChatbotSidecar'
  DeployedBy: 'AzureDevOps'
  CostCenter: 'Engineering'
  Purpose: 'AI-Chatbot-Production'
  BusinessUnit: 'Technology'
  Compliance: 'Required'
}