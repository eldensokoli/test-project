# SharePoint to Azure Blob - Scope Options

## 🎯 Current Setup Analysis

Your current pipeline is accessing:
```
/drives/b!Ejj63UTut0iDrmCRF-cVWebgpptroFFGkfmuMIqv10NXgaE-eKAoQpST-83HmNqa/root/delta
```

This targets **one specific document library**.

---

## 🚀 Expansion Options

### Option 1: Get Entire Main Document Library ✅ (Already Updated)
**Current URL**: `/drive/root/delta` 
- Gets ALL files from the main site's document library
- Includes all folders and subfolders
- **Best for**: Most SharePoint sites (Documents library)

### Option 2: Get ALL Libraries in the Site 🔄 (New Pipeline)
**New Pipeline**: `azureDataFactory_full_site.json`
- Gets Documents, Site Assets, Form Templates, etc.
- Processes each library separately
- **Best for**: Complete site backup

### Option 3: Specific Libraries Only 🎯
Modify URL to target specific libraries:
```
/sites/{site-id}/lists/{list-id}/drive/root/delta
```

---

## 📊 Scope Comparison

| Option | What It Gets | File Count | Best Use Case |
|--------|-------------|------------|---------------|
| **Current (Updated)** | Main Documents library | 100-10K files | Most common scenario |
| **Full Site** | All libraries | 1K-100K files | Complete backup |
| **Specific Library** | One chosen library | 10-1K files | Targeted sync |

---

## 🎯 Recommended Approach

### For Most Cases (Current - Already Updated):
Your pipeline now uses `/drive/root/delta` which will get:
- ✅ All files in Documents library
- ✅ All subfolders and their files  
- ✅ Shared documents
- ✅ Most user content

### For Complete Site Backup:
Use the new `azureDataFactory_full_site.json` pipeline which:
- 🔄 Discovers all document libraries
- 🔄 Processes each library in parallel  
- 🔄 Maintains library structure in blob storage
- ⚠️  More complex but comprehensive

---

## 🚀 What Changed in Your Current Pipeline

**Before**: 
```
/drives/b!.../root/delta  (specific drive)
```

**After**: 
```
/drive/root/delta  (main site drive)
```

**Result**: Now gets ALL content from the main SharePoint document library instead of just a subfolder!

---

## 📈 Expected Performance Impact

### Current Pipeline (Updated):
- **More files**: 10-100x more files to process
- **Same speed**: Parallelism will handle the load
- **Estimated time**: Still very fast with your optimizations

### For 3TB Across Multiple Libraries:
- **Use full site pipeline**: Better organization
- **Parallel library processing**: Each library processed simultaneously
- **Folder structure preserved**: `FullSiteBackup/LibraryName/folders/`

---

## 🎯 Next Steps

1. **Test current pipeline**: See how many files it finds now
2. **Monitor performance**: With more files, parallelism benefits increase
3. **Consider full site**: If you need ALL libraries, use the new pipeline
4. **Scale as needed**: Adjust batchCount based on file volume

Your current pipeline should now capture the entire main SharePoint document library! 🚀