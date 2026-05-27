# InspectionValidationView

**Module:** InspectionDetail / InspectionValidation  
**Pattern:** MVVM (SwiftUI + `@StateObject`)  
**Created:** 2026-01-03

---

## Overview

`InspectionValidationView` is a full-screen detail sheet used inside an inspection workflow. It allows an inspector to:

- Review photos of a specific inspection field (e.g., "Carton Overview").
- Add or delete photos via the device camera.
- Enter free-text comments.
- Mark the field as **Passed** or **Not Applicable** from a fixed bottom action bar.

The view is pushed onto a `NavigationStack` and dismisses itself after saving.

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
    fieldId: String,           // Unique ID of the inspection field
    fieldLabel: String,        // Navigation title & display label
    initialImages: [InspectionImage],  // Pre-loaded images (local or remote)
    inspectionId: String? = nil,       // Parent inspection ID; required for cloud upload
    onSave: @escaping (FieldValidation) -> Void,  // Called immediately when status is set
    onUploadComplete: (() -> Void)? = nil         // Called after async cloud upload finishes
)
```

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

All sections animate in with a staggered `easeOut` slide-up on `.task` (offset 0 ms → 80 ms → 160 ms → 240 ms).

---

## ViewModel — Published State

| Property | Type | Purpose |
|---|---|---|
| `status` | `ValidationStatus` | Current field status (`.pending`, `.passed`, `.failed`, `.notApplicable`) |
| `comments` | `String` | Inspector notes |
| `images` | `[InspectionImage]` | All images for this field (local + remote) |
| `showCamera` | `Bool` | Triggers `.sheet` with `CameraView` |
| `isLoading` | `Bool` | Reserved for async loading indicator |
| `errorMessage` | `String?` | Error banner binding |
| `showReorderMode` | `Bool` | Puts image list into delete-selection mode |
| `isDirty` | `Bool` | `true` when status / comments / image count differ from initial values |
| `showDeleteConfirmation` | `Bool` | Triggers `DeleteConfirmationView` fullScreenCover |

### Key Methods

| Method | Description |
|---|---|
| `saveValidation(status:)` | Sets status, builds `FieldValidation`, saves draft to `UserDefaults`, fires `onSave`, then kicks off async upload |
| `appendImages(_:)` | Wraps `[UIImage]` into `[InspectionImage]` and appends to `images` |
| `requestDeleteImage(at:)` | Stores pending index and shows confirmation dialog |
| `confirmDeleteImage()` | Removes the stored index after user confirms |
| `updateComments(_:)` | Mutates `comments` and marks dirty |
| `openCamera()` | Sets `showCamera = true` |
| `toggleReorderMode()` | Flips `showReorderMode` |
| `loadDraft()` | Restores status + comments from `UserDefaults` key `draft_validation_<fieldId>` |

---

## Upload Flow

```
saveValidation(status:)
    │
    ├─► onSave(validation)          ← parent updates immediately
    │
    └─► Task {
            uploadPhotosAndUpdateField(fieldId, images)
                ├─ Skip images where isRemote == true (already have URLs)
                ├─ Parallel TaskGroup upload via UploadInspectionMediaUseCase
                ├─ Merge existingRemoteURLs + newlyUploadedURLs
                └─ storageService.updateInspection(inspection)   → Firestore
            updateInspectionStatus()
                └─ inspection.status = .inProgress → Firestore
            onUploadComplete?()     ← parent refreshes if needed
        }
```

---

## Sub-components

### `ImageGalleryItemView`

Located at `Views/ImageGalleryItemView.swift`.

| Prop | Type | Description |
|---|---|---|
| `inspectionImage` | `InspectionImage` | Source image (local `UIImage` or remote `URL`) |
| `isReorderMode` | `Bool` | Shows delete (`xmark.circle.fill`) overlay when `true` |
| `onDelete` | `() -> Void` | Forwarded to `requestDeleteImage(at:)` in the parent VM |
| `descriptionBinding` | `Binding<String>` | Two-way bind to `images[index].description` |

Renders remote images via `CachedAsyncImage` (with loading spinner and error fallback); falls back to `Image(uiImage:)` for local captures.

### `ClearBackgroundView`

A `UIViewRepresentable` helper that sets the `fullScreenCover` window background to `.clear`, enabling the translucent `DeleteConfirmationView` overlay.

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
| `CachedAsyncImage` | Async image loader with memory cache |

---

## Draft Persistence

A lightweight draft is written to `UserDefaults` under the key `draft_validation_<fieldId>` on every `saveValidation` call. The stored payload is:

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

## Previews

Three Xcode previews are declared at the bottom of `InspectionValidationView.swift`:

| Preview | Description |
|---|---|
| `"With Images"` | Four placeholder images pre-loaded |
| `"Empty State"` | No images — gallery section is hidden |
| `"Dark Mode"` | Two images, `.preferredColorScheme(.dark)` |
