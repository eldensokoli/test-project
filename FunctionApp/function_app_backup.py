import azure.functions as func
import datetime
import json
import logging
import time
import jwt
import os
import requests
from typing import Optional, Dict, Any

# Create the main function app
app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

def create_error_response(error_message: str, status_code: int, details: Optional[str] = None) -> func.HttpResponse:
    """Create standardized error response"""
    response_body = {
        "status": "error",
        "message": error_message,
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
    }
    if details:
        response_body["details"] = details
    
    return func.HttpResponse(
        json.dumps(response_body),
        status_code=status_code,
        mimetype="application/json"
    )

def create_success_response(data: Dict[Any, Any], status_code: int = 200) -> func.HttpResponse:
    """Create standardized success response"""
    response_body = {
        "status": "success",
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        **data
    }
    
    return func.HttpResponse(
        json.dumps(response_body),
        status_code=status_code,
        mimetype="application/json"
    )

@app.route(route="generate_jwt")
def generate_jwt_token(req: func.HttpRequest) -> func.HttpResponse:
    """Generate JWT token for GitHub App authentication"""
    logging.info('GitHub JWT generation function processed a request.')

    try:
        # Get parameters from environment variables (primary), JSON body, or query params
        client_id = os.environ.get('GITHUB_CLIENT_ID')
        pem_content = os.environ.get('PEM_SECRET_NAME')
        
        # Try to get from JSON body, fallback gracefully
        req_body = req.get_json() if req.get_body() else None
        if req_body:
            client_id = req_body.get('client_id', client_id)
            pem_content = req_body.get('pem_content', pem_content)

        # Fallback to query parameters
        client_id = client_id or req.params.get('client_id')
        pem_content = pem_content or req.params.get('pem_content')

        if not client_id or not pem_content:
            return func.HttpResponse(
                json.dumps({
                    "error": "Missing required parameters",
                    "message": "GitHub Client ID or PEM content not found in environment variables, JSON body, or query parameters"
                }),
                status_code=400,
                mimetype="application/json"
            )

        # Create JWT payload
        payload = {
            # Issued at time
            'iat': int(time.time()),
            # JWT expiration time (10 minutes maximum)
            'exp': int(time.time()) + 600,
            # GitHub App's client ID
            'iss': client_id
        }

        # Generate JWT
        encoded_jwt = jwt.encode(payload, pem_content.encode(), algorithm='RS256')

        return func.HttpResponse(
            json.dumps({
                "jwt": encoded_jwt,
                "expires_at": payload['exp'],
                "issued_at": payload['iat']
            }),
            status_code=200,
            mimetype="application/json"
        )

    except Exception as e:
        logging.error(f"Error generating JWT: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "error": "JWT generation failed",
                "message": str(e)
            }),
            status_code=500,
            mimetype="application/json"
        )

@app.route(route="generate_installation_token")
def generate_installation_token(req: func.HttpRequest) -> func.HttpResponse:
    """Generate Installation Access Token for GitHub repository operations"""
    logging.info('GitHub Installation Token generation function processed a request.')

    try:
        # Get repository from request (required for installation token)
        req_body = req.get_json() if req.get_body() else None
        
        # Get parameters from JSON body or query params
        repository = None
        installation_id = '89231209'  # Default installation ID
        
        if req_body:
            repository = req_body.get('repository')
            installation_id = req_body.get('installation_id', installation_id)
        
        # Fallback to query parameters
        repository = repository or req.params.get('repository')
        installation_id = req.params.get('installation_id', installation_id)

        # Step 1: Generate JWT token internally
        client_id = os.environ.get('GITHUB_CLIENT_ID')
        pem_content = os.environ.get('PEM_SECRET_NAME')

        if not client_id or not pem_content:
            return func.HttpResponse(
                json.dumps({
                    "error": "Missing GitHub App credentials",
                    "message": "GITHUB_CLIENT_ID or PEM_SECRET_NAME not found in environment variables"
                }),
                status_code=400,
                mimetype="application/json"
            )

        # Create JWT payload
        payload = {
            'iat': int(time.time()),
            'exp': int(time.time()) + 600,
            'iss': client_id
        }

        # Generate JWT
        jwt_token = jwt.encode(payload, pem_content.encode(), algorithm='RS256')

        # Step 2: Use JWT to get Installation Access Token
        headers = {
            'Authorization': f'Bearer {jwt_token}',
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Azure-Function-GitHub-App'
        }

        # Get installation access token
        install_token_url = f'https://api.github.com/app/installations/{installation_id}/access_tokens'
        
        # Optional: specify repository permissions
        token_data = {}
        if repository:
            token_data = {
                "repositories": [repository.split('/')[-1]],  # Just repo name, not full path
                "permissions": {
                    "actions": "write",
                    "contents": "write",
                    "metadata": "read"
                }
            }

        response = requests.post(install_token_url, headers=headers, json=token_data, timeout=30)
        
        if response.status_code != 201:
            logging.error(f"Failed to get installation token: {response.status_code} - {response.text}")
            return func.HttpResponse(
                json.dumps({
                    "error": "Failed to generate installation access token",
                    "message": response.text,
                    "status_code": response.status_code
                }),
                status_code=response.status_code,
                mimetype="application/json"
            )

        token_response = response.json()

        return func.HttpResponse(
            json.dumps({
                "access_token": token_response['token'],
                "expires_at": token_response['expires_at'],
                "repository": repository,
                "installation_id": installation_id,
                "permissions": token_response.get('permissions', {}),
                "token_type": "installation_access_token"
            }),
            status_code=200,
            mimetype="application/json"
        )

    except Exception as e:
        logging.error(f"Error generating installation token: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "error": "Installation token generation failed",
                "message": str(e)
            }),
            status_code=500,
            mimetype="application/json"
        )