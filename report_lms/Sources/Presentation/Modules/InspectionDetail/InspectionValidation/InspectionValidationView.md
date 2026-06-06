# InspectionValidationView

**Module:** InspectionDetail / InspectionValidation  
**Pattern:** MVVM (SwiftUI + `@StateObject`)  
**Created:** 2026-01-03  
**Last updated:** 2026-06-06

---

## Overview

`InspectionValidationView` is a full-screen detail sheet used inside an inspection workflow. It allows an inspector to:

- Review photos of a specific inspection field (e.g., "Carton Overview").
- Add or delete photos via the device camera.
- Enter free-text comments.
- Mark the field as **Passed** or **Not Applicable** from a fixed bottom action bar.

Photos are stored locally until the user explicitly saves. When the user taps **Đã kiểm tra** or **Không áp dụng**, all local images are uploaded to Firebase Storage concurrently. A floating progress toast appears at the bottom during the upload.

---

## Architecture

```
InspectionValidationView  (SwiftUI View)
    └── InspectionValidationViewModel  (@MainActor ObservableObject)
            ├── InspectionStorageServiceType  (Firestore persistence)
            └── UploadInspectionMediaUseCase  (Firebase Storage upload)
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
    onSave: @escaping (FieldValidation) -> Void,   // Called immediately when status is set
    onUploadComplete: (() -> Void)? = nil          // Called after Firestore write succeeds
)
```

> `inspectionId` is **required** for upload to work. Without it, `uploadPhotosAndUpdateField` returns early and no photos are written to Firebase.

`onSave` fires synchronously so the parent list can update immediately. `onUploadComplete` fires later, after Firebase Storage upload and Firestore write succeed.

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
| `appendImages(_:)` | Wraps `[UIImage]` → `[InspectionImage]` and appends to `images`; **no upload yet** — images stay local until save |
| `saveValidation(status:)` | Sets status, builds `FieldValidation`, saves draft, fires `onSave`, then uploads all local images and writes to Firestore |
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
                    └── images.append(...)   ← stored locally, NO upload yet

User taps "Đã kiểm tra" / "Không áp dụng"
    └── saveValidation(status:)
            ├── onSave(validation)                      ← parent updates immediately
            ├── withAnimation { isUploading = true }    ← toast slides up
            └── Task {
                    uploadPhotosAndUpdateField(fieldId, images)
                        ├── localImages = images.filter { !$0.isRemote }
                        ├── withTaskGroup → concurrent upload of all local images
                        │     └── Task.detached { image.prepareForUpload() }
                        │           ├── Resize to ≤2048px
                        │           └── JPEG 0.8 quality (~500KB)
                        ├── uploadUseCase.execute(imageData, inspectionId) → URL
                        └── storageService.updateInspection(inspection) → Firestore
                    updateInspectionStatus()
                        └── inspection.status = .inProgress → Firestore
                    withAnimation { uploadProgress = 1.0 }
                    sleep 0.5s
                    withAnimation { isUploading = false }   ← toast slides down
                    onUploadComplete?()
                }
```

> **Performance:** Resize + compress runs in `Task.detached(priority: .userInitiated)` — does not block `@MainActor`. 3 images concurrent ≈ 2s vs 6s sequential.

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

Renders remote images via `CachedAsyncImage` (with loading spinner + error fallback); falls back to `Image(uiImage:)` for local captures.

### `ClearBackgroundView`

A `UIViewRepresentable` helper that sets the `fullScreenCover` window background to `.clear`, enabling the translucent `DeleteConfirmationView` overlay.

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
| `CachedAsyncImage` | Async image loader with memory cache (`ImageCacheActor`) |

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
| JPEG resize + compress | `Task.detached(priority: .userInitiated)` — background thread |
| Firebase Storage upload | Concurrent — `withTaskGroup` (N images upload in parallel) |
| Firestore write | `storageService` actor — serial executor |

---

## Previews

Three Xcode previews are declared at the bottom of `InspectionValidationView.swift`:

| Preview | Description |
|---|---|
| `"With Images"` | Four placeholder images pre-loaded |
| `"Empty State"` | No images — gallery section is hidden |
| `"Dark Mode"` | Two images, `.preferredColorScheme(.dark)` |
