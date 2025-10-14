using './deploy-functionapp.bicep'

// Required parameters - you need to provide these values
param githubClientId = 'your_github_app_client_id_here'
param pemSecretContent = 'your_pem_private_key_content_here'

// Optional parameters with defaults
param functionAppName = 'github-dispatch-function-app'
param location = 'West Europe'
param githubInstallationId = '89231209'
param defaultRepository = 'Stackmeisterei/elden-test-repo'

// Tags
param tags = {
  environment: 'production'
  project: 'github-dispatch-function'
  createdBy: 'bicep'
  owner: 'your-name'
}
