# Get SharePoint Site IDs using Graph API
# Replace YOUR_ACCESS_TOKEN with actual token

# 1. Score Media Group (Root)
# URL: https://scoremediagroup.sharepoint.com
# API Call:
curl -X GET "https://graph.microsoft.com/v1.0/sites/scoremediagroup.sharepoint.com:" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# 2. Finance Site  
# URL: https://scoremediagroup.sharepoint.com/finance
# API Call:
curl -X GET "https://graph.microsoft.com/v1.0/sites/scoremediagroup.sharepoint.com:/finance:" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# 3. Communications Site
# URL: https://scoremediagroup.sharepoint.com/Communications  
# API Call:
curl -X GET "https://graph.microsoft.com/v1.0/sites/scoremediagroup.sharepoint.com:/Communications:" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# 4. Communications/Marketing (Subsite)
# URL: https://scoremediagroup.sharepoint.com/Communications/Marketing
# API Call:
curl -X GET "https://graph.microsoft.com/v1.0/sites/scoremediagroup.sharepoint.com:/Communications/Marketing:" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# The response will include:
# {
#   "id": "scoremediagroup.sharepoint.com,{site-guid},{web-guid}",
#   "displayName": "Site Name",
#   "webUrl": "https://scoremediagroup.sharepoint.com/..."
# }