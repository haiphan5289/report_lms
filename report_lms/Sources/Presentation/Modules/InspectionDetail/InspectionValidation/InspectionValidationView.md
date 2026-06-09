# InspectionValidationView

**Module:** InspectionDetail / InspectionValidation  
**Pattern:** MVVM (SwiftUI + `@StateObject`)  
**Created:** 2026-01-03  
**Last updated:** 2026-06-09 (Cache: RAM + disk image caching, auto-retry, debug overlay — overlay commented out)

---

## Overview

`InspectionValidationView` is a full-screen detail sheet used inside an inspection workflow. It allows an inspector to:

- Review photos of a specific inspection field (e.g., "Carton Overview").
- Add or delete photos via the device camera.
- Enter free-text comments.
- Mark the field as **Passed** or **Not Applicable** from a fixed bottom action bar.

Photos are stored locally until the user explicitly saves. When the user taps **Đã kiểm tra** or **Không áp dụng**, all local images are uploaded to Firebase Storage concurrently. A floating progress toast appears at the bottom during the upload.

When a photo is captured, it is **immediately written to disk** (`Documents/inspection-images/<inspectionId>/<fieldId>/`) via `InspectionImageCacheActor` and registered in `PendingUploadStore` (UserDefaults). On re-entry to the same field while pending uploads exist, images are automatically loaded from disk and upload is retried without any user action. Cache is evicted when the inspection is completed or deleted.

---

## Architecture

```
InspectionValidationView  (SwiftUI View)
    └── InspectionValidationViewModel  (@MainActor ObservableObject)
            ├── InspectionStorageServiceType  (Firestore persistence)
            │     └── updateFieldImageURLs(inspectionId:fieldId:imageURLs:)
            │           — serialized via @MainActor pendingFieldWrite task chain in
            │             FirestoreInspectionStorageService; safe for concurrent field uploads
            ├── UploadInspectionMediaUseCase  (Firebase Storage upload)
            ├── InspectionImageCacheActor  (RAM + Documents-dir disk cache — durable)
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
    onSave: ((FieldValidation) -> Void)? = nil,            // Called immediately when status is set
    onUploadComplete: (() -> Void)? = nil,                 // Called after Firestore write succeeds
    onTaskCompleted: (() -> Void)? = nil,                  // Called after isUploading resets — triggers notifyUploadCompleted()
    onImageProgress: (@Sendable (Int, Double) -> Void)? = nil,  // Per-image upload progress (0.0→1.0)
    onImageDone: (@Sendable (Int) -> Void)? = nil,         // Per-image upload success
    onImageFail: (@Sendable (Int) -> Void)? = nil          // Per-image upload failure
)
```

> `inspectionId` is **required** for upload to work. Without it, `uploadPhotosAndUpdateField` returns early and no photos are written to Firebase.

`onSave` fires synchronously so the parent list can update immediately. `onUploadComplete` fires after Firestore write. `onTaskCompleted` fires last — after `isUploading` resets — and is wired to `InspectionDetailViewModel.notifyUploadCompleted()` which decrements `activeUploadCount`.

---

## UI Sections

| Section | View var | Description |
|---|---|---|
| Header | `headerSection` | Field title + camera shortcut button |
| Status & Comments | `statusSection` | Current validation status chip + `TextEditor` for remarks |
| Image Gallery | `imageGallerySection` | Vertical list of `ImageGalleryItemView` cells; hidden when empty |
| Actions | `actionsSection` | "Chụp thêm ảnh" (add photo) + toggle delete-mode button |
| Bottom Bar | `bottomActionsView` | Fixed overlay with **Đã kiểm tra** (Pass) and **Không áp dụng** (N/A) buttons |
| Upload Toast | `uploadToastView` | Floating card above bottom bar — visible while `isUploading == true` |

All content sections animate in with a staggered `easeOut` slide-up on `.task` (0 ms → 80 ms → 160 ms → 240 ms).

---

## Upload Toast

A floating card that slides up from the bottom whenever `isUploading == true`:

```
┌─────────────────────────────────────┐
│  ↑  Đang tải ảnh lên...             │  ← indeterminate shimmer
│  ════════════░░░░░░░░░░░░░░░░░░░░░  │
└─────────────────────────────────────┘

        [✓ Đã kiểm tra]  [/ Không áp dụng]   ← bottom buttons bên dưới

↓ Khi upload xong (uploadProgress == 1.0):

┌─────────────────────────────────────┐
│  ✓  Đã tải lên                      │  ← icon và text đổi màu xanh
│  ████████████████████████████████   │  ← fill 100%
└─────────────────────────────────────┘
```

- Positioned inside the root `ZStack` with `.padding(.bottom, bottomButtonHeight + 12)` — never overlaps the action buttons
- Appears/disappears with `.move(edge: .bottom).combined(with: .opacity)` and a spring animation
- Uses `LMSUploadProgressBar` internally (height 4pt, indeterminate → determinate on completion)
- Icon and label swap automatically when `uploadProgress >= 1.0`

---

## ViewModel — Published State

| Property | Type | Purpose |
|---|---|---|
| `status` | `ValidationStatus` | Current field status (`.pending`, `.passed`, `.failed`, `.notApplicable`) |
| `comments` | `String` | Inspector notes |
| `images` | `[InspectionImage]` | All images for this field (local + remote) |
| `showCamera` | `Bool` | Triggers `.sheet` with `CameraView` |
| `isUploading` | `Bool` | `true` while any eager or save upload is in flight; drives the upload toast |
| `uploadProgress` | `Double` | `0.0` → `1.0`; switches toast bar from indeterminate to determinate fill |
| `errorMessage` | `String?` | Error banner binding |
| `showReorderMode` | `Bool` | Puts image list into delete-selection mode |
| `isDirty` | `Bool` | `true` when status / comments / image count differ from initial values |
| `showDeleteConfirmation` | `Bool` | Triggers `DeleteConfirmationView` fullScreenCover |
| `isDownloading` | `Bool` | `true` while downloading a remote image for edit/share; shows `LMSLoadingOverlay` |

### Key Methods

| Method | Description |
|---|---|
| `appendImages(_:)` | Wraps `[UIImage]` → `[InspectionImage]` and appends to `images`. Immediately writes each image to disk via `InspectionImageCacheActor.cacheCapture()` and registers the file path in `PendingUploadStore`. **No Firebase upload yet** — images stay local until save |
| `saveValidation(status:)` | Sets status, builds `FieldValidation`, saves draft, fires `onSave`, then uploads all local images and writes to Firestore. Clears `PendingUploadStore` entry on success |
| `loadPendingCaptures()` | On field re-entry: reads pending file paths from `PendingUploadStore`, loads images from disk via `InspectionImageCacheActor`, prepends them to `images`, then auto-triggers `retryPendingUploads()` |
| `requestDeleteImage(at:)` | Stores pending index and shows confirmation dialog |
| `confirmDeleteImage()` | Removes the stored index after user confirms |
| `updateComments(_:)` | Mutates `comments` and marks dirty |
| `openCamera()` | Sets `showCamera = true` |
| `toggleReorderMode()` | Flips `showReorderMode` |
| `loadDraft()` | Restores status + comments from `UserDefaults` key `draft_validation_<fieldId>` |
| `replaceImage(at:with:)` | Replaces an image in-place after editing; preserves existing description |

---

## Upload Flow

```
User takes photo in CameraView
    └── onPhotoCaptured([UIImage]) callback
            └── viewModel.appendImages(images)
                    ├── images.append(...)   ← stored locally, NO Firebase upload yet
                    └── [Task — background] for each new image:
                            InspectionImageCacheActor.cacheCapture(image, inspectionId, fieldId)
                                └── writes JPEG to Documents/inspection-images/<id>/<fid>/capture_<UUID>.jpg
                            PendingUploadStore.addPending(filePath, inspectionId, fieldId)
                                └── appends path to UserDefaults key pendingUploads_<id>_<fid>
                            CacheDebugLogger.log(.diskWrite / .pendingAdded)   ← debug overlay

User re-enters same inspection field with pending uploads
    └── InspectionValidationView .task → viewModel.loadPendingCaptures()
            ├── PendingUploadStore.getPendingFilePaths() → [String] (stale paths filtered out)
            ├── InspectionImageCacheActor.loadFromPath(path) → UIImage  (for each path)
            ├── images.insert(contentsOf: loaded, at: 0)
            └── retryPendingUploads()   ← isUploading = true, auto-triggers full upload

User taps "Đã kiểm tra" / "Không áp dụng"
    └── saveValidation(status:)
            ├── onSave(validation)                      ← parent updates immediately
            ├── withAnimation { isUploading = true }    ← toast slides up
            └── Task {
                    uploadPhotosAndUpdateField(fieldId, images)
                        ├── localImages = images.filter { !$0.isRemote }
                        ├── Phase 1 — Compress (max 4 concurrent on high-RAM, 3 on low-RAM):
                        │     withTaskGroup → Task.detached(priority: .userInitiated) {
                        │           image.prepareForUpload()
                        │               ├── Resize to ≤1600px (aspect-ratio preserved)
                        │               └── JPEG 0.8 quality (~600KB)
                        │     }
                        ├── Phase 2 — Upload (max 8 concurrent on WiFi/5G, 6 on cellular):
                        │     withTaskGroup → uploadUseCase.executeWithProgress(data, inspectionId,
                        │           onProgress: progressCb(index, fraction)   ← UI progress bar
                        │           onDone:     doneCb(index)                  ← mark item .done
                        │           onFail:     failCb(index)                  ← mark item .failed
                        │     ) → [String URL]
                        ├── merge existingRemoteURLs + newlyUploadedURLs
                        ├── storageService.updateFieldImageURLs(inspectionId, fieldId, uploadedURLs)
                        │     ← serialized write: chains on pendingFieldWrite task chain
                        │     ← reads fresh cache AFTER previous field's write lands
                        │     ← safe when multiple fields upload concurrently
                        └── PendingUploadStore.clearField(inspectionId, fieldId)   ← ✅ upload done
                              CacheDebugLogger.log(.uploadSuccess)
                    updateInspectionStatus()
                        └── inspection.status = .inProgress → Firestore
                    withAnimation { uploadProgress = 1.0 }
                    sleep 0.5s
                    withAnimation { isUploading = false }   ← toast slides down
                    onUploadComplete?()
                    onTaskCompleted?()   ← InspectionDetailViewModel.notifyUploadCompleted() → activeUploadCount -= 1
                }
```

> **Performance:** Phase 1 compress runs in `Task.detached(priority: .userInitiated)` — off main thread. Phase 2 upload uses throttled `withTaskGroup` — 8 slots on fast network, 6 on cellular. Decoupling compress/upload means upload slots never idle waiting for CPU work.

---

## Sub-components

### `LMSUploadProgressBar`

**Path:** `Sources/Common/Components/Loading/LMSUploadProgressBar.swift`

Design system component for upload activity feedback.

| Mode | Behaviour |
|---|---|
| `.indeterminate` | Gradient shimmer sweeping left → right, repeating forever |
| `.determinate(Double)` | Solid fill animating to the given fraction (0.0–1.0) |

```swift
LMSUploadProgressBar(mode: .indeterminate)               // shimmer
LMSUploadProgressBar(mode: .determinate(0.7))            // 70% fill
LMSUploadProgressBar(mode: .determinate(1.0), height: 4) // custom height
```

Default height: `3pt`. Color: `LMSColor.primary` (fill), `LMSColor.primary.opacity(0.15)` (track).

### `ImageGalleryItemView`

Located at `Views/ImageGalleryItemView.swift`.

| Prop | Type | Description |
|---|---|---|
| `inspectionImage` | `InspectionImage` | Source image (local `UIImage` or remote `URL`) |
| `isReorderMode` | `Bool` | Shows delete (`xmark.circle.fill`) overlay when `true` |
| `onDelete` | `() -> Void` | Forwarded to `requestDeleteImage(at:)` in parent VM |
| `descriptionBinding` | `Binding<String>` | Two-way bind to `images[index].description` |
| `inspectionId` | `String?` | Optional — passed from `InspectionValidationView` for durable remote cache |
| `fieldId` | `String?` | Optional — paired with `inspectionId` for 3-tier loader |

When both `inspectionId` and `fieldId` are provided, renders remote images via `InspectionCachedImage` (3-tier durable loader: `Documents/` → `Caches/` → network). Otherwise falls back to `CachedAsyncImage`. Local captures always render via `Image(uiImage:)`.

### `InspectionCachedImage`

Located at `Views/InspectionCachedImage.swift`.

3-tier image loader for remote inspection photos that survives iOS Caches purge:

| Tier | Store | Durable? | Description |
|---|---|---|---|
| 1 | `InspectionImageCacheActor` (RAM + Documents/) | ✅ Yes | First check — fastest path after first load |
| 2 | `ImageCacheActor` (RAM + Caches/) | ❌ Purgeable | Fallback to existing ephemeral cache |
| 3 | Network fetch | — | Downloads and writes to BOTH tier 1 + tier 2 |

```swift
InspectionCachedImage(url: url, inspectionId: id, fieldId: fid) { phase in
    switch phase {
    case .success(let image): image.resizable()...
    case .empty: ProgressView()
    case .failure: Image(systemName: "exclamationmark.triangle")
    }
}
```

### `ClearBackgroundView`

A `UIViewRepresentable` helper that sets the `fullScreenCover` window background to `.clear`, enabling the translucent `DeleteConfirmationView` overlay.

---

## Cache & Auto-Retry

### Storage Layout

```
Documents/inspection-images/
    <inspectionId>/
        <fieldId>/
            capture_<UUID>.jpg       ← local capture (written at appendImages time)
            remote_<urlHash>.jpg     ← remote image (written after network fetch)
```

- **RAM cache**: `InspectionImageCacheActor` also holds a `[String: UIImage]` dict (FIFO eviction at 200 entries)
- **PendingUploadStore** keys: `pendingUploads_<inspectionId>_<fieldId>` → `[String]` (absolute file paths)
- `getPendingFilePaths()` auto-filters paths where `FileManager.fileExists` returns false (stale entries after Caches purge)

### Eviction Policy

| Trigger | Action |
|---|---|
| Inspection completed (`markInspectionCompleted`) | `InspectionImageCacheActor.evictInspection(id)` + `PendingUploadStore.clearInspection(id)` |
| Inspection deleted (`deleteInspection`) | Same — both `FirestoreInspectionStorageService` and `InspectionStorageService` |
| Upload success | `PendingUploadStore.clearField(inspectionId, fieldId)` only — disk images kept until inspection eviction |

Cache otherwise free-grows — no size limit until inspection lifecycle ends.

### Auto-Retry Flow

```
App launch → user navigates to InspectionValidationView
    └── .task → viewModel.loadPendingCaptures()
            ├── PendingUploadStore.getPendingFilePaths(inspectionId, fieldId) → ["/Documents/.../capture_uuid.jpg"]
            ├── [ paths empty ] → return   (nothing to retry)
            └── [ paths non-empty ]
                    ├── InspectionImageCacheActor.loadFromPath(path) → UIImage  (each)
                    ├── images.insert(loaded, at: 0)
                    └── retryPendingUploads()
                            ├── isUploading = true, uploadProgress = 0.0
                            ├── uploadPhotosAndUpdateField(fieldId, images)
                            └── [on success] PendingUploadStore.clearField(...)
```

---

## Debug Overlay

> **Status: Commented out.** The toolbar button and sheet are currently disabled via `// #if DEBUG` comments in `InspectionValidationView.swift` (lines 126–140). To re-enable, uncomment those blocks.

`InspectionValidationView` previously included a **debug overlay** (DEBUG builds only) accessible via a 🐛 (ladybug) button in the navigation bar. When enabled, tapping the button opens `CacheDebugOverlay` as a bottom sheet.

### Stats Strip

| Chip | What it shows |
|---|---|
| RAM | Count of images in `InspectionImageCacheActor` RAM dict for this field |
| Disk | Count of `.jpg` files in `Documents/inspection-images/<id>/<fid>/` |
| Pending | Count of paths in `PendingUploadStore` for this field |

Tap ↺ to refresh counts.

### Event Log (up to 60 entries, newest first)

| Icon | Event | When fired |
|---|---|---|
| ⬇ | `DISK WRITE <tag> (N KB)` | On `cacheCapture` or `cacheRemote` success |
| 💾 | `DISK HIT <tag>` | On `loadFromPath` or `loadRemote` disk hit |
| ⚡ | `RAM HIT <tag>` | On RAM dict hit |
| 📋 | `PENDING +1 <fieldId> → N total` | On `PendingUploadStore.addPending` |
| 🔄 | `RETRY UPLOAD N image(s)` | On `retryPendingUploads` start |
| ✅ | `UPLOAD SUCCESS <fieldId>` | After Firestore write + `clearField` |
| 🗑 | `EVICTED <inspectionId>` | On `evictInspection` |

The overlay uses `@StateObject private var logger = CacheDebugLogger.shared`. Log entries are non-isolating — `CacheDebugLogger.log()` is callable from any actor or thread.

---

## InspectionImage Model

```swift
struct InspectionImage: Identifiable {
    let id: UUID
    var image: UIImage          // local capture (placeholder if remote)
    var remoteURL: URL?         // nil = not yet uploaded
    var description: String

    var isRemote: Bool { remoteURL != nil }

    init(image: UIImage, description: String = "")       // local
    init(remoteURL: URL, description: String = "")       // remote
}
```

After eager upload succeeds, a local entry is replaced with `InspectionImage(remoteURL:)`. `isRemote` switches to `true` and the save flow skips it.

---

## Dependencies

| Symbol | Source |
|---|---|
| `InspectionImage` | Domain model — wraps `UIImage` + optional `remoteURL` + `description` |
| `FieldValidation` | Domain model — snapshot of one field's status, comments, images, timestamp |
| `ValidationStatus` | Enum: `.pending`, `.passed`, `.failed`, `.notApplicable` |
| `InspectionStorageServiceType` | Protocol — Firestore read/write for `Inspection` documents |
| `UploadInspectionMediaUseCase` | Use-case — uploads JPEG data to Firebase Storage, returns `String` URL |
| `CameraView` | Shared capture sheet; returns `[UIImage]` via closure |
| `DeleteConfirmationView` | Reusable confirmation overlay |
| `LMSButton`, `LMSLabel` | LMS Design System components |
| `LMSColor` | Color tokens (`.primary`, `.shadow`) |
| `LMSUploadProgressBar` | DS progress bar — indeterminate shimmer or determinate fill |
| `LMSLoadingOverlay` | Full-screen loading overlay used during image download |
| `CachedAsyncImage` | Async image loader with memory cache (`ImageCacheActor`) — ephemeral |
| `InspectionImageCacheActor` | `Common/Helpers/InspectionImageCacheActor.swift` — RAM + `Documents/`-dir durable cache |
| `PendingUploadStore` | `Common/Helpers/PendingUploadStore.swift` — UserDefaults file-path tracker for pending uploads |
| `CacheDebugLogger` | `Common/Helpers/CacheDebugLogger.swift` — realtime event logger, callable from any actor |
| `CacheDebugOverlay` | `Views/CacheDebugOverlay.swift` — debug sheet with stats strip + event log _(currently commented out in view)_ |
| `InspectionCachedImage` | `Views/InspectionCachedImage.swift` — 3-tier durable remote image loader |

---

## Draft Persistence

A lightweight draft is written to `UserDefaults` under the key `draft_validation_<fieldId>` on every `saveValidation` call:

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

## Thread Safety

| Operation | Context |
|---|---|
| `@Published` property updates | `@MainActor` — always on main thread |
| `saveValidation` → `uploadPhotosAndUpdateField` | `@MainActor` starts Task → suspends at first `await` |
| Phase 1: JPEG resize + compress | `Task.detached(priority: .userInitiated)` — background thread; max 4 slots (3 on low-RAM) |
| Phase 2: Firebase Storage upload | `withTaskGroup`; max 8 slots on WiFi/5G, 6 on cellular |
| `progressCb` / `doneCb` / `failCb` | `@Sendable` — called from non-isolated TaskGroup; dispatch back via `Task { @MainActor }` in `InspectionDetailViewModel` |
| Firestore write | `storageService` actor — serial executor; fires AFTER Phase 2 completes |

---

## Previews

Three Xcode previews are declared at the bottom of `InspectionValidationView.swift`:

| Preview | Description |
|---|---|
| `"With Images"` | Four placeholder images pre-loaded |
| `"Empty State"` | No images — gallery section is hidden |
| `"Dark Mode"` | Two images, `.preferredColorScheme(.dark)` |
