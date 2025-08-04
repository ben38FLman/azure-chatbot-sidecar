# Generic ARM Pipeline Usage Guide

This pipeline can deploy ANY ARM template by configuring the parameters when you run it.

## 🚀 Quick Start Examples

### Application Gateway Deployment
```yaml
Parameters:
- resourceType: AppGateway
- templatePath: ARM_Deployments/AppGateway/ApplicationGateway.json
- parametersPath: ARM_Deployments/AppGateway/parameters.json
- resourceGroupName: rg-appgateway-nonprod
- location: East US
- environment: nonprod
- skipCleanup: true
```

### Storage Account Deployment
```yaml
Parameters:
- resourceType: StorageAccount
- templatePath: ARM_Deployments/Storage/StorageAccount.json
- parametersPath: ARM_Deployments/Storage/parameters.json
- resourceGroupName: rg-storage-nonprod
- location: East US
- environment: nonprod
- skipCleanup: true
```

### Virtual Network Deployment
```yaml
Parameters:
- resourceType: VirtualNetwork
- templatePath: ARM_Deployments/VNet/VirtualNetwork.json
- parametersPath: ARM_Deployments/VNet/parameters.json
- resourceGroupName: rg-network-nonprod
- location: East US
- environment: nonprod
- skipCleanup: true
```

## 📁 Recommended Folder Structure

```
ARM_Deployments/
├── AppGateway/
│   ├── ApplicationGateway.json
│   ├── parameters.json
│   └── README.md
├── Storage/
│   ├── StorageAccount.json
│   ├── parameters.json
│   └── README.md
├── VNet/
│   ├── VirtualNetwork.json
│   ├── parameters.json
│   └── README.md
└── KeyVault/
    ├── KeyVault.json
    ├── parameters.json
    └── README.md
```

## 🔧 Pipeline Features

### ✅ What This Pipeline Does:
- **Validates** ARM template syntax before deployment
- **Creates** resource groups automatically if they don't exist
- **Deploys** any ARM template with parameters
- **Tests** deployment success and lists created resources
- **Supports** multiple environments (dev, test, nonprod, prod)
- **Optional cleanup** with manual approval for test deployments
- **Detailed logging** and error handling
- **Artifact publishing** for tracking deployments

### 🎯 Pipeline Stages:
1. **Validate** - Template syntax and parameter validation
2. **Deploy** - ARM template deployment with approval gates
3. **Test** - Verify deployment success and resource creation
4. **Cleanup** - Optional resource cleanup for testing (manual approval required)

## 🚀 How to Use

### Option 1: Manual Pipeline Run
1. Go to Azure DevOps → Pipelines
2. Select "azure-pipelines-generic"
3. Click "Run pipeline"
4. Configure the parameters for your specific deployment
5. Click "Run"

### Option 2: Create Specific Pipelines
Use this generic pipeline as a template and create specific ones:
- `azure-pipelines-appgateway.yml` (with pre-configured parameters)
- `azure-pipelines-storage.yml` (with pre-configured parameters)

## ⚙️ Configuration Required

Before using this pipeline, ensure you have:
1. ✅ Azure service connection configured
2. ✅ Environment created in Azure DevOps (e.g., "nonprod-azure")
3. ✅ Updated subscription ID in the variables section
4. ✅ ARM templates and parameter files in the correct folders

## 🔐 Security Features

- **Environment approval gates** for production deployments
- **Manual validation** required for resource cleanup
- **Service connection** authentication to Azure
- **Resource group isolation** for different environments

## 📝 Best Practices

1. **Always test in nonprod first**
2. **Use meaningful resource group names**
3. **Keep cleanup enabled for test deployments**
4. **Review deployment outputs before approving production**
5. **Use consistent naming conventions**

This pipeline scales to support your entire Azure infrastructure deployment needs! 🎯
