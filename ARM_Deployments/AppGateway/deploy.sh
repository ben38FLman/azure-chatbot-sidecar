#!/bin/bash

# Azure Application Gateway Deployment Script
# This script deploys the Application Gateway ARM template using Azure CLI

set -e  # Exit on any error

# Default values
LOCATION="eastus"
TEMPLATE_FILE="ApplicationGateway.json"
PARAMETERS_FILE="parameters.json"
DEPLOYMENT_NAME="AppGateway-Deployment-$(date +%Y%m%d-%H%M%S)"

# Function to display usage
usage() {
    echo "Usage: $0 -g <resource-group-name> [-l <location>] [-t <template-file>] [-p <parameters-file>] [-d <deployment-name>]"
    echo ""
    echo "Options:"
    echo "  -g    Resource group name (required)"
    echo "  -l    Azure location (default: eastus)"
    echo "  -t    ARM template file (default: ApplicationGateway.json)"
    echo "  -p    Parameters file (default: parameters.json)"
    echo "  -d    Deployment name (default: auto-generated)"
    echo "  -h    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -g myResourceGroup -l eastus2"
    exit 1
}

# Parse command line arguments
while getopts "g:l:t:p:d:h" opt; do
    case $opt in
        g) RESOURCE_GROUP="$OPTARG";;
        l) LOCATION="$OPTARG";;
        t) TEMPLATE_FILE="$OPTARG";;
        p) PARAMETERS_FILE="$OPTARG";;
        d) DEPLOYMENT_NAME="$OPTARG";;
        h) usage;;
        \?) echo "Invalid option -$OPTARG" >&2; usage;;
    esac
done

# Check if required parameters are provided
if [ -z "$RESOURCE_GROUP" ]; then
    echo "Error: Resource group name is required"
    usage
fi

echo "=========================================="
echo "Azure Application Gateway Deployment"
echo "=========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Template File: $TEMPLATE_FILE"
echo "Parameters File: $PARAMETERS_FILE"
echo "Deployment Name: $DEPLOYMENT_NAME"
echo "=========================================="

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in
echo "Checking Azure CLI login status..."
if ! az account show &> /dev/null; then
    echo "Not logged in to Azure. Please log in..."
    az login
fi

# Get current subscription info
SUBSCRIPTION=$(az account show --query "name" -o tsv)
ACCOUNT=$(az account show --query "user.name" -o tsv)
echo "Current Azure Context: $ACCOUNT - $SUBSCRIPTION"

# Check if template files exist
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found in current directory."
    exit 1
fi

if [ ! -f "$PARAMETERS_FILE" ]; then
    echo "Error: Parameters file '$PARAMETERS_FILE' not found in current directory."
    exit 1
fi

# Check if resource group exists, create if it doesn't
echo "Checking if resource group exists..."
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo "Resource group '$RESOURCE_GROUP' does not exist. Creating..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo "Resource group created successfully."
else
    echo "Resource group '$RESOURCE_GROUP' already exists."
fi

# Validate the template
echo "Validating ARM template..."
VALIDATION_RESULT=$(az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMETERS_FILE" \
    --query "error" -o tsv 2>/dev/null || echo "validation_failed")

if [ "$VALIDATION_RESULT" != "null" ] && [ "$VALIDATION_RESULT" != "" ] && [ "$VALIDATION_RESULT" != "validation_failed" ]; then
    echo "Error: Template validation failed"
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "@$PARAMETERS_FILE"
    exit 1
fi

echo "Template validation successful."

# Deploy the template
echo "Starting deployment..."
echo "This may take several minutes..."

DEPLOYMENT_OUTPUT=$(az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMETERS_FILE" \
    --query "properties.provisioningState" -o tsv)

if [ "$DEPLOYMENT_OUTPUT" = "Succeeded" ]; then
    echo "✅ Deployment completed successfully!"
    
    # Get and display deployment outputs
    echo ""
    echo "📊 Deployment Outputs:"
    echo "======================"
    
    # Get specific outputs
    APP_GATEWAY_NAME=$(az deployment group show \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.outputs.applicationGatewayName.value" -o tsv 2>/dev/null || echo "N/A")
    
    PUBLIC_IP=$(az deployment group show \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.outputs.publicIPAddress.value" -o tsv 2>/dev/null || echo "N/A")
    
    VNET_NAME=$(az deployment group show \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.outputs.virtualNetworkName.value" -o tsv 2>/dev/null || echo "N/A")
    
    echo "Application Gateway Name: $APP_GATEWAY_NAME"
    echo "Public IP Address: $PUBLIC_IP"
    echo "Virtual Network Name: $VNET_NAME"
    
    echo ""
    echo "🎯 Next Steps:"
    echo "=============="
    echo "1. Configure your backend applications to accept traffic from the Application Gateway subnet"
    echo "2. Update DNS records to point to the Application Gateway public IP: $PUBLIC_IP"
    echo "3. Configure SSL certificates if using HTTPS"
    echo "4. Set up monitoring and alerts"
    echo "5. Test the Application Gateway configuration"
    
    echo ""
    echo "🔍 Useful Commands:"
    echo "==================="
    echo "View Application Gateway details:"
    echo "  az network application-gateway show --name $APP_GATEWAY_NAME --resource-group $RESOURCE_GROUP"
    echo ""
    echo "View backend health:"
    echo "  az network application-gateway show-backend-health --name $APP_GATEWAY_NAME --resource-group $RESOURCE_GROUP"
    echo ""
    echo "View public IP details:"
    echo "  az network public-ip show --name \$(az deployment group show --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP --query 'properties.outputs.publicIPAddress.value' -o tsv) --resource-group $RESOURCE_GROUP"
    
else
    echo "❌ Deployment failed!"
    echo "Deployment state: $DEPLOYMENT_OUTPUT"
    
    # Show deployment error details
    echo ""
    echo "Error details:"
    az deployment group show \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.error" -o json
    
    exit 1
fi

echo ""
echo "🎉 Deployment script completed successfully!"
