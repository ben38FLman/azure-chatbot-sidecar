# Azure App Service with Sidecar Deployment Guide

This guide provides step-by-step instructions for deploying an AI chatbot application with a Phi-4 sidecar container to Azure App Service.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Deployment Options](#deployment-options)
- [Configuration](#configuration)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## 🎯 Overview

This solution demonstrates how to deploy a Node.js chatbot application that leverages a Phi-4 language model running in a sidecar container within Azure App Service. The architecture enables AI capabilities while maintaining separation of concerns and scalability.

### Key Features

- **AI-Powered Chatbot**: Interactive web interface for chatting with Phi-4 AI model
- **Sidecar Architecture**: AI model runs in a separate container for optimal resource utilization
- **Real-time Health Monitoring**: Built-in health checks for both application and AI services
- **Session Management**: Persistent chat sessions with conversation history
- **Azure Integration**: Application Insights monitoring and Log Analytics integration
- **Responsive Design**: Modern web interface that works on desktop and mobile

## 📋 Prerequisites

### Required Tools

- **Azure CLI** (version 2.50.0 or later)
  ```bash
  az --version
  ```

- **Azure PowerShell** (for PowerShell deployment script)
  ```powershell
  Get-Module -Name Az -ListAvailable
  ```

- **Node.js** (version 18.x or later)
  ```bash
  node --version
  npm --version
  ```

### Azure Requirements

- **Azure Subscription** with appropriate permissions
- **Resource Group** creation permissions
- **App Service** deployment permissions
- **Bicep CLI** (automatically installed with Azure CLI 2.20.0+)

### Supported SKUs

The sidecar container feature requires **Premium V3** App Service Plan:
- P1V3 (minimum recommended)
- P2V3 (better performance)
- P3V3 (optimal performance)

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
# Navigate to the deployment directory
cd ARM_Deployments/ChatbotAppService
```

### 2. Login to Azure

```bash
# Azure CLI
az login

# PowerShell (alternative)
Connect-AzAccount
```

### 3. Deploy Using Scripts

#### Option A: Bash Script (Linux/macOS/WSL)

```bash
# Make script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

#### Option B: PowerShell Script (Windows/Cross-platform)

```powershell
# Run deployment
.\deploy.ps1

# With custom parameters
.\deploy.ps1 -ResourceGroupName "my-rg" -Location "westus2"
```

### 4. Access Your Application

After deployment, the script will display the application URL:
- **Main App**: `https://your-app-name.azurewebsites.net`
- **Health Check**: `https://your-app-name.azurewebsites.net/health`
- **API Info**: `https://your-app-name.azurewebsites.net/api/info`

## 🏗️ Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure App Service                        │
├─────────────────────────┬───────────────────────────────────┤
│   Main Container        │       Sidecar Container          │
│   (Node.js App)         │       (Phi-4 AI Model)           │
│                         │                                   │
│   ┌─────────────────┐   │   ┌─────────────────────────────┐ │
│   │   Frontend      │   │   │      Ollama Server          │ │
│   │   (HTML/CSS/JS) │   │   │      Phi-4 Model           │ │
│   │                 │   │   │      Port: 11434            │ │
│   └─────────────────┘   │   └─────────────────────────────┘ │
│   ┌─────────────────┐   │                                   │
│   │   Backend API   │───┼─► http://localhost:11434         │
│   │   (Express.js)  │   │                                   │
│   │   Port: 3000    │   │                                   │
│   └─────────────────┘   │                                   │
└─────────────────────────┴───────────────────────────────────┘
```

### Data Flow

1. **User Interaction**: User sends message through web interface
2. **API Processing**: Express.js backend receives and processes request
3. **AI Inference**: Backend calls sidecar container via localhost
4. **Response Generation**: Phi-4 model generates AI response
5. **Result Display**: Response is formatted and displayed to user

## 🛠️ Deployment Options

### Option 1: Azure DevOps Pipeline

The repository includes a pre-configured Azure DevOps pipeline:

1. **Import Pipeline**: Use `azure-pipelines-sidecar.yml`
2. **Configure Service Connection**: Set up `MSFT-NonProd-DevOpsConnection`
3. **Trigger Deployment**: Push to main or feature branch

### Option 2: Manual Deployment Scripts

#### Bash Deployment

```bash
# Set environment variables (optional)
export RESOURCE_GROUP_NAME="my-sidecar-rg"
export LOCATION="eastus"

# Run deployment
./deploy.sh
```

#### PowerShell Deployment

```powershell
# Deploy with custom parameters
.\deploy.ps1 `
  -ResourceGroupName "my-sidecar-rg" `
  -Location "eastus" `
  -SkipConfirmation
```

### Option 3: Azure CLI Direct

```bash
# Create resource group
az group create --name "my-sidecar-rg" --location "eastus"

# Deploy infrastructure
az deployment group create \
  --resource-group "my-sidecar-rg" \
  --template-file "ChatbotAppService-Sidecar.bicep" \
  --parameters @"ChatbotAppService-Sidecar.bicepparam"

# Deploy application code
cd sidecar-app
npm install --production
az webapp deploy \
  --resource-group "my-sidecar-rg" \
  --name "your-app-name" \
  --src-path . \
  --type zip
```

## ⚙️ Configuration

### Environment Variables

The application supports the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `development` | Application environment |
| `PORT` | `3000` | Application port |
| `SIDECAR_ENDPOINT` | `http://localhost:11434` | Sidecar API endpoint |
| `AI_TIMEOUT` | `30000` | AI request timeout (ms) |
| `MAX_CONVERSATION_HISTORY` | `10` | Max messages in context |

### Bicep Parameters

Customize deployment by modifying parameters in `ChatbotAppService-Sidecar.bicepparam`:

```bicep
param appConfig = {
  name: 'your-app-name'
  environment: 'nonprod'
  location: 'eastus'
  sku: 'P2V3'  // Upgrade for better performance
  reserved: true
}

param sidecarConfig = {
  enabled: true
  image: 'mcr.microsoft.com/azure-ai/phi-4-q4-gguf:latest'
  targetPort: '11434'
  // Add custom environment variables
}
```

## 🧪 Testing

### Health Check Endpoints

```bash
# Application health
curl https://your-app.azurewebsites.net/health

# Sidecar health
curl https://your-app.azurewebsites.net/api/sidecar/health

# API information
curl https://your-app.azurewebsites.net/api/info
```

### Chat API Testing

```bash
# Create chat session
SESSION_ID=$(curl -X POST https://your-app.azurewebsites.net/api/chat/sessions \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Session"}' | jq -r '.sessionId')

# Send message
curl -X POST "https://your-app.azurewebsites.net/api/chat/sessions/$SESSION_ID/messages" \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello, how are you?","model":"phi4"}'
```

### Local Development

```bash
# Navigate to app directory
cd sidecar-app

# Install dependencies
npm install

# Set up environment
cp .env.example .env

# Start development server
npm run dev
```

## 📊 Monitoring

### Application Insights

The deployment includes Application Insights integration:

- **Performance Monitoring**: Request times, dependency calls
- **Error Tracking**: Exceptions and failed requests
- **Custom Metrics**: AI response times, session counts
- **Log Analytics**: Centralized logging and querying

### Health Monitoring

Built-in health endpoints provide:

- **Application Status**: Service availability
- **Sidecar Status**: AI model connectivity
- **Dependency Health**: External service status
- **Resource Metrics**: Memory, CPU usage

### Azure Portal

Monitor your deployment through:

1. **App Service Overview**: Basic metrics and status
2. **Application Insights**: Detailed performance data
3. **Log Analytics**: Advanced querying and analysis
4. **Container Logs**: Sidecar container diagnostics

## 🔧 Troubleshooting

### Common Issues

#### 1. Sidecar Container Not Starting

**Symptoms**: AI requests fail, sidecar health check returns unhealthy

**Solutions**:
```bash
# Check container logs
az webapp log tail --name your-app-name --resource-group your-rg

# Verify container configuration
az webapp config container show --name your-app-name --resource-group your-rg

# Restart container
az webapp restart --name your-app-name --resource-group your-rg
```

#### 2. Out of Memory Errors

**Symptoms**: Application restarts, 502 errors

**Solutions**:
- Upgrade to P2V3 or P3V3 SKU
- Optimize AI model parameters
- Monitor memory usage in Application Insights

#### 3. Slow AI Responses

**Symptoms**: Request timeouts, poor user experience

**Solutions**:
```bicep
// Increase timeout
param appSettings = [
  {
    name: 'AI_TIMEOUT'
    value: '60000'  // 60 seconds
  }
]

// Optimize sidecar environment
param sidecarConfig = {
  environmentVariables: [
    {
      name: 'OLLAMA_NUM_PARALLEL'
      value: '2'  // Increase parallel processing
    }
  ]
}
```

### Diagnostic Commands

```bash
# Application logs
az webapp log tail --name your-app-name --resource-group your-rg

# Container configuration
az webapp config container show --name your-app-name --resource-group your-rg

# App settings
az webapp config appsettings list --name your-app-name --resource-group your-rg

# Deployment status
az deployment group show --name your-deployment-name --resource-group your-rg
```

## 🔒 Security Considerations

### Network Security

- **HTTPS Only**: All traffic encrypted in transit
- **Private Endpoints**: Consider for production workloads
- **IP Restrictions**: Limit access to trusted networks
- **CORS Configuration**: Restrict cross-origin requests

### Authentication

```bicep
// Add authentication (example)
resource authSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: appService
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    // Configure identity providers
  }
}
```

### Data Protection

- **Input Validation**: Sanitize user inputs
- **Rate Limiting**: Prevent abuse
- **Session Security**: Secure session management
- **Audit Logging**: Track user activities

### Best Practices

1. **Use Managed Identity** for Azure service authentication
2. **Store secrets** in Azure Key Vault
3. **Enable diagnostics** for all resources
4. **Regular updates** of base images and dependencies
5. **Monitor security alerts** in Azure Security Center

## 📚 Additional Resources

- [Azure App Service Sidecar Documentation](https://docs.microsoft.com/en-us/azure/app-service/configure-sidecar)
- [Phi-4 Model Documentation](https://huggingface.co/microsoft/phi-4)
- [Ollama Documentation](https://ollama.ai/docs)
- [Azure Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Need Help?** Check the troubleshooting section or open an issue in the repository.