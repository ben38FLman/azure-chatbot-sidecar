# Troubleshooting Script for ChatBot Sidecar Deployment
# This script helps diagnose deployment issues and provides detailed information

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-chatbot-sidecar-nonprod",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipResourceGroupCreation
)

Write-Host "🔧 ChatBot Sidecar Deployment Troubleshooting Script" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check Azure CLI installation and login
function Test-AzureCLI {
    Write-ColorOutput "🔍 Checking Azure CLI..." "Yellow"
    
    try {
        $azVersion = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Azure CLI version: $($azVersion.'azure-cli')" "Green"
        
        # Check if logged in
        $account = az account show --output json 2>$null | ConvertFrom-Json
        if ($account) {
            Write-ColorOutput "✅ Logged in as: $($account.user.name)" "Green"
            Write-ColorOutput "📍 Current subscription: $($account.name) ($($account.id))" "Green"
            return $true
        } else {
            Write-ColorOutput "❌ Not logged into Azure. Please run 'az login'" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Azure CLI not found or not working. Please install Azure CLI." "Red"
        return $false
    }
}

# Function to validate and create resource group
function Test-ResourceGroup {
    param([string]$rgName, [string]$location)
    
    Write-ColorOutput "🔍 Checking resource group: $rgName" "Yellow"
    
    try {
        $rg = az group show --name $rgName --output json 2>$null | ConvertFrom-Json
        if ($rg) {
            Write-ColorOutput "✅ Resource group exists: $($rg.name) in $($rg.location)" "Green"
            return $true
        }
    } catch {
        # Resource group doesn't exist
    }
    
    if (-not $SkipResourceGroupCreation) {
        Write-ColorOutput "⚠️  Resource group '$rgName' not found. Creating..." "Yellow"
        try {
            az group create --name $rgName --location $location --output json | Out-Null
            Write-ColorOutput "✅ Resource group created successfully" "Green"
            return $true
        } catch {
            Write-ColorOutput "❌ Failed to create resource group: $_" "Red"
            return $false
        }
    } else {
        Write-ColorOutput "❌ Resource group '$rgName' not found and creation skipped" "Red"
        return $false
    }
}

# Function to validate Bicep template
function Test-BicepTemplate {
    Write-ColorOutput "🔍 Validating Bicep template..." "Yellow"
    
    $templateFile = "ChatbotAppService-Sidecar.bicep"
    $paramFile = "ChatbotAppService-Sidecar.bicepparam"
    
    if (-not (Test-Path $templateFile)) {
        Write-ColorOutput "❌ Template file not found: $templateFile" "Red"
        return $false
    }
    
    if (-not (Test-Path $paramFile)) {
        Write-ColorOutput "❌ Parameter file not found: $paramFile" "Red"
        return $false
    }
    
    try {
        Write-ColorOutput "📝 Running template validation..." "Yellow"
        $validation = az deployment group validate `
            --resource-group $ResourceGroupName `
            --template-file $templateFile `
            --parameters @$paramFile `
            --output json | ConvertFrom-Json
            
        if ($validation.error) {
            Write-ColorOutput "❌ Template validation failed:" "Red"
            Write-ColorOutput $validation.error.message "Red"
            if ($validation.error.details) {
                foreach ($detail in $validation.error.details) {
                    Write-ColorOutput "  - $($detail.message)" "Red"
                }
            }
            return $false
        } else {
            Write-ColorOutput "✅ Template validation passed" "Green"
            return $true
        }
    } catch {
        Write-ColorOutput "❌ Template validation error: $_" "Red"
        return $false
    }
}

# Function to check for existing resources that might conflict
function Test-ExistingResources {
    Write-ColorOutput "🔍 Checking for existing resources..." "Yellow"
    
    try {
        $resources = az resource list --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
        if ($resources -and $resources.Count -gt 0) {
            Write-ColorOutput "⚠️  Found $($resources.Count) existing resources in the resource group:" "Yellow"
            foreach ($resource in $resources) {
                Write-ColorOutput "  - $($resource.name) ($($resource.type))" "Yellow"
            }
        } else {
            Write-ColorOutput "✅ No existing resources found - clean deployment" "Green"
        }
    } catch {
        Write-ColorOutput "⚠️  Could not list existing resources: $_" "Yellow"
    }
}

# Function to test deployment with what-if
function Test-DeploymentWhatIf {
    Write-ColorOutput "🔍 Running deployment what-if analysis..." "Yellow"
    
    $templateFile = "ChatbotAppService-Sidecar.bicep"
    $paramFile = "ChatbotAppService-Sidecar.bicepparam"
    
    try {
        Write-ColorOutput "📊 Analyzing what resources will be created/modified..." "Yellow"
        az deployment group what-if `
            --resource-group $ResourceGroupName `
            --template-file $templateFile `
            --parameters @$paramFile `
            --output table
            
        Write-ColorOutput "✅ What-if analysis completed" "Green"
        return $true
    } catch {
        Write-ColorOutput "❌ What-if analysis failed: $_" "Red"
        return $false
    }
}

# Function to check Azure resource quotas
function Test-Quotas {
    Write-ColorOutput "🔍 Checking Azure quotas and limits..." "Yellow"
    
    try {
        # Check App Service plan quota
        $usage = az appservice plan list --output json | ConvertFrom-Json
        Write-ColorOutput "📊 Current App Service Plans: $($usage.Count)" "Green"
        
        # Check location availability
        $locations = az account list-locations --output json | ConvertFrom-Json
        $locationExists = $locations | Where-Object { $_.name -eq $Location }
        if ($locationExists) {
            Write-ColorOutput "✅ Location '$Location' is available" "Green"
        } else {
            Write-ColorOutput "❌ Location '$Location' is not available" "Red"
            Write-ColorOutput "Available locations:" "Yellow"
            $locations | Select-Object -First 10 | ForEach-Object { Write-ColorOutput "  - $($_.name) ($($_.displayName))" "White" }
        }
    } catch {
        Write-ColorOutput "⚠️  Could not check quotas: $_" "Yellow"
    }
}

# Function to suggest fixes for common issues
function Show-CommonSolutions {
    Write-ColorOutput "`n🔧 Common Solutions for Deployment Issues:" "Cyan"
    Write-ColorOutput "==========================================" "Cyan"
    
    Write-ColorOutput "`n1. Resource Naming Conflicts:" "Yellow"
    Write-ColorOutput "   - Resource names must be globally unique for some services" "White"
    Write-ColorOutput "   - The template now includes unique suffixes to prevent conflicts" "White"
    Write-ColorOutput "   - Check if resources with similar names already exist" "White"
    
    Write-ColorOutput "`n2. Service Principal Permissions:" "Yellow"
    Write-ColorOutput "   - Ensure your account/service principal has Contributor role" "White"
    Write-ColorOutput "   - Check if subscription has policy restrictions" "White"
    Write-ColorOutput "   - Verify resource group permissions" "White"
    
    Write-ColorOutput "`n3. Resource Provider Registration:" "Yellow"
    Write-ColorOutput "   - Run: az provider register --namespace Microsoft.Web" "White"
    Write-ColorOutput "   - Run: az provider register --namespace Microsoft.OperationalInsights" "White"
    Write-ColorOutput "   - Run: az provider register --namespace Microsoft.Insights" "White"
    
    Write-ColorOutput "`n4. Template Issues:" "Yellow"
    Write-ColorOutput "   - Ensure all parameter values are valid" "White"
    Write-ColorOutput "   - Check API versions are current" "White"
    Write-ColorOutput "   - Validate Bicep syntax: az bicep build --file ChatbotAppService-Sidecar.bicep" "White"
    
    Write-ColorOutput "`n5. Region Availability:" "Yellow"
    Write-ColorOutput "   - Some features may not be available in all regions" "White"
    Write-ColorOutput "   - Try deploying to a different region if issues persist" "White"
    Write-ColorOutput "   - Check Azure status page for service issues" "White"
}

# Main execution
try {
    # Set subscription if provided
    if ($SubscriptionId) {
        Write-ColorOutput "🔄 Setting subscription to: $SubscriptionId" "Yellow"
        az account set --subscription $SubscriptionId
    }
    
    # Run all checks
    $cliOk = Test-AzureCLI
    if (-not $cliOk) { 
        Show-CommonSolutions
        exit 1 
    }
    
    $rgOk = Test-ResourceGroup -rgName $ResourceGroupName -location $Location
    if (-not $rgOk) { 
        Show-CommonSolutions
        exit 1 
    }
    
    Test-ExistingResources
    Test-Quotas
    
    $templateOk = Test-BicepTemplate
    if (-not $templateOk) { 
        Show-CommonSolutions
        exit 1 
    }
    
    $whatIfOk = Test-DeploymentWhatIf
    if (-not $whatIfOk) { 
        Show-CommonSolutions
        exit 1 
    }
    
    Write-ColorOutput "`n🎉 All checks passed! You should be able to deploy successfully." "Green"
    Write-ColorOutput "`nTo deploy, run:" "Cyan"
    Write-ColorOutput "  .\deploy.ps1 -ResourceGroupName '$ResourceGroupName' -Location '$Location'" "White"
    
} catch {
    Write-ColorOutput "`n❌ Unexpected error occurred: $_" "Red"
    Show-CommonSolutions
    exit 1
}