#!/bin/bash
# Validation script to check all dependencies before Docker build

set -e

echo "🔍 Validating Python dependencies..."

# Create a temporary virtual environment for testing
python3 -m venv /tmp/validate-env
source /tmp/validate-env/bin/activate

# Try to install all requirements
pip install --no-cache-dir -r requirements.txt

# Verify imports work - test ALL imports from our Python files
echo "✅ Testing imports..."
python3 << EOF
import sys

print("Testing stdlib imports...")
try:
    import argparse
    import json
    import os
    import logging
    import sqlite3
    import random
    from datetime import datetime
    print("  ✓ Standard library imports OK")
except ImportError as e:
    print(f"  ✗ Stdlib import failed: {e}")
    sys.exit(1)

print("Testing external package imports...")
try:
    # From app.py
    from dotenv import load_dotenv
    from aiohttp import web
    from azure.ai.agents.aio import AgentsClient
    from azure.identity.aio import DefaultAzureCredential, get_bearer_token_provider
    print("  ✓ app.py imports OK")
    
    # From functions.py
    from azure.communication.messages import NotificationMessagesClient
    from azure.communication.messages.models import TextNotificationContent
    print("  ✓ functions.py imports OK")
    
    print("✅ All Python imports successful!")
except ImportError as e:
    print(f"  ✗ Import failed: {e}")
    sys.exit(1)
EOF

# Clean up
deactivate
rm -rf /tmp/validate-env

echo "✅ All dependencies validated successfully!"
echo "📦 Ready to build Docker image"
