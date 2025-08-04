# Manual Deployment Script for Testing
# Use this script to test your deployment before setting up the pipeline

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = "ApplicationGateway.json",
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "parameters.json"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "=== Azure Application Gateway Manual Deployment ===" -ForegroundColor Green
Write-Host "Subscription ID: $SubscriptionId" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow

try {
    # Check if user is logged in to Azure
    Write-Host "Checking Azure login status..." -ForegroundColor Cyan
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Not logged in to Azure. Please log in..." -ForegroundColor Yellow
        Connect-AzAccount
    }

    # Set the subscription context
    Write-Host "Setting subscription context..." -ForegroundColor Cyan
    Set-AzContext -SubscriptionId $SubscriptionId

    # Check if resource group exists, create if it doesn't
    Write-Host "Checking if resource group exists..." -ForegroundColor Cyan
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
    Write-Host "Validating ARM template..." -ForegroundColor Cyan
    $validationResult = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile $ParametersFile
    
    if ($validationResult) {
        Write-Error "Template validation failed:"
        foreach ($error in $validationResult) {
            Write-Error "  - $($error.Message)"
        }
        exit 1
    }
    
    Write-Host "✅ Template validation successful." -ForegroundColor Green

    # Deploy the template
    $deploymentName = "AppGateway-Manual-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "Starting deployment: $deploymentName" -ForegroundColor Cyan
    Write-Host "⏳ This may take 10-20 minutes..." -ForegroundColor Yellow
    
    $deployment = New-AzResourceGroupDeployment `
        -Name $deploymentName `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParametersFile `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
        
        # Display deployment outputs
        if ($deployment.Outputs) {
            Write-Host "`n📊 Deployment Outputs:" -ForegroundColor Cyan
            Write-Host "======================" -ForegroundColor Cyan
            foreach ($output in $deployment.Outputs.GetEnumerator()) {
                Write-Host "  $($output.Key): $($output.Value.Value)" -ForegroundColor White
            }
        }
        
        # Get Application Gateway details
        Write-Host "`n🔍 Application Gateway Status:" -ForegroundColor Cyan
        Write-Host "==============================" -ForegroundColor Cyan
        
        $appGatewayName = $deployment.Outputs.applicationGatewayName.Value
        $appGateway = Get-AzApplicationGateway -Name $appGatewayName -ResourceGroupName $ResourceGroupName
        
        Write-Host "  Name: $($appGateway.Name)" -ForegroundColor White
        Write-Host "  Location: $($appGateway.Location)" -ForegroundColor White
        Write-Host "  Provisioning State: $($appGateway.ProvisioningState)" -ForegroundColor White
        Write-Host "  Operational State: $($appGateway.OperationalState)" -ForegroundColor White
        
        # Test connectivity
        if ($deployment.Outputs.publicIPAddress) {
            $publicIP = $deployment.Outputs.publicIPAddress.Value
            Write-Host "`n🌐 Testing Connectivity:" -ForegroundColor Cyan
            Write-Host "========================" -ForegroundColor Cyan
            Write-Host "  Public IP: $publicIP" -ForegroundColor White
            
            try {
                $response = Invoke-WebRequest -Uri "http://$publicIP" -Method GET -TimeoutSec 30 -ErrorAction Stop
                Write-Host "  ✅ HTTP connectivity test successful" -ForegroundColor Green
                Write-Host "  Status Code: $($response.StatusCode)" -ForegroundColor White
            }
            catch {
                Write-Host "  ⚠️ HTTP connectivity test failed (expected if backend not configured)" -ForegroundColor Yellow
                Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Display next steps
        Write-Host "`n🎯 Next Steps:" -ForegroundColor Cyan
        Write-Host "==============" -ForegroundColor Cyan
        Write-Host "1. Configure your backend applications to accept traffic from the Application Gateway subnet" -ForegroundColor White
        Write-Host "2. Set up health probes for backend monitoring" -ForegroundColor White
        Write-Host "3. Configure SSL certificates for HTTPS (if needed)" -ForegroundColor White
        Write-Host "4. Set up monitoring and alerts" -ForegroundColor White
        Write-Host "5. Test end-to-end connectivity" -ForegroundColor White
        
    } else {
        Write-Error "❌ Deployment failed with state: $($deployment.ProvisioningState)"
        if ($deployment.Error) {
            Write-Error "Error details: $($deployment.Error)"
        }
        exit 1
    }

} catch {
    Write-Error "❌ An error occurred during deployment: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n🎉 Manual deployment script completed successfully!" -ForegroundColor Green
Write-Host "You can now set up the Azure DevOps pipeline for automated deployments." -ForegroundColor Cyan
