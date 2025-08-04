# Azure Application Gateway - Basic ARM Template

This is a simplified ARM template that deploys the minimum required components for an Azure Application Gateway. After deployment, you can configure additional settings through the Azure Portal or Azure CLI.

## What Gets Deployed

- **Virtual Network** with a single subnet for the Application Gateway
- **Public IP Address** (Standard SKU, Static allocation)
- **Application Gateway** (Standard_v2 SKU with basic configuration)

## Required Parameters

You only need to provide these essential parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `applicationGatewayName` | Name for your Application Gateway | `myapp-gateway` |
| `virtualNetworkName` | Name for the virtual network | `myapp-vnet` |
| `subnetName` | Name for the Application Gateway subnet | `appgateway-subnet` |
| `publicIPName` | Name for the public IP address | `myapp-gateway-pip` |
| `backendIPAddress` | IP address of your backend server | `10.0.2.10` |

## Optional Parameters (with defaults)

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `location` | Resource group location | Azure region |
| `subnetAddressPrefix` | `10.0.1.0/24` | Address range for App Gateway subnet |
| `vnetAddressPrefix` | `10.0.0.0/16` | Address range for virtual network |

## Default Configuration

The template creates an Application Gateway with these default settings:

- **SKU**: Standard_v2 (supports auto-scaling)
- **Capacity**: Auto-scale between 1-2 instances
- **Frontend**: Port 80 (HTTP)
- **Backend**: Port 80 (HTTP)
- **Protocol**: HTTP
- **Timeout**: 20 seconds
- **Affinity**: Disabled

## Quick Deployment

### 1. Edit Parameters
Update `parameters.json` with your values:

```json
{
  "applicationGatewayName": {"value": "YOUR-GATEWAY-NAME"},
  "virtualNetworkName": {"value": "YOUR-VNET-NAME"},
  "subnetName": {"value": "YOUR-SUBNET-NAME"},
  "publicIPName": {"value": "YOUR-PIP-NAME"},
  "backendIPAddress": {"value": "YOUR-BACKEND-IP"}
}
```

### 2. Deploy with PowerShell
```powershell
.\deploy.ps1 -ResourceGroupName "my-resource-group" -Location "eastus"
```

### 3. Deploy with Azure CLI
```bash
az deployment group create \
  --resource-group my-resource-group \
  --template-file ApplicationGateway.json \
  --parameters @parameters.json
```

## Post-Deployment Configuration

After the basic deployment, you can add these features through the Azure Portal:

### Security Features
- **SSL/TLS certificates** for HTTPS
- **Web Application Firewall (WAF)** rules
- **Custom security policies**

### Advanced Routing
- **Path-based routing** rules
- **Multi-site hosting**
- **URL rewrite rules**
- **Custom error pages**

### Backend Configuration
- **Additional backend pools**
- **Health probes** with custom paths
- **Session affinity** settings
- **Connection draining**

### Monitoring & Diagnostics
- **Application Insights** integration
- **Diagnostic logs**
- **Metrics and alerts**
- **Network Watcher** integration

## Common Next Steps

1. **Add HTTPS**: Upload SSL certificates and configure HTTPS listeners
2. **Configure custom health probes**: Set up health checks for your backends
3. **Add more backends**: Scale out your application with multiple backend servers
4. **Set up monitoring**: Configure alerts and dashboards
5. **Implement WAF**: Add web application firewall protection

## Network Requirements

- **Subnet size**: Minimum /27 (32 IP addresses) for the Application Gateway
- **Backend connectivity**: Ensure your backend servers are reachable from the Application Gateway subnet
- **NSG rules**: Allow traffic on ports 65200-65535 (for v1) or 65503-65534 (for v2) for Azure infrastructure

## Troubleshooting

### Common Issues
- **502 errors**: Check if backend servers are running and accessible
- **Deployment failures**: Verify subnet sizes and IP address ranges
- **Connectivity issues**: Check NSG rules and routing tables

### Useful Commands
```bash
# Check Application Gateway status
az network application-gateway show --name YOUR-GATEWAY-NAME --resource-group YOUR-RG

# View backend health
az network application-gateway show-backend-health --name YOUR-GATEWAY-NAME --resource-group YOUR-RG
```

## Template Files

| File | Purpose |
|------|---------|
| `ApplicationGateway.json` | Main ARM template |
| `parameters.json` | Sample parameters file |
| `deploy.ps1` | PowerShell deployment script |
| `deploy.sh` | Bash deployment script |

---

**Note**: This template creates a basic Application Gateway suitable for development/testing. For production deployments, consider additional security, monitoring, and high availability configurations.
