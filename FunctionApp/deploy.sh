#!/bin/bash

# Enhanced GitHub Dispatch Function App Deployment Script
# This script deploys the function app to Azure using Bicep

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

print_color $BLUE "🚀 Enhanced GitHub Dispatch Function App Deployment"
print_color $BLUE "=================================================="

# Check prerequisites
print_color $YELLOW "📋 Checking prerequisites..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_color $RED "❌ Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is logged in
if ! az account show &> /dev/null; then
    print_color $YELLOW "🔐 Please login to Azure CLI first:"
    az login
fi

# Check if Azure Functions Core Tools is installed
if ! command -v func &> /dev/null; then
    print_color $YELLOW "⚠️  Azure Functions Core Tools not found. Installing..."
    npm install -g azure-functions-core-tools@4 --unsafe-perm true
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
print_color $GREEN "✅ Using Azure subscription: $SUBSCRIPTION_ID"

# Prompt for required parameters
print_color $YELLOW "📝 Please provide the following required parameters:"

read -p "Enter Resource Group name (or press Enter for 'rg-github-dispatch-function'): " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-"rg-github-dispatch-function"}

read -p "Enter Function App name (or press Enter for auto-generated): " FUNCTION_APP_NAME
FUNCTION_APP_NAME=${FUNCTION_APP_NAME:-"github-dispatch-func-$(date +%s)"}

read -p "Enter Azure region (or press Enter for 'West Europe'): " LOCATION
LOCATION=${LOCATION:-"West Europe"}

read -p "Enter GitHub Client ID: " GITHUB_CLIENT_ID
if [ -z "$GITHUB_CLIENT_ID" ]; then
    print_color $RED "❌ GitHub Client ID is required"
    exit 1
fi

read -p "Enter GitHub Installation ID (or press Enter for '89231209'): " GITHUB_INSTALLATION_ID
GITHUB_INSTALLATION_ID=${GITHUB_INSTALLATION_ID:-"89231209"}

read -p "Enter Default Repository (or press Enter for 'Stackmeisterei/elden-test-repo'): " DEFAULT_REPOSITORY
DEFAULT_REPOSITORY=${DEFAULT_REPOSITORY:-"Stackmeisterei/elden-test-repo"}

print_color $YELLOW "Enter PEM private key content (paste and press Ctrl+D when done):"
PEM_CONTENT=$(cat)

if [ -z "$PEM_CONTENT" ]; then
    print_color $RED "❌ PEM content is required"
    exit 1
fi

# Create resource group
print_color $YELLOW "🏗️  Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# Deploy Bicep template
print_color $YELLOW "🚀 Deploying Function App infrastructure..."
DEPLOYMENT_OUTPUT=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file deploy-functionapp.bicep \
    --parameters \
        functionAppName="$FUNCTION_APP_NAME" \
        location="$LOCATION" \
        githubClientId="$GITHUB_CLIENT_ID" \
        pemSecretContent="$PEM_CONTENT" \
        githubInstallationId="$GITHUB_INSTALLATION_ID" \
        defaultRepository="$DEFAULT_REPOSITORY" \
    --query 'properties.outputs' \
    --output json)

if [ $? -ne 0 ]; then
    print_color $RED "❌ Infrastructure deployment failed"
    exit 1
fi

# Extract outputs
FUNCTION_APP_URL=$(echo $DEPLOYMENT_OUTPUT | jq -r '.functionAppUrl.value')
FUNCTION_APP_NAME_DEPLOYED=$(echo $DEPLOYMENT_OUTPUT | jq -r '.functionAppName.value')

print_color $GREEN "✅ Infrastructure deployed successfully!"
print_color $BLUE "Function App URL: $FUNCTION_APP_URL"

# Create and deploy function package
print_color $YELLOW "📦 Creating deployment package..."

# Create a temporary directory for deployment
TEMP_DIR=$(mktemp -d)
cp enhanced_function_app.py "$TEMP_DIR/function_app.py"
cp host.json "$TEMP_DIR/"
cp requirements.txt "$TEMP_DIR/"

# Create .funcignore
cat > "$TEMP_DIR/.funcignore" << EOF
*.py[cod]
*.so
.Python
.venv/
venv/
env/
__pycache__/
.pytest_cache/
.coverage
htmlcov/
.tox/
.git/
.gitignore
.DS_Store
*.log
local.settings.json
.vscode/
.idea/
*.bicep
*.bicepparam
deploy.sh
README.md
logicapp.*
EOF

# Deploy function code
print_color $YELLOW "🚀 Deploying function code..."
cd "$TEMP_DIR"

# Initialize functions project
func init . --python --force

# Deploy
func azure functionapp publish "$FUNCTION_APP_NAME_DEPLOYED" --python

if [ $? -eq 0 ]; then
    print_color $GREEN "✅ Function code deployed successfully!"
else
    print_color $RED "❌ Function code deployment failed"
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Cleanup
cd - > /dev/null
rm -rf "$TEMP_DIR"

# Get function keys for testing
print_color $YELLOW "🔑 Retrieving function keys..."
sleep 30  # Wait for deployment to complete

MASTER_KEY=$(az functionapp keys list --name "$FUNCTION_APP_NAME_DEPLOYED" --resource-group "$RESOURCE_GROUP" --query "masterKey" -o tsv 2>/dev/null || echo "")

print_color $GREEN "🎉 Deployment Complete!"
print_color $BLUE "================================"
print_color $BLUE "Function App Name: $FUNCTION_APP_NAME_DEPLOYED"
print_color $BLUE "Function App URL: $FUNCTION_APP_URL"
print_color $BLUE "Resource Group: $RESOURCE_GROUP"

if [ ! -z "$MASTER_KEY" ]; then
    print_color $BLUE "Master Key: $MASTER_KEY"
    echo ""
    print_color $YELLOW "🧪 Test your functions:"
    echo "Health Check:"
    echo "curl \"$FUNCTION_APP_URL/api/health?code=$MASTER_KEY\""
    echo ""
    echo "Status Check:"
    echo "curl \"$FUNCTION_APP_URL/api/status?code=$MASTER_KEY\""
    echo ""
    echo "Trigger GitHub Dispatch:"
    echo "curl -X POST \"$FUNCTION_APP_URL/api/trigger_github_dispatch?code=$MASTER_KEY\" \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{\"repository\":\"$DEFAULT_REPOSITORY\",\"event_type\":\"test_event\",\"image\":\"test-image\",\"tags\":[\"v1.0.0\"]}'"
else
    print_color $YELLOW "⚠️  Could not retrieve master key automatically. You can get it from the Azure portal."
fi

print_color $GREEN "🏁 Deployment completed successfully!"