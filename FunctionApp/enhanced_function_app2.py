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


@app.route(route="trigger_github_dispatch2")
def trigger_github_dispatch2(req: func.HttpRequest) -> func.HttpResponse:
    """
    Single HTTP trigger that runs complete GitHub dispatch workflow.
    
    Workflow Steps (all automatic):
    1. Parse input parameters
    2. Generate GitHub App JWT token  
    3. Exchange JWT for Installation Access Token
    4. Trigger GitHub Repository Dispatch Event
    5. Return comprehensive workflow results
    """
    workflow_id = f"workflow-{int(time.time())}"
    logging.info(f'[{workflow_id}] Logic App Workflow Started - GitHub Dispatch Trigger')

    workflow_steps = []
    
    try:
        # STEP 1: Parse and validate input parameters
        logging.info(f'[{workflow_id}] Step 1: Parsing input parameters')
        workflow_steps.append("✓ Step 1: Input validation started")
        
        req_body = req.get_json() if req.get_body() else None
        if not req_body:
            return create_error_response(
                "Workflow failed at Step 1: Input validation",
                400,
                "JSON body is required with repository, event_type, and optional image/tags"
            )

        # Extract parameters with defaults
        repository = req_body.get('repository', os.environ.get('DEFAULT_REPOSITORY', 'Stackmeisterei/elden-test-repo'))
        event_type = req_body.get('event_type', 'client_package_push')
        image = req_body.get('image', 'my-client/package-name')
        tags = req_body.get('tags', ['v1.0.0', 'latest'])
        installation_id = req_body.get('installation_id', os.environ.get('GITHUB_INSTALLATION_ID', '89231209'))

        workflow_steps.append(f"✓ Step 1 Completed: Repository={repository}, Event={event_type}")
        logging.info(f'[{workflow_id}] Step 1 Completed: Processing dispatch for {repository}, event: {event_type}')

        # STEP 2: Generate GitHub App JWT token
        logging.info(f'[{workflow_id}] Step 2: Generating GitHub App JWT token')
        workflow_steps.append("✓ Step 2: JWT generation started")
        
        client_id = os.environ.get('GITHUB_CLIENT_ID')
        pem_content = os.environ.get('PEM_SECRET_NAME')

        if not client_id or not pem_content:
            workflow_steps.append("✗ Step 2 Failed: Missing GitHub App credentials")
            return create_error_response(
                "Workflow failed at Step 2: JWT generation",
                400,
                "GITHUB_CLIENT_ID or PEM_SECRET_NAME not found in environment variables"
            )

        # Create JWT payload
        jwt_payload = {
            'iat': int(time.time()),
            'exp': int(time.time()) + 600,
            'iss': client_id
        }

        # Generate JWT
        jwt_token = jwt.encode(jwt_payload, pem_content.encode(), algorithm='RS256')
        workflow_steps.append(f"✓ Step 2 Completed: JWT token generated (expires: {jwt_payload['exp']})")
        logging.info(f'[{workflow_id}] Step 2 Completed: JWT token generated successfully')

        # STEP 3: Exchange JWT for Installation Access Token
        logging.info(f'[{workflow_id}] Step 3: Getting Installation Access Token')
        workflow_steps.append("✓ Step 3: Installation token exchange started")
        
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
            workflow_steps.append(f"✗ Step 3 Failed: GitHub API returned {token_response.status_code}")
            logging.error(f'[{workflow_id}] Step 3 Failed: {token_response.status_code} - {token_response.text}')
            return create_error_response(
                "Workflow failed at Step 3: Installation token exchange",
                token_response.status_code,
                token_response.text
            )

        access_token = token_response.json()['token']
        token_expires = token_response.json().get('expires_at', 'N/A')
        workflow_steps.append(f"✓ Step 3 Completed: Installation token acquired (expires: {token_expires})")
        logging.info(f'[{workflow_id}] Step 3 Completed: Installation access token acquired')

        # STEP 4: Trigger GitHub Repository Dispatch Event
        logging.info(f'[{workflow_id}] Step 4: Triggering GitHub Repository Dispatch')
        workflow_steps.append("✓ Step 4: Repository dispatch started")
        
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
                "triggered_by": "Azure Function App (Logic App Replacement)",
                "workflow_id": workflow_id,
                "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
            }
        }

        dispatch_response = requests.post(dispatch_url, headers=dispatch_headers, json=dispatch_payload, timeout=30)

        if dispatch_response.status_code == 204:
            # Success - GitHub returns 204 No Content for successful dispatch
            workflow_steps.append("✓ Step 4 Completed: GitHub repository dispatch triggered successfully")
            logging.info(f'[{workflow_id}] Step 4 Completed: Repository dispatch successful')
            
            # STEP 5: Workflow completion
            workflow_steps.append("✓ Workflow Completed Successfully: All steps executed")
            logging.info(f'[{workflow_id}] Workflow Completed: All steps successful')
            
            return create_success_response({
                "message": "Logic App Workflow completed successfully",
                "workflow_id": workflow_id,
                "workflow_steps": workflow_steps,
                "execution_summary": {
                    "repository": repository,
                    "event_type": event_type,
                    "image": image,
                    "tags": tags,
                    "installation_id": installation_id,
                    "dispatch_url": dispatch_url,
                    "steps_completed": 4,
                    "total_steps": 4
                }
            })
        else:
            workflow_steps.append(f"✗ Step 4 Failed: GitHub dispatch returned {dispatch_response.status_code}")
            logging.error(f'[{workflow_id}] Step 4 Failed: {dispatch_response.status_code} - {dispatch_response.text}')
            return create_error_response(
                "Workflow failed at Step 4: Repository dispatch",
                dispatch_response.status_code,
                {
                    "github_response": dispatch_response.text,
                    "workflow_steps": workflow_steps,
                    "workflow_id": workflow_id
                }
            )

    except Exception as e:
        workflow_steps.append(f"✗ Workflow Failed: Unexpected error - {str(e)}")
        logging.error(f'[{workflow_id}] Workflow Failed: {str(e)}')
        return create_error_response(
            "Logic App Workflow failed with unexpected error", 
            500, 
            {
                "error_details": str(e),
                "workflow_steps": workflow_steps,
                "workflow_id": workflow_id
            }
        )