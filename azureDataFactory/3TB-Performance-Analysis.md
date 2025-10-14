# 3TB File Transfer Time Estimation Calculator
# Azure Data Factory Pipeline Performance Analysis

## Scenario: 3TB of SharePoint files to Azure Blob Storage

### Key Performance Factors:
1. **Network Throughput**: SharePoint Graph API + Azure Blob Storage
2. **File Count**: Total number of files affects parallelism benefits
3. **Average File Size**: Determines copy operation efficiency
4. **Pipeline Configuration**: Sequential vs Parallel processing

---

## Performance Estimates for 3TB Transfer

### Assumptions:
- **Average throughput per file**: 10-50 MB/s (depends on file size and network)
- **SharePoint Graph API limit**: ~10,000 requests per 10 minutes
- **Azure Integration Runtime**: Standard performance tier
- **Network latency**: Typical internet connection

---

### Scenario 1: Many Small Files (Average 1MB each)
**File Count**: ~3,000,000 files
**Sequential Baseline**: 
- Time per file: ~0.5-2 seconds (including API calls)
- **Total time**: 17-69 days 😱
- **Bottleneck**: API call overhead, not bandwidth

**Optimized Parallel (batchCount: 50)**:
- Concurrent operations: 50 files at once
- **Total time**: 8-33 hours ⚡
- **Improvement**: ~50x faster

---

### Scenario 2: Medium Files (Average 10MB each)
**File Count**: ~300,000 files
**Sequential Baseline**:
- Time per file: ~2-10 seconds
- **Total time**: 7-35 days
- **Bottleneck**: Still API overhead

**Optimized Parallel (batchCount: 50)**:
- **Total time**: 3-17 hours ⚡
- **Improvement**: ~50x faster

---

### Scenario 3: Large Files (Average 100MB each)
**File Count**: ~30,000 files
**Sequential Baseline**:
- Time per file: ~10-60 seconds
- **Total time**: 3-21 days
- **Bottleneck**: Bandwidth becomes more important

**Optimized Parallel (batchCount: 50, parallelCopies: 4)**:
- **Total time**: 2-10 hours ⚡
- **Improvement**: ~40x faster

---

### Scenario 4: Very Large Files (Average 1GB each)
**File Count**: ~3,000 files
**Sequential Baseline**:
- Time per file: ~2-10 minutes
- **Total time**: 4-21 days
- **Bottleneck**: Pure bandwidth

**Optimized Parallel (batchCount: 50, parallelCopies: 4)**:
- **Total time**: 2-8 hours ⚡
- **Improvement**: ~30x faster

---

## Realistic Time Estimates for Mixed File Sizes

### Baseline Pipeline (Sequential):
```
Optimistic:  7-14 days
Realistic:   14-30 days  
Pessimistic: 30-60 days
```

### Your Optimized Pipeline (Parallel):
```
Optimistic:  4-12 hours
Realistic:   12-24 hours
Pessimistic: 1-3 days
```

---

## Key Bottlenecks to Consider:

### 1. SharePoint Graph API Limits:
- **Rate Limit**: 10,000 requests per 10 minutes per app
- **Impact**: With 3TB, you might hit these limits
- **Solution**: Implement retry logic and potentially use multiple service principals

### 2. Azure Blob Storage Limits:
- **Standard Storage**: 20,000 requests/second per account
- **Premium Storage**: Much higher limits
- **Impact**: Usually not the bottleneck for this scenario

### 3. Integration Runtime Performance:
- **Current**: Standard IR with DIU=4
- **Upgrade Option**: Increase to DIU=8 or DIU=16 for better performance
- **Cost Impact**: Higher DIU = higher cost but faster transfer

---

## Optimization Recommendations for 3TB:

### 1. Increase Parallel Processing:
```json
"batchCount": 100,          // Up from 50
"parallelCopies": 8,        // Up from 4  
"dataIntegrationUnits": 8   // Up from 4
```

### 2. Implement Chunking Strategy:
- Process files in smaller batches (e.g., by folder)
- Run multiple pipeline instances
- Avoid hitting API rate limits

### 3. Add Error Handling:
- Implement exponential backoff for API throttling
- Add retry logic for failed transfers
- Create checkpoint/resume capability

### 4. Monitor and Adjust:
- Start with smaller batches to test performance
- Scale up batchCount based on observed throughput
- Monitor for API throttling and adjust accordingly

---

## Bottom Line Estimate for 3TB:

**Baseline Sequential Pipeline**: 2-8 weeks 😱
**Your Optimized Parallel Pipeline**: 12-48 hours ⚡

**Speed Improvement**: 20-50x faster with parallelism!

---

## Recommendation:
For 3TB, definitely use the parallel pipeline with these additional optimizations:
1. Increase batchCount to 100
2. Consider splitting into multiple pipeline runs by folder/date
3. Monitor API rate limits and adjust accordingly
4. Use Premium Blob Storage if budget allows