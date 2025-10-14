param workflows_eldentest_name string = 'eldentest3'
param functionAppUrl string = 'https://testgeneratejwt-drcdfccyc4bzhgfa.westeurope-01.azurewebsites.net'
param functionKey string // Store this securely

resource workflows_eldentest_name_resource 'Microsoft.Logic/workflows@2017-07-01' = {
  name: workflows_eldentest_name
  location: 'westeurope'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        functionAppUrl: {
          defaultValue: functionAppUrl
          type: 'String'
        }
        functionKey: {
          defaultValue: functionKey
          type: 'SecureString'
        }
      }
      triggers: {
        When_a_HTTP_request_is_received: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            method: 'POST'
            schema: {
              type: 'object'
              properties: {
                repository: { type: 'string' }
                event_type: { type: 'string' }
                image: { type: 'string' }
                tags: { 
                  type: 'array'
                  items: { type: 'string' }
                }
              }
              required: ['repository', 'event_type']
            }
          }
        }
      }
      actions: {
        Generate_Installation_Token: {
          runAfter: {}
          type: 'Http'
          inputs: {
            uri: '@{parameters(\'functionAppUrl\')}/api/generate_installation_token?code=@{parameters(\'functionKey\')}'
            method: 'POST'
            headers: {
              'Content-Type': 'application/json'
              'Accept': 'application/json'
            }
            body: {
              repository: '@{coalesce(triggerBody()?[\'repository\'], \'Stackmeisterei/elden-test-repo\')}'
              installation_id: '89231209'
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
        Parse_Token_Response: {
          runAfter: {
            Generate_Installation_Token: ['Succeeded']
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Generate_Installation_Token\')'
            schema: {
              type: 'object'
              properties: {
                access_token: { type: 'string' }
                expires_at: { type: 'string' }
                repository: { type: 'string' }
                installation_id: { type: 'string' }
                token_type: { type: 'string' }
              }
              required: ['access_token']
            }
          }
        }
        Trigger_GitHub_Dispatch: {
          runAfter: {
            Parse_Token_Response: ['Succeeded']
          }
          type: 'Http'
          inputs: {
            uri: 'https://api.github.com/repos/@{coalesce(triggerBody()?[\'repository\'], \'Stackmeisterei/elden-test-repo\')}/dispatches'
            method: 'POST'
            headers: {
              'Accept': 'application/vnd.github.v3+json'
              'Authorization': 'Bearer @{body(\'Parse_Token_Response\')?[\'access_token\']}'
              'User-Agent': 'Azure-LogicApp'
            }
            body: {
              event_type: '@{coalesce(triggerBody()?[\'event_type\'], \'client_package_push\')}'
              client_payload: {
                image: '@{coalesce(triggerBody()?[\'image\'], \'my-client/package-name\')}'
                tags: '@{coalesce(triggerBody()?[\'tags\'], createArray(\'v1.0.0\', \'latest\'))}'
                triggered_by: 'Azure Logic App'
                timestamp: '@{utcnow()}'
              }
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
        Handle_Success: {
          runAfter: {
            Trigger_GitHub_Dispatch: ['Succeeded']
          }
          type: 'Response'
          inputs: {
            statusCode: 200
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              status: 'success'
              message: 'GitHub repository dispatch triggered successfully'
              repository: '@{coalesce(triggerBody()?[\'repository\'], \'Stackmeisterei/elden-test-repo\')}'
              event_type: '@{coalesce(triggerBody()?[\'event_type\'], \'client_package_push\')}'
              timestamp: '@{utcnow()}'
            }
          }
        }
        Handle_Token_Error: {
          runAfter: {
            Generate_Installation_Token: ['Failed', 'TimedOut']
          }
          type: 'Response'
          inputs: {
            statusCode: 500
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              status: 'error'
              message: 'Failed to generate installation access token'
              error: '@{body(\'Generate_Installation_Token\')}'
              timestamp: '@{utcnow()}'
            }
          }
        }
        Handle_GitHub_Error: {
          runAfter: {
            Trigger_GitHub_Dispatch: ['Failed', 'TimedOut']
          }
          type: 'Response'
          inputs: {
            statusCode: 502
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              status: 'error'
              message: 'Failed to trigger GitHub repository dispatch'
              github_response: '@{body(\'Trigger_GitHub_Dispatch\')}'
              timestamp: '@{utcnow()}'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      functionAppUrl: {
        value: functionAppUrl
      }
      functionKey: {
        value: functionKey
      }
    }
  }
}
