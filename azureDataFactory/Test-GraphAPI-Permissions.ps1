# Simple test to verify Graph API permissions
# Test with your updated credentials

$TenantId = "3cb927ea-38d4-4f40-a2e3-0d1eb5234b2a"
$ClientId = "65b1ec57-eaf8-4c07-832c-26f2eb6663b4"
$ClientSecret = "9nr8Q~zatKvsOPQ5FLPO8wOa64B_6b1Dhe3ahaPf"

Write-Host "🔑 Testing Graph API permissions..." -ForegroundColor Cyan

# Get access token
$body = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://graph.microsoft.com/.default"
}

try {
    Write-Host "Getting access token..." -ForegroundColor Yellow
    $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
    
    if ($tokenResponse.access_token) {
        Write-Host "✅ Access token obtained successfully!" -ForegroundColor Green
        
        # Test basic Graph API call
        $headers = @{
            "Authorization" = "Bearer $($tokenResponse.access_token)"
            "Content-Type" = "application/json"
        }
        
        Write-Host "Testing basic Graph API access..." -ForegroundColor Yellow
        
        # Simple test - get root SharePoint site
        $testUrl = "https://graph.microsoft.com/v1.0/sites/scoremediagroup.sharepoint.com:"
        
        $siteResponse = Invoke-RestMethod -Uri $testUrl -Headers $headers -Method GET
        
        if ($siteResponse.id) {
            Write-Host "✅ SUCCESS! Graph API permissions are working!" -ForegroundColor Green
            Write-Host "Site ID: $($siteResponse.id)" -ForegroundColor Cyan
            Write-Host "Site Name: $($siteResponse.displayName)" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "🎯 You DO NOT need to configure SharePoint site-level permissions!" -ForegroundColor Green
            Write-Host "Your Azure AD app registration permissions are sufficient." -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*Forbidden*" -or $_.Exception.Message -like "*403*") {
        Write-Host ""
        Write-Host "🔐 Permission issue detected. Please verify:" -ForegroundColor Yellow
        Write-Host "1. Graph API permissions are granted: Sites.Read.All, Files.Read.All" -ForegroundColor White
        Write-Host "2. Admin consent has been granted" -ForegroundColor White
        Write-Host "3. Wait 5-10 minutes for permissions to propagate" -ForegroundColor White
    }
    elseif ($_.Exception.Message -like "*Unauthorized*" -or $_.Exception.Message -like "*401*") {
        Write-Host ""
        Write-Host "🔑 Authentication issue detected. Please verify:" -ForegroundColor Yellow
        Write-Host "1. Tenant ID is correct" -ForegroundColor White
        Write-Host "2. Client ID is correct" -ForegroundColor White  
        Write-Host "3. Client Secret is valid and not expired" -ForegroundColor White
    }
    else {
        Write-Host ""
        Write-Host "🌐 Network or other issue. Please check:" -ForegroundColor Yellow
        Write-Host "1. Internet connectivity" -ForegroundColor White
        Write-Host "2. Firewall settings" -ForegroundColor White
        Write-Host "3. Proxy configuration" -ForegroundColor White
    }
}