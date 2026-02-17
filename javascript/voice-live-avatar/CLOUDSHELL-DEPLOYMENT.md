# Cloud Shell Deployment Guide - Southeast Asia

## Quick Start

### 1. Open Cloud Shell
- Go to [Azure Portal](https://portal.azure.com)
- Click the **>_** (Cloud Shell) icon at the top
- Choose **Bash** (not PowerShell)
- Make sure you're viewing the **correct subscription** (check breadcrumb at top)

### 2. Clone and Prepare
```bash
# Clone repository (if not already cloned)
git clone <your-repo-url>
cd voice-live-samples/javascript/voice-live-avatar

# Make script executable
chmod +x deploy-cloudshell-sea.sh
```

### 3. Run Deployment
```bash
# Run the deployment script
./deploy-cloudshell-sea.sh
```

The script will:
1. ✅ Verify your Azure subscription in Southeast Asia
2. ✅ Create resource group in `southeastasia` region
3. ✅ Create Azure Container Registry
4. ✅ Build Docker image using ACR Tasks (no local Docker needed!)
5. ✅ Create Container App Environment
6. ✅ Deploy Container App with System-Assigned Managed Identity
7. ✅ **Assign permissions** to access `pw-sea-foundry-resource`
8. ✅ Configure environment variables
9. ✅ Display your application URL

**Total time**: ~10-15 minutes

---

## What the Script Does

### Container App Deployment
- **Region**: Southeast Asia (`southeastasia`)
- **Managed Identity**: System-assigned (automatic)
- **Authentication**: `DefaultAzureCredential` uses the managed identity
- **Port**: 3333 (internal), 443 (HTTPS public)

### RBAC Permissions
- **Role**: `Cognitive Services User`
- **Scope**: `pw-sea-foundry-resource`
- **Effect**: Managed identity can access all models, avatars, and Voice Live features

### No Credentials Needed!
Once deployed, your `app.py` automatically uses managed identity:
```python
# In app.py
get_token = get_bearer_token_provider(DefaultAzureCredential(), "https://ai.azure.com/.default")
# ↑ Automatically uses Container App's managed identity
```

---

## After Deployment

### Access Your Application
```bash
# URL will be shown at the end of deployment, e.g.:
https://voice-live-avatar-sea.yellowrock-xyz.southeastasia.azurecontainerapps.io
```

### View Logs
```bash
az containerapp logs show \
  --name voice-live-avatar-sea \
  --resource-group voice-live-sea-rg \
  -n 100
```

### Update Container Image (after code change)
```bash
# Rebuild and redeploy
./deploy-cloudshell-sea.sh
```

Or manually:
```bash
# Rebuild in ACR
az acr build \
  --registry voiceliveseareg123456 \
  --image voice-live-avatar:latest \
  https://github.com/your-repo.git#main:javascript/voice-live-avatar

# Redeploy
az containerapp update \
  --name voice-live-avatar-sea \
  --resource-group voice-live-sea-rg \
  --image voiceliveseareg123456.azurecr.io/voice-live-avatar:latest
```

---

## Troubleshooting

### Container won't start
```bash
# Check logs
az containerapp logs show \
  --name voice-live-avatar-sea \
  --resource-group voice-live-sea-rg
```

### Can't access Foundry resource
```bash
# Verify role assignment
az role assignment list \
  --scope /subscriptions/<subscription-id>/resourceGroups/pw-sea-foundry-resource/providers/Microsoft.CognitiveServices/accounts/pw-sea-foundry-resource \
  --output table
```

### Get the application URL
```bash
# If you forgot the URL
az containerapp show \
  --name voice-live-avatar-sea \
  --resource-group voice-live-sea-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv
```

---

## Clean Up Resources

```bash
# Delete everything (can't undo!)
az group delete \
  --name voice-live-sea-rg \
  --yes
```

---

## Script Customization

Edit these variables in `deploy-cloudshell-sea.sh` if needed:

```bash
REGION="southeastasia"                    # Change region (if moving away from SE Asia)
RESOURCE_GROUP="voice-live-sea-rg"       # Change resource group name
CONTAINER_APP_NAME="voice-live-avatar-sea" # Change app name
FOUNDRY_PROJECT_NAME="pw-sea-foundry"     # Change Foundry project
```

---

## Permissions Details

### Assigned Roles
- **Cognitive Services User**: Can access all cognitive services in scope (including Voice Live, models, avatars)
- **Cognitive Services OpenAI User**: If available (for GPT model permissions)

### Scope
- **Resource**: `pw-sea-foundry-resource` in `pw-sea-foundry-resource` RG
- **Effect**: Managed identity can use all deployed models and avatars

### How It Works
1. Container App gets a **System-Assigned Managed Identity** automatically
2. Script gets the **Principal ID** of that identity
3. Script assigns **Cognitive Services User** role on Foundry resource
4. When `app.py` runs, `DefaultAzureCredential` detects the managed identity
5. App automatically authenticates to Azure and Foundry without any credentials!

---

## Architecture

```
User Browser (HTTPS)
    ↓
https://voice-live-avatar-sea.azurecontainerapps.io
    ↓
Container App (port 3333)
    ├─ System-Assigned Managed Identity
    ├─ DefaultAzureCredential (auto-configured)
    └─ python app.py
         ↓
Azure AI Services (pw-sea-foundry-resource)
         ├─ Access via Managed Identity
         └─ Voice Live API + Models + Avatars
```

---

## Questions?

- Check logs: `az containerapp logs show --name voice-live-avatar-sea --resource-group voice-live-sea-rg`
- Verify subscription: `az account show`
- List resources: `az resource list --resource-group voice-live-sea-rg`
