# Azure Application Gateway Deployment Script
# This script deploys the Application Gateway ARM template

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = "ApplicationGateway.json",
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "parameters.json",
    
    [Parameter(Mandatory = $false)]
    [string]$DeploymentName = "AppGateway-Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "Starting Azure Application Gateway deployment..." -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Deployment Name: $DeploymentName" -ForegroundColor Yellow

try {
    # Check if Azure PowerShell module is installed
    if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
        Write-Error "Azure PowerShell module (Az.Resources) is not installed. Please install it using: Install-Module -Name Az -AllowClobber -Force"
        exit 1
    }

    # Check if user is logged in to Azure
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Not logged in to Azure. Please log in..." -ForegroundColor Yellow
        Connect-AzAccount
    }

    Write-Host "Current Azure Context: $($context.Account.Id) - $($context.Subscription.Name)" -ForegroundColor Cyan

    # Check if resource group exists, create if it doesn't
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $resourceGroup) {
        Write-Host "Resource group '$ResourceGroupName' does not exist. Creating..." -ForegroundColor Yellow
        $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Host "Resource group created successfully." -ForegroundColor Green
    } else {
        Write-Host "Resource group '$ResourceGroupName' already exists." -ForegroundColor Cyan
    }

    # Validate template files exist
    if (-not (Test-Path $TemplateFile)) {
        Write-Error "Template file '$TemplateFile' not found in current directory."
        exit 1
    }

    if (-not (Test-Path $ParametersFile)) {
        Write-Error "Parameters file '$ParametersFile' not found in current directory."
        exit 1
    }

    # Validate the template
    Write-Host "Validating ARM template..." -ForegroundColor Yellow
    $validationResult = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile $ParametersFile
    
    if ($validationResult) {
        Write-Error "Template validation failed:"
        foreach ($error in $validationResult) {
            Write-Error "  - $($error.Message)"
        }
        exit 1
    }
    
    Write-Host "Template validation successful." -ForegroundColor Green

    # Deploy the template
    Write-Host "Starting deployment..." -ForegroundColor Yellow
    $deployment = New-AzResourceGroupDeployment `
        -Name $DeploymentName `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParametersFile `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "Deployment completed successfully!" -ForegroundColor Green
        
        # Display deployment outputs
        if ($deployment.Outputs) {
            Write-Host "`nDeployment Outputs:" -ForegroundColor Cyan
            foreach ($output in $deployment.Outputs.GetEnumerator()) {
                Write-Host "  $($output.Key): $($output.Value.Value)" -ForegroundColor White
            }
        }
        
        # Display next steps
        Write-Host "`nNext Steps:" -ForegroundColor Cyan
        Write-Host "1. Configure your backend applications to accept traffic from the Application Gateway subnet" -ForegroundColor White
        Write-Host "2. Update DNS records to point to the Application Gateway public IP" -ForegroundColor White
        Write-Host "3. Configure SSL certificates if using HTTPS" -ForegroundColor White
        Write-Host "4. Set up monitoring and alerts" -ForegroundColor White
        
    } else {
        Write-Error "Deployment failed with state: $($deployment.ProvisioningState)"
        if ($deployment.Error) {
            Write-Error "Error details: $($deployment.Error)"
        }
        exit 1
    }

} catch {
    Write-Error "An error occurred during deployment: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nDeployment script completed." -ForegroundColor Green
