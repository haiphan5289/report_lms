# InspectionValidationView

**Module:** InspectionDetail / InspectionValidation  
**Pattern:** MVVM (SwiftUI + `@StateObject`)  
**Created:** 2026-01-03  
**Last updated:** 2026-06-14 (Memory fix: file-reference model — thumbnail in RAM, full-res on disk)

---

## Overview

`InspectionValidationView` is a full-screen detail sheet used inside an inspection workflow. It allows an inspector to:

- Review photos of a specific inspection field (e.g., "Carton Overview").
- Add or delete photos via the device camera.
- Enter free-text comments.
- Mark the field as **Passed** or **Not Applicable** from a fixed bottom action bar.

Photos are stored locally until the user explicitly saves. When the user taps **Đã kiểm tra** or **Không áp dụng**, all local images are uploaded to Firebase Storage concurrently.

When a photo is captured, a **display thumbnail** (~800 px, ~1.9 MB) is written to the `images` array immediately, while the **full-resolution JPEG** is written to disk (`Documents/inspection-images/<inspectionId>/<fieldId>/`) via `InspectionImageCacheActor`. The file path is registered in `PendingUploadStore` (UserDefaults). The upload path always reads full-res from disk to preserve original quality. On re-entry to the same field while pending uploads exist, images are automatically loaded from disk and upload is retried without any user action. Cache is evicted when the inspection is completed or deleted.

> **Memory budget:** Each camera photo is ~48 MB decoded. Storing only a thumbnail in RAM limits each captured photo to ~1.9 MB — a 25× reduction. Full-res is never held in `viewModel.images` after capture.

---

## Architecture

```
InspectionValidationView  (SwiftUI View)
    └── InspectionValidationViewModel  (@MainActor ObservableObject)
            ├── InspectionStorageServiceType  (Firestore persistence)
            │     └── updateFieldImageURLs(inspectionId:fieldId:imageURLs:)
            │           — serialized via @MainActor pendingFieldWrite task chain
            ├── UploadInspectionMediaUseCase  (Firebase Storage upload)
            ├── InspectionImageCacheActor  (RAM thumbnail + Documents-dir full-res disk cache)
            │     └── cacheCapture / loadFromPath / cacheRemote / loadRemote / evictInspection
            └── PendingUploadStore  (UserDefaults — tracks file paths awaiting upload)
```

Both services are resolved from `Container.shared` (Swinject DI) and can be injected directly for testing.

---

## Initialisation

```swift
InspectionValidationView(
    fieldId: String,                        // Unique ID of the inspection field
    fieldLabel: String,                     // Navigation title & display label
    initialImages: [InspectionImage],       // Pre-loaded images (local or remote)
    inspectionId: String? = nil,            // Parent inspection ID; required for cloud upload
    onSave: @escaping (FieldValidation) -> Void,             // Required — called immediately when status is set
    onSilentSave: ((FieldValidation) -> Void)? = nil,        // Optional — called on auto-save without NavigationStack pop
    onUploadComplete: (() -> Void)? = nil,                   // Called after Firestore write succeeds
    onTaskCompleted: (() -> Void)? = nil,                    // Called after isUploading resets — triggers notifyUploadCompleted()
    onImageProgress: (@Sendable (Int, Double) -> Void)? = nil,  // Per-image upload progress (0.0→1.0)
    onImageDone: (@Sendable (Int) -> Void)? = nil,           // Per-image upload success
    onImageFail: (@Sendable (Int) -> Void)? = nil            // Per-image upload failure
)
```

> `inspectionId` is **required** for upload to work. Without it, `uploadPhotosAndUpdateField` returns early and no photos are written to Firebase.

> `onSave` is **required** (non-optional `@escaping`). `onSilentSave` is optional and fires on auto-save after camera capture (`notifyParent: false` path) — does NOT pop the NavigationStack.

`onSave` fires synchronously so the parent list can update immediately. `onUploadComplete` fires after Firestore write. `onTaskCompleted` fires last — after `isUploading` resets — and is wired to `InspectionDetailViewModel.notifyUploadCompleted()` which decrements `activeUploadCount`.

---

## UI Sections

| Section | View var | Description |
|---|---|---|
| Header | `headerSection` | Field title + camera shortcut button |
| Status & Comments | `statusSection` | Current validation status chip + `TextEditor` for remarks |
| Image Gallery | `imageGallerySection` | Vertical list of `ImageGalleryItemView` cells; hidden when `viewModel.hasImages == false` |
| Actions | `actionsSection` | "Chụp thêm ảnh" (add photo) + toggle delete-mode button ("Xoá hình ảnh" / "Hoàn tất") |
| Bottom Bar | `bottomActionsView` | Fixed overlay with **Đã kiểm tra** (Pass) and **Không áp dụng** (N/A) buttons |

All content sections animate in with a staggered `easeOut` slide-up on `.task` (0 ms → 80 ms → 160 ms → 240 ms).

---

## Image Action Menu

Tapping the `⋯` button on any `ImageGalleryItemView` opens a `confirmationDialog` with three actions:

| Action | Behaviour |
|---|---|
| **Chỉnh sửa** | Loads full-res image from `fileURL` (disk) or downloads remote URL, opens `ImageEditorView` sheet |
| **Chia sẻ** | Loads full-res image from `fileURL` (disk) or downloads remote URL, presents `ShareSheet` (`UIActivityViewController`) |
| **Xoá bỏ** | Calls `viewModel.requestDeleteImage(at:)` → shows `DeleteConfirmationView` fullScreenCover |

`imageRefreshTrigger: Int` is incremented after `replaceImage(at:with:)` completes and is applied as `.id("\(image.id)-\(imageRefreshTrigger)")` on each gallery cell to force a SwiftUI re-render of the edited image.

---

## ViewModel — Published State

| Property | Type | Purpose |
|---|---|---|
| `status` | `ValidationStatus` | Current field status (`.pending`, `.passed`, `.failed`, `.notApplicable`) |
| `comments` | `String` | Inspector notes |
| `images` | `[InspectionImage]` | All images for this field — local entries hold thumbnail + fileURL, remote entries hold remoteURL only |
| `showCamera` | `Bool` | Triggers `.sheet` with `CameraView` |
| `isLoading` | `Bool` | General loading state — distinct from upload tracking (upload state lives in `InspectionDetailViewModel.uploadSessions`) |
| `snackbarMessage` | `String?` | Bound to `.lmsSnackbar(message:type:)` for error banners |
| `showReorderMode` | `Bool` | Puts image list into delete-selection mode |
| `isDirty` | `Bool` | `true` when status / comments / image count differ from initial values |
| `showDeleteConfirmation` | `Bool` | Triggers `DeleteConfirmationView` fullScreenCover |
| `isDownloading` | `Bool` | `true` while loading a remote or disk image for edit/share; shows `LMSLoadingOverlay` |

### Key Methods

| Method | Description |
|---|---|
| `appendImages(_:)` | **Phase 1** (chunked 4-at-a-time, `.utility`): generates 800 px thumbnails, appends `InspectionImage(image: thumb)` to `images[]` immediately so UI updates right away. **Phase 2** (sequential nested Task): for each original image calls `cacheCapture()` then updates `images[id].fileURL` in-place after disk write. After all fileURLs set, calls `saveValidation(status: self.status, notifyParent: false)` exactly once |
| `saveValidation(status:notifyParent:)` | Saves draft, creates `currentUploadTask` that chains onto previous task via `await prevTask?.value` (serial — prevents Firestore race when second batch captured mid-upload). Strips thumbnails from camera-photo entries before upload. Fires `onSave` or `onSilentSave` synchronously; upload + Firestore write runs async inside the chained task |
| `loadPendingCaptures()` | On field re-entry: reads pending file paths from `PendingUploadStore`. Skips prepend if `images` already contains local entries (dedup guard). Loads thumbnails from `InspectionImageCacheActor`, prepends `InspectionImage(fileURL:thumbnail:)` entries. Calls `onSilentSave?` so parent calls `startUploadSession`, then calls `retryPendingUploads()` |
| `requestDeleteImage(at:)` | Stores pending index and shows confirmation dialog |
| `requestDeleteImage(byId:)` | Looks up index by `UUID`, forwards to `requestDeleteImage(at:)` |
| `confirmDeleteImage()` | Removes the stored index after user confirms |
| `cancelDeleteImage()` | Clears pending index without removing |
| `updateComments(_:)` | Mutates `comments` and marks dirty |
| `updateDescription(_:for:)` | Updates `images[id].description` by UUID — used by gallery `descriptionBinding` |
| `moveImage(from:to:)` | Reorders `images[]` via drag-to-reorder; marks dirty |
| `openCamera()` | Sets `showCamera = true` |
| `toggleReorderMode()` | Flips `showReorderMode` |
| `loadDraft()` | Restores status + comments from `UserDefaults` key `draft_validation_<fieldId>` |
| `replaceImage(at:with:)` | Generates 800 px thumbnail from edited `UIImage`, replaces entry in-place preserving `description`. No `fileURL` — edited result is thumbnail-only (upload uses thumbnail quality, not full-res) |
| `downloadImage(from:)` | Downloads a remote URL, caches in `ImageCacheActor`, returns `UIImage` (resized to max 2048 px) |

---

## Upload Flow

```
User takes photo in CameraView
    └── onPhotoCaptured([UIImage]) callback
            └── viewModel.appendImages(images)
                    └── Task { @MainActor }
                            │
                            ├── Phase 1 — bounded parallel resize (chunks of 4, .utility priority):
                            │       while chunkStart < newImages.count:
                            │           chunk = newImages[chunkStart..<chunkStart+4]
                            │           tasks = chunk.map { Task.detached(.utility) { $0.resizedIfNeeded(800px) } }
                            │           thumbnails += tasks.map { await $0.value }
                            │       for thumb in thumbnails:
                            │           images.append(InspectionImage(image: thumb))  ← no fileURL yet
                            │       [UI shows thumbnails immediately — disk write NOT started yet]
                            │
                            └── Phase 2 — sequential disk writes (nested Task, 1 full-res in RAM at a time):
                                    for each newImages[i]:
                                        InspectionImageCacheActor.cacheCapture(image, thumbnail, inspectionId, fieldId)
                                            ├── RAM: stores thumb (800px) — NOT full-res
                                            └── Disk: writes full-res JPEG → Documents/.../capture_<UUID>.jpg
                                        PendingUploadStore.addPending(filePath, inspectionId, fieldId)
                                        images[id].fileURL = URL(fileURLWithPath: path)   ← update in-place by UUID
                                    [all fileURLs set]
                                    saveValidation(status: self.status, notifyParent: false)

User re-enters same inspection field with pending uploads
    └── InspectionValidationView .task → viewModel.loadPendingCaptures()
            ├── PendingUploadStore.getPendingFilePaths() → [String]
            ├── Guard: if images already has local entries → skip prepend (dedup)
            ├── InspectionImageCacheActor.loadFromPath(path) → UIImage (thumb from RAM or disk)
            ├── images.insert(contentsOf: InspectionImage(fileURL:thumbnail:), at: 0)
            ├── onSilentSave?(retryValidation)          ← parent calls startUploadSession
            └── retryPendingUploads()
                    ├── strip thumbnail=nil for fileURL entries
                    └── uploadPhotosAndUpdateField(...)

User taps "Đã kiểm tra" / "Không áp dụng"
    └── saveValidation(status:)
            ├── saveDraft(validation)
            ├── currentUploadTask = Task {
            │       _ = await prevTask?.value            ← serial: wait for any prev upload first
            │       imagesForUpload = images with thumbnail=nil for fileURL entries  ← strip
            │       await uploadPhotosAndUpdateField(fieldId, imagesForUpload)
            │           ├── fullIndexedLocal = images.enumerated().filter { !$0.isRemote }
            │           ├── withTaskGroup (3 / 4 / 5 / 6 slots — see Thread Safety table):
            │           │     addJob: Task.detached(.userInitiated) {
            │           │         Data(contentsOf: fileURL) → UIImage → prepareForUpload()
            │           │         Falls back to thumbnail.prepareForUpload() if no fileURL
            │           │         uploadUseCase.executeWithProgress → URL
            │           │         progressCb(idx, progress) / doneCb(idx) / failCb(idx)
            │           │     }
            │           │     for await (idx, url) in group:
            │           │         ← on success, per image immediately: →
            │           │         images[pos] = InspectionImage(remoteURL:)  ← 2 MB thumbnail freed NOW
            │           │         Task.detached(.background) { cacheRemote(thumb, remoteURL, ...) }
            │           │         ← seed next slot →
            │           ├── merge existingRemoteURLs + newlyUploadedURLs
            │           ├── storageService.updateFieldImageURLs(inspectionId, fieldId, uploadedURLs)
            │           ├── PendingUploadStore.clearField(inspectionId, fieldId)
            │           ├── onSilentSave?(updatedDraft)  ← propagates remote URLs to parent capturedPhotos
            │           └── onUploadComplete?()
            │       await updateInspectionStatus()       ← partial Firestore: only status field
            │       onTaskCompleted?()                   ← decrements activeUploadCount
            │   }
            └── (notifyParent) ? onSave?(validation) : onSilentSave?(validation)
```

> **Upload quality:** Full-res JPEG is always read from disk (via `fileURL`). Thumbnails are stripped from the function-parameter copy before upload to prevent N × 2 MB accumulating in the async stack. The thumbnail in `self.images[]` is released progressively per image as each upload completes. `prepareForUpload()` resizes to ≤1600 px and encodes as WebP/JPEG.

> **Serial upload guarantee:** `currentUploadTask` chains each new upload onto the previous via `await prevTask?.value`. If the user captures a second batch while a first upload is in flight, the second upload waits for the first to finish. This ensures `existingRemoteURLs` is always fresh (includes images just uploaded by the previous task) and prevents two concurrent tasks writing different URL sets to Firestore.

---

## Sub-components

### `ImageGalleryItemView`

Located at `Views/ImageGalleryItemView.swift`.

| Prop | Type | Description |
|---|---|---|
| `inspectionImage` | `InspectionImage` | Source image — displays `thumbnail` for local captures, remote URL via `InspectionCachedImage` |
| `isReorderMode` | `Bool` | Shows delete (`xmark.circle.fill`) overlay when `true` |
| `onDelete` | `() -> Void` | Forwarded to `requestDeleteImage(at:)` in parent VM |
| `onMenu` | `() -> Void` | Opens `confirmationDialog` with Edit / Share / Delete actions |
| `descriptionBinding` | `Binding<String>` | ID-based two-way bind to `images[index].description` (safe against deletion races) |
| `inspectionId` | `String?` | Optional — passed from `InspectionValidationView` for durable remote cache |
| `fieldId` | `String?` | Optional — paired with `inspectionId` for 3-tier loader |

When both `inspectionId` and `fieldId` are provided, renders remote images via `InspectionCachedImage` (3-tier durable loader). Otherwise falls back to `CachedAsyncImage`. Local captures render `thumbnail` via `Image(uiImage: inspectionImage.image)` (`.image` is now a computed property returning `thumbnail ?? UIImage()`).

> **Binding safety:** The gallery uses `ForEach(viewModel.images)` (non-binding) with a manual ID-based `Binding(get:set:)` for `description`. This prevents an `Array index out of range` crash that occurred when SwiftUI's attribute graph tried to update an index-based binding after an image was deleted.

### `InspectionCachedImage`

Located at `Views/InspectionCachedImage.swift`.

3-tier image loader for remote inspection photos:

| Tier | Store | Durable? |
|---|---|---|
| 1 | `InspectionImageCacheActor` (RAM thumbnail + Documents/) | ✅ Yes |
| 2 | `ImageCacheActor` (RAM + Caches/) | ❌ Purgeable |
| 3 | Network fetch | — |

### `LMSUploadProgressBar`

**Path:** `Sources/Common/Components/Loading/LMSUploadProgressBar.swift`

| Mode | Behaviour |
|---|---|
| `.indeterminate` | Gradient shimmer sweeping left → right |
| `.determinate(Double)` | Solid fill animating to the given fraction |

### `ClearBackgroundView`

A `UIViewRepresentable` helper that sets the `fullScreenCover` window background to `.clear`, enabling the translucent `DeleteConfirmationView` overlay.

### `ImageEditorView`

Presented as a `.sheet` when the user taps **Chỉnh sửa** from the image action menu. Receives the full-res `UIImage` loaded from `fileURL` (or downloaded for remote images). Returns the edited `UIImage` via closure → `viewModel.replaceImage(at:with:)`.

---

## InspectionImage Model

```swift
struct InspectionImage: Identifiable, Equatable {
    let id: UUID
    var thumbnail: UIImage?   // display copy (~800 px, ~1.9 MB in RAM). nil for remote images
    var fileURL: URL?         // absolute path to full-res JPEG on disk. nil for remote/legacy
    var remoteURL: URL?       // Firebase Storage URL. nil until uploaded

    var isRemote: Bool  { remoteURL != nil }
    var hasLocalFile: Bool { fileURL != nil }

    // Backward-compatible accessor — returns thumbnail for display.
    // Upload and edit flows MUST load full-res from fileURL instead.
    var image: UIImage { thumbnail ?? UIImage() }

    // Primary init — camera captures
    init(fileURL: URL, thumbnail: UIImage, description: String = "")

    // Remote image after upload
    init(remoteURL: URL, description: String = "")

    // Legacy init — PDF/HTML generation, tests (stores UIImage as thumbnail, no fileURL)
    init(image: UIImage, description: String = "")
}
```

### Memory per image

| State | RAM usage |
|---|---|
| Just captured (thumbnail) | ~1.9 MB |
| After upload (remoteURL only) | ~0 MB |
| Remote image (not yet loaded) | ~0 MB |

After a successful upload, a local entry is replaced with `InspectionImage(remoteURL:)`. `thumbnail` becomes `nil`, `fileURL` becomes `nil`, `isRemote` becomes `true`.

---

## Cache & Auto-Retry

### Storage Layout

```
Documents/inspection-images/
    <inspectionId>/
        <fieldId>/
            capture_<UUID>.jpg       ← full-res local capture (written at appendImages time)
            remote_<urlHash>.jpg     ← remote image (written after network fetch)
```

- **RAM cache** (`InspectionImageCacheActor`): stores **thumbnails** (~800 px) keyed by file path. FIFO eviction at **60 entries** — when full, the oldest 30 are evicted (half-eviction). Full-res is never kept in RAM.
- **PendingUploadStore** keys: `pendingUploads_<inspectionId>_<fieldId>` → `[String]` (absolute file paths)
- `getPendingFilePaths()` auto-filters paths where `FileManager.fileExists` returns false

### Eviction Policy

| Trigger | Action |
|---|---|
| Inspection completed | `InspectionImageCacheActor.evictInspection(id)` + `PendingUploadStore.clearInspection(id)` |
| Inspection deleted | Same |
| Upload success | `PendingUploadStore.clearField(inspectionId, fieldId)` — disk images kept until inspection eviction |
| Memory warning | `InspectionImageCacheActor.evictAllRAM()` — clears all 60 RAM thumbnails; disk untouched (next display reloads from disk transparently) |

---

## Thread Safety

| Operation | Context |
|---|---|
| `@Published` property updates | `@MainActor` |
| `appendImages` Phase 1 thumbnail generation | `Task.detached(priority: .utility)` — chunked 4-at-a-time; `.utility` prevents thermal saturation vs `.userInitiated` on 300-photo batches |
| `appendImages` Phase 2 disk write (`cacheCapture`) | `InspectionImageCacheActor` actor — sequential, 1 full-res image in RAM at a time |
| Upload compress — load from disk + `prepareForUpload()` | `Task.detached(priority: .userInitiated)` |
| Upload — Firebase Storage | `withTaskGroup`; **3** slots (<6 GB RAM), **5 WiFi / 4 cellular** (6–8 GB), **6 WiFi / 5 cellular** (≥8 GB) |
| Firestore write | `storageService` actor — serial executor |
| Edit/Share — full-res load from disk | `Task.detached` — background |

---

## Draft Persistence

Written to `UserDefaults` under `draft_validation_<fieldId>` on every `saveValidation` call:

```json
{
  "status": "passed",
  "comments": "No visible damage",
  "imageCount": 3,
  "lastUpdated": 1748304000.0
}
```

Full image data is **not** persisted in the draft; only metadata. Call `viewModel.loadDraft()` to restore status and comments on re-entry.

---

## Debug Overlay

> **Status: Commented out.** The toolbar button and sheet are disabled via `// #if DEBUG` comments in `InspectionValidationView.swift` (lines 121–135). To re-enable, uncomment those blocks.

When enabled (DEBUG builds only), a 🐛 button opens `CacheDebugOverlay` as a bottom sheet with:

- **Stats strip:** RAM count / Disk count / Pending count for the current field
- **Event log** (up to 60 entries): disk writes, RAM hits, pending additions, upload success, evictions

---

## Dependencies

| Symbol | Source |
|---|---|
| `InspectionImage` | Domain model — thumbnail + fileURL + optional remoteURL + description |
| `FieldValidation` | Domain model — snapshot of one field's status, comments, images, timestamp |
| `ValidationStatus` | Enum: `.pending`, `.passed`, `.failed`, `.notApplicable` |
| `InspectionStorageServiceType` | Protocol — Firestore read/write for `Inspection` documents |
| `UploadInspectionMediaUseCase` | Use-case — uploads compressed data to Firebase Storage, returns URL |
| `CameraView` | Shared capture sheet; returns `[UIImage]` (full-res) via closure |
| `ImageEditorView` | In-place image editor; returns edited `UIImage` via closure |
| `DeleteConfirmationView` | Reusable confirmation overlay |
| `LMSButton`, `LMSLabel` | LMS Design System components |
| `LMSColor` | Color tokens (`.primary`, `.shadow`) |
| `LMSLoadingOverlay` | Full-screen loading overlay shown during remote image download |
| `CachedAsyncImage` | Async image loader with ephemeral cache (`ImageCacheActor`) |
| `InspectionImageCacheActor` | `Common/Helpers/InspectionImageCacheActor.swift` — RAM thumbnail + Documents-dir full-res cache |
| `PendingUploadStore` | `Common/Helpers/PendingUploadStore.swift` — UserDefaults file-path tracker |
| `CacheDebugLogger` | `Common/Helpers/CacheDebugLogger.swift` — realtime event logger |
| `CacheDebugOverlay` | `Views/CacheDebugOverlay.swift` — debug sheet _(currently commented out)_ |
| `InspectionCachedImage` | `Views/InspectionCachedImage.swift` — 3-tier durable remote image loader |
| `ClearBackgroundView` | Helper — clears `fullScreenCover` window background for translucent overlay |
| `CrashlyticsLogger` | `Common/Helpers/CrashlyticsLogger.swift` — non-fatal error recording to Firebase Crashlytics |

---

## Previews

| Preview | Description |
|---|---|
| `"With Images"` | Four placeholder images pre-loaded |
| `"Empty State"` | No images — gallery section is hidden |
| `"Dark Mode"` | Two images, `.preferredColorScheme(.dark)` |
