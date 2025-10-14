# Enhanced GitHub Dispatch Function App

A comprehensive Azure Function App that replaces the combination of your previous Function App and Logic App with a single, more powerful solution.

## 🚀 Features

### Core Functions
1. **`generate_jwt`** - Generate JWT tokens for GitHub App authentication
2. **`generate_installation_token`** - Create installation access tokens for repository operations
3. **`trigger_github_dispatch`** - Complete workflow that generates tokens and triggers GitHub repository dispatch (replaces Logic App)
4. **`health`** - Health check endpoint for monitoring
5. **`status`** - Status endpoint that checks GitHub connectivity and configuration

### Key Improvements
- ✅ **All-in-one solution** - No need for separate Logic App
- ✅ **Better error handling** - Standardized error responses with detailed logging
- ✅ **Enhanced monitoring** - Built-in health and status checks
- ✅ **Flex Consumption plan** - Cost-effective and scalable Azure hosting
- ✅ **Comprehensive logging** - Application Insights integration
- ✅ **Security best practices** - Secure credential management
- ✅ **Linux runtime** - Optimized for Python workloads

## 📋 Prerequisites

- **Azure Subscription** with appropriate permissions
- **GitHub App** configured with required permissions
- **Python 3.8+** (recommended: Python 3.11)
- **Azure Functions Core Tools v4**
- **Azure CLI** (for deployment)
- **GitHub repository** with Actions workflows

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone <your-repo>
cd functionApp
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Configure Environment Variables
Create `local.settings.json`:
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "your-storage-connection-string",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "GITHUB_CLIENT_ID": "your-github-app-client-id",
    "PEM_SECRET_NAME": "your-github-app-private-key"
  }
}
```

### 3. Test Locally
```bash
func start
```

### 4. Deploy to Azure
```bash
func azure functionapp publish <your-function-app-name> --python
```

## 🔧 Core Components

### Azure Functions App (function_app.py)

The function app contains **6 specialized functions**:

#### 🔐 Authentication Functions

**A. JWT Token Generation (`generate_jwt`)**
```python
@app.route(route="generate_jwt")
def generate_jwt_token(req: func.HttpRequest) -> func.HttpResponse:
```
- **Purpose**: Generates JWT tokens for GitHub App authentication
- **Use Case**: App-level GitHub operations
- **Endpoint**: `POST /api/generate_jwt`
- **Authentication**: Function key required

**B. Installation Access Token (`generate_installation_token`)**
```python
@app.route(route="generate_installation_token")
def generate_installation_token(req: func.HttpRequest) -> func.HttpResponse:
```
- **Purpose**: Generates Installation Access Tokens for repository operations
- **Use Case**: Repository dispatch, issues, PRs, etc.
- **Endpoint**: `POST /api/generate_installation_token`
- **Parameters**: `repository`, `installation_id`

#### 🔧 Utility Functions

**C. HTTP Trigger (`http_trigger`)**
- **Purpose**: Basic HTTP endpoint for testing
- **Endpoint**: `GET/POST /api/http_trigger`

**D. Timer Trigger (`timer_trigger`)**
- **Purpose**: Scheduled function (every 5 minutes)
- **Use Case**: Periodic maintenance, monitoring

**E. Blob Trigger (`blob_trigger`)**
- **Purpose**: Triggered by blob storage uploads
- **Path**: `samples-workitems/{name}`

**F. Queue Trigger (`queue_trigger`)**
- **Purpose**: Processes Azure Storage Queue messages
- **Queue**: `python-queue-items`

### Azure Logic App (logicapp.bicep)

The Logic App orchestrates the complete workflow:

#### Workflow Steps:
1. **HTTP Trigger** - Receives external requests
2. **Generate Installation Token** - Calls Azure Function
3. **Parse Response** - Extracts access token
4. **Call GitHub API** - Triggers repository dispatch
5. **Return Result** - Provides success/error response

## 📖 Complete Setup Guide

### Step 1: Create GitHub App

1. Go to GitHub Settings → Developer settings → GitHub Apps
2. Create a new GitHub App with these permissions:
   - **Actions**: Write
   - **Contents**: Write  
   - **Metadata**: Read
3. Generate and download the private key
4. Note the Client ID and Installation ID

### Step 2: Deploy Azure Functions

```bash
# Create Azure Function App
az functionapp create \
  --resource-group <resource-group> \
  --consumption-plan-location <location> \
  --runtime python \
  --runtime-version 3.12 \
  --functions-version 4 \
  --name <function-app-name> \
  --storage-account <storage-account>

# Configure environment variables
az functionapp config appsettings set \
  --name <function-app-name> \
  --resource-group <resource-group> \
  --settings \
  GITHUB_CLIENT_ID="your-client-id" \
  PEM_SECRET_NAME="your-private-key-content"

# Deploy the function
func azure functionapp publish <function-app-name> --python
```

### Step 3: Deploy Logic App

1. Update `logicapp.parameters.json`:
```json
{
  "parameters": {
    "workflows_eldentest_name": {
      "value": "your-logic-app-name"
    },
    "functionAppUrl": {
      "value": "https://your-function-app.azurewebsites.net"
    },
    "functionKey": {
      "value": "your-function-key"
    }
  }
}
```

2. Deploy with Bicep:
```bash
az deployment group create \
  --resource-group <resource-group> \
  --template-file logicapp.bicep \
  --parameters @logicapp.parameters.json
```

### Step 4: Create GitHub Actions Workflow

Create `.github/workflows/dispatch-handler.yml` in your target repository:

```yaml
name: Repository Dispatch Handler

on:
  repository_dispatch:
    types: 
      - client_package_push
      - deployment_trigger
      - custom_event

jobs:
  handle-dispatch:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
      
    - name: Display dispatch information
      run: |
        echo "🎉 Repository dispatch event received!"
        echo "Event type: ${{ github.event.action }}"
        echo "Repository: ${{ github.repository }}"
        echo "Triggered by: ${{ github.event.client_payload.triggered_by }}"
        echo "Message: ${{ github.event.client_payload.message }}"
        
    - name: Run actions based on event type
      run: |
        case "${{ github.event.action }}" in
          "client_package_push")
            echo "📦 Running package deployment..."
            # Add your deployment logic here
            ;;
          "deployment_trigger")
            echo "🚀 Running deployment workflow..."
            # Add your deployment logic here
            ;;
          *)
            echo "🔄 Running default actions..."
            ;;
        esac
```

## 🧪 Testing Guide

### Test Azure Functions Directly

```bash
# Test JWT generation
curl -X POST "https://your-function-app.azurewebsites.net/api/generate_jwt?code=your-function-key" \
  -H "Content-Type: application/json" \
  -d '{}'

# Test Installation Access Token
curl -X POST "https://your-function-app.azurewebsites.net/api/generate_installation_token?code=your-function-key" \
  -H "Content-Type: application/json" \
  -d '{
    "repository": "owner/repo-name",
    "installation_id": "your-installation-id"
  }'
```

### Test Complete Workflow via Logic App

```bash
curl -X POST "https://your-logic-app-trigger-url" \
  -H "Content-Type: application/json" \
  -d '{
    "repository": "owner/repo-name",
    "event_type": "client_package_push",
    "client_data": {
      "message": "Test deployment",
      "version": "1.0.0",
      "environment": "production"
    }
  }'
```

### Test Direct GitHub Repository Dispatch

```bash
# Get token first
TOKEN=$(curl -s -X POST "https://your-function-app.azurewebsites.net/api/generate_installation_token?code=your-function-key" \
  -H "Content-Type: application/json" \
  -d '{"repository": "owner/repo", "installation_id": "123"}' | jq -r '.access_token')

# Send repository dispatch
curl -X POST "https://api.github.com/repos/owner/repo/dispatches" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d '{
    "event_type": "client_package_push",
    "client_payload": {
      "message": "Direct API test"
    }
  }'
```

## 🔐 Security Architecture

### Authentication Layers
1. **Function Keys**: Protect Azure Function endpoints
2. **JWT Tokens**: Authenticate as GitHub App
3. **Installation Tokens**: Repository-specific access with limited permissions
4. **Environment Variables**: Securely store GitHub App credentials

### Permission Model
- **GitHub App Level**: Defined in GitHub App settings
- **Installation Level**: Specific to organization/repositories  
- **Token Level**: Runtime permissions for specific operations

## 📊 Data Flow Example

### Complete Request Flow:

1. **External System** sends HTTP request to Logic App:
```json
{
  "repository": "owner/repo",
  "event_type": "client_package_push",
  "image": "my-app:v1.0.0"
}
```

2. **Logic App** processes request and calls Azure Function

3. **Azure Function** generates Installation Access Token:
```python
# Create JWT internally
payload = {
    'iat': int(time.time()),
    'exp': int(time.time()) + 600,
    'iss': 'github-client-id'
}
jwt_token = jwt.encode(payload, private_key, algorithm='RS256')

# Exchange JWT for Installation Access Token
response = requests.post(
    f'https://api.github.com/app/installations/{installation_id}/access_tokens',
    headers={'Authorization': f'Bearer {jwt_token}'},
    json={
        "repositories": ["repo-name"],
        "permissions": {"actions": "write", "contents": "write"}
    }
)
```

4. **Logic App** uses token to call GitHub API:
```bash
POST https://api.github.com/repos/owner/repo/dispatches
Authorization: Bearer installation_access_token
{
  "event_type": "client_package_push",  
  "client_payload": {"image": "my-app:v1.0.0"}
}
```

5. **GitHub Actions** workflow triggers and processes the event

## 🛠️ Project Structure

```
functionApp/
├── function_app.py              # Main Azure Functions application
├── requirements.txt             # Python dependencies
├── host.json                   # Function host configuration
├── local.settings.json         # Local development settings
├── logicapp.bicep             # Logic App infrastructure template
├── logicapp.parameters.json   # Deployment parameters
├── .gitignore                 # Git ignore rules
└── README.md                  # This documentation
```

## 🔧 Configuration Reference

### Environment Variables

**Azure Functions:**
- `GITHUB_CLIENT_ID`: GitHub App Client ID
- `PEM_SECRET_NAME`: GitHub App Private Key (PEM format)
- `AzureWebJobsStorage`: Storage account connection string
- `FUNCTIONS_WORKER_RUNTIME`: Set to "python"

**Logic App Parameters:**
- `functionAppUrl`: Azure Function App URL
- `functionKey`: Azure Function access key
- `workflows_eldentest_name`: Logic App name

### GitHub App Permissions Required

- **Actions**: Write (for repository dispatch)
- **Contents**: Write (required for dispatch events)
- **Metadata**: Read (basic repository information)

## 🚨 Troubleshooting

### Common Issues

**1. "Resource not accessible by integration" (403)**
- Check GitHub App permissions include Contents: write
- Verify Installation Access Token has correct repository access

**2. "Failed to generate installation access token"**
- Verify GitHub Client ID and private key are correct
- Check installation ID is valid and app is installed on repository

**3. Logic App fails to call Function**
- Verify function key is current and correct
- Check function app URL is accessible

**4. GitHub Actions workflow not triggering**
- Ensure repository has workflow file listening for dispatch events
- Check event_type matches workflow configuration
- Verify workflow file is in `.github/workflows/` directory

### Debugging Commands

```bash
# Check Azure Function logs
az functionapp logs tail --name <function-app-name> --resource-group <resource-group>

# Get Logic App run history
az rest --method GET --url "https://management.azure.com/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Logic/workflows/{logic-app-name}/runs?api-version=2016-06-01"

# Test GitHub App authentication
curl -H "Authorization: Bearer <jwt-token>" https://api.github.com/app
```

## 🌟 Key Benefits

### 🔒 **Security**
- Short-lived tokens (10-minute expiration)
- Minimal required permissions
- Secure credential storage
- Function-level access control

### 🚀 **Scalability** 
- Serverless architecture scales automatically
- Event-driven processing
- Multiple trigger types
- Pay-per-execution model

### 🔧 **Flexibility**
- Dynamic repository targeting
- Configurable event types
- Custom payload support
- Multiple integration points

### 💰 **Cost-Effective**
- No always-on infrastructure
- Built-in monitoring and logging
- Automatic scaling based on demand

## 📚 Additional Resources

- [Azure Functions Python Developer Guide](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-python)
- [GitHub Apps Documentation](https://docs.github.com/en/developers/apps)
- [Azure Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)
- [Repository Dispatch Events](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.