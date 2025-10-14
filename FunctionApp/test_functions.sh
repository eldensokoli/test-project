#!/bin/bash

# Simple test script for the Enhanced GitHub Dispatch Function App
# Usage: ./test_functions.sh <function_app_url> <function_key>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_color() {
    printf "${1}${2}${NC}\n"
}

if [ $# -ne 2 ]; then
    print_color $RED "Usage: $0 <function_app_url> <function_key>"
    print_color $YELLOW "Example: $0 https://my-function-app.azurewebsites.net abc123..."
    exit 1
fi

FUNCTION_URL="$1"
FUNCTION_KEY="$2"

print_color $BLUE "🧪 Testing Enhanced GitHub Dispatch Function App"
print_color $BLUE "=============================================="
print_color $YELLOW "Function URL: $FUNCTION_URL"
echo ""

# Test 1: Health Check
print_color $YELLOW "1. Testing Health Check..."
HEALTH_RESPONSE=$(curl -s "${FUNCTION_URL}/api/health?code=${FUNCTION_KEY}")
if echo "$HEALTH_RESPONSE" | grep -q "success"; then
    print_color $GREEN "✅ Health check passed"
    echo "   Response: $(echo "$HEALTH_RESPONSE" | jq -r '.message' 2>/dev/null || echo "$HEALTH_RESPONSE")"
else
    print_color $RED "❌ Health check failed"
    echo "   Response: $HEALTH_RESPONSE"
fi
echo ""

# Test 2: Status Check
print_color $YELLOW "2. Testing Status Check..."
STATUS_RESPONSE=$(curl -s "${FUNCTION_URL}/api/status?code=${FUNCTION_KEY}")
if echo "$STATUS_RESPONSE" | grep -q "success"; then
    print_color $GREEN "✅ Status check passed"
    GITHUB_STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.github_api' 2>/dev/null || echo "unknown")
    CONFIG_STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.configuration' 2>/dev/null || echo "unknown")
    print_color $BLUE "   GitHub API: $GITHUB_STATUS"
    print_color $BLUE "   Configuration: $CONFIG_STATUS"
else
    print_color $RED "❌ Status check failed"
    echo "   Response: $STATUS_RESPONSE"
fi
echo ""

# Test 3: JWT Generation (if configured)
print_color $YELLOW "3. Testing JWT Generation..."
JWT_RESPONSE=$(curl -s "${FUNCTION_URL}/api/generate_jwt?code=${FUNCTION_KEY}")
if echo "$JWT_RESPONSE" | grep -q "success"; then
    print_color $GREEN "✅ JWT generation passed"
    echo "   JWT token generated successfully"
elif echo "$JWT_RESPONSE" | grep -q "Missing required parameters"; then
    print_color $YELLOW "⚠️  JWT generation requires GitHub credentials (expected in test environment)"
else
    print_color $RED "❌ JWT generation failed"
    echo "   Response: $JWT_RESPONSE"
fi
echo ""

# Test 4: Installation Token (if configured)
print_color $YELLOW "4. Testing Installation Token Generation..."
INSTALL_TOKEN_RESPONSE=$(curl -s -X POST "${FUNCTION_URL}/api/generate_installation_token?code=${FUNCTION_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"repository": "test/repo"}')
if echo "$INSTALL_TOKEN_RESPONSE" | grep -q "success"; then
    print_color $GREEN "✅ Installation token generation passed"
elif echo "$INSTALL_TOKEN_RESPONSE" | grep -q "Missing GitHub App credentials"; then
    print_color $YELLOW "⚠️  Installation token generation requires GitHub credentials (expected in test environment)"
else
    print_color $RED "❌ Installation token generation failed"
    echo "   Response: $INSTALL_TOKEN_RESPONSE"
fi
echo ""

# Test 5: GitHub Dispatch (if configured)
print_color $YELLOW "5. Testing GitHub Dispatch..."
DISPATCH_RESPONSE=$(curl -s -X POST "${FUNCTION_URL}/api/trigger_github_dispatch?code=${FUNCTION_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "repository": "test/repo",
        "event_type": "test_event",
        "image": "test-image",
        "tags": ["v1.0.0"]
    }')
if echo "$DISPATCH_RESPONSE" | grep -q "success"; then
    print_color $GREEN "✅ GitHub dispatch passed"
elif echo "$DISPATCH_RESPONSE" | grep -q "Missing GitHub App credentials"; then
    print_color $YELLOW "⚠️  GitHub dispatch requires GitHub credentials (expected in test environment)"
else
    print_color $RED "❌ GitHub dispatch failed"
    echo "   Response: $DISPATCH_RESPONSE"
fi
echo ""

print_color $BLUE "🏁 Testing Complete!"
print_color $YELLOW "Note: Some tests may show warnings if GitHub credentials are not configured."
print_color $YELLOW "This is normal for testing environments."