# Quick Deployment Reference

## 🚀 One-Command Deployment

```bash
# Linux/macOS
./deploy-to-azure.sh

# Windows PowerShell
.\deploy-to-azure.ps1
```

## 📋 Prerequisites Checklist

- [ ] Azure CLI installed: `az --version`
- [ ] Docker installed: `docker --version`
- [ ] Logged into Azure: `az login`
- [ ] Azure subscription active

## 🎯 Deployment Options

### Option 1: Bash Script (Linux/macOS)
```bash
chmod +x deploy-to-azure.sh
./deploy-to-azure.sh
```

### Option 2: PowerShell Script (Windows)
```powershell
.\deploy-to-azure.ps1
```

### Option 3: Custom Configuration
```bash
export RESOURCE_GROUP="my-rg"
export LOCATION="westus2"
export CONTAINER_APP_NAME="my-app"
./deploy-to-azure.sh
```

### Option 4: Bicep IaC
```bash
# Create resource group
az group create --name voice-live-rg --location eastus2

# Deploy infrastructure
az deployment group create \
  --resource-group voice-live-rg \
  --template-file infrastructure.bicep \
  --parameters location=eastus2

# Get registry and build/push image
ACR_NAME=$(az deployment group show \
  --resource-group voice-live-rg \
  --name infrastructure \
  --query properties.outputs.containerRegistryName.value -o tsv)

az acr login --name $ACR_NAME
docker build -t $ACR_NAME.azurecr.io/voice-live-avatar:latest .
docker push $ACR_NAME.azurecr.io/voice-live-avatar:latest

# Update container app
az containerapp update \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --image $ACR_NAME.azurecr.io/voice-live-avatar:latest
```

## 🌍 Supported Regions for Avatar

- `eastus2` - East US 2
- `westus2` - West US 2
- `southcentralus` - South Central US
- `westeurope` - West Europe
- `northeurope` - North Europe
- `southeastasia` - Southeast Asia
- `swedencentral` - Sweden Central

## 🔧 Post-Deployment

### View Application
```bash
az containerapp show \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --query properties.configuration.ingress.fqdn -o tsv
```

### Stream Logs
```bash
az containerapp logs show \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --follow
```

### Update Application
```bash
# Rebuild and push
docker build -t <acr-name>.azurecr.io/voice-live-avatar:v2 .
docker push <acr-name>.azurecr.io/voice-live-avatar:v2

# Update container app
az containerapp update \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --image <acr-name>.azurecr.io/voice-live-avatar:v2
```

## 🔐 Environment Variables

Set secrets via Azure CLI:
```bash
az containerapp secret set \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --secrets "api-key=your-secret"

az containerapp update \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --set-env-vars "API_KEY=secretref:api-key"
```

## 📊 Monitoring

### Application Insights (Optional)
```bash
# Create Application Insights
az monitor app-insights component create \
  --app voice-live-insights \
  --location eastus2 \
  --resource-group voice-live-rg

# Get instrumentation key
INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app voice-live-insights \
  --resource-group voice-live-rg \
  --query instrumentationKey -o tsv)

# Add to container app
az containerapp update \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --set-env-vars "APPINSIGHTS_INSTRUMENTATIONKEY=$INSTRUMENTATION_KEY"
```

## 🧹 Cleanup

```bash
# Delete all resources
az group delete --name voice-live-rg --yes --no-wait
```

## 🆘 Troubleshooting

### Check Container App Status
```bash
az containerapp show \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --query "properties.runningStatus"
```

### View Revisions
```bash
az containerapp revision list \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --output table
```

### Check Ingress Configuration
```bash
az containerapp ingress show \
  --name voice-live-avatar \
  --resource-group voice-live-rg
```

### Common Issues

**Image pull errors:**
```bash
# Verify ACR credentials
az acr credential show --name <acr-name>

# Test ACR login
az acr login --name <acr-name>
```

**App not responding:**
```bash
# Check logs
az containerapp logs show \
  --name voice-live-avatar \
  --resource-group voice-live-rg \
  --tail 100
```

**Port issues:**
- Ensure Dockerfile exposes port 3000
- Verify `--target-port 3000` in deployment

## 📚 Additional Resources

- [Azure Container Apps Docs](https://learn.microsoft.com/azure/container-apps/)
- [Azure Speech Services Docs](https://learn.microsoft.com/azure/ai-services/speech-service/)
- [Voice Live API Docs](https://learn.microsoft.com/azure/ai-services/speech-service/voice-live)
- Full documentation: See [DEPLOYMENT.md](DEPLOYMENT.md)
