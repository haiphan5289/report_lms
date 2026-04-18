# ErrorHome Workflow

> Last updated: 2026-04-18 (updated by session: instant thumbnail + scroll-to-top after save)

---

## Architecture

```
ErrorHomeView
  └── ErrorHomeViewModel
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
                      └── onSaved callback
                           └── ErrorHomeView: Task { await viewModel.loadErrorInspections() }
```

### 4. Update Existing Error ("Lưu Thay đổi")
```
PhotoCaptureErrorReviewView "Lưu Thay đổi" button
  └── viewModel.updateReview()
       └── same path as saveReview() above
            (existing .remote URLs preserved, new .local images uploaded)
```

### 5. Upsert Logic (local cache)
```swift
// Not used after server re-fetch, kept for reference
func upsertErrorItem(_ item: SavedErrorItem) {
    if found by id → replace in-place
    else → insert at index 0
}
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
| `ErrorHomeView.swift` | List UI + `ErrorItemCardView` (thumbnail card) |
| `ErrorHomeViewModel.swift` | `[SavedErrorItem]` state, load + upsert |
| `ErrorRepositoryType.swift` | Protocol: `fetchErrorItems`, `saveError`, `saveErrorItem` |
| `ErrorRepository.swift` | Firestore + Storage implementation |
| `PhotoCaptureErrorReviewView.swift` | Capture + review form |
| `PhotoCaptureErrorReviewViewModel.swift` | `[ImageSource]` state, `saveReview`, `updateReview` |

---

## Known Issues / Follow-up

- [ ] `NavigationLink(value: item)` in `ErrorHomeView` has no `.navigationDestination(for: SavedErrorItem.self)` — detail screen not wired yet
- [ ] `errorView` retry button uses external `.frame` instead of `LMSButton(isFullWidth:)` 
- [ ] `saveError` / `fetchErrors` protocol methods are dead code — can be removed
