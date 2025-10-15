using './ChatbotAppService-Sidecar.bicep'

param appServiceName = 'chatbot-sidecar-nonprod-001'
param appServicePlanName = 'plan-chatbot-sidecar-001'
param location = 'eastus'
param appServicePlanSku = 'P2mv3'
param environment = 'dev'