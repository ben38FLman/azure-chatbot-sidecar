# Azure Application Gateway - Deployment Guide

## Quick Start

This guide will help you deploy an Azure Application Gateway using the provided ARM templates.

## Prerequisites

Before deploying, ensure you have:

- **Azure Subscription** with appropriate permissions
- **Azure CLI** or **Azure PowerShell** installed
- **Resource Group** (will be created if it doesn't exist)
- **Network planning** completed (IP address ranges, backend servers)

## Files Included

| File | Description |
|------|-------------|
| `ApplicationGateway.json` | Main ARM template |
| `parameters.json` | Parameters file with example values |
| `deploy.ps1` | PowerShell deployment script |
| `deploy.sh` | Bash deployment script (Linux/macOS/WSL) |
| `README.md` | Comprehensive documentation |
| `DEPLOYMENT_GUIDE.md` | This file |

## Method 1: PowerShell Deployment (Recommended for Windows)

### Step 1: Customize Parameters
Edit `parameters.json` to match your environment:

```json
{
  "applicationGatewayName": {"value": "YOUR-APP-GATEWAY-NAME"},
  "virtualNetworkName": {"value": "YOUR-VNET-NAME"},
  "backendAddresses": {
    "value": [
      {"ipAddress": "YOUR-BACKEND-IP-1"},
      {"ipAddress": "YOUR-BACKEND-IP-2"}
    ]
  }
}
```

### Step 2: Run Deployment Script
```powershell
# Navigate to the template directory
cd "c:\path\to\ARM_Deployments\AppGateway"

# Run the deployment script
.\deploy.ps1 -ResourceGroupName "my-resource-group" -Location "eastus"
```

### Step 3: Monitor Deployment
The script will:
- ✅ Validate your Azure login
- ✅ Create resource group if needed
- ✅ Validate the ARM template
- ✅ Deploy the resources
- ✅ Display outputs and next steps

## Method 2: Azure CLI Deployment

### Step 1: Login to Azure
```bash
az login
```

### Step 2: Create Resource Group (if needed)
```bash
az group create --name my-resource-group --location eastus
```

### Step 3: Deploy Template
```bash
az deployment group create \
  --resource-group my-resource-group \
  --template-file ApplicationGateway.json \
  --parameters @parameters.json
```

## Method 3: Azure Portal Deployment

1. **Login** to [Azure Portal](https://portal.azure.com)
2. **Search** for "Deploy a custom template"
3. **Build your own template** in the editor
4. **Copy and paste** the content from `ApplicationGateway.json`
5. **Configure parameters** or upload `parameters.json`
6. **Review and create**

## Configuration Options

### Basic Configuration
For a simple web application:
```json
{
  "applicationGatewaySku": {"value": "Standard_v2"},
  "frontendPort": {"value": 80},
  "backendPort": {"value": 80},
  "protocol": {"value": "Http"}
}
```

### High Availability Configuration
For production workloads:
```json
{
  "applicationGatewaySku": {"value": "Standard_v2"},
  "autoScaleMinCapacity": {"value": 2},
  "autoScaleMaxCapacity": {"value": 20},
  "healthProbeEnabled": {"value": true}
}
```

### WAF-Enabled Configuration
For enhanced security:
```json
{
  "applicationGatewaySku": {"value": "WAF_v2"},
  "autoScaleMinCapacity": {"value": 1},
  "autoScaleMaxCapacity": {"value": 10}
}
```

## Post-Deployment Tasks

### 1. Verify Deployment
```powershell
# Check Application Gateway status
az network application-gateway show \
  --name YOUR-APP-GATEWAY-NAME \
  --resource-group YOUR-RESOURCE-GROUP
```

### 2. Configure Backend Servers
Ensure your backend servers are:
- ✅ Running and accessible
- ✅ Configured to accept traffic from the Application Gateway subnet
- ✅ Responding to health probe requests

### 3. Test Connectivity
```bash
# Test the public IP
curl http://YOUR-PUBLIC-IP

# Or use a web browser to navigate to the public IP
```

### 4. Configure DNS (Optional)
Update your DNS records to point to the Application Gateway's public IP.

### 5. Set Up Monitoring
Configure Azure Monitor alerts for:
- Backend health
- Response times
- Error rates
- Capacity utilization

## Troubleshooting

### Common Issues

**Issue**: 502 Bad Gateway errors
**Solution**: 
- Check backend server health
- Verify network connectivity
- Review NSG rules

**Issue**: Health probe failures
**Solution**:
- Verify health probe path exists
- Check backend server response codes
- Ensure correct port configuration

**Issue**: SSL/TLS errors
**Solution**:
- Verify certificate configuration
- Check certificate expiration
- Validate certificate chain

### Diagnostic Commands

```powershell
# Check backend health
az network application-gateway show-backend-health \
  --name YOUR-APP-GATEWAY-NAME \
  --resource-group YOUR-RESOURCE-GROUP

# View Application Gateway configuration
az network application-gateway show \
  --name YOUR-APP-GATEWAY-NAME \
  --resource-group YOUR-RESOURCE-GROUP

# Check public IP details
az network public-ip show \
  --name YOUR-PUBLIC-IP-NAME \
  --resource-group YOUR-RESOURCE-GROUP
```

## Security Considerations

1. **Network Security Groups**: Configure NSGs to allow necessary traffic
2. **SSL/TLS**: Implement HTTPS for production workloads
3. **WAF Rules**: Configure Web Application Firewall policies
4. **Backend Authentication**: Secure communication to backend servers
5. **Access Controls**: Implement proper RBAC permissions

## Cost Optimization

- **Right-size instances**: Use auto-scaling for variable workloads
- **Monitor usage**: Set up cost alerts and budgets
- **Reserved instances**: Consider reserved pricing for predictable workloads
- **Regular reviews**: Periodically review and optimize configuration

## Next Steps

1. **Configure HTTPS** with SSL certificates
2. **Set up custom domains** and DNS
3. **Implement WAF policies** for security
4. **Configure monitoring** and alerting
5. **Set up backup/disaster recovery** procedures
6. **Document** your specific configuration

## Support

For issues with this template:
1. Review the [Azure Application Gateway documentation](https://docs.microsoft.com/en-us/azure/application-gateway/)
2. Check the Azure portal for deployment errors
3. Review the deployment logs
4. Contact your Azure administrator or support team

---

**Last Updated**: $(Get-Date -Format "yyyy-MM-dd")  
**Version**: 1.0  
**Maintained by**: Infrastructure Team
