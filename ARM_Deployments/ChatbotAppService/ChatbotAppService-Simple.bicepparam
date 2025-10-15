using './ChatbotAppService-Simple.bicep'

param appServiceName = 'chatbot-nonprod-simple-001'
param appServicePlanName = 'plan-chatbot-simple-001'
param location = 'eastus'
param appServicePlanSku = 'B2'
param environment = 'dev'