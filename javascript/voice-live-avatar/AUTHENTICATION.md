# Authentication Guide - Voice Live Avatar

## Overview

Authentication is now **fully automatic** using Azure's `DefaultAzureCredential`. Users don't need to manually input tokens anymore. The application automatically uses the appropriate credentials based on the environment.

## Authentication Flow

### Authorization Chain (Automatic)

The backend uses `DefaultAzureCredential` which tries credentials in this order:

1. **Environment Variables** (Service Principal)
   ```bash
   # For CI/CD and container deployments
   export AZURE_CLIENT_ID="..."
   export AZURE_CLIENT_SECRET="..."
   export AZURE_TENANT_ID="..."
   ```

2. **Managed Identity** (Container Apps 🏆 Recommended for Production)
   - Automatically used when deployed to Azure Container Apps
   - No credentials needed - fully managed by Azure

3. **Azure CLI** (Local Development 🏆 Recommended for Local)
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

4. **Azure PowerShell**
   ```powershell
   Connect-AzAccount
   Set-AzContext -SubscriptionId <subscription-id>
   ```

5. **Visual Studio**
   - Automatically detected if you're signed into Visual Studio

6. **Visual Studio Code**
   - Uses Azure extension credentials if installed

## Setup per Environment

### Local Development

**Minimum setup:**
```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription <your-subscription-id>

# Start the application
npm run dev  # Next.js dev server on 3001
python app.py --port 3333  # Python backend on 3333
```

The application will automatically use your logged-in Azure credentials. No manual token input needed!

### Container Apps Deployment

**No additional setup needed!** Azure Container Apps automatically provides a managed identity that the application can use. The `DefaultAzureCredential` will automatically detect and use it.

**Deploy example:**
```bash
docker build -t voice-live-avatar .
az containerapp create \
  --name voice-live-avatar \
  --environment $CONTAINER_APP_ENV \
  --registry-server $REGISTRY \
  --registry-username $REGISTRY_USER \
  --registry-password $REGISTRY_PASS \
  --image $IMAGE_NAME \
  --cpu 1.0 \
  --memory 2.0Gi \
  --environment-variables \
    AI_SERVICE_ENDPOINT="$AI_SERVICE_ENDPOINT" \
    RETURN_CONFIGS="true"
```

### CI/CD Pipeline

**Using service principal:**
```bash
# Set environment variables
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_TENANT_ID="your-tenant-id"

# Run the application
npm run build
python app.py
```

## API Key Fallback (Optional)

For non-Azure environments or testing, you can optionally provide an API Key:

1. **Connection Settings** → **Subscription Key (Optional)**
2. Enter your Azure AI Services API Key
3. Leave empty if using Azure Credentials (preferred)

**Precedence:**
- If auto-fetched token is available → **Use it** ✅
- Else if API Key is provided → **Use API Key** (fallback)

## Frontend Authentication Flow

```
User opens app → Frontend fetches /config endpoint
                    ↓
              Backend uses DefaultAzureCredential
                    ↓
              Returns token to frontend
                    ↓
          Frontend stores token (autoToken)
                    ↓
         RTClient uses token for WebSocket connection
                    ↓
         Session established with VoiceLive API
```

## Supported Modes

All authentication methods work with:
- ✅ **Model Mode** - Direct gpt-4o realtime model
- ✅ **Agent Mode** - Azure Foundry agents
- ✅ **Agent V2 Mode** - Latest agent framework
- ✅ **Avatar** - Works with both static and photo avatars

## Secrets Management

### Local Development
- Use `.env` file (already in `.gitignore`)
- Secrets are NOT stored in code or config

### Container Apps
- Use Azure Key Vault integration
- Reference secrets as environment variables:
  ```bash
  --secret AI_SERVICE_ENDPOINT="keyvault-secret-name"
  ```

## Troubleshooting

### "Authentication failed" Error

**Check these in order:**

1. **Are you logged in?**
   ```bash
   az account show
   ```
   If not logged in:
   ```bash
   az login
   ```

2. **Is your subscription set correctly?**
   ```bash
   az account set --subscription <subscription-id>
   ```

3. **Do you have permissions?**
   - Your Azure user needs `Cognitive Services User` role on the AI Services resource
   - Container's managed identity needs the same role

4. **Is the endpoint correct?**
   - Must be in: `eastus2`, `swedencentral`, `westeurope`, etc.
   - Check [Voice Live availability](https://learn.microsoft.com/azure/ai-services/speech-service/voice-live)

### Token Expiration

Tokens are automatically refreshed:
- Cached locally for 1 hour
- When `/config` is called, fresh token is fetched
- No user action needed

## Security Best Practices

✅ **Do:**
- Use managed identity in production (Container Apps)
- Use service principal in CI/CD (with short-lived credentials)
- Use Azure CLI for local development
- Rotate service principal secrets regularly

❌ **Don't:**
- Commit credentials to version control
- Share API keys via email or chat
- Use the same credential across environments
- Store tokens in browser localStorage

## Related Documentation

- [Azure Identity Client Library](https://github.com/Azure/azure-sdk-for-python/tree/main/sdk/identity/azure-identity)
- [Voice Live API Documentation](https://learn.microsoft.com/azure/ai-services/speech-service/voice-live)
- [Azure Container Apps Managed Identity](https://learn.microsoft.com/azure/container-apps/managed-identity)
- [Azure AI Services Authentication](https://learn.microsoft.com/azure/cognitive-services/cognitive-services-authentication)
