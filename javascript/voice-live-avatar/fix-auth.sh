#!/bin/bash
# Quick fix script for ACR authentication issues

set -e

RESOURCE_GROUP="${RESOURCE_GROUP:-voice-live-rg}"
CONTAINER_APP_NAME="${CONTAINER_APP_NAME:-voice-live-avatar}"
CONTAINER_REGISTRY_NAME="${CONTAINER_REGISTRY_NAME}"

if [ -z "$CONTAINER_REGISTRY_NAME" ]; then
    echo "Please provide the Container Registry name:"
    read -r CONTAINER_REGISTRY_NAME
fi

echo "Fixing ACR authentication for Container App..."

# Get ACR details
ACR_LOGIN_SERVER=$(az acr show --name "$CONTAINER_REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show --name "$CONTAINER_REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$CONTAINER_REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query "passwords[0].value" -o tsv)

echo "Registry: $ACR_LOGIN_SERVER"
echo "Updating container app registry credentials..."

# Update registry credentials
az containerapp registry set \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --server "$ACR_LOGIN_SERVER" \
    --username "$ACR_USERNAME" \
    --password "$ACR_PASSWORD"

echo "✅ Registry credentials updated!"
echo ""
echo "Now run the deployment script again:"
echo "./deploy-to-azure.sh"
