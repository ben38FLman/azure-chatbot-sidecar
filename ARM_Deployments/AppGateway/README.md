# Azure Application Gateway ARM Template

This ARM template deploys an Azure Application Gateway with associated resources including a virtual network, subnet, and public IP address.

## Resources Deployed

- **Virtual Network**: Creates a new VNet with a dedicated subnet for the Application Gateway
- **Public IP Address**: Static public IP for the Application Gateway frontend
- **Application Gateway**: Layer 7 load balancer with configurable backend pools and health probes

## Features

- **Auto-scaling**: Supports both fixed capacity and auto-scaling configurations (for Standard_v2 and WAF_v2 SKUs)
- **Health Probes**: Configurable custom health probes for backend health monitoring
- **Flexible Backend Configuration**: Support for multiple backend addresses
- **Multiple SKU Support**: Compatible with Standard and WAF SKUs
- **Comprehensive Tagging**: Apply tags to all resources for better organization

## Parameters

### Required Parameters
- `applicationGatewayName`: Name of the Application Gateway
- `virtualNetworkName`: Name of the virtual network
- `subnetName`: Name of the subnet for Application Gateway
- `publicIPName`: Name of the public IP address

### Optional Parameters (with defaults)
- `location`: Azure region (defaults to resource group location)
- `applicationGatewaySku`: SKU of the Application Gateway (default: Standard_v2)
- `capacity`: Number of instances (default: 2, ignored for v2 SKUs with auto-scaling)
- `autoScaleMinCapacity`: Minimum instances for auto-scaling (default: 1)
- `autoScaleMaxCapacity`: Maximum instances for auto-scaling (default: 10)
- `backendAddresses`: Array of backend server addresses
- `frontendPort`: Frontend port (default: 80)
- `backendPort`: Backend port (default: 80)
- `protocol`: Protocol for communication (default: Http)
- `healthProbeEnabled`: Enable custom health probe (default: true)
- `tags`: Object containing tags to apply to resources

## Deployment Instructions

### Prerequisites
- Azure subscription
- Appropriate permissions to create resources in the target resource group
- Azure CLI or Azure PowerShell

### Deploy using Azure CLI

```bash
# Create a resource group (if it doesn't exist)
az group create --name myResourceGroup --location eastus

# Deploy the template
az deployment group create \
  --resource-group myResourceGroup \
  --template-file ApplicationGateway.json \
  --parameters @parameters.json
```

### Deploy using Azure PowerShell

```powershell
# Create a resource group (if it doesn't exist)
New-AzResourceGroup -Name "myResourceGroup" -Location "East US"

# Deploy the template
New-AzResourceGroupDeployment `
  -ResourceGroupName "myResourceGroup" `
  -TemplateFile "ApplicationGateway.json" `
  -TemplateParameterFile "parameters.json"
```

### Deploy using Azure Portal

1. Go to the Azure Portal
2. Create a new deployment from template
3. Upload the `ApplicationGateway.json` file
4. Fill in the required parameters or upload the `parameters.json` file
5. Review and create

## Configuration Examples

### Basic Web Application
```json
{
  "backendAddresses": [
    {"ipAddress": "10.0.2.4"},
    {"ipAddress": "10.0.2.5"}
  ],
  "frontendPort": 80,
  "backendPort": 80,
  "protocol": "Http"
}
```

### High Availability Setup
```json
{
  "applicationGatewaySku": "Standard_v2",
  "autoScaleMinCapacity": 2,
  "autoScaleMaxCapacity": 20,
  "healthProbeEnabled": true,
  "healthProbePath": "/health"
}
```

### WAF-Enabled Configuration
```json
{
  "applicationGatewaySku": "WAF_v2",
  "autoScaleMinCapacity": 1,
  "autoScaleMaxCapacity": 10
}
```

## Post-Deployment Configuration

After deployment, you may need to:

1. **Configure SSL certificates** (for HTTPS listeners)
2. **Set up additional routing rules** for complex applications
3. **Configure WAF policies** (if using WAF SKU)
4. **Update DNS records** to point to the Application Gateway's public IP
5. **Configure backend applications** to accept traffic from the Application Gateway subnet

## Monitoring and Troubleshooting

### Key Metrics to Monitor
- Backend response time
- Failed requests
- Healthy host count
- Application Gateway total time

### Common Issues
- **Backend health probe failures**: Check the health probe path and backend server health
- **502 Bad Gateway errors**: Verify backend server configuration and network connectivity
- **SSL certificate issues**: Ensure certificates are properly configured and not expired

## Networking Considerations

- The Application Gateway requires a dedicated subnet
- Minimum subnet size is /27 (32 addresses)
- Network Security Groups (NSGs) must allow traffic on ports 65200-65535 for v1 SKUs, or 65503-65534 for v2 SKUs
- Backend servers should be configured to accept traffic from the Application Gateway subnet

## Cost Optimization

- Use Standard_v2 or WAF_v2 SKUs for auto-scaling capabilities
- Configure appropriate auto-scaling limits based on expected traffic
- Monitor usage and adjust capacity as needed
- Consider reserved instances for predictable workloads

## Security Best Practices

1. Use WAF SKU for web application protection
2. Configure SSL/TLS certificates for HTTPS traffic
3. Implement proper backend authentication
4. Use Azure Key Vault for certificate management
5. Configure appropriate NSG rules
6. Enable diagnostic logging and monitoring

## Template Outputs

The template provides the following outputs:
- `applicationGatewayName`: Name of the deployed Application Gateway
- `applicationGatewayResourceId`: Resource ID of the Application Gateway
- `publicIPAddress`: Public IP address assigned to the Application Gateway
- `publicIPFqdn`: FQDN of the public IP (if configured)
- `virtualNetworkName`: Name of the virtual network
- `subnetName`: Name of the Application Gateway subnet

## Support and Contributing

For issues or questions related to this template:
1. Check the Azure Application Gateway documentation
2. Review Azure Resource Manager template best practices
3. Submit issues or improvements through your DevOps process

## Version History

- **v1.0**: Initial release with basic Application Gateway deployment
  - Support for Standard and WAF SKUs
  - Auto-scaling configuration for v2 SKUs
  - Custom health probes
  - Comprehensive parameter validation
