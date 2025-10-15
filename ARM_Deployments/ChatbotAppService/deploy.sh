#!/bin/bash

# Azure App Service with Sidecar - Deployment Script
# This script deploys the chatbot application with Phi-4 sidecar to Azure App Service

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-chatbot-sidecar-nonprod}"
LOCATION="${LOCATION:-eastus}"
DEPLOYMENT_NAME="ChatbotSidecar-$(date +%Y%m%d-%H%M%S)"
BICEP_FILE="$SCRIPT_DIR/ChatbotAppService-Sidecar.bicep"
PARAMETERS_FILE="$SCRIPT_DIR/ChatbotAppService-Sidecar.bicepparam"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if user is logged in
    if ! az account show &> /dev/null; then
        log_error "You are not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check if Bicep file exists
    if [[ ! -f "$BICEP_FILE" ]]; then
        log_error "Bicep file not found: $BICEP_FILE"
        exit 1
    fi
    
    # Check if parameters file exists
    if [[ ! -f "$PARAMETERS_FILE" ]]; then
        log_error "Parameters file not found: $PARAMETERS_FILE"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to display deployment information
show_deployment_info() {
    log_info "Deployment Configuration:"
    echo "  Resource Group: $RESOURCE_GROUP_NAME"
    echo "  Location: $LOCATION"
    echo "  Deployment Name: $DEPLOYMENT_NAME"
    echo "  Bicep File: $BICEP_FILE"
    echo "  Parameters File: $PARAMETERS_FILE"
    echo ""
}

# Function to create resource group
create_resource_group() {
    log_info "Creating resource group '$RESOURCE_GROUP_NAME' in '$LOCATION'..."
    
    if az group create \
        --name "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --output table; then
        log_success "Resource group created successfully"
    else
        log_error "Failed to create resource group"
        exit 1
    fi
}

# Function to validate deployment
validate_deployment() {
    log_info "Validating Bicep deployment..."
    
    if az deployment group validate \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file "$BICEP_FILE" \
        --parameters @"$PARAMETERS_FILE" \
        --output table; then
        log_success "Deployment validation passed"
    else
        log_error "Deployment validation failed"
        exit 1
    fi
}

# Function to deploy infrastructure
deploy_infrastructure() {
    log_info "Deploying infrastructure..."
    
    if az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file "$BICEP_FILE" \
        --parameters @"$PARAMETERS_FILE" \
        --name "$DEPLOYMENT_NAME" \
        --output table; then
        log_success "Infrastructure deployment completed"
    else
        log_error "Infrastructure deployment failed"
        exit 1
    fi
}

# Function to deploy application code
deploy_application() {
    local app_name
    app_name=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query 'properties.outputs.appServiceName.value' \
        --output tsv)
    
    if [[ -z "$app_name" ]]; then
        log_error "Could not retrieve App Service name from deployment outputs"
        exit 1
    fi
    
    log_info "Deploying application code to '$app_name'..."
    
    # Navigate to application directory
    cd "$SCRIPT_DIR/sidecar-app"
    
    # Create deployment package (if needed)
    if [[ -f "package.json" ]]; then
        log_info "Installing application dependencies..."
        npm install --production
    fi
    
    # Deploy using zip deployment
    if az webapp deploy \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$app_name" \
        --src-path . \
        --type zip \
        --timeout 300; then
        log_success "Application deployment completed"
    else
        log_error "Application deployment failed"
        exit 1
    fi
    
    # Return to script directory
    cd "$SCRIPT_DIR"
}

# Function to show deployment outputs
show_deployment_outputs() {
    log_info "Deployment outputs:"
    
    az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query 'properties.outputs' \
        --output table
    
    # Get the application URL
    local app_url
    app_url=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query 'properties.outputs.appServiceUrl.value' \
        --output tsv)
    
    if [[ -n "$app_url" ]]; then
        echo ""
        log_success "Application deployed successfully!"
        echo "  🌐 Application URL: $app_url"
        echo "  🏥 Health Check: $app_url/health"
        echo "  📖 API Info: $app_url/api/info"
        echo ""
        log_info "Next Steps:"
        echo "  1. Open the application URL in your browser"
        echo "  2. Check the health endpoints to verify deployment"
        echo "  3. Create a new chat session to test the AI functionality"
        echo "  4. Monitor logs using Azure Portal or Azure CLI"
    fi
}

# Function to test deployment
test_deployment() {
    local app_url
    app_url=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query 'properties.outputs.appServiceUrl.value' \
        --output tsv)
    
    if [[ -n "$app_url" ]]; then
        log_info "Testing deployment..."
        
        # Wait for app to be ready
        log_info "Waiting for application to start (60 seconds)..."
        sleep 60
        
        # Test health endpoint
        log_info "Testing health endpoint..."
        if curl -f -s "$app_url/health" > /dev/null; then
            log_success "Health check passed"
        else
            log_warning "Health check failed - app may need more time to start"
        fi
        
        # Test API info endpoint
        log_info "Testing API info endpoint..."
        if curl -f -s "$app_url/api/info" > /dev/null; then
            log_success "API info endpoint accessible"
        else
            log_warning "API info endpoint not accessible"
        fi
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "🤖 Azure App Service with Sidecar"
    echo "    Deployment Script"
    echo "======================================"
    echo ""
    
    check_prerequisites
    show_deployment_info
    
    # Confirm deployment
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled by user"
        exit 0
    fi
    
    echo ""
    log_info "Starting deployment process..."
    
    create_resource_group
    validate_deployment
    deploy_infrastructure
    deploy_application
    show_deployment_outputs
    test_deployment
    
    echo ""
    log_success "🎉 Deployment completed successfully!"
    echo ""
}

# Handle script interruption
cleanup() {
    log_warning "Deployment interrupted"
    exit 1
}

trap cleanup SIGINT SIGTERM

# Run main function
main "$@"