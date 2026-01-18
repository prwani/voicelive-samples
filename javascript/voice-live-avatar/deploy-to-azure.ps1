# ============================================================================
# Azure Container Apps Deployment Script for Voice Live Avatar (PowerShell)
# ============================================================================
# This script deploys the Voice Live Avatar application to Azure Container Apps
# Prerequisites:
# - Azure CLI installed (https://docs.microsoft.com/cli/azure/install-azure-cli)
# - Docker Desktop installed and running
# - Logged in to Azure CLI (az login)
# ============================================================================

param(
    [string]$ResourceGroup = "voice-live-rg",
    [string]$Location = "eastus2",  # Avatar supported regions
    [string]$ContainerAppName = "voice-live-avatar",
    [string]$ContainerRegistryName = "voicelivereg$(Get-Random -Maximum 9999)",
    [string]$ContainerAppEnv = "voice-live-env",
    [string]$ImageName = "voice-live-avatar",
    [string]$ImageTag = "latest",
    [string]$CnvVoice = ""
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================================" -ForegroundColor Cyan
}

function Write-InfoMessage {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

Write-Header "Pre-flight Checks"

# Check if Azure CLI is installed
try {
    $null = az --version
    Write-SuccessMessage "Azure CLI is installed"
} catch {
    Write-ErrorMessage "Azure CLI is not installed. Please install it from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check if Docker is installed
try {
    $null = docker --version
    Write-SuccessMessage "Docker is installed"
} catch {
    Write-ErrorMessage "Docker is not installed. Please install Docker Desktop from: https://www.docker.com/get-started"
    exit 1
}

# Check if logged in to Azure
try {
    $accountInfo = az account show | ConvertFrom-Json
    Write-SuccessMessage "Logged in to Azure"
    $subscriptionId = $accountInfo.id
    $subscriptionName = $accountInfo.name
    Write-InfoMessage "Using subscription: $subscriptionName ($subscriptionId)"
} catch {
    Write-ErrorMessage "Not logged in to Azure. Please run 'az login' first"
    exit 1
}

# ============================================================================
# Resource Group Creation
# ============================================================================

Write-Header "Creating Resource Group"

try {
    $rgExists = az group show --name $ResourceGroup 2>$null
    if ($rgExists) {
        Write-InfoMessage "Resource group '$ResourceGroup' already exists"
    } else {
        throw
    }
} catch {
    Write-InfoMessage "Creating resource group '$ResourceGroup' in location '$Location'..."
    az group create --name $ResourceGroup --location $Location --output none
    Write-SuccessMessage "Resource group created"
}

# ============================================================================
# Azure Container Registry Creation
# ============================================================================

Write-Header "Setting up Azure Container Registry"

# Ensure registry name is lowercase and alphanumeric only
$ContainerRegistryName = $ContainerRegistryName.ToLower() -replace '[^a-z0-9]', ''

try {
    $acrExists = az acr show --name $ContainerRegistryName --resource-group $ResourceGroup 2>$null
    if ($acrExists) {
        Write-InfoMessage "Container registry '$ContainerRegistryName' already exists"
    } else {
        throw
    }
} catch {
    Write-InfoMessage "Creating Azure Container Registry '$ContainerRegistryName'..."
    az acr create `
        --resource-group $ResourceGroup `
        --name $ContainerRegistryName `
        --sku Basic `
        --admin-enabled true `
        --location $Location `
        --output none
    Write-SuccessMessage "Container registry created"
}

# Get ACR login server
$acrInfo = az acr show --name $ContainerRegistryName --resource-group $ResourceGroup | ConvertFrom-Json
$acrLoginServer = $acrInfo.loginServer
Write-InfoMessage "ACR Login Server: $acrLoginServer"

# ============================================================================
# Build and Push Docker Image
# ============================================================================

Write-Header "Building and Pushing Docker Image"

Write-InfoMessage "Logging in to Azure Container Registry..."
az acr login --name $ContainerRegistryName
Write-SuccessMessage "Logged in to ACR"

$fullImageName = "$acrLoginServer/${ImageName}:${ImageTag}"
Write-InfoMessage "Building Docker image: $fullImageName"

if ($CnvVoice) {
    docker build --build-arg CNV_VOICE=$CnvVoice -t $fullImageName .
} else {
    docker build -t $fullImageName .
}

Write-SuccessMessage "Docker image built"

Write-InfoMessage "Pushing image to Azure Container Registry..."
docker push $fullImageName
Write-SuccessMessage "Image pushed to ACR"

# ============================================================================
# Container Apps Environment Creation
# ============================================================================

Write-Header "Creating Container Apps Environment"

try {
    $envExists = az containerapp env show --name $ContainerAppEnv --resource-group $ResourceGroup 2>$null
    if ($envExists) {
        Write-InfoMessage "Container Apps environment '$ContainerAppEnv' already exists"
    } else {
        throw
    }
} catch {
    Write-InfoMessage "Creating Container Apps environment '$ContainerAppEnv'..."
    az containerapp env create `
        --name $ContainerAppEnv `
        --resource-group $ResourceGroup `
        --location $Location `
        --output none
    Write-SuccessMessage "Container Apps environment created"
}

# ============================================================================
# Get ACR Credentials
# ============================================================================

Write-Header "Retrieving ACR Credentials"

$acrCreds = az acr credential show --name $ContainerRegistryName --resource-group $ResourceGroup | ConvertFrom-Json
$acrUsername = $acrCreds.username
$acrPassword = $acrCreds.passwords[0].value
Write-SuccessMessage "ACR credentials retrieved"

# ============================================================================
# Deploy Container App
# ============================================================================

Write-Header "Deploying Container App"

try {
    $appExists = az containerapp show --name $ContainerAppName --resource-group $ResourceGroup 2>$null
    if ($appExists) {
        Write-InfoMessage "Container app '$ContainerAppName' already exists. Updating..."
        
        # Update registry credentials first to avoid authentication issues
        Write-InfoMessage "Updating container app with new image and credentials..."
        az containerapp registry set `
            --name $ContainerAppName `
            --resource-group $ResourceGroup `
            --server $acrLoginServer `
            --username $acrUsername `
            --password $acrPassword `
            --output none 2>$null
        
        az containerapp update `
            --name $ContainerAppName `
            --resource-group $ResourceGroup `
            --image $fullImageName `
            --output none
        
        Write-SuccessMessage "Container app updated"
    } else {
        throw
    }
} catch {
    Write-InfoMessage "Creating container app '$ContainerAppName'..."
    
    $createArgs = @(
        "containerapp", "create",
        "--name", $ContainerAppName,
        "--resource-group", $ResourceGroup,
        "--environment", $ContainerAppEnv,
        "--image", $fullImageName,
        "--registry-server", $acrLoginServer,
        "--registry-username", $acrUsername,
        "--registry-password", $acrPassword,
        "--target-port", "3000",
        "--ingress", "external",
        "--min-replicas", "1",
        "--max-replicas", "5",
        "--cpu", "1.0",
        "--memory", "2.0Gi",
        "--output", "none"
    )
    
    if ($CnvVoice) {
        $createArgs += "--env-vars"
        $createArgs += "VITE_CNV_VOICE=$CnvVoice"
    }
    
    & az $createArgs
    
    Write-SuccessMessage "Container app created"
}

# ============================================================================
# Get Application URL
# ============================================================================

Write-Header "Deployment Complete"

$appInfo = az containerapp show `
    --name $ContainerAppName `
    --resource-group $ResourceGroup | ConvertFrom-Json

$appUrl = $appInfo.properties.configuration.ingress.fqdn

Write-SuccessMessage "Application deployed successfully!"
Write-Host ""
Write-Host "🌐 Application URL: https://$appUrl" -ForegroundColor Yellow
Write-Host ""
Write-Host "📝 Resource Details:" -ForegroundColor Cyan
Write-Host "   - Resource Group: $ResourceGroup"
Write-Host "   - Location: $Location"
Write-Host "   - Container App: $ContainerAppName"
Write-Host "   - Container Registry: $ContainerRegistryName"
Write-Host "   - Environment: $ContainerAppEnv"
Write-Host ""
Write-Host "📊 To view logs, run:" -ForegroundColor Cyan
Write-Host "   az containerapp logs show --name $ContainerAppName --resource-group $ResourceGroup --follow"
Write-Host ""
Write-Host "🔧 To update the app with a new image, run this script again or:" -ForegroundColor Cyan
Write-Host "   az containerapp update --name $ContainerAppName --resource-group $ResourceGroup --image $fullImageName"
Write-Host ""
Write-InfoMessage "Next steps:"
Write-Host "   1. Open https://$appUrl in your browser"
Write-Host "   2. Configure your Azure AI Services endpoint and subscription key"
Write-Host "   3. Enable avatar feature and start your conversation"
Write-Host ""
