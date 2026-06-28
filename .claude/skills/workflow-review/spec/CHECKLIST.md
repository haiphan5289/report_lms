# Workflow Review Checklists

---

## § Accuracy — Doc vs. Live Code (5 points each → /25)

Score each dimension from 5 (fully accurate) to 0 (completely wrong). Deduct per finding.

### A1 · Call Chain Accuracy

Does each workflow diagram correctly reflect the actual call sequence in the code?

Deductions from 5:
- `-3` Documented function does not exist at that call site (wrong caller or callee)
- `-2` Documented phase order is wrong (e.g. Phase 2 before Phase 1 in reality)
- `-1` Missing intermediate step that has observable side effects (e.g. a `PendingUploadStore.addPending` call omitted)
- `-1` Extra documented step that does not exist in code

**How to check:**
1. Identify every `→` or `├──` in the diagram
2. Find the corresponding line in the Swift source
3. Confirm the called function is at that exact call site

---

### A2 · Parameter & Return Type Accuracy

Do function signatures match what the doc says?

Deductions from 5:
- `-2` Function documented with wrong parameter label or type
- `-2` Return type documented incorrectly (e.g. doc says `String?`, code returns `URL?`)
- `-1` Optional vs non-optional mismatch
- `-1` `async` / `throws` modifier missing or wrong in description

---

### A3 · Numeric Constants Accuracy

Are all memory sizes, entry limits, and concurrency counts correct?

Deductions from 5:
- `-2` RAM entry cap (e.g. `maxRAMCount`) documented wrong
- `-2` Eviction batch size (e.g. "FIFO evict 30") documented wrong
- `-2` Upload slot count documented wrong (check all RAM tiers AND network types)
- `-1` Image resize dimension documented wrong (e.g. 800px vs 1024px)
- `-1` JPEG quality value documented wrong (e.g. 0.85 vs 0.9)

**Reference constants to always check:**
```swift
// InspectionImageCacheActor
let maxRAMCount = 60         // → doc must say 60, evict 30
// ImageCacheActor
// maxRAMCount = 100         // → doc must say 100, evict 50
// Upload slots
// <6GB: 3, 6-8GB WiFi:5/Cell:4, ≥8GB WiFi:6/Cell:5
```

---

### A4 · Disk Path & Key Accuracy

Are all file system paths and cache key algorithms described correctly?

Deductions from 5:
- `-3` Disk root directory wrong (Documents vs Caches vs tmp)
- `-2` Key algorithm documented wrong (e.g. `hashValue` vs SHA256)
- `-1` Filename pattern wrong (e.g. `capture_<uuid>` vs `photo_<uuid>`)
- `-1` Remote key filename wrong (e.g. `remote_<sha>.jpg`)

---

### A5 · Post-Processing Steps Accuracy

Are side effects after the main flow (e.g. post-upload thumbnail promotion, silent save callbacks) documented?

Deductions from 5:
- `-3` Major post-processing step entirely absent (e.g. local→remote image conversion after upload)
- `-2` Callback documented in wrong order relative to the main flow
- `-1` `onTaskCompleted` / `onSilentSave` callbacks omitted from a flow where they fire

---

## § Completeness — Gaps in the Doc (5 points → /5)

### C1 · All Code Flows Documented

Score: 5 − (number of undocumented flows with observable side effects)

Flows to check for:
- [ ] `appendImages` — capture + Phase 1 + Phase 2 + upload trigger
- [ ] `loadPendingCaptures` — retry on view appear
- [ ] `uploadPhotosAndUpdateField` — compress + upload + remote conversion + `cacheRemote` promotion
- [ ] `PendingUploadRetryService.retryAllPendingUploads` — app-launch retry
- [ ] `downloadImage` — edit download via `ImageCacheActor`
- [ ] `replaceImage` — edit-result thumbnail-only path (no fileURL)
- [ ] `evictInspection` — cleanup on delete/complete
- [ ] Memory warning → `evictAllRAM`

Missing flows: `-1` per flow not documented (minimum 0).

---

## § Memory — Budget Claims (5 points → /5)

### M1 · Memory Budget Table Accuracy

Score: 5 − (number of wrong entries × 1)

Check every row in the Memory Budget table:

| Claim to verify | Source constant |
|---|---|
| Capture thumbnail RAM size (~2MB) | 800px × 800px × 4 bytes = ~2.4 MB |
| Remote display RAM size (~4MB) | 1024px × 1024px × 4 bytes = ~4 MB |
| Full-res 12MP decoded (~48MB) | 4032px × 3024px × 4 bytes = ~46 MB |
| `InspectionImageCacheActor` max 60 entries | `maxRAMCount = 60` |
| `ImageCacheActor` max 100 entries | `maxRAMCount = 100` |
| Worst-case 60 remote = 240MB | 60 × 4MB |

Deductions:
- `-1` per wrong number
- `-2` if worst-case total is calculated from wrong per-entry size

---

## Scoring Summary

| Dimension | Max |
|---|---|
| A1 · Call Chain | 5 |
| A2 · Parameters | 5 |
| A3 · Numerics | 5 |
| A4 · Disk Paths | 5 |
| A5 · Post-Processing | 5 |
| C1 · Completeness | 5 |
| M1 · Memory Budget | 5 |
| **Total** | **35** |

**Grade thresholds:**
| Score | Verdict |
|---|---|
| 30–35 | ✅ ACCURATE — safe to share |
| 20–29 | ⚠️ NEEDS UPDATE — fix before sharing |
| 0–19  | ❌ STALE — significant drift from code |
