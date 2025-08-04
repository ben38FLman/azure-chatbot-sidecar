# Quick Pipeline Setup Guide for Ben Ruggiero

## 🚀 Your Pipeline is Ready!

I've created a comprehensive Azure DevOps pipeline that's configured for your specific network setup:

### 📋 **Your Configuration**
- **Network Range**: 10.10.0.0/22
- **App Gateway Subnet**: 10.10.1.32/27  
- **Backend IP**: 10.10.2.10
- **App Gateway**: agw-benruggiero-nonprod
- **VNet**: vnet-benruggiero-nonprod

## ⚡ **Quick Setup (5 minutes)**

### Step 1: Update Pipeline Variables
Edit the variables section in `azure-pipelines.yml`:

```yaml
variables:
  azureServiceConnection: 'YOUR-SERVICE-CONNECTION-NAME'  # Update this
  subscriptionId: 'YOUR-SUBSCRIPTION-ID'                 # Update this
  resourceGroupName: 'rg-appgateway-nonprod'             # Or your preferred RG name
```

### Step 2: Create Service Connection
1. Go to **Azure DevOps** → **Project Settings** → **Service Connections**
2. Click **New service connection** → **Azure Resource Manager**
3. Choose **Service principal (automatic)**
4. Select your subscription
5. Name it: `Azure-ServiceConnection` (or update the pipeline variable)

### Step 3: Create Environment
1. Go to **Pipelines** → **Environments**
2. Click **New environment**
3. Name: `nonprod-azure`
4. Type: **None** (or add approval if you want manual approval)

### Step 4: Create the Pipeline
1. Go to **Pipelines** → **Create Pipeline**
2. Choose **Azure Repos Git** → Select your repo
3. Choose **Existing Azure Pipelines YAML file**
4. Select `/azure-pipelines.yml`
5. **Save and run**

## 🎯 **What the Pipeline Does**

### Stage 1: 🔍 **Validate** (Always runs)
- Validates ARM template syntax
- Shows your configuration
- Catches errors before deployment

### Stage 2: 🚀 **Deploy** (Only on main branch)
- Creates resource group if needed
- Deploys Application Gateway with your settings
- Shows deployment results

### Stage 3: ✅ **Post-Deploy** (After successful deployment)
- Checks Application Gateway status
- Tests backend health
- Tests basic connectivity
- Provides next steps

### Stage 4: 🧹 **Cleanup** (Manual only)
- Available for cleanup when needed
- Disabled by default for safety

## 📱 **Testing Your Setup**

### Option 1: Trigger Pipeline
Push a change to the main branch or manually run the pipeline

### Option 2: Manual Test First
```powershell
cd "ARM_Deployments\AppGateway"
.\test-deployment.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "rg-appgateway-nonprod"
```

## 🔧 **Customization Options**

### Change Resource Names
Update these variables in the pipeline:
```yaml
applicationGatewayName: 'agw-yourname-nonprod'
virtualNetworkName: 'vnet-yourname-nonprod'
resourceGroupName: 'rg-yourname-nonprod'
```

### Add Approval Gates
In your `nonprod-azure` environment:
1. Go to **Environments** → **nonprod-azure**
2. Click **Approvals and checks**
3. Add required approvers

### Multi-Environment Support
Create separate variable groups:
- `AppGateway-Dev`
- `AppGateway-Test` 
- `AppGateway-Prod`

## 🆘 **Troubleshooting**

### Common Issues:
1. **Service connection permissions**: Ensure Contributor role
2. **Subscription ID**: Get from Azure Portal → Subscriptions
3. **Resource group**: Pipeline will create it if it doesn't exist

### Need Help?
- Check pipeline logs for detailed error messages
- Validate template manually first with `test-deployment.ps1`
- Ensure your backend server at 10.10.2.10 is accessible

## 🎉 **You're All Set!**

Your pipeline is production-ready with:
- ✅ Comprehensive validation
- ✅ Detailed status reporting  
- ✅ Error handling
- ✅ Post-deployment testing
- ✅ Security best practices

**Next**: Update the two variables mentioned in Step 1 and run your pipeline!
