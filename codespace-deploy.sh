#!/bin/bash

# GitHub Codespace deployment script for Azure App Service with AI Sidecar
# Based on: https://learn.microsoft.com/en-us/azure/app-service/tutorial-ai-slm-spring-boot

set -e

echo "🚀 Starting Azure App Service with AI Sidecar deployment..."

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Installing..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Check Azure login status
if ! az account show &> /dev/null; then
    echo "🔐 Please log in to Azure:"
    az login --use-device-code
fi

# Set variables
RESOURCE_GROUP="rg-chatbot-sidecar-$(date +%s)"
LOCATION="eastus"
APP_NAME="chatbot-sidecar-$(date +%s)"
APP_SERVICE_PLAN="asp-chatbot-sidecar"

echo "📝 Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  App Name: $APP_NAME"
echo "  App Service Plan: $APP_SERVICE_PLAN"

# Navigate to the application directory
cd ARM_Deployments/ChatbotAppService/sidecar-app

echo "📦 Installing Node.js dependencies..."
npm install

echo "🏗️ Building the application..."
npm run build 2>/dev/null || echo "No build script found, proceeding with existing files..."

echo "☁️ Deploying to Azure App Service..."

# Deploy using az webapp up (similar to the Spring Boot tutorial)
az webapp up \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "P3MV3" \
    --runtime "NODE:20-lts" \
    --os-type "linux" \
    --startup-file "node app.js"

echo "✅ Application deployed successfully!"

# Get the app URL
APP_URL=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "defaultHostName" -o tsv)

echo "🌐 Application URL: https://$APP_URL"
echo ""
echo "🔧 Next step: Add the Phi-4 sidecar extension through Azure Portal:"
echo "   1. Navigate to: https://portal.azure.com"
echo "   2. Go to your App Service: $APP_NAME"
echo "   3. Navigate to: Deployment > Deployment Center > Containers"
echo "   4. Select: Add > Sidecar extension"
echo "   5. Choose: AI: phi-4-q4-gguf (Experimental)"
echo "   6. Provide a name and save"
echo ""
echo "🎉 Deployment completed! Your chatbot will be ready once the sidecar is added."