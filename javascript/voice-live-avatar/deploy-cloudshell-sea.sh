#!/bin/bash

####################################################################
# Voice Live Avatar - Azure Cloud Shell Deployment Script
# Region: Southeast Asia (southeastasia)
# Target: Azure Container Apps with Managed Identity
####################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${1}${NC}"
}

log_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

####################################################################
# CONFIGURATION
####################################################################

REGION="southeastasia"
RESOURCE_GROUP="voice-live-sea-rg"
CONTAINER_REGISTRY_NAME="voiceliveseareg$(date +%s | tail -c 6)"
CONTAINER_APP_NAME="voice-live-avatar-sea"
CONTAINER_APP_ENV="voice-live-sea-env"
IMAGE_NAME="voice-live-avatar"

# Foundry Resource Configuration
FOUNDRY_SUBSCRIPTION="default"  # Will use current subscription
FOUNDRY_RESOURCE_GROUP="rg-ai-sea"
FOUNDRY_PROJECT_NAME="pw-sea-foundry"

####################################################################
# STEP 1: Verify Cloud Shell and Azure Subscription
####################################################################

log_info "Step 1: Verifying Cloud Shell and Azure Subscription"

CURRENT_SUBSCRIPTION=$(az account show --query id -o tsv)
CURRENT_TENANT=$(az account show --query tenantId -o tsv)

if [ -z "$CURRENT_SUBSCRIPTION" ]; then
    log_error "Not authenticated to Azure. Run 'az login' first."
    exit 1
fi

log_success "Current Subscription: $CURRENT_SUBSCRIPTION"
log_success "Current Tenant: $CURRENT_TENANT"
log_info "Region: $REGION"

####################################################################
# STEP 2: Create Resource Group
####################################################################

log_info "Step 2: Creating Resource Group in $REGION"

az group create \
    --name "$RESOURCE_GROUP" \
    --location "$REGION" \
    --query "{Name:name, Location:location}" \
    --output table

log_success "Resource Group created: $RESOURCE_GROUP"

####################################################################
# STEP 3: Create Azure Container Registry (ACR)
####################################################################

log_info "Step 3: Creating Azure Container Registry"

az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CONTAINER_REGISTRY_NAME" \
    --sku Basic \
    --admin-enabled true \
    --query "{Name:name, SkuName:sku.name}" \
    --output table

log_success "Container Registry created: $CONTAINER_REGISTRY_NAME"

####################################################################
# STEP 4: Build Image in ACR (ACR Tasks)
####################################################################

log_info "Step 4: Building Docker image in ACR (this may take 5-10 minutes)"
log_info "Repository: $CONTAINER_REGISTRY_NAME"

# Get the git repo URL - assumes we're in the repo root or subdirectory
REPO_URL=$(git config --get remote.origin.url)
if [ -z "$REPO_URL" ]; then
    log_error "Not in a git repository. Please clone the repo first."
    exit 1
fi

log_info "Git Repository: $REPO_URL"

# Build in ACR
# The context is scoped to javascript/voice-live-avatar via the #main:<subdir> syntax,
# so the Dockerfile path is relative to that subdirectory.
az acr build \
    --registry "$CONTAINER_REGISTRY_NAME" \
    --image "$IMAGE_NAME:latest" \
    --file "Dockerfile" \
    "$REPO_URL#main:javascript/voice-live-avatar" \
    --verbose || {
        log_error "ACR build failed. Check logs above."
        exit 1
    }

log_success "Docker image built successfully in ACR"

####################################################################
# STEP 5: Create Container App Environment
####################################################################

log_info "Step 5: Creating Container App Environment"

az containerapp env create \
    --name "$CONTAINER_APP_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$REGION" \
    --query "{Name:name, Location:location}" \
    --output table

log_success "Container App Environment created: $CONTAINER_APP_ENV"

####################################################################
# STEP 6: Deploy Container App with Managed Identity
####################################################################

log_info "Step 6: Deploying Container App with System-Assigned Managed Identity"

# Get ACR credentials for container app to pull the image
ACR_USERNAME=$(az acr credential show --name "$CONTAINER_REGISTRY_NAME" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$CONTAINER_REGISTRY_NAME" --query "passwords[0].value" -o tsv)

az containerapp create \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$CONTAINER_APP_ENV" \
    --image "$CONTAINER_REGISTRY_NAME.azurecr.io/$IMAGE_NAME:latest" \
    --registry-server "$CONTAINER_REGISTRY_NAME.azurecr.io" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --target-port 3333 \
    --ingress external \
    --cpu 1.0 \
    --memory 2.0Gi \
    --min-replicas 1 \
    --max-replicas 3 \
    --query "{Name:name, ProvisioningState:provisioningState, IngressFqdn:properties.configuration.ingress.fqdn}" \
    --output table \
    --system-assigned

log_success "Container App deployed: $CONTAINER_APP_NAME"

# Get the created app details
APP=$(az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{Id:id, Name:name}" -o json)

APP_ID=$(echo "$APP" | grep -o '"Id": "[^"]*' | cut -d'"' -f4)

log_info "Container App ID: $APP_ID"

####################################################################
# STEP 7: Get Managed Identity
####################################################################

log_info "Step 7: Retrieving Managed Identity details"

# Get managed identity principal ID
MANAGED_IDENTITY=$(az containerapp identity show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{PrincipalId:principalId, TenantId:tenantId}" -o json)

PRINCIPAL_ID=$(echo "$MANAGED_IDENTITY" | grep -o '"PrincipalId": "[^"]*' | cut -d'"' -f4)

log_success "Managed Identity Principal ID: $PRINCIPAL_ID"

####################################################################
# STEP 8: Assign RBAC Role to Foundry Resource
####################################################################

log_info "Step 8: Assigning permissions to Foundry Resource"
log_info "Foundry Resource: $FOUNDRY_RESOURCE_GROUP/$FOUNDRY_PROJECT_NAME"

# Get the Foundry resource ID
FOUNDRY_RESOURCE=$(az cognitiveservices account show \
    --name "pw-sea-foundry-resource" \
    --resource-group "$FOUNDRY_RESOURCE_GROUP" \
    --query "id" -o tsv)

if [ -z "$FOUNDRY_RESOURCE" ]; then
    log_error "Could not find Foundry resource: pw-sea-foundry-resource"
    log_info "Make sure the resource exists in $FOUNDRY_RESOURCE_GROUP"
    exit 1
fi

log_success "Foundry Resource ID: $FOUNDRY_RESOURCE"

# Assign "Cognitive Services User" role to the managed identity
log_info "Assigning 'Cognitive Services User' role to managed identity..."

az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role "Cognitive Services User" \
    --scope "$FOUNDRY_RESOURCE" \
    --query "{PrincipalId:principalId, RoleDefinitionName:roleDefinitionName, Scope:scope}" \
    --output table

log_success "Managed Identity assigned to Foundry resource"

# Also assign "Cognitive Services OpenAI User" if available
log_info "Assigning 'Cognitive Services OpenAI User' role to managed identity..."

az role assignment create \
    --assignee "$PRINCIPAL_ID" \
    --role "Cognitive Services OpenAI User" \
    --scope "$FOUNDRY_RESOURCE" \
    --query "{PrincipalId:principalId, RoleDefinitionName:roleDefinitionName, Scope:scope}" \
    --output table 2>/dev/null || log_warning "Cognitive Services OpenAI User role not available (expected)"

####################################################################
# STEP 9: Configure Environment Variables
####################################################################

log_info "Step 9: Updating Container App environment variables"

# Update the container app with required environment variables
az containerapp update \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --set-env-vars \
        AI_SERVICE_ENDPOINT="$FOUNDRY_RESOURCE" \
        AZURE_FOUNDRY_PROJECT_NAME="$FOUNDRY_PROJECT_NAME" \
        RETURN_CONFIGS="true" \
    --query "{Name:name}" --output table

log_success "Environment variables configured"

####################################################################
# STEP 10: Get Deployment URL
####################################################################

log_info "Step 10: Retrieving deployment URL"

INGRESS_URL=$(az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.configuration.ingress.fqdn" -o tsv)

if [ -z "$INGRESS_URL" ]; then
    log_warning "Could not retrieve ingress URL. Container app deployment may still be initializing."
else
    log_success "Application Ingress URL: https://$INGRESS_URL"
fi

####################################################################
# SUMMARY
####################################################################

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Deployment Summary:${NC}"
echo "  Region:                   $REGION"
echo "  Resource Group:           $RESOURCE_GROUP"
echo "  Container Registry:       $CONTAINER_REGISTRY_NAME.azurecr.io"
echo "  Container App:            $CONTAINER_APP_NAME"
echo "  Container App Env:        $CONTAINER_APP_ENV"
echo "  Managed Identity:         $PRINCIPAL_ID"
echo ""
echo -e "${BLUE}Foundry Integration:${NC}"
echo "  Foundry Resource Group:   $FOUNDRY_RESOURCE_GROUP"
echo "  Foundry Project:          $FOUNDRY_PROJECT_NAME"
echo "  Identity Permissions:     ✅ Assigned"
echo ""
echo -e "${BLUE}Access:${NC}"
if [ ! -z "$INGRESS_URL" ]; then
    echo "  URL: https://$INGRESS_URL"
else
    echo "  URL: Retrieving... (may take 1-2 minutes)"
    echo "  Run: az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP"
fi
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  View logs:                az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP -n 100"
echo "  Update image:             az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --image <new-image>"
echo "  Delete all resources:     az group delete --name $RESOURCE_GROUP --yes"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""

log_success "Notes:"
log_success "- Container App uses System-Assigned Managed Identity"
log_success "- Managed Identity has access to Foundry resource and all models/avatars"
log_success "- DefaultAzureCredential in app.py will automatically use this identity"
log_success "- No explicit credentials needed in Container App!"
echo ""
