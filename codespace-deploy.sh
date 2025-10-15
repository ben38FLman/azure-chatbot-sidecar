#!/bin/bash

# GitHub Codespace deployment script for Azure App Service with AI Sidecar
# Based on: https://learn.microsoft.com/en-us/azure/app-service/tutorial-ai-slm-spring-boot
# Following Azure-Samples/ai-slm-in-app-service-sidecar pattern

set -e

echo "🚀 Starting Azure App Service with AI Sidecar deployment..."
echo "   Following: https://github.com/Azure-Samples/ai-slm-in-app-service-sidecar"

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Installing..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Check Azure login status
if ! az account show &> /dev/null; then
    echo "🔐 Please log in to Azure:"
    az login
fi

# Set variables (following the tutorial pattern)
LOCATION="eastus"
APP_NAME="chatbot-sidecar-$(date +%s)"

echo "📝 Configuration:"
echo "  Location: $LOCATION"
echo "  App Name: $APP_NAME"
echo "  SKU: P3MV3 (Required for sidecar support)"
echo "  Runtime: NODE:20-lts"

# Navigate to the application directory
cd ARM_Deployments/ChatbotAppService/sidecar-app

echo "📦 Installing Node.js dependencies..."
npm install

echo "☁️ Deploying to Azure App Service..."
echo "   Using 'az webapp up' command (same pattern as Spring Boot tutorial)"

# Deploy using az webapp up (exactly like the tutorial)
az webapp up \
    --sku P3MV3 \
    --runtime "NODE:20-lts" \
    --os-type linux \
    --name "$APP_NAME" \
    --location "$LOCATION"

echo "✅ Application deployed successfully!"

# Get the app URL and resource group (auto-created by az webapp up)
APP_URL=$(az webapp show --name "$APP_NAME" --query "defaultHostName" -o tsv)
RESOURCE_GROUP=$(az webapp show --name "$APP_NAME" --query "resourceGroup" -o tsv)

echo ""
echo "📋 Deployment Summary:"
echo "   App Name: $APP_NAME"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   App URL: https://$APP_URL"
echo ""
echo "🔧 Next step: Add the Phi-4 sidecar extension through Azure Portal:"
echo "   1. Navigate to: https://portal.azure.com"
echo "   2. Go to your App Service: $APP_NAME"
echo "   3. Navigate to: Deployment > Deployment Center"
echo "   4. Click the 'Containers' tab"
echo "   5. Select: Add > Sidecar extension"
echo "   6. Choose: AI: phi-4-q4-gguf (Experimental)"
echo "   7. Provide a name for the sidecar extension"
echo "   8. Select Save to apply the changes"
echo "   9. Wait for the Status to show 'Running'"
echo ""
echo "🧪 Testing:"
echo "   1. Open: https://$APP_URL"
echo "   2. Test the chat interface"
echo "   3. Verify AI responses after sidecar is running"
echo ""
echo "🎉 Deployment completed! Your chatbot will be ready once the sidecar is added."