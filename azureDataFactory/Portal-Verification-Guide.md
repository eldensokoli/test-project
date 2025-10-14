# How to Verify Parallelism is Working - Azure Portal Guide

## 🔍 Step-by-Step Verification in Azure Portal

### 1. Navigate to Your Pipeline Run
1. Go to **Azure Data Factory** in Azure Portal
2. Click **Monitor** in the left menu
3. Find your recent **"testing_paralelism"** pipeline run
4. Click on the **Run ID** to open details

### 2. Check Activity Timeline
Look for these signs of parallelism:

✅ **Multiple "CopyFileWithName" activities running simultaneously**
- You should see overlapping green bars in the timeline
- Instead of one after another, multiple should run at the same time

✅ **Gantt Chart View**
- Switch to "Gantt" view in the monitoring
- Parallel activities will show as overlapping horizontal bars

### 3. Check Performance Variables
1. Click on **"CalculatePerformance"** activity
2. Look at the **Output** tab
3. Find the `PerformanceStats` variable
4. It shows: `"Files processed: X | Duration: Y minutes"`

### 4. Calculate Throughput
**Formula**: Files ÷ Duration = Files per minute

**Performance Indicators**:
- **Sequential**: ~0.5-2 files/minute
- **Good Parallel**: 5-15 files/minute  
- **Excellent Parallel**: 15+ files/minute

### 5. Compare Activity Run Details
1. Click **"Activity runs"** tab
2. Look for multiple **"CopyFileWithName"** entries
3. Check their **Start Time** and **End Time**
4. **Parallel = overlapping times**
5. **Sequential = consecutive times**

### 6. Integration Runtime Metrics
1. Go to **Integration Runtimes** in ADF
2. Check **Metrics** tab
3. Look for **CPU** and **Memory** usage spikes
4. Higher usage during pipeline run = more parallelism

---

## 🎯 What Good Parallelism Looks Like:

### Timeline View:
```
File1: [====== ]
File2:  [====== ]
File3:   [====== ]
File4: [====== ]
File5:  [====== ]
```
*(Multiple files processing at same time)*

### Bad (Sequential) Timeline:
```
File1: [======]
File2:        [======]
File3:                [======]
File4:                        [======]
```
*(One file after another)*

---

## 📊 Performance Benchmarks:

| Configuration | Expected Throughput | 100 Files Time |
|--------------|-------------------|----------------|
| **Sequential** | 0.5-2 files/min | 50-200 minutes |
| **Parallel (batch 50)** | 10-30 files/min | 3-10 minutes |
| **Optimized (batch 100)** | 20-50 files/min | 2-5 minutes |

---

## 🚨 Troubleshooting Signs:

### If Performance Seems Slow:
1. **Check for throttling errors** in activity details
2. **Verify batchCount** is set correctly (should be 100)
3. **Check SharePoint API rate limits**
4. **Monitor Integration Runtime capacity**

### Red Flags:
- ❌ Only 1-2 files per minute
- ❌ All copy activities have consecutive times
- ❌ No overlapping activity execution
- ❌ Frequent timeout or throttling errors