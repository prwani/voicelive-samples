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
    
    # Update with registry credentials to avoid authentication issues
    UPDATE_CMD="az containerapp update \
        --name \"$CONTAINER_APP_NAME\" \
        --resource-group \"$RESOURCE_GROUP\" \
        --image \"$FULL_IMAGE_NAME\" \
        --set-env-vars VITE_CNV_VOICE=\"$CNV_VOICE\" \
        --output none"
    
    # Try update with registry credentials
    print_info "Updating container app with new image and credentials..."
    az containerapp registry set \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$ACR_LOGIN_SERVER" \
        --username "$ACR_USERNAME" \
        --password "$ACR_PASSWORD" \
        --output none || true
    
    az containerapp update \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --image "$FULL_IMAGE_NAME" \
        --output none
    
    print_success "Container app updated"
else
    print_info "Creating container app '$CONTAINER_APP_NAME'..."
    
    CREATE_CMD="az containerapp create \
        --name \"$CONTAINER_APP_NAME\" \
        --resource-group \"$RESOURCE_GROUP\" \
        --environment \"$CONTAINER_APP_ENV\" \
        --image \"$FULL_IMAGE_NAME\" \
        --registry-server \"$ACR_LOGIN_SERVER\" \
        --registry-username \"$ACR_USERNAME\" \
        --registry-password \"$ACR_PASSWORD\" \
        --target-port 3000 \
        --ingress external \
        --min-replicas 1 \
        --max-replicas 5 \
        --cpu 1.0 \
        --memory 2.0Gi \
        --output none"
    
    # Add CNV_VOICE environment variable if provided
    if [ -n "$CNV_VOICE" ]; then
        CREATE_CMD="$CREATE_CMD --env-vars VITE_CNV_VOICE=\"$CNV_VOICE\""
    fi
    
    eval "$CREATE_CMD"
    
    print_success "Container app created"
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
echo ""
echo "📊 To view logs, run:"
echo "   az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --follow"
echo ""
echo "🔧 To update the app with a new image, run this script again or:"
echo "   az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --image $FULL_IMAGE_NAME"
echo ""
print_info "Next steps:"
echo "   1. Open https://$APP_URL in your browser"
echo "   2. Configure your Azure AI Services endpoint and subscription key"
echo "   3. Enable avatar feature and start your conversation"
echo ""
