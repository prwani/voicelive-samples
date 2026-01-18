#!/bin/bash

# ============================================================================
# Azure Container Apps Deployment Script for Voice Live Avatar
# ============================================================================
# This script deploys the Voice Live Avatar application to Azure Container Apps
# Prerequisites:
# - Azure CLI installed (https://docs.microsoft.com/cli/azure/install-azure-cli)
# - Docker installed
# - Logged in to Azure CLI (az login)
# ============================================================================

set -e  # Exit on error

# ============================================================================
# Configuration Variables
# ============================================================================

# Required: Set these variables before running
RESOURCE_GROUP="${RESOURCE_GROUP:-voice-live-rg}"
LOCATION="${LOCATION:-eastus2}"  # Avatar supported: eastus2, westus2, southcentralus, westeurope, northeurope, southeastasia, swedencentral
CONTAINER_APP_NAME="${CONTAINER_APP_NAME:-voice-live-avatar}"
CONTAINER_REGISTRY_NAME="${CONTAINER_REGISTRY_NAME:-voicelivereg$RANDOM}"  # Must be globally unique
CONTAINER_APP_ENV="${CONTAINER_APP_ENV:-voice-live-env}"
IMAGE_NAME="voice-live-avatar"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Optional: CNV Voice configuration (pass as build argument if needed)
CNV_VOICE="${CNV_VOICE:-}"

# Optional: AI Service Configuration for Managed Identity
AI_SERVICE_ENDPOINT="${AI_SERVICE_ENDPOINT:-}"
AZURE_FOUNDRY_PROJECT_NAME="${AZURE_FOUNDRY_PROJECT_NAME:-}"

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo "============================================================================"
    echo "$1"
    echo "============================================================================"
}

print_info() {
    echo "ℹ️  $1"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

print_header "Pre-flight Checks"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi
print_success "Azure CLI is installed"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it from: https://www.docker.com/get-started"
    exit 1
fi
print_success "Docker is installed"

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first"
    exit 1
fi
print_success "Logged in to Azure"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
print_info "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# ============================================================================
# Resource Group Creation
# ============================================================================

print_header "Creating Resource Group"

if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    print_info "Resource group '$RESOURCE_GROUP' already exists"
else
    print_info "Creating resource group '$RESOURCE_GROUP' in location '$LOCATION'..."
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none
    print_success "Resource group created"
fi

# ============================================================================
# Azure Container Registry Creation
# ============================================================================

print_header "Setting up Azure Container Registry"

# Make sure registry name is lowercase and alphanumeric only
CONTAINER_REGISTRY_NAME=$(echo "$CONTAINER_REGISTRY_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')

if az acr show --name "$CONTAINER_REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_info "Container registry '$CONTAINER_REGISTRY_NAME' already exists"
else
    print_info "Creating Azure Container Registry '$CONTAINER_REGISTRY_NAME'..."
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CONTAINER_REGISTRY_NAME" \
        --sku Basic \
        --admin-enabled true \
        --location "$LOCATION" \
        --output none
    print_success "Container registry created"
fi

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name "$CONTAINER_REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)
print_info "ACR Login Server: $ACR_LOGIN_SERVER"

# ============================================================================
# Build and Push Docker Image
# ============================================================================

print_header "Building and Pushing Docker Image"

print_info "Logging in to Azure Container Registry..."
az acr login --name "$CONTAINER_REGISTRY_NAME"
print_success "Logged in to ACR"

FULL_IMAGE_NAME="$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
print_info "Building Docker image: $FULL_IMAGE_NAME"

if [ -n "$CNV_VOICE" ]; then
    docker build \
        --build-arg CNV_VOICE="$CNV_VOICE" \
        -t "$FULL_IMAGE_NAME" \
        .
else
    docker build -t "$FULL_IMAGE_NAME" .
fi

print_success "Docker image built"

print_info "Pushing image to Azure Container Registry..."
docker push "$FULL_IMAGE_NAME"
print_success "Image pushed to ACR"

# ============================================================================
# Container Apps Environment Creation
# ============================================================================

print_header "Creating Container Apps Environment"

if az containerapp env show --name "$CONTAINER_APP_ENV" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_info "Container Apps environment '$CONTAINER_APP_ENV' already exists"
else
    print_info "Creating Container Apps environment '$CONTAINER_APP_ENV'..."
    az containerapp env create \
        --name "$CONTAINER_APP_ENV" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none
    print_success "Container Apps environment created"
fi

# ============================================================================
# Get ACR Credentials
# ============================================================================

print_header "Retrieving ACR Credentials"

ACR_USERNAME=$(az acr credential show --name "$CONTAINER_REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$CONTAINER_REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query "passwords[0].value" -o tsv)
print_success "ACR credentials retrieved"

# ============================================================================
# Deploy Container App
# ============================================================================

print_header "Deploying Container App"

if az containerapp show --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_info "Container app '$CONTAINER_APP_NAME' already exists. Updating..."
    
    # Try update with registry credentials
    print_info "Updating container app with new image and credentials..."
    az containerapp registry set \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$ACR_LOGIN_SERVER" \
        --username "$ACR_USERNAME" \
        --password "$ACR_PASSWORD" \
        --output none || true
    
    # Build environment variables
    ENV_VARS="RETURN_CONFIGS=true"
    if [ -n "$CNV_VOICE" ]; then
        ENV_VARS="$ENV_VARS VITE_CNV_VOICE=$CNV_VOICE"
    fi
    if [ -n "$AI_SERVICE_ENDPOINT" ]; then
        ENV_VARS="$ENV_VARS AI_SERVICE_ENDPOINT=$AI_SERVICE_ENDPOINT"
    fi
    if [ -n "$AZURE_FOUNDRY_PROJECT_NAME" ]; then
        ENV_VARS="$ENV_VARS AZURE_FOUNDRY_PROJECT_NAME=$AZURE_FOUNDRY_PROJECT_NAME"
    fi
    
    az containerapp update \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --image "$FULL_IMAGE_NAME" \
        --set-env-vars $ENV_VARS \
        --output none
    
    print_success "Container app updated"
else
    print_info "Creating container app '$CONTAINER_APP_NAME'..."
    
    # Build environment variables
    ENV_VARS="RETURN_CONFIGS=true"
    if [ -n "$CNV_VOICE" ]; then
        ENV_VARS="$ENV_VARS VITE_CNV_VOICE=$CNV_VOICE"
    fi
    if [ -n "$AI_SERVICE_ENDPOINT" ]; then
        ENV_VARS="$ENV_VARS AI_SERVICE_ENDPOINT=$AI_SERVICE_ENDPOINT"
    fi
    if [ -n "$AZURE_FOUNDRY_PROJECT_NAME" ]; then
        ENV_VARS="$ENV_VARS AZURE_FOUNDRY_PROJECT_NAME=$AZURE_FOUNDRY_PROJECT_NAME"
    fi
    
    az containerapp create \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --environment "$CONTAINER_APP_ENV" \
        --image "$FULL_IMAGE_NAME" \
        --registry-server "$ACR_LOGIN_SERVER" \
        --registry-username "$ACR_USERNAME" \
        --registry-password "$ACR_PASSWORD" \
        --target-port 3000 \
        --ingress external \
        --min-replicas 1 \
        --max-replicas 5 \
        --cpu 1.0 \
        --memory 2.0Gi \
        --env-vars $ENV_VARS \
        --output none
    
    print_success "Container app created"
fi

# ============================================================================
# Enable Managed Identity
# ============================================================================

print_header "Configuring Managed Identity"

print_info "Enabling system-assigned managed identity..."
az containerapp identity assign \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --system-assigned \
    --output none

PRINCIPAL_ID=$(az containerapp identity show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query principalId -o tsv)

print_success "Managed Identity enabled with Principal ID: $PRINCIPAL_ID"

# Grant Cognitive Services User role if AI_SERVICE_ENDPOINT is provided
if [ -n "$AI_SERVICE_ENDPOINT" ]; then
    print_info "Granting 'Cognitive Services User' role to managed identity..."
    
    # Extract resource name from endpoint (handles both regional and custom domain)
    AI_RESOURCE_NAME=$(echo "$AI_SERVICE_ENDPOINT" | sed -E 's|https://([^.]+).*|\1|')
    
    # Try to find the AI service resource
    AI_RESOURCE_ID=$(az cognitiveservices account list \
        --query "[?name=='$AI_RESOURCE_NAME'].id" -o tsv 2>/dev/null | head -n 1)
    
    if [ -n "$AI_RESOURCE_ID" ]; then
        az role assignment create \
            --assignee "$PRINCIPAL_ID" \
            --role "Cognitive Services User" \
            --scope "$AI_RESOURCE_ID" \
            --output none 2>/dev/null || print_info "Role assignment may already exist or need manual configuration"
        
        print_success "Role assignment completed"
    else
        print_info "Could not automatically find AI Service resource."
        print_info "Please manually assign 'Cognitive Services User' role to Principal ID: $PRINCIPAL_ID"
        echo "   Run: az role assignment create --assignee $PRINCIPAL_ID --role 'Cognitive Services User' --scope <AI_SERVICE_RESOURCE_ID>"
    fi
else
    print_info "AI_SERVICE_ENDPOINT not set. Please manually assign roles to Principal ID: $PRINCIPAL_ID"
fi

# ============================================================================
# Get Application URL
# ============================================================================

print_header "Deployment Complete"

APP_URL=$(az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn \
    -o tsv)

print_success "Application deployed successfully!"
echo ""
echo "🌐 Application URL: https://$APP_URL"
echo ""
echo "📝 Resource Details:"
echo "   - Resource Group: $RESOURCE_GROUP"
echo "   - Location: $LOCATION"
echo "   - Container App: $CONTAINER_APP_NAME"
echo "   - Container Registry: $CONTAINER_REGISTRY_NAME"
echo "   - Environment: $CONTAINER_APP_ENV"
echo "   - Managed Identity Principal ID: $PRINCIPAL_ID"
echo ""
echo "📊 To view logs, run:"
echo "   az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --follow"
echo ""
echo "🔧 To update the app with a new image, run this script again or:"
echo "   az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --image $FULL_IMAGE_NAME"
echo ""
print_info "Next steps:"
echo "   1. Open https://$APP_URL in your browser"
if [ -z "$AI_SERVICE_ENDPOINT" ]; then
echo "   2. Configure your Azure AI Services endpoint in the UI (or set AI_SERVICE_ENDPOINT env var)"
echo "   3. The app will automatically use Managed Identity for authentication"
else
echo "   2. The app is configured to use AI Service: $AI_SERVICE_ENDPOINT"
echo "   3. Authentication is automatic via Managed Identity (no keys needed)"
fi
echo "   4. Enable avatar feature and start your conversation"
echo ""
