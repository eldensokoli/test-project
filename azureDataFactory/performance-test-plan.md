# Azure Data Factory Pipeline Performance Testing Plan

## Current Configuration Analysis
- **Batch Count**: 50 (up to 50 concurrent file operations)
- **Parallel Copies**: 4 (each copy operation uses 4 parallel streams)
- **Data Integration Units**: 4 (compute resources allocated)
- **Sequential Processing**: Disabled (files process in parallel)

## Performance Testing Strategy

### 1. Baseline Test (Before Optimization)
Create a version with sequential processing to compare:
```json
"isSequential": true,
"batchCount": 1,
// Remove parallelCopies and dataIntegrationUnits
```

### 2. Current Optimized Test
Your current configuration with:
- batchCount: 50
- parallelCopies: 4
- dataIntegrationUnits: 4

### 3. Monitoring Metrics

#### Key Performance Indicators:
- **Total Pipeline Duration**
- **Average File Copy Time**
- **Concurrent Operations Count**
- **Throughput (files/minute)**
- **Data Transfer Rate (MB/s)**

#### Azure Data Factory Metrics to Monitor:
- Pipeline run duration
- Activity run duration
- Failed runs
- Data read/written
- Integration runtime CPU/Memory usage

## Expected Performance Improvements

### File Count Scenarios:
- **10 files**: 2-5x faster
- **50 files**: 10-25x faster  
- **100+ files**: 25-50x faster

### Factors Affecting Performance:
1. **File Size**: Larger files benefit more from parallelCopies
2. **Network Bandwidth**: SharePoint API throttling limits
3. **Blob Storage Performance**: Standard vs Premium tiers
4. **Integration Runtime**: Capacity and location

## Testing Steps

### Phase 1: Configuration Validation
1. Deploy the optimized pipeline
2. Test with a small batch (5-10 files)
3. Verify all files transfer successfully
4. Check for any errors or timeouts

### Phase 2: Performance Comparison
1. Run baseline (sequential) version
2. Run optimized (parallel) version
3. Compare execution times
4. Document throughput improvements

### Phase 3: Scale Testing
1. Test with increasing file counts: 25, 50, 100, 200
2. Monitor for bottlenecks or failures
3. Adjust batchCount if needed
4. Test different file sizes

## Potential Issues to Watch For

### SharePoint Graph API Limits:
- **Rate Limiting**: 10,000 requests per 10 minutes per app
- **Concurrent Requests**: May need throttling
- **Solution**: Add retry logic with exponential backoff

### Azure Blob Storage Limits:
- **Standard Storage**: 20,000 requests/second per account
- **Premium Storage**: Higher limits available
- **Solution**: Monitor storage account metrics

### Memory and Compute:
- **Integration Runtime**: May need scaling up
- **Data Integration Units**: Can increase up to 256
- **Solution**: Monitor IR performance metrics

## Success Criteria

✅ **Pipeline completes successfully**
✅ **All files transferred without corruption**
✅ **50%+ reduction in total execution time**
✅ **No increase in failure rates**
✅ **Cost per file transfer remains reasonable**

## Monitoring Dashboard Queries

Use these Azure Monitor queries to track performance:

### Pipeline Duration Trend:
```kusto
ADFPipelineRun
| where PipelineName == "testing_paralelism"
| summarize avg(DurationInMs) by bin(TimeGenerated, 1h)
| render timechart
```

### Throughput Analysis:
```kusto
ADFActivityRun
| where PipelineName == "testing_paralelism"
| where ActivityName == "CopyFileWithName"
| summarize FilesProcessed = count(), AvgDuration = avg(DurationInMs) by PipelineRunId
```