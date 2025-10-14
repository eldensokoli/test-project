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
            return create_error_response(
                "Missing required parameters",
                400,
                "GitHub Client ID or PEM content not found in environment variables, JSON body, or query parameters"
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

        return create_success_response({
            "jwt": encoded_jwt,
            "expires_at": payload['exp'],
            "issued_at": payload['iat']
        })

    except Exception as e:
        logging.error(f"Error generating JWT: {str(e)}")
        return create_error_response("JWT generation failed", 500, str(e))

@app.route(route="generate_installation_token")
def generate_installation_token(req: func.HttpRequest) -> func.HttpResponse:
    """Generate Installation Access Token for GitHub repository operations"""
    logging.info('GitHub Installation Token generation function processed a request.')

    try:
        # Get repository from request (required for installation token)
        req_body = req.get_json() if req.get_body() else None
        
        # Get parameters from JSON body or query params
        repository = None
        installation_id = os.environ.get('GITHUB_INSTALLATION_ID', '89231209')  # Default from env or fallback
        
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
            return create_error_response(
                "Missing GitHub App credentials",
                400,
                "GITHUB_CLIENT_ID or PEM_SECRET_NAME not found in environment variables"
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
            return create_error_response(
                "Failed to generate installation access token",
                response.status_code,
                response.text
            )

        token_response = response.json()

        return create_success_response({
            "access_token": token_response['token'],
            "expires_at": token_response['expires_at'],
            "repository": repository,
            "installation_id": installation_id,
            "permissions": token_response.get('permissions', {}),
            "token_type": "installation_access_token"
        })

    except Exception as e:
        logging.error(f"Error generating installation token: {str(e)}")
        return create_error_response("Installation token generation failed", 500, str(e))

@app.route(route="trigger_github_dispatch")
def trigger_github_dispatch(req: func.HttpRequest) -> func.HttpResponse:
    """
    Combined function that generates installation token and triggers GitHub repository dispatch.
    This replaces the Logic App workflow functionality.
    """
    logging.info('GitHub dispatch trigger function processed a request.')

    try:
        # Parse request body
        req_body = req.get_json() if req.get_body() else None
        if not req_body:
            return create_error_response(
                "Missing request body",
                400,
                "JSON body is required with repository, event_type, and optional image/tags"
            )

        # Extract parameters with defaults
        repository = req_body.get('repository', os.environ.get('DEFAULT_REPOSITORY', 'Stackmeisterei/elden-test-repo'))
        event_type = req_body.get('event_type', 'client_package_push')
        image = req_body.get('image', 'my-client/package-name')
        tags = req_body.get('tags', ['v1.0.0', 'latest'])
        installation_id = req_body.get('installation_id', os.environ.get('GITHUB_INSTALLATION_ID', '89231209'))

        logging.info(f"Processing dispatch for repository: {repository}, event: {event_type}")

        # Step 1: Generate JWT token internally
        client_id = os.environ.get('GITHUB_CLIENT_ID')
        pem_content = os.environ.get('PEM_SECRET_NAME')

        if not client_id or not pem_content:
            return create_error_response(
                "Missing GitHub App credentials",
                400,
                "GITHUB_CLIENT_ID or PEM_SECRET_NAME not found in environment variables"
            )

        # Create JWT payload
        payload = {
            'iat': int(time.time()),
            'exp': int(time.time()) + 600,
            'iss': client_id
        }

        # Generate JWT
        jwt_token = jwt.encode(payload, pem_content.encode(), algorithm='RS256')

        # Step 2: Get Installation Access Token
        headers = {
            'Authorization': f'Bearer {jwt_token}',
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Azure-Function-GitHub-App'
        }

        install_token_url = f'https://api.github.com/app/installations/{installation_id}/access_tokens'
        
        token_data = {
            "repositories": [repository.split('/')[-1]],
            "permissions": {
                "actions": "write",
                "contents": "write",
                "metadata": "read"
            }
        }

        token_response = requests.post(install_token_url, headers=headers, json=token_data, timeout=30)
        
        if token_response.status_code != 201:
            logging.error(f"Failed to get installation token: {token_response.status_code} - {token_response.text}")
            return create_error_response(
                "Failed to generate installation access token",
                token_response.status_code,
                token_response.text
            )

        access_token = token_response.json()['token']

        # Step 3: Trigger GitHub Repository Dispatch
        dispatch_headers = {
            'Accept': 'application/vnd.github.v3+json',
            'Authorization': f'Bearer {access_token}',
            'User-Agent': 'Azure-Function-GitHub-App'
        }

        dispatch_url = f'https://api.github.com/repos/{repository}/dispatches'
        dispatch_payload = {
            "event_type": event_type,
            "client_payload": {
                "image": image,
                "tags": tags,
                "triggered_by": "Azure Function App",
                "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
            }
        }

        dispatch_response = requests.post(dispatch_url, headers=dispatch_headers, json=dispatch_payload, timeout=30)

        if dispatch_response.status_code == 204:
            # Success - GitHub returns 204 No Content for successful dispatch
            return create_success_response({
                "message": "GitHub repository dispatch triggered successfully",
                "repository": repository,
                "event_type": event_type,
                "image": image,
                "tags": tags,
                "installation_id": installation_id
            })
        else:
            logging.error(f"GitHub dispatch failed: {dispatch_response.status_code} - {dispatch_response.text}")
            return create_error_response(
                "Failed to trigger GitHub repository dispatch",
                dispatch_response.status_code,
                dispatch_response.text
            )

    except Exception as e:
        logging.error(f"Error in trigger_github_dispatch: {str(e)}")
        return create_error_response("GitHub dispatch trigger failed", 500, str(e))

@app.route(route="health")
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """Health check endpoint for monitoring"""
    logging.info('Health check endpoint called.')
    
    return create_success_response({
        "message": "Function App is healthy",
        "version": "2.0",
        "functions": ["generate_jwt", "generate_installation_token", "trigger_github_dispatch", "health"]
    })

@app.route(route="status")
def get_status(req: func.HttpRequest) -> func.HttpResponse:
    """Status endpoint that checks GitHub connectivity"""
    logging.info('Status check endpoint called.')
    
    try:
        # Check if we can reach GitHub API
        response = requests.get('https://api.github.com/octocat', timeout=10)
        github_status = "connected" if response.status_code == 200 else "disconnected"
        
        # Check environment variables
        required_env_vars = ['GITHUB_CLIENT_ID', 'PEM_SECRET_NAME']
        missing_vars = [var for var in required_env_vars if not os.environ.get(var)]
        
        config_status = "complete" if not missing_vars else "incomplete"
        
        return create_success_response({
            "message": "Status check complete",
            "github_api": github_status,
            "configuration": config_status,
            "missing_env_vars": missing_vars,
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
        })
        
    except Exception as e:
        logging.error(f"Status check error: {str(e)}")
        return create_error_response("Status check failed", 500, str(e))