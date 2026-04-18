# ErrorHome Workflow

> Last updated: 2026-04-18 (updated by session: delete workflow — optimistic remove + Firebase delete + re-fetch on failure)

---

## Architecture

```
ErrorHomeView
  └── ErrorHomeViewModel
       ├── errorInspections: [SavedErrorItem]   (list state)
       ├── thumbnailCache: [String: UIImage]     (transient, keyed by item.id)
       └── ErrorRepositoryType (protocol)
            └── ErrorRepository (impl) → Firestore + Firebase Storage
```

---

## Data Models

### `SavedErrorItem` — list model (`ErrorItem.swift`)
| Field | Type | Description |
|---|---|---|
| `id` | `String` | UUID |
| `imageURLs` | `[String]` | Remote Firebase Storage URLs |
| `severity` | `SeverityLevel` | `.low` / `.medium` / `.critical` |
| `generalCondition` | `Int?` | 1–10 scale, optional |
| `defectType` | `DefectType?` | e.g. `.su9`, `.pa4` |
| `comments` | `String` | Free text |
| `createdAt` | `Date` | Firestore timestamp |

### `ImageSource` — edit/capture model (`ErrorItem.swift`)
```swift
enum ImageSource {
    case remote(url: String)   // fetched item → displayed with AsyncImage
    case local(image: UIImage) // just captured → uploaded on save
}
```

### `InspectionReviewData` — capture session snapshot (`PhotoCaptureErrorReviewViewModel.swift`)
```swift
struct InspectionReviewData {
    let images: [ImageSource]
    let severity: SeverityLevel
    let generalCondition: Int?
    let defectType: DefectType?
    let comments: String
}
```

---

## Full Workflow

### 1. Load List
```
ErrorHomeView.onAppear / .refreshable
  └── viewModel.loadErrorInspections()
       └── errorRepository.fetchErrorItems(for: inspectionId)
            └── Firestore: inspections/{id}/errorItems (ordered by createdAt desc)
                 └── savedErrorItem(from:id:) → [SavedErrorItem]
                      └── errorInspections: [SavedErrorItem] → list renders
```

### 2. Add New Error (FAB Flow)
```
floatingButton tap → showErrorCamera = true
  └── navigationDestination → CameraView(source: .errorReport)
       └── onPhotoCaptured: [UIImage]
            ├── capturedImages = images
            └── showErrorReview = true
                 └── sheet → PhotoCaptureErrorReviewView(
                          inspectionId: viewModel.inspectionId,
                          initialImages: capturedImages.map { .local(image: $0) }
                        )
```

### 3. Save Review ("Hoàn thành")
```
PhotoCaptureErrorReviewView "Hoàn thành" button
  ├── capture localImages = viewModel.images.compactMap { .local → UIImage }
  └── viewModel.saveReview()
       ├── guard images not empty
       ├── buildSavedErrorItem() → SavedErrorItem (imageURLs = [])
       └── errorRepository.saveErrorItem(item, imageSources: images, for: inspectionId)
            ├── keep existing .remote URLs
            ├── upload .local UIImages → Firebase Storage
            │    path: inspections/{inspectionId}/errors/{item.id}/{index}.jpg
            ├── merge all URLs → SavedErrorItem(imageURLs: [...])
            └── Firestore write: inspections/{inspectionId}/errorItems/{item.id}
                 └── returns SavedErrorItem with real imageURLs
                      └── onSaved(saved, localImages) callback
                           ├── ErrorHomeView: viewModel.upsertErrorItem(saved, thumbnails: localImages)
                           │    ├── thumbnailCache[item.id] = localImages.first  ← instant thumbnail
                           │    └── insert at index 0 (or replace by id)
                           └── scrollToTopTrigger.toggle()
                                └── ScrollViewReader: proxy.scrollTo("errorList-top")  ← scroll to top
```

### 4. Edit Existing Error (tap item card)
```
NavigationLink(value: item) tap
  └── .navigationDestination(for: SavedErrorItem.self)
       └── PhotoCaptureErrorReviewView(
                inspectionId: viewModel.inspectionId,
                initialImages: item.imageURLs.map { .remote(url: $0) },
                editingItem: item,   ← triggers edit mode
                onSaved: upsertErrorItem + scrollToTopTrigger
              )
            ├── VM pre-fills: severity, generalCondition, defectType, comments
            ├── VM stores editingItemId = item.id
            ├── isEditMode = true
            │    ├── navigationTitle → "Chỉnh sửa lỗi"
            │    ├── "Hoàn thành" nav bar button hidden
            │    └── actionButtonsSection shown ("Xoá" / "Lưu Thay đổi")
            └── takeMorePhotosSection → showCamera = true → CameraView
                 └── addImages(_:) → appends .local to existing .remote images
```

### 5. Save Edited Error ("Lưu Thay đổi")
```
PhotoCaptureErrorReviewView "Lưu Thay đổi" button
  ├── capture localImages = viewModel.images.compactMap { .local → UIImage }
  └── viewModel.updateReview()
       └── buildSavedErrorItem() uses editingItemId (preserves original Firestore doc id)
            (existing .remote URLs preserved, new .local images uploaded)
            └── onSaved(saved, localImages) → same upsert + scroll-to-top flow
```

### 6. Delete Error ("Xoá lỗi")
```
PhotoCaptureErrorReviewView "Xoá" button (edit mode only)
  └── showDeleteConfirmation = true
       └── confirmationDialog: "Bạn có chắc muốn xoá lỗi này không?"
            └── "Xoá lỗi" (destructive) button
                 ├── guard let item = editingItem else { return }
                 ├── onDeleted(item) → ErrorHomeViewModel.deleteErrorItem(item)
                 │    ├── removeErrorItem(id:)                ← optimistic: immediate UI update
                 │    │    ├── errorInspections.removeAll { $0.id == id }
                 │    │    └── thumbnailCache.removeValue(forKey: id)
                 │    └── Task (background)
                 │         ├── errorRepository.deleteErrorItem(item, for: inspectionId)
                 │         │    ├── storageService.deleteImage(fromURL:) for each imageURL
                 │         │    │    └── individual image failure → warning, continue
                 │         │    └── Firestore delete: inspections/{id}/errorItems/{item.id}
                 │         └── on failure → loadErrorInspections()   ← re-fetch, item restores at original position
                 └── dismiss() → pop back to ErrorHomeView
                      └── onAppear → guard !hasLoadedOnce → skip re-fetch (list already updated)
```

### 7. Upsert + Thumbnail Cache Logic
```swift
// Called by onSaved — no server re-fetch needed
func upsertErrorItem(_ item: SavedErrorItem, thumbnails: [UIImage] = []) {
    if let first = thumbnails.first {
        thumbnailCache[item.id] = first   // instant display, no AsyncImage wait
    }
    if found by id → replace in-place
    else → insert at index 0
}
```

### 8. Thumbnail Display in ErrorItemCardView
```
ErrorItemCardView(item:, cachedThumbnail:)
  └── thumbnailView
       ├── if cachedThumbnail != nil → Image(uiImage:)   ← zero network, same frame
       ├── else if item.imageURLs.first → AsyncImage(url:)  ← remote load (existing items)
       └── else → placeholderImage
```

---

## Firestore Collections

| Collection path | Written by | Read by |
|---|---|---|
| `inspections/{id}/errorItems` | `saveErrorItem` | `fetchErrorItems` |
| `inspections/{id}/errors` | `saveError` (legacy, unused) | — |

> **Note:** `saveError` and `fetchErrors` are legacy methods kept in the protocol but not used by the current ErrorHome flow.

---

## Key Files

| File | Role |
|---|---|
| `ErrorItem.swift` | `SavedErrorItem`, `ImageSource` domain models |
| `ErrorHomeView.swift` | List UI + scroll-to-top trigger (`scrollToTopTrigger`, `ScrollViewReader`) |
| `ErrorHomeViewModel.swift` | `[SavedErrorItem]` state, `thumbnailCache`, `upsertErrorItem`, `deleteErrorItem`, `removeErrorItem` |
| `ErrorListItemView.swift` | `ErrorItemCardView` — shows `cachedThumbnail` first, falls back to `AsyncImage` |
| `ErrorRepositoryType.swift` | Protocol: `fetchErrorItems`, `saveErrorItem`, `deleteErrorItem` |
| `ErrorRepository.swift` | Firestore + Storage implementation (including Storage image deletion) |
| `FirebaseStorageService.swift` | `uploadImage`, `downloadImage`, `deleteImage(at:)`, `deleteImage(fromURL:)` |
| `PhotoCaptureErrorReviewView.swift` | Capture + review form; `onSaved`, `onDeleted` callbacks; `confirmationDialog` |
| `PhotoCaptureErrorReviewViewModel.swift` | `[ImageSource]` state, `saveReview`, `updateReview`, `isEditMode`, `editingItemId` |

---

## Known Issues / Follow-up

- [x] `NavigationLink(value: item)` in `ErrorHomeView` now wired via `.navigationDestination(for: SavedErrorItem.self)` → edit flow
- [ ] `errorView` retry button uses external `.frame` instead of `LMSButton(isFullWidth:)` 
- [ ] `saveError` / `fetchErrors` protocol methods are dead code — can be removed
