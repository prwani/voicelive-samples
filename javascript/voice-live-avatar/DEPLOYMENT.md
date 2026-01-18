# Azure Container Apps Deployment Guide

This guide explains how to deploy the Voice Live Avatar application to Azure Container Apps.

## Prerequisites

Before running the deployment script, ensure you have:

1. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
2. **Docker** - [Install Docker](https://www.docker.com/get-started)
3. **Azure Account** - [Create free account](https://azure.microsoft.com/free/ai-services)
4. **Azure AI Services** - Resource created in a supported region

## Supported Regions for Avatar Feature

The avatar feature is available in:
- East US 2 (`eastus2`)
- West US 2 (`westus2`)
- South Central US (`southcentralus`)
- West Europe (`westeurope`)
- North Europe (`northeurope`)
- Southeast Asia (`southeastasia`)
- Sweden Central (`swedencentral`)

## Quick Start

### Option 1: Using the Deployment Script (Recommended)

1. **Login to Azure:**
   ```bash
   az login
   ```

2. **Make the script executable:**
   ```bash
   chmod +x deploy-to-azure.sh
   ```

3. **Run the deployment script:**
   ```bash
   ./deploy-to-azure.sh
   ```

   The script will:
   - Create a resource group
   - Create an Azure Container Registry
   - Build and push your Docker image
   - Create a Container Apps environment
   - Deploy your application

4. **Access your application:**
   The script will output your application URL at the end. Open it in your browser.

### Option 2: Custom Configuration

You can customize the deployment by setting environment variables:

```bash
# Set custom configuration
export RESOURCE_GROUP="my-voice-live-rg"
export LOCATION="eastus2"
export CONTAINER_APP_NAME="my-voice-app"
export CONTAINER_REGISTRY_NAME="myvoicereg"
export CNV_VOICE="your-voice-config"

# Run deployment
./deploy-to-azure.sh
```

### Option 3: Manual Deployment

If you prefer manual steps, follow these commands:

```bash
# 1. Set variables
RESOURCE_GROUP="voice-live-rg"
LOCATION="eastus2"
CONTAINER_REGISTRY_NAME="voicelivereg$RANDOM"
CONTAINER_APP_NAME="voice-live-avatar"
CONTAINER_APP_ENV="voice-live-env"

# 2. Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# 3. Create Azure Container Registry
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_REGISTRY_NAME \
  --sku Basic \
  --admin-enabled true

# 4. Build and push image
az acr login --name $CONTAINER_REGISTRY_NAME
ACR_LOGIN_SERVER=$(az acr show --name $CONTAINER_REGISTRY_NAME --query loginServer -o tsv)
docker build -t $ACR_LOGIN_SERVER/voice-live-avatar:latest .
docker push $ACR_LOGIN_SERVER/voice-live-avatar:latest

# 5. Create Container Apps environment
az containerapp env create \
  --name $CONTAINER_APP_ENV \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# 6. Get ACR credentials
ACR_USERNAME=$(az acr credential show --name $CONTAINER_REGISTRY_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $CONTAINER_REGISTRY_NAME --query "passwords[0].value" -o tsv)

# 7. Deploy Container App
az containerapp create \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --image $ACR_LOGIN_SERVER/voice-live-avatar:latest \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --target-port 3000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 5 \
  --cpu 1.0 \
  --memory 2.0Gi

# 8. Get application URL
az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn \
  -o tsv
```

## Configuration

### Environment Variables

You can set environment variables for your Container App:

```bash
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars "KEY1=value1" "KEY2=value2"
```

### Secrets Management

For sensitive data like API keys, use Container Apps secrets:

```bash
# Add a secret
az containerapp secret set \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --secrets "api-key=your-secret-value"

# Use secret as environment variable
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars "API_KEY=secretref:api-key"
```

## Scaling Configuration

### Manual Scaling

```bash
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --min-replicas 2 \
  --max-replicas 10
```

### Auto-scaling Rules

```bash
# Scale based on HTTP requests
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --scale-rule-name http-rule \
  --scale-rule-type http \
  --scale-rule-http-concurrency 100
```

## Monitoring and Troubleshooting

### View Application Logs

```bash
# Stream logs in real-time
az containerapp logs show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --follow

# View recent logs
az containerapp logs show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --tail 100
```

### View Container App Details

```bash
az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP
```

### Check Revision Status

```bash
az containerapp revision list \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --output table
```

## Updating the Application

To deploy a new version:

```bash
# Option 1: Re-run the deployment script
./deploy-to-azure.sh

# Option 2: Build and push new image, then update
docker build -t $ACR_LOGIN_SERVER/voice-live-avatar:v2 .
docker push $ACR_LOGIN_SERVER/voice-live-avatar:v2
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $ACR_LOGIN_SERVER/voice-live-avatar:v2
```

## CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Azure Container Apps

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Build and push image
        run: |
          az acr login --name ${{ secrets.ACR_NAME }}
          docker build -t ${{ secrets.ACR_NAME }}.azurecr.io/voice-live-avatar:${{ github.sha }} .
          docker push ${{ secrets.ACR_NAME }}.azurecr.io/voice-live-avatar:${{ github.sha }}
      
      - name: Deploy to Container Apps
        run: |
          az containerapp update \
            --name ${{ secrets.CONTAINER_APP_NAME }} \
            --resource-group ${{ secrets.RESOURCE_GROUP }} \
            --image ${{ secrets.ACR_NAME }}.azurecr.io/voice-live-avatar:${{ github.sha }}
```

## Cost Optimization

- **Consumption Plan**: Container Apps automatically scales to zero when not in use
- **Set appropriate min/max replicas**: Adjust based on your traffic patterns
- **Right-size resources**: Start with smaller CPU/memory and scale up if needed
- **Use Basic ACR tier**: Sufficient for most scenarios

## Security Best Practices

1. **Use Managed Identity**: Enable managed identity for secure access to Azure resources
2. **Store secrets securely**: Use Container Apps secrets or Azure Key Vault
3. **Enable HTTPS**: Always use HTTPS for external ingress (enabled by default)
4. **Network isolation**: Consider using VNET integration for production workloads
5. **Update regularly**: Keep base images and dependencies up to date

## Cleanup

To delete all resources:

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Azure AI Services Speech Documentation](https://learn.microsoft.com/azure/ai-services/speech-service/)
- [Voice Live Overview](https://learn.microsoft.com/azure/ai-services/speech-service/voice-live)
- [Container Apps Best Practices](https://learn.microsoft.com/azure/container-apps/best-practices)

## Support

For issues or questions:
- Azure Container Apps: [Azure Support](https://azure.microsoft.com/support/)
- Application-specific: Check the main README.md in this repository
