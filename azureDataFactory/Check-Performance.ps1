# Quick Performance Checker for Azure Data Factory
# Run this to compare your pipeline runs

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$DataFactoryName,
    
    [Parameter(Mandatory=$false)]
    [int]$DaysBack = 7
)

Write-Host "🔍 Analyzing Azure Data Factory Pipeline Performance" -ForegroundColor Green

# Connect to Azure if needed
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

try {
    # Get recent pipeline runs
    $startTime = (Get-Date).AddDays(-$DaysBack)
    $runs = Get-AzDataFactoryV2PipelineRun -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -LastUpdatedAfter $startTime | Where-Object { $_.PipelineName -eq "testing_paralelism" }
    
    Write-Host "`n📊 Recent Pipeline Runs (Last $DaysBack days):" -ForegroundColor Cyan
    
    $performanceData = @()
    
    foreach ($run in $runs | Sort-Object RunStart -Descending | Select-Object -First 10) {
        $duration = if ($run.RunEnd -and $run.RunStart) { 
            [math]::Round((New-TimeSpan -Start $run.RunStart -End $run.RunEnd).TotalMinutes, 2)
        } else { 
            "N/A" 
        }
        
        # Get activity runs to count files processed
        $activityRuns = Get-AzDataFactoryV2ActivityRun -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineRunId $run.RunId -RunStartedAfter $run.RunStart.AddMinutes(-5) -RunStartedBefore $run.RunEnd.AddMinutes(5)
        $copyActivities = $activityRuns | Where-Object { $_.ActivityName -eq "CopyFileWithName" }
        $filesProcessed = $copyActivities.Count
        
        $throughput = if ($duration -ne "N/A" -and $duration -gt 0 -and $filesProcessed -gt 0) {
            [math]::Round($filesProcessed / $duration, 2)
        } else {
            "N/A"
        }
        
        $performanceData += [PSCustomObject]@{
            RunId = $run.RunId.Substring(0, 8) + "..."
            StartTime = $run.RunStart.ToString("MM/dd HH:mm")
            Status = $run.Status
            Duration = "$duration min"
            FilesProcessed = $filesProcessed
            ThroughputPerMin = "$throughput files/min"
        }
    }
    
    # Display results
    $performanceData | Format-Table -AutoSize
    
    # Calculate averages
    $successfulRuns = $performanceData | Where-Object { $_.Status -eq "Succeeded" -and $_.Duration -ne "N/A min" }
    
    if ($successfulRuns.Count -gt 0) {
        $avgDuration = ($successfulRuns | ForEach-Object { [double]($_.Duration -replace " min", "") } | Measure-Object -Average).Average
        $avgFiles = ($successfulRuns | Measure-Object -Property FilesProcessed -Average).Average
        $avgThroughput = if ($avgDuration -gt 0) { [math]::Round($avgFiles / $avgDuration, 2) } else { 0 }
        
        Write-Host "`n📈 Performance Summary:" -ForegroundColor Green
        Write-Host "  Average Duration: $([math]::Round($avgDuration, 2)) minutes" -ForegroundColor White
        Write-Host "  Average Files: $([math]::Round($avgFiles, 0)) files" -ForegroundColor White
        Write-Host "  Average Throughput: $avgThroughput files/min" -ForegroundColor White
        
        # Performance assessment
        if ($avgThroughput -gt 10) {
            Write-Host "`n🚀 EXCELLENT: High throughput - parallelism is working great!" -ForegroundColor Green
        } elseif ($avgThroughput -gt 3) {
            Write-Host "`n✅ GOOD: Decent throughput - parallelism is helping" -ForegroundColor Yellow
        } else {
            Write-Host "`n⚠️  SLOW: Low throughput - might need optimization" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n💡 Tips to verify parallelism:" -ForegroundColor Cyan
Write-Host "1. Check Azure Portal monitoring - you should see multiple copy activities running simultaneously" -ForegroundColor White
Write-Host "2. Look for 'CopyFileWithName' activities with overlapping time ranges" -ForegroundColor White
Write-Host "3. Higher throughput (files/min) indicates successful parallelism" -ForegroundColor White