# Azure DevOps Pipeline Setup Guide

This guide will help you set up an Azure DevOps pipeline to deploy your Application Gateway ARM template.

## Prerequisites

Before setting up the pipeline, ensure you have:

1. **Azure DevOps Organization** with a project
2. **Azure Subscription** with appropriate permissions
3. **Service Principal** or **Managed Identity** for Azure authentication
4. **Resource Group** (will be created if it doesn't exist)

## Step 1: Create Azure Service Connection

1. **Navigate to Project Settings** in Azure DevOps
2. **Go to Service Connections** under Pipelines
3. **Create a new service connection**:
   - Type: **Azure Resource Manager**
   - Authentication method: **Service principal (automatic)** or **Service principal (manual)**
   - Scope level: **Subscription**
   - Subscription: Select your Azure subscription
   - Resource group: Leave empty for subscription-level access
   - Service connection name: `Azure-ServiceConnection` (or update the pipeline YAML)

## Step 2: Configure Pipeline Variables

### Option A: Update azure-pipelines.yml directly

Edit the variables section in `azure-pipelines.yml`:

```yaml
variables:
  azureServiceConnection: 'YOUR-SERVICE-CONNECTION-NAME'
  subscriptionId: 'YOUR-SUBSCRIPTION-ID'
  resourceGroupName: 'YOUR-RESOURCE-GROUP-NAME'
  location: 'YOUR-PREFERRED-REGION'
```

### Option B: Use Variable Groups (Recommended)

1. **Go to Pipelines > Library** in Azure DevOps
2. **Create a Variable Group** named `AppGateway-NonProd`
3. **Add these variables**:

| Variable Name | Value | Description |
|---------------|-------|-------------|
| `azureServiceConnection` | `Azure-ServiceConnection` | Your service connection name |
| `subscriptionId` | `your-subscription-id` | Your Azure subscription ID |
| `resourceGroupName` | `rg-appgateway-nonprod` | Resource group name |
| `location` | `East US` | Azure region |
| `applicationGatewayName` | `agw-myapp-nonprod` | Application Gateway name |
| `virtualNetworkName` | `vnet-nonprod` | Virtual network name |
| `subnetName` | `snet-appgateway` | Subnet name |
| `publicIPName` | `pip-appgateway-nonprod` | Public IP name |
| `backendIPAddress` | `10.10.2.10` | Backend server IP |
| `subnetAddressPrefix` | `10.10.1.32/27` | App Gateway subnet CIDR |
| `vnetAddressPrefix` | `10.10.0.0/22` | Virtual network CIDR |

4. **Update the pipeline** to use variable groups:

```yaml
variables:
- group: AppGateway-NonProd
```

## Step 3: Create Azure DevOps Environment

1. **Go to Pipelines > Environments**
2. **Create new environment**:
   - Name: `nonprod-azure`
   - Description: `Non-production Azure environment`
3. **Configure approvals** (optional):
   - Add required reviewers for production deployments
   - Set up approval policies

## Step 4: Set Up the Pipeline

### Option A: Create from Repository

1. **Go to Pipelines** in Azure DevOps
2. **Click "New pipeline"**
3. **Select "Azure Repos Git"** (or your source)
4. **Select your repository**
5. **Choose "Existing Azure Pipelines YAML file"**
6. **Select the path**: `/azure-pipelines.yml`
7. **Review and run**

### Option B: Import Pipeline

1. **Copy the pipeline YAML** from `azure-pipelines.yml`
2. **Create a new pipeline** in Azure DevOps
3. **Paste the YAML content**
4. **Save and run**

## Step 5: Configure Parameters

### Using Static Parameters File

Keep the current `parameters.json` with your specific values:

```json
{
  "applicationGatewayName": {"value": "your-gateway-name"},
  "virtualNetworkName": {"value": "your-vnet-name"},
  "backendIPAddress": {"value": "your-backend-ip"}
}
```

### Using Pipeline Variables (Advanced)

1. **Use `parameters-pipeline.json`** which contains tokenized values
2. **Add a token replacement task** to the pipeline:

```yaml
- task: replacetokens@5
  displayName: 'Replace tokens in parameters file'
  inputs:
    rootDirectory: 'ARM_Deployments/AppGateway'
    targetFiles: 'parameters-pipeline.json'
    encoding: 'auto'
    tokenPattern: 'custom'
    tokenPrefix: '#{'
    tokenSuffix: '}#'
```

## Step 6: Run the Pipeline

1. **Trigger the pipeline** by:
   - Pushing changes to the main branch
   - Manually running the pipeline
   - Creating a pull request (if configured)

2. **Monitor the pipeline** stages:
   - **Validate**: Validates the ARM template
   - **Deploy**: Deploys the Application Gateway
   - **PostDeployment**: Validates the deployment

## Pipeline Features

### 🔍 **Validation Stage**
- Validates ARM template syntax
- Checks parameter compatibility
- Runs without deploying resources

### 🚀 **Deployment Stage**
- Creates or updates the Application Gateway
- Deploys only on main branch
- Uses incremental deployment mode
- Captures deployment outputs

### ✅ **Post-Deployment Stage**
- Checks Application Gateway status
- Validates backend health
- Tests basic connectivity
- Displays public IP address

## Customization Options

### Multi-Environment Pipeline

Create separate parameter files for different environments:

```
ARM_Deployments/AppGateway/
├── parameters-dev.json
├── parameters-test.json
├── parameters-prod.json
```

### Branch-based Deployments

```yaml
- stage: DeployDev
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/develop')
  
- stage: DeployProd
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
```

### Approval Gates

Add manual approval for production:

```yaml
environment: 'prod-azure'
strategy:
  runOnce:
    deploy:
      steps:
      # Deployment steps here
```

## Troubleshooting

### Common Issues

1. **Service Connection Permissions**
   - Ensure the service principal has Contributor rights
   - Check subscription and resource group permissions

2. **Resource Group Not Found**
   - The pipeline will create the resource group if it doesn't exist
   - Ensure the service connection has rights to create resource groups

3. **Template Validation Failures**
   - Check parameter values in parameters.json
   - Verify ARM template syntax
   - Review API versions compatibility

4. **Deployment Timeouts**
   - Application Gateway deployment can take 10-20 minutes
   - Increase pipeline timeout if needed

### Useful Commands

Check deployment status:
```bash
az deployment group show --name AppGateway-123456 --resource-group rg-appgateway-nonprod
```

View Application Gateway details:
```bash
az network application-gateway show --name agw-myapp-nonprod --resource-group rg-appgateway-nonprod
```

## Security Best Practices

1. **Use Variable Groups** for sensitive data
2. **Enable approval gates** for production
3. **Limit service connection scope** to specific resource groups
4. **Use Managed Identity** when possible
5. **Enable pipeline audit logs**
6. **Implement branch protection** policies

## Next Steps

After successful deployment:

1. **Configure backend servers** in the Application Gateway
2. **Set up SSL certificates** for HTTPS
3. **Configure health probes** for backend monitoring
4. **Set up monitoring and alerts**
5. **Implement backup and disaster recovery**

---

**File Structure:**
```
├── azure-pipelines.yml           # Main pipeline definition
├── pipeline-variables.yml        # Variable templates and examples
└── ARM_Deployments/AppGateway/
    ├── ApplicationGateway.json    # ARM template
    ├── parameters.json            # Static parameters
    ├── parameters-pipeline.json   # Tokenized parameters
    └── PIPELINE_SETUP.md         # This guide
```
