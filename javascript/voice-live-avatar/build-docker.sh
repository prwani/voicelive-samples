#!/bin/bash
# Smart Docker build script with dependency validation

set -e

echo "🚀 Starting validated Docker build process..."

# Step 1: Validate dependencies locally (optional but recommended)
if [ "$SKIP_VALIDATION" != "true" ]; then
    echo ""
    echo "📋 Step 1/3: Validating dependencies..."
    if ./validate-deps.sh; then
        echo "✅ Dependency validation passed"
    else
        echo "❌ Dependency validation failed. Fix requirements.txt before building."
        exit 1
    fi
else
    echo "⚠️  Skipping validation (SKIP_VALIDATION=true)"
fi

# Step 2: Build Docker image
echo ""
echo "🐳 Step 2/3: Building Docker image..."
docker build -t voice-live-avatar . || {
    echo "❌ Docker build failed!"
    echo ""
    echo "💡 Troubleshooting tips:"
    echo "   1. Check that all files in COPY commands exist"
    echo "   2. Verify requirements.txt has correct package names"
    echo "   3. Check Docker logs for specific errors"
    exit 1
}

# Step 3: Quick smoke test (optional)
if [ "$SKIP_TEST" != "true" ]; then
    echo ""
    echo "🧪 Step 3/3: Running smoke test..."
    echo "Testing if container starts and imports work..."
    docker run --rm voice-live-avatar python3 -c "
import aiohttp
from azure.communication.messages import NotificationMessagesClient
print('✅ Container smoke test passed!')
" || {
        echo "❌ Container smoke test failed!"
        exit 1
    }
else
    echo "⚠️  Skipping smoke test (SKIP_TEST=true)"
fi

echo ""
echo "✅ Build complete! Image: voice-live-avatar"
echo ""
echo "To run: docker run --rm -p 3000:3000 voice-live-avatar"
