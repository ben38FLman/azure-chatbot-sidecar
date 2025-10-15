# Azure App Service with AI Sidecar - Codespace Deployment

This repository contains a Node.js chatbot application that can be deployed to Azure App Service with a Phi-4 AI sidecar extension, following the pattern from the [Microsoft Learn tutorial](https://learn.microsoft.com/en-us/azure/app-service/tutorial-ai-slm-spring-boot).

## 🚀 Quick Start with GitHub Codespace

### Step 1: Create a Codespace

1. **Navigate to your GitHub repository**
2. **Click the green "Code" button**
3. **Select "Codespaces" tab**
4. **Click "Create codespace on main"** (or your feature branch)

### Step 2: Deploy from Codespace

Once your Codespace is ready:

```bash
# The Codespace will automatically install dependencies
# Run the deployment script
chmod +x codespace-deploy.sh
./codespace-deploy.sh
```

The script will:
- ✅ Install Azure CLI (if needed)
- 🔐 Prompt you to log in to Azure
- 📦 Install Node.js dependencies
- ☁️ Deploy your app to Azure App Service with P3MV3 SKU
- 🌐 Provide the application URL

### Step 3: Add the AI Sidecar Extension

After deployment, you'll need to manually add the Phi-4 sidecar through the Azure Portal:

1. **Navigate to [Azure Portal](https://portal.azure.com)**
2. **Find your App Service** (name will be shown in deployment output)
3. **Go to: Deployment > Deployment Center**
4. **Click the "Containers" tab**
5. **Select: Add > Sidecar extension**
6. **Choose: AI: phi-4-q4-gguf (Experimental)**
7. **Provide a name for the sidecar**
8. **Click Save and wait for deployment**

## 🎯 What Gets Deployed

### **Application Architecture**
- **Node.js Express App**: Main chatbot application
- **Responsive Frontend**: HTML/CSS/JavaScript chat interface
- **Session Management**: Chat session handling
- **Health Endpoints**: Application monitoring

### **Azure Resources**
- **App Service**: Premium V3 (P3MV3) for sidecar support
- **AI Sidecar**: Phi-4 model running on localhost:11434
- **Application Insights**: Monitoring and telemetry (if configured)

### **Key Features**
- 🤖 **AI-Powered Chat**: Phi-4 model integration
- 💬 **Session Management**: Multiple chat sessions
- 📱 **Responsive UI**: Works on desktop and mobile
- 🔍 **Health Monitoring**: Built-in health checks
- 🔒 **Secure Configuration**: Environment-based settings

## 🔧 Local Development

If you want to run locally in the Codespace:

```bash
cd ARM_Deployments/ChatbotAppService/sidecar-app
npm install
npm start
```

The app will be available at `http://localhost:3000`.

## 📚 Tutorial Comparison

This implementation follows the same pattern as the [Microsoft Learn Spring Boot tutorial](https://learn.microsoft.com/en-us/azure/app-service/tutorial-ai-slm-spring-boot) but uses:

| Tutorial (Spring Boot) | This Implementation (Node.js) |
|----------------------|--------------------------------|
| Java + Spring Boot | Node.js + Express |
| `mvnw clean package` | `npm install` |
| `az webapp up --runtime "JAVA:21-java21"` | `az webapp up --runtime "NODE:20-lts"` |
| localhost:11434/v1/chat/completions | Same API endpoint |

## 🛠️ Configuration

### Environment Variables

The application uses these environment variables:

```bash
# In production (App Service), these are set automatically
AI_API_URL=http://localhost:11434/v1/chat/completions
PORT=3000
NODE_ENV=production
```

### Sidecar Communication

The application communicates with the Phi-4 sidecar using the OpenAI-compatible API:

```javascript
// POST to http://localhost:11434/v1/chat/completions
{
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "User's question"}
  ],
  "stream": true,
  "cache_prompt": false,
  "n_predict": 2048
}
```

## 🧪 Testing

After deployment and sidecar setup:

1. **Open your app URL** (provided in deployment output)
2. **Test the chat interface**
3. **Verify AI responses** are working
4. **Check health endpoint**: `https://your-app.azurewebsites.net/health`

## 🔒 Security Considerations

- **No API Keys**: The sidecar runs locally, no external API calls
- **Private Data**: All AI processing happens within your App Service
- **Network Security**: Sidecar communication is localhost-only
- **Resource Isolation**: Sidecar runs in a separate container

## 📊 Monitoring

- **Application Insights**: Automatic telemetry (if configured)
- **Health Endpoints**: `/health` and `/api/health`
- **App Service Logs**: Available in Azure Portal
- **Sidecar Logs**: Available in Deployment Center

## ❓ FAQ

### **Q: Why use Codespace instead of local deployment?**
A: Codespaces provide a consistent environment with pre-installed tools, similar to the Microsoft Learn tutorial pattern.

### **Q: Can I use a different AI model?**
A: Yes! You can create custom sidecar containers or use other available AI extensions.

### **Q: What if the sidecar fails to start?**
A: Check the Deployment Center logs and ensure you're using P3MV3 or higher SKU.

### **Q: How much does this cost?**
A: P3MV3 App Service Plan costs vary by region. Check [Azure Pricing](https://azure.microsoft.com/pricing/details/app-service/) for current rates.

## 🔗 Additional Resources

- [Azure App Service Sidecar Documentation](https://learn.microsoft.com/en-us/azure/app-service/overview-sidecar)
- [Original Azure-Samples Repository](https://github.com/Azure-Samples/ai-slm-in-app-service-sidecar)
- [Spring Boot Tutorial](https://learn.microsoft.com/en-us/azure/app-service/tutorial-ai-slm-spring-boot)
- [Phi-4 Model Information](https://huggingface.co/microsoft/Phi-4)

---

**Ready to deploy?** Create your Codespace and run `./codespace-deploy.sh`! 🚀