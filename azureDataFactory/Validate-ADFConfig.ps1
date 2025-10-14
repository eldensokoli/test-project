# Quick ADF Pipeline Validation Script
# This script validates your pipeline configuration and tests with a small batch

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$DataFactoryName
)

Write-Host "🔍 Validating Azure Data Factory Pipeline Configuration" -ForegroundColor Green

# Check if connected to Azure
if (-not (Get-AzContext)) {
    Write-Host "Please connect to Azure first:" -ForegroundColor Yellow
    Write-Host "Connect-AzAccount" -ForegroundColor Cyan
    exit
}

try {
    # Check if Data Factory exists
    $df = Get-AzDataFactoryV2 -ResourceGroupName $ResourceGroupName -Name $DataFactoryName -ErrorAction Stop
    Write-Host "✅ Data Factory found: $($df.DataFactoryName)" -ForegroundColor Green
    
    # Check pipeline existence
    $pipelines = Get-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName
    $optimizedPipeline = $pipelines | Where-Object { $_.Name -eq "testing_paralelism" }
    
    if ($optimizedPipeline) {
        Write-Host "✅ Optimized pipeline found: testing_paralelism" -ForegroundColor Green
        
        # Analyze pipeline configuration
        $pipelineContent = Get-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Name "testing_paralelism"
        
        Write-Host "`n📊 Pipeline Configuration Analysis:" -ForegroundColor Cyan
        Write-Host "Pipeline Name: $($pipelineContent.Name)"
        
        # Check for ForEach activity configuration
        $activities = $pipelineContent.Activities
        $forEachActivity = $activities | Where-Object { $_.Type -eq "ForEach" }
        
        if ($forEachActivity) {
            $isSequential = $forEachActivity.TypeProperties.IsSequential
            $batchCount = $forEachActivity.TypeProperties.BatchCount
            
            Write-Host "ForEach Configuration:" -ForegroundColor Yellow
            Write-Host "  Sequential Processing: $isSequential" -ForegroundColor $(if ($isSequential) { "Red" } else { "Green" })
            Write-Host "  Batch Count: $batchCount" -ForegroundColor $(if ($batchCount -ge 20) { "Green" } else { "Yellow" })
            
            # Check Copy activity within ForEach
            $copyActivity = $forEachActivity.Activities | Where-Object { $_.Type -eq "Copy" }
            if ($copyActivity) {
                $parallelCopies = $copyActivity.TypeProperties.ParallelCopies
                $diu = $copyActivity.TypeProperties.DataIntegrationUnits
                
                Write-Host "Copy Activity Configuration:" -ForegroundColor Yellow
                Write-Host "  Parallel Copies: $parallelCopies" -ForegroundColor $(if ($parallelCopies -ge 2) { "Green" } else { "Yellow" })
                Write-Host "  Data Integration Units: $diu" -ForegroundColor $(if ($diu -ge 2) { "Green" } else { "Yellow" })
            }
        }
        
        # Provide recommendations
        Write-Host "`n💡 Configuration Assessment:" -ForegroundColor Green
        
        if (-not $isSequential -and $batchCount -ge 20) {
            Write-Host "✅ EXCELLENT: Parallel processing is enabled with good batch size" -ForegroundColor Green
        } elseif (-not $isSequential) {
            Write-Host "⚠️  GOOD: Parallel processing enabled, consider increasing batch count" -ForegroundColor Yellow
        } else {
            Write-Host "❌ ISSUE: Sequential processing is enabled - this will be slow!" -ForegroundColor Red
        }
        
        # Test pipeline with debug run
        Write-Host "`n🧪 Would you like to run a test? (y/n): " -ForegroundColor Cyan -NoNewline
        $response = Read-Host
        
        if ($response -eq 'y' -or $response -eq 'Y') {
            Write-Host "🚀 Starting test run..." -ForegroundColor Green
            
            $runId = Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineName "testing_paralelism"
            Write-Host "Pipeline triggered. Run ID: $($runId.RunId)" -ForegroundColor Cyan
            
            Write-Host "Monitor the run in Azure Portal or wait for completion..." -ForegroundColor Yellow
            Write-Host "Portal URL: https://portal.azure.com/#@/resource/subscriptions/$($(Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DataFactory/factories/$DataFactoryName/pipelines" -ForegroundColor Blue
        }
        
    } else {
        Write-Host "❌ Pipeline 'testing_paralelism' not found" -ForegroundColor Red
        Write-Host "Available pipelines:" -ForegroundColor Yellow
        $pipelines | ForEach-Object { Write-Host "  - $($_.Name)" }
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n📋 Next Steps:" -ForegroundColor Green
Write-Host "1. Deploy your updated pipeline to Azure Data Factory" -ForegroundColor White
Write-Host "2. Run the full performance test: .\Test-ADFPerformance.ps1" -ForegroundColor White
Write-Host "3. Monitor results in Azure Portal" -ForegroundColor White
Write-Host "4. Compare baseline vs optimized performance" -ForegroundColor White