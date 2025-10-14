# Azure Data Factory Performance Testing Script
# This script helps test and compare pipeline performance

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$DataFactoryName,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [int]$TestRuns = 3
)

# Import required modules
Import-Module Az.DataFactory -Force

# Connect to Azure (if not already connected)
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

if ($SubscriptionId) {
    Set-AzContext -SubscriptionId $SubscriptionId
}

Write-Host "🚀 Starting Azure Data Factory Performance Test" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Data Factory: $DataFactoryName" -ForegroundColor Yellow
Write-Host "Test Runs: $TestRuns" -ForegroundColor Yellow

# Function to run pipeline and measure performance
function Test-PipelinePerformance {
    param(
        [string]$PipelineName,
        [string]$TestName,
        [int]$RunNumber
    )
    
    Write-Host "`n📊 Running $TestName - Run $RunNumber..." -ForegroundColor Cyan
    
    $startTime = Get-Date
    
    try {
        # Trigger pipeline run
        $runId = Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineName $PipelineName
        
        Write-Host "Pipeline Run ID: $($runId.RunId)" -ForegroundColor Gray
        
        # Wait for completion and monitor status
        do {
            Start-Sleep -Seconds 30
            $status = Get-AzDataFactoryV2PipelineRun -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineRunId $runId.RunId
            Write-Host "Status: $($status.Status) - Elapsed: $([math]::Round((New-TimeSpan -Start $startTime -End (Get-Date)).TotalMinutes, 2)) minutes" -ForegroundColor Gray
        } while ($status.Status -eq "InProgress")
        
        $endTime = Get-Date
        $duration = New-TimeSpan -Start $startTime -End $endTime
        
        # Get detailed activity runs
        $activityRuns = Get-AzDataFactoryV2ActivityRun -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineRunId $runId.RunId -RunStartedAfter $startTime -RunStartedBefore $endTime
        
        $copyActivities = $activityRuns | Where-Object { $_.ActivityType -eq "Copy" }
        $filesProcessed = $copyActivities.Count
        
        $result = [PSCustomObject]@{
            TestName = $TestName
            RunNumber = $RunNumber
            RunId = $runId.RunId
            Status = $status.Status
            StartTime = $startTime
            EndTime = $endTime
            DurationMinutes = [math]::Round($duration.TotalMinutes, 2)
            DurationSeconds = [math]::Round($duration.TotalSeconds, 2)
            FilesProcessed = $filesProcessed
            ThroughputFilesPerMinute = if ($duration.TotalMinutes -gt 0) { [math]::Round($filesProcessed / $duration.TotalMinutes, 2) } else { 0 }
            ErrorMessage = if ($status.Status -eq "Failed") { $status.Message } else { "" }
        }
        
        Write-Host "✅ Completed: $($result.DurationMinutes) min, $($result.FilesProcessed) files, $($result.ThroughputFilesPerMinute) files/min" -ForegroundColor Green
        
        return $result
    }
    catch {
        $endTime = Get-Date
        $duration = New-TimeSpan -Start $startTime -End $endTime
        
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        
        return [PSCustomObject]@{
            TestName = $TestName
            RunNumber = $RunNumber
            RunId = "N/A"
            Status = "Failed"
            StartTime = $startTime
            EndTime = $endTime
            DurationMinutes = [math]::Round($duration.TotalMinutes, 2)
            DurationSeconds = [math]::Round($duration.TotalSeconds, 2)
            FilesProcessed = 0
            ThroughputFilesPerMinute = 0
            ErrorMessage = $_.Exception.Message
        }
    }
}

# Test both pipelines
$allResults = @()

# Test baseline pipeline (sequential)
Write-Host "`n🔄 Testing Baseline Pipeline (Sequential Processing)" -ForegroundColor Magenta
for ($i = 1; $i -le $TestRuns; $i++) {
    $result = Test-PipelinePerformance -PipelineName "testing_paralelism_baseline" -TestName "Baseline (Sequential)" -RunNumber $i
    $allResults += $result
    
    if ($i -lt $TestRuns) {
        Write-Host "⏳ Waiting 2 minutes before next run..." -ForegroundColor Yellow
        Start-Sleep -Seconds 120
    }
}

# Test optimized pipeline (parallel)
Write-Host "`n⚡ Testing Optimized Pipeline (Parallel Processing)" -ForegroundColor Magenta
for ($i = 1; $i -le $TestRuns; $i++) {
    $result = Test-PipelinePerformance -PipelineName "testing_paralelism" -TestName "Optimized (Parallel)" -RunNumber $i
    $allResults += $result
    
    if ($i -lt $TestRuns) {
        Write-Host "⏳ Waiting 2 minutes before next run..." -ForegroundColor Yellow
        Start-Sleep -Seconds 120
    }
}

# Calculate and display results
Write-Host "`n📈 PERFORMANCE ANALYSIS" -ForegroundColor Green
Write-Host "=" * 50

$baselineResults = $allResults | Where-Object { $_.TestName -eq "Baseline (Sequential)" -and $_.Status -eq "Succeeded" }
$optimizedResults = $allResults | Where-Object { $_.TestName -eq "Optimized (Parallel)" -and $_.Status -eq "Succeeded" }

if ($baselineResults.Count -gt 0) {
    $avgBaselineDuration = ($baselineResults | Measure-Object -Property DurationMinutes -Average).Average
    $avgBaselineThroughput = ($baselineResults | Measure-Object -Property ThroughputFilesPerMinute -Average).Average
    
    Write-Host "Baseline (Sequential) Performance:" -ForegroundColor Yellow
    Write-Host "  Average Duration: $([math]::Round($avgBaselineDuration, 2)) minutes" -ForegroundColor White
    Write-Host "  Average Throughput: $([math]::Round($avgBaselineThroughput, 2)) files/min" -ForegroundColor White
}

if ($optimizedResults.Count -gt 0) {
    $avgOptimizedDuration = ($optimizedResults | Measure-Object -Property DurationMinutes -Average).Average
    $avgOptimizedThroughput = ($optimizedResults | Measure-Object -Property ThroughputFilesPerMinute -Average).Average
    
    Write-Host "`nOptimized (Parallel) Performance:" -ForegroundColor Yellow
    Write-Host "  Average Duration: $([math]::Round($avgOptimizedDuration, 2)) minutes" -ForegroundColor White
    Write-Host "  Average Throughput: $([math]::Round($avgOptimizedThroughput, 2)) files/min" -ForegroundColor White
}

if ($baselineResults.Count -gt 0 -and $optimizedResults.Count -gt 0) {
    $speedImprovement = $avgBaselineDuration / $avgOptimizedDuration
    $throughputImprovement = $avgOptimizedThroughput / $avgBaselineThroughput
    
    Write-Host "`n🏆 IMPROVEMENT SUMMARY:" -ForegroundColor Green
    Write-Host "  Speed Improvement: $([math]::Round($speedImprovement, 2))x faster" -ForegroundColor Cyan
    Write-Host "  Throughput Improvement: $([math]::Round($throughputImprovement, 2))x more files/min" -ForegroundColor Cyan
    
    if ($speedImprovement -gt 2) {
        Write-Host "  🎉 EXCELLENT: Significant performance improvement!" -ForegroundColor Green
    } elseif ($speedImprovement -gt 1.5) {
        Write-Host "  ✅ GOOD: Noticeable performance improvement" -ForegroundColor Yellow  
    } else {
        Write-Host "  ⚠️  MARGINAL: Consider further optimization" -ForegroundColor Red
    }
}

# Export results to CSV
$csvPath = "ADF_Performance_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$allResults | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "`n📊 Results exported to: $csvPath" -ForegroundColor Cyan

# Display detailed results table
Write-Host "`n📋 DETAILED RESULTS:" -ForegroundColor Green
$allResults | Format-Table -AutoSize TestName, RunNumber, Status, DurationMinutes, FilesProcessed, ThroughputFilesPerMinute

Write-Host "`n✅ Performance testing completed!" -ForegroundColor Green