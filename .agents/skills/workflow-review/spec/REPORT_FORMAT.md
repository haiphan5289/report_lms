# Workflow Review Report Format

## Score Summary

```
📋 Workflow Review — [DocumentName]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Document: [path]
Files read: [list all Swift files read]

Accuracy Score
  A1 · Call Chain          N/5
  A2 · Parameters          N/5
  A3 · Numeric Constants   N/5
  A4 · Disk Paths & Keys   N/5
  A5 · Post-Processing     N/5

Completeness Score
  C1 · All Flows Covered   N/5

Memory Budget Score
  M1 · Budget Claims       N/5

Overall:  N/35
Verdict:  ✅ ACCURATE | ⚠️ NEEDS UPDATE | ❌ STALE
```

---

## Inaccuracies Section

### Critical Inaccuracies (misleading — fix before sharing)

```
❌ [A3-Numerics] Upload slot count wrong
   Doc says: "maxConcurrent: 3 hoặc 4 tùy RAM device"
   Code says: 3/4/5/6 depending on RAM tier and network (maxConcurrentSlots)
   File: InspectionValidationViewModel.swift:501
   Fix: Update diagram to "3/4/5/6 tùy RAM + network type"
```

### Gaps (flows in code not in doc)

```
⚠️ [C1-Completeness] Post-upload cacheRemote promotion not documented
   Flow: After updateFieldImageURLs succeeds, each local image is converted to
         a remote entry and its thumbnail is promoted to InspectionImageCacheActor
   File: InspectionValidationViewModel.swift:394–408
   Fix: Add promotion step at the end of the Upload workflow diagram
```

### Passing Checks

```
✅ [A4] SHA256 key rationale correct — matches remoteKey(for:) implementation
✅ [A3] FIFO eviction: 60 entries / evict 30 — matches maxRAMCount=60, half=30
✅ [M1] Capture thumbnail RAM ~2MB — consistent with 800px resize
```

---

## Prioritised Fix List

```
Fix order (highest impact first):
  1. [❌ A3] Correct upload slot count in Upload workflow diagram
  2. [❌ A5] Add post-upload local→remote conversion + cacheRemote step
  3. [⚠️ A1] Phase 1 description: add "max 4 concurrent, chunked"
  4. [⚠️ C1] Document replaceImage (edit) thumbnail-only limitation
  5. [⚠️ C1] Document isOnWiFiOrEthernet blocking semaphore in Known Limitations
```

---

## Example Full Report

```
📋 Workflow Review — IMAGE_CACHE_WORKFLOW.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Document: Sources/Presentation/Modules/InspectionDetail/IMAGE_CACHE_WORKFLOW.md
Files read:
  • Sources/Common/Helpers/InspectionImageCacheActor.swift
  • Sources/Presentation/Modules/InspectionDetail/InspectionValidation/InspectionValidationViewModel.swift

Accuracy Score
  A1 · Call Chain          4/5   ⚠️ Phase 1 missing chunking detail
  A2 · Parameters          5/5   ✅
  A3 · Numeric Constants   3/5   ❌ Upload slots wrong (says 3/4, actually 3/4/5/6)
  A4 · Disk Paths & Keys   5/5   ✅
  A5 · Post-Processing     2/5   ❌ Post-upload cacheRemote promotion entirely absent

Completeness Score
  C1 · All Flows Covered   3/5   ⚠️ replaceImage and isOnWiFiOrEthernet not documented

Memory Budget Score
  M1 · Budget Claims       5/5   ✅

Overall: 27/35
Verdict: ⚠️ NEEDS UPDATE

Inaccuracies:

❌ [A3] Upload slot count wrong
   Doc: "maxConcurrent: 3 hoặc 4 tùy RAM device"
   Code: 3 slots (<6GB), 5 WiFi/4 cellular (6–8GB), 6 WiFi/5 cellular (≥8GB)
   File: InspectionValidationViewModel.swift:501–510
   Fix: "maxConcurrent: 3/4/5/6 tùy RAM + network"

❌ [A5] Post-upload local→remote conversion + cacheRemote promotion absent
   After updateFieldImageURLs: images[idx] = InspectionImage(remoteURL:)
   Then: Task.detached { cacheRemote(image: thumb, url: remoteURL, ...) }
   File: InspectionValidationViewModel.swift:394–408
   Fix: Add promotion block at end of Upload workflow diagram

⚠️ [A1] Phase 1 described as unbounded parallel (Task.detached × N)
   Code uses chunkSize=4, processes chunks sequentially
   File: InspectionValidationViewModel.swift:108–116
   Fix: "max 4 concurrent Task.detached per chunk (chunked for thermal budget)"

⚠️ [C1] replaceImage flow not documented
   Creates thumbnail-only InspectionImage (no fileURL) → upload uses 800px quality
   File: InspectionValidationViewModel.swift:434–448
   Fix: Add to Known Limitations table

⚠️ [C1] isOnWiFiOrEthernet uses DispatchSemaphore (blocks cooperative thread)
   File: InspectionValidationViewModel.swift:514–524
   Fix: Add to Known Limitations or refactor to async

Passing:
  ✅ [A4] SHA256 key — matches remoteKey(for:) exactly
  ✅ [A3] RAM cap 60/evict 30 and 100/evict 50 — correct
  ✅ [A2] cacheCapture(image:thumbnail:inspectionId:fieldId:) signature matches
  ✅ [M1] All MB estimates consistent with pixel math
  ✅ [A1] loadPendingCaptures flow matches code

Prioritised Fix List:
  1. [❌ A3] Correct slot count to 3/4/5/6 — IMAGE_CACHE_WORKFLOW.md Upload diagram
  2. [❌ A5] Add post-upload promotion step — IMAGE_CACHE_WORKFLOW.md Upload diagram
  3. [⚠️ A1] Add "chunked" to Phase 1 description
  4. [⚠️ C1] Add replaceImage row to Known Limitations
  5. [⚠️ C1] Add isOnWiFiOrEthernet note to Known Limitations
```
