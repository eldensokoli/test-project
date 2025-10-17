# PowerShell Script to Get SharePoint Site IDs
# This uses your existing authentication setup

param(
    [string]$TenantId = "3cb927ea-38d4-4f40-a2e3-0d1eb5234b2a",
    [string]$ClientId = "65b1ec57-eaf8-4c07-832c-26f2eb6663b4", 
    [string]$ClientSecret = "9nr8Q~zatKvsOPQ5FLPO8wOa64B_6b1Dhe3ahaPf"
)

# Function to get access token
function Get-GraphAccessToken {
    param($TenantId, $ClientId, $ClientSecret)
    
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
    }
    
    $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
    return $response.access_token
}

# Function to get site ID
function Get-SharePointSiteId {
    param($SiteUrl, $AccessToken)
    
    # Convert URL to Graph API format
    $siteIdentifier = $SiteUrl -replace "https://", "" -replace "/", ":"
    if (!$siteIdentifier.EndsWith(":")) {
        $siteIdentifier += ":"
    }
    
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteIdentifier" -Headers $headers -Method GET
        return $response
    }
    catch {
        Write-Error "Failed to get site ID for $SiteUrl : $($_.Exception.Message)"
        return $null
    }
}

# Get access token
Write-Host "🔑 Getting access token..."
$accessToken = Get-GraphAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

if ($accessToken) {
    Write-Host "✅ Access token obtained successfully"
    
    # Define your SharePoint sites
    $sites = @(
        "https://scoremediagroup.sharepoint.com",
        "https://scoremediagroup.sharepoint.com/finance", 
        "https://scoremediagroup.sharepoint.com/Communications",
        "https://scoremediagroup.sharepoint.com/Communications/Marketing",
        "https://scoremediagroup.sharepoint.com/Communications/PR",
        "https://scoremediagroup.sharepoint.com/Sales",
        "https://scoremediagroup.sharepoint.com/Sales/Intelligence",
        "https://scoremediagroup.sharepoint.com/Sales/Strategy", 
        "https://scoremediagroup.sharepoint.com/Sales/Operations",
        "https://scoremediagroup.sharepoint.com/CareersDevelopment",
        "https://scoremediagroup.sharepoint.com/AdministrationOrganisation",
        "https://scoremediagroup.sharepoint.com/ClientServiceMediaPlanning"
    )
    
    Write-Host ""
    Write-Host "📋 SharePoint Site IDs:"
    Write-Host "=" * 80
    
    foreach ($siteUrl in $sites) {
        Write-Host "🔍 Getting site ID for: $siteUrl"
        $siteInfo = Get-SharePointSiteId -SiteUrl $siteUrl -AccessToken $accessToken
        
        if ($siteInfo) {
            Write-Host "   ✅ Site ID: $($siteInfo.id)" -ForegroundColor Green
            Write-Host "   📁 Display Name: $($siteInfo.displayName)" -ForegroundColor Cyan
            Write-Host "   🔗 Web URL: $($siteInfo.webUrl)" -ForegroundColor Yellow
            Write-Host ""
        }
        else {
            Write-Host "   ❌ Failed to get site ID" -ForegroundColor Red
            Write-Host ""
        }
        
        # Small delay to avoid throttling
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "=" * 80
    Write-Host "✅ Site ID retrieval completed!"
}
else {
    Write-Host "❌ Failed to get access token"
}