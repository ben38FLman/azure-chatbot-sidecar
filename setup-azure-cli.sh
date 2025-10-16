#!/bin/bash

# Simple Azure CLI setup script for Codespace
echo "🔧 Setting up Azure CLI..."

# Check if Azure CLI is already installed
if command -v az &> /dev/null; then
    echo "✅ Azure CLI is already installed:"
    az --version
else
    echo "📦 Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    
    # Verify installation
    if command -v az &> /dev/null; then
        echo "✅ Azure CLI installed successfully:"
        az --version
    else
        echo "❌ Azure CLI installation failed"
        exit 1
    fi
fi

echo ""
echo "🚀 Ready to use Azure CLI!"
echo "Run: az login"