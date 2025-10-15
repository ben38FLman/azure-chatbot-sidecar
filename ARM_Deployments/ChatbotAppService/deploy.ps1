# Azure App Service with Sidecar - PowerShell Deployment Script
# This script deploys the chatbot application with Phi-4 sidecar to Azure App Service

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-chatbot-sidecar-nonprod",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipConfirmation,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipTest
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DeploymentName = "ChatbotSidecar-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$BicepFile = Join-Path $ScriptDir "ChatbotAppService-Sidecar.bicep"
$ParametersFile = Join-Path $ScriptDir "ChatbotAppService-Sidecar.bicepparam"

# Logging functions
function Write-InfoLog {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-SuccessLog {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-WarningLog {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-ErrorLog {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-InfoLog "Checking prerequisites..."
    
    # Check if Azure PowerShell module is installed
    if (-not (Get-Module -ListAvailable -Name Az)) {
        Write-ErrorLog "Azure PowerShell module is not installed. Please install it using: Install-Module -Name Az -AllowClobber -Scope CurrentUser"
        exit 1
    }
    
    # Check if user is logged in
    try {
        $context = Get-AzContext
        if (-not $context) {
            throw "Not logged in"
        }
    }
    catch {
        Write-ErrorLog "You are not logged in to Azure. Please run 'Connect-AzAccount' first."
        exit 1
    }
    
    # Check if Bicep file exists
    if (-not (Test-Path $BicepFile)) {
        Write-ErrorLog "Bicep file not found: $BicepFile"
        exit 1
    }
    
    # Check if parameters file exists
    if (-not (Test-Path $ParametersFile)) {
        Write-ErrorLog "Parameters file not found: $ParametersFile"
        exit 1
    }
    
    Write-SuccessLog "Prerequisites check passed"
}

# Function to display deployment information
function Show-DeploymentInfo {
    Write-InfoLog "Deployment Configuration:"
    Write-Host "  Resource Group: $ResourceGroupName"
    Write-Host "  Location: $Location"
    Write-Host "  Deployment Name: $DeploymentName"
    Write-Host "  Bicep File: $BicepFile"
    Write-Host "  Parameters File: $ParametersFile"
    
    $context = Get-AzContext
    Write-Host "  Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
    Write-Host ""
}

# Function to set subscription
function Set-AzureSubscription {
    if ($SubscriptionId) {
        Write-InfoLog "Setting subscription to: $SubscriptionId"
        try {
            Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
            Write-SuccessLog "Subscription set successfully"
        }
        catch {
            Write-ErrorLog "Failed to set subscription: $($_.Exception.Message)"
            exit 1
        }
    }
}

# Function to create resource group
function New-ResourceGroupIfNotExists {
    Write-InfoLog "Creating resource group '$ResourceGroupName' in '$Location'..."
    
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if ($rg) {
            Write-InfoLog "Resource group already exists"
        }
        else {
            $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
            Write-SuccessLog "Resource group created successfully"
        }
    }
    catch {
        Write-ErrorLog "Failed to create resource group: $($_.Exception.Message)"
        exit 1
    }
}

# Function to validate deployment
function Test-AzureDeployment {
    Write-InfoLog "Validating Bicep deployment..."
    
    try {
        $validation = Test-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $BicepFile `
            -TemplateParameterFile $ParametersFile
        
        if ($validation) {
            Write-ErrorLog "Deployment validation failed:"
            $validation | ForEach-Object {
                Write-Host "  - $($_.Message)" -ForegroundColor Red
            }
            exit 1
        }
        else {
            Write-SuccessLog "Deployment validation passed"
        }
    }
    catch {
        Write-ErrorLog "Deployment validation failed: $($_.Exception.Message)"
        exit 1
    }
}

# Function to deploy infrastructure
function Deploy-Infrastructure {
    Write-InfoLog "Deploying infrastructure..."
    
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $BicepFile `
            -TemplateParameterFile $ParametersFile `
            -Name $DeploymentName `
            -Verbose
        
        if ($deployment.ProvisioningState -eq "Succeeded") {
            Write-SuccessLog "Infrastructure deployment completed"
            return $deployment
        }
        else {
            Write-ErrorLog "Infrastructure deployment failed with state: $($deployment.ProvisioningState)"
            exit 1
        }
    }
    catch {
        Write-ErrorLog "Infrastructure deployment failed: $($_.Exception.Message)"
        exit 1
    }
}

# Function to deploy application code
function Deploy-Application {
    param([object]$Deployment)
    
    $appName = $Deployment.Outputs.appServiceName.Value
    if (-not $appName) {
        Write-ErrorLog "Could not retrieve App Service name from deployment outputs"
        exit 1
    }
    
    Write-InfoLog "Deploying application code to '$appName'..."
    
    try {
        # Navigate to application directory
        $appDir = Join-Path $ScriptDir "sidecar-app"
        Push-Location $appDir
        
        # Create deployment package
        if (Test-Path "package.json") {
            Write-InfoLog "Installing application dependencies..."
            npm install --production
            if ($LASTEXITCODE -ne 0) {
                throw "NPM install failed"
            }
        }
        
        # Create zip file for deployment
        $zipPath = Join-Path $env:TEMP "sidecar-app-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
        Write-InfoLog "Creating deployment package: $zipPath"
        
        # Compress application files
        $excludePatterns = @("node_modules\**", ".git\**", "*.log", ".env")
        Compress-Archive -Path ".\*" -DestinationPath $zipPath -Force
        
        # Deploy using Azure CLI (more reliable for zip deployment)
        Write-InfoLog "Deploying application package..."
        $deployCmd = "az webapp deploy --resource-group '$ResourceGroupName' --name '$appName' --src-path '$zipPath' --type zip --timeout 300"
        Invoke-Expression $deployCmd
        
        if ($LASTEXITCODE -eq 0) {
            Write-SuccessLog "Application deployment completed"
        }
        else {
            throw "Application deployment failed"
        }
        
        # Clean up zip file
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-ErrorLog "Application deployment failed: $($_.Exception.Message)"
        exit 1
    }
    finally {
        Pop-Location
    }
}

# Function to show deployment outputs
function Show-DeploymentOutputs {
    param([object]$Deployment)
    
    Write-InfoLog "Deployment outputs:"
    
    $outputs = $Deployment.Outputs
    foreach ($output in $outputs.GetEnumerator()) {
        Write-Host "  $($output.Key): $($output.Value.Value)"
    }
    
    $appUrl = $outputs.appServiceUrl.Value
    if ($appUrl) {
        Write-Host ""
        Write-SuccessLog "Application deployed successfully!"
        Write-Host "  🌐 Application URL: $appUrl" -ForegroundColor Cyan
        Write-Host "  🏥 Health Check: $appUrl/health" -ForegroundColor Cyan
        Write-Host "  📖 API Info: $appUrl/api/info" -ForegroundColor Cyan
        Write-Host ""
        Write-InfoLog "Next Steps:"
        Write-Host "  1. Open the application URL in your browser"
        Write-Host "  2. Check the health endpoints to verify deployment"
        Write-Host "  3. Create a new chat session to test the AI functionality"
        Write-Host "  4. Monitor logs using Azure Portal or Azure CLI"
        
        return $appUrl
    }
}

# Function to test deployment
function Test-Deployment {
    param([string]$AppUrl)
    
    if ($SkipTest) {
        Write-InfoLog "Skipping deployment test"
        return
    }
    
    if ($AppUrl) {
        Write-InfoLog "Testing deployment..."
        
        # Wait for app to be ready
        Write-InfoLog "Waiting for application to start (60 seconds)..."
        Start-Sleep -Seconds 60
        
        try {
            # Test health endpoint
            Write-InfoLog "Testing health endpoint..."
            $healthResponse = Invoke-RestMethod -Uri "$AppUrl/health" -Method Get -TimeoutSec 10
            if ($healthResponse.status -eq "healthy") {
                Write-SuccessLog "Health check passed"
            }
            else {
                Write-WarningLog "Health check returned: $($healthResponse.status)"
            }
        }
        catch {
            Write-WarningLog "Health check failed - app may need more time to start"
        }
        
        try {
            # Test API info endpoint
            Write-InfoLog "Testing API info endpoint..."
            $apiResponse = Invoke-RestMethod -Uri "$AppUrl/api/info" -Method Get -TimeoutSec 10
            if ($apiResponse.name) {
                Write-SuccessLog "API info endpoint accessible"
            }
        }
        catch {
            Write-WarningLog "API info endpoint not accessible"
        }
    }
}

# Main execution
function Main {
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "🤖 Azure App Service with Sidecar" -ForegroundColor Cyan
    Write-Host "    PowerShell Deployment Script" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    
    Test-Prerequisites
    Set-AzureSubscription
    Show-DeploymentInfo
    
    # Confirm deployment
    if (-not $SkipConfirmation) {
        $confirm = Read-Host "Do you want to proceed with the deployment? (y/N)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-InfoLog "Deployment cancelled by user"
            return
        }
    }
    
    Write-Host ""
    Write-InfoLog "Starting deployment process..."
    
    New-ResourceGroupIfNotExists
    Test-AzureDeployment
    $deployment = Deploy-Infrastructure
    Deploy-Application -Deployment $deployment
    $appUrl = Show-DeploymentOutputs -Deployment $deployment
    Test-Deployment -AppUrl $appUrl
    
    Write-Host ""
    Write-SuccessLog "🎉 Deployment completed successfully!"
    Write-Host ""
}

# Error handling
trap {
    Write-ErrorLog "Deployment failed: $($_.Exception.Message)"
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

# Run main function
Main