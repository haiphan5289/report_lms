# Photo Capture Error Review Workflow

**Last updated:** 2026-06-08

## Tổng quan

Tài liệu này mô tả kiến trúc, luồng dữ liệu, và cách tích hợp `PhotoCaptureErrorReviewView` — màn hình cho phép người dùng xem lại, gắn nhãn và lưu các ảnh lỗi sau khi chụp.

Màn hình hỗ trợ hai chế độ:
- **New mode**: Tạo mới một `SavedErrorItem` từ ảnh vừa chụp
- **Edit mode**: Chỉnh sửa một `SavedErrorItem` đã tồn tại

---

## Cấu trúc file

```
Sources/Presentation/Modules/Home/ErrorHome/PhotoCaptureErrorReview/
├── PhotoCaptureErrorReviewView.swift       # SwiftUI View, nhận initialImages + callbacks
└── PhotoCaptureErrorReviewViewModel.swift  # @MainActor ViewModel, quản lý state + business logic

Sources/Common/Helpers/
└── LocalImageStore.swift                   # Actor — lưu ảnh xuống Caches/
```

---

## Kiến trúc

```
┌────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│                                                            │
│   PhotoCaptureErrorReviewView (SwiftUI)                    │
│   ├── @StateObject PhotoCaptureErrorReviewViewModel        │
│   ├── @EnvironmentObject LocalizationManager               │
│   ├── imagesSection       (LazyVStack, ImageRowCard)       │
│   ├── takeMorePhotosSection (opens CameraView)             │
│   ├── severityLevelSection  (radio buttons)                │
│   ├── generalConditionSection (1–10 chip picker)           │
│   ├── defectTypesSection    (searchable list sheet)        │
│   ├── commentsSection       (TextEditor)                   │
│   └── actionButtonsSection  (edit mode only: delete/save)  │
│                                                            │
│   PhotoCaptureErrorReviewViewModel (@MainActor)            │
│   ├── @Published images, selectedSeverity, comments…       │
│   ├── localImages: [UIImage]  (computed, local-only)       │
│   ├── saveReview() async → SavedErrorItem?                 │
│   └── updateReview() async → SavedErrorItem?               │
└────────────────────────────────┬───────────────────────────┘
                                 │
┌────────────────────────────────▼───────────────────────────┐
│                    Common Layer                             │
│   LocalImageStore (actor, singleton)                       │
│   └── Caches/pending-uploads/{userId}/{itemId}/            │
└────────────────────────────────────────────────────────────┘
                                 │ (edit mode only)
┌────────────────────────────────▼───────────────────────────┐
│                      Domain / Data Layer                    │
│   ErrorRepositoryType → ErrorRepository (actor)            │
│   └── saveErrorItem / updateReview → Firebase Storage      │
└────────────────────────────────────────────────────────────┘
```

---

## Luồng hoạt động

### Bước 1: Mở màn hình

**Caller (ví dụ: `ErrorHomeView`)**

```swift
// New mode
PhotoCaptureErrorReviewView(
    inspectionId: inspectionId,
    initialImages: capturedImages.map { ImageWithNote(source: .local(image: $0)) },
    onImagesUpdated: { images in viewModel.updateImages(images) },
    onSaved: { item, localImages in viewModel.appendErrorItem(item, images: localImages) }
)
.environmentObject(LocalizationManager.shared)

// Edit mode (truyền thêm editingItem)
PhotoCaptureErrorReviewView(
    inspectionId: inspectionId,
    initialImages: item.imageSources,
    editingItem: item,
    onImagesUpdated: { ... },
    onSaved: { ... },
    onDeleted: { item in viewModel.removeErrorItem(item) }
)
.environmentObject(LocalizationManager.shared)
```

```
PhotoCaptureErrorReviewView.onAppear
    └── viewModel.setInitialImages(initialImages)
```

---

### Bước 2: Chụp thêm ảnh

```
User tap "Chụp ảnh"
    └── viewModel.showCamera = true   [@Published → sheet present]
            └── CameraView(source: .errorReport, onPhotoCaptured:)
                    └── User chụp xong, tap "Hoàn thành"
                            └── onPhotoCaptured([UIImage])
                                    ├── viewModel.addImages(newImages)
                                    └── onImagesUpdated(viewModel.images)  [callback lên caller]
```

---

### Bước 3: Lưu (New mode) — nhấn "Xong"

> **Không có upload Storage, không có Firestore write. Dismiss ngay lập tức.**

```
User tap "Xong" (toolbar)
    └── Task { await viewModel.saveReview() }
            │
            ├─ guard !images.isEmpty
            │         └─ Nếu rỗng → errorMessage = "Vui lòng chụp ít nhất một ảnh"
            │
            ├─ [LocalImageStore] Save ảnh local xuống disk
            │     Path: Caches/pending-uploads/{userId}/{itemId}/{index}_{UUID}.jpg
            │     • userId = Firebase Auth UID (fallback "anonymous")
            │     • Chỉ save ảnh .local, bỏ qua .remote
            │     • Không upload lên Firebase Storage
            │     • Không write Firestore
            │
            └─ return SavedErrorItem (built locally, không có network call)
                    │
                    ▼
            [View] onSaved(saved, localImages) → dismiss()
```

---

### Bước 4: Mở lại item (Edit mode) — setInitialImages

```
[View] onAppear → setInitialImages(initialImages)
       │
       ▼
[ViewModel] setInitialImages()
       │
       ├─ isEditMode && editingItemId != nil
       │
       ├─ Check LocalImageStore.hasImages(for: itemId)
       │         │
       │    Cache HIT ──▶ Load UIImages từ Caches/
       │         │         images = [.local(img), ...]
       │         │         RETURN sớm (không download Storage)
       │         │
       │    Cache MISS ──▶ isDownloading = true
       │                   Download remote URLs từ Firebase Storage
       │                   (legacy flow — dành cho items cũ có imageURLs)
       │                   isDownloading = false
       │
       └─ images sẵn sàng để edit
```

---

### Bước 5: Cập nhật (Edit mode) — nhấn "Lưu thay đổi"

> Flow cũ giữ nguyên — có upload Storage và write Firestore.

```
User tap "Lưu thay đổi" (actionButtonsSection)
    └── Task { await viewModel.updateReview() }
            ├── isLoading = true
            ├── buildSavedErrorItem()  → SavedErrorItem (editingItemId preserved)
            └── errorRepository.saveErrorItem(item, imageSources: images, for: inspectionId)
                    ├── withThrowingTaskGroup → upload local images lên Firebase Storage
                    │     └── image.prepareForUpload() → resize ≤2048px, JPEG 0.8
                    ├── Write Firestore: inspections/{id}/errorItems/{itemId}
                    ├── success → onSaved / dismiss()
                    └── failure → errorMessage
```

---

### Bước 6: Xoá (Edit mode)

```
User tap "Xoá"
    └── showDeleteConfirmation = true   [confirmationDialog]
            └── User xác nhận
                    └── onDeleted?(editingItem)   [callback lên caller]
                        dismiss()
```

> Xoá không đi qua repository — trách nhiệm thuộc về caller.

---

## Local Image Storage

### Helper: `LocalImageStore`

**File:** `Sources/Common/Helpers/LocalImageStore.swift`

| Method | Description |
|--------|-------------|
| `save(_ images:, for itemId:)` | Lưu `[UIImage]` xuống Caches/, trả về `[URL]` |
| `load(for itemId:)` | Đọc ảnh theo thứ tự index, trả về `[UIImage]` |
| `hasImages(for itemId:)` | Check folder có file `.jpg` không |
| `clear(for itemId:)` | Xóa toàn bộ folder của item |

**Path structure:**
```
Caches/
└── pending-uploads/
    └── {Firebase Auth UID}/
        └── {itemId}/
            ├── 0_{UUID}.jpg
            ├── 1_{UUID}.jpg
            └── 2_{UUID}.jpg
```

**Notes:**
- `Caches/` có thể bị OS xóa khi low storage — đây là by design.
- Mỗi ảnh có UUID để tránh collision.
- Sort theo `lastPathComponent` (prefix index) để giữ đúng thứ tự.

---

## So sánh saveReview vs updateReview

| | `saveReview()` (New mode) | `updateReview()` (Edit mode) |
|---|---|---|
| Firebase Storage | Không | Có (upload local images) |
| Firestore write | Không | Có |
| LocalImageStore | Save ảnh xuống Caches/ | Không |
| Loading overlay | Không | Có (`isLoading`) |
| Network | Offline-capable | Cần network |

---

## iOS 26.5 Gotchas

### ScrollView freeze
`DragGesture(minimumDistance: 0)` với `.simultaneousGesture` chặn toàn bộ scroll trên iOS 26.5.
Đã xóa toàn bộ gesture này khỏi `imagesSection`, `takeMorePhotosSection`, `ImageRowCard`.

### Không dùng `UploadStatusBottomSheet`
`saveReview()` không upload nên không cần progress sheet. Sheet chỉ dùng ở `InspectionValidationView`.

---

## Computed Properties quan trọng

### `localImages: [UIImage]`

```swift
var localImages: [UIImage] {
    images.compactMap { if case .local(let img) = $0.source { return img } else { return nil } }
}
```

Được pass qua callback `onSaved(saved, viewModel.localImages)` để caller hiển thị ảnh mà không cần re-download.

### `isEditMode: Bool`

```swift
var isEditMode: Bool { editingItemId != nil }
```

Điều khiển navigation title, toolbar button "Xong", và `actionButtonsSection`.

---

## Localization

Tất cả chuỗi UI đều đi qua `LocalizationManager`. View **yêu cầu** inject qua `@EnvironmentObject` — thiếu sẽ crash runtime.

| Key | VI |
|---|---|
| `errorReview.title.new` | Đánh giá ảnh chụp |
| `errorReview.title.edit` | Chỉnh sửa lỗi |
| `errorReview.section.images` | Ảnh đã chụp |
| `errorReview.images.empty` | Chưa có ảnh nào |
| `errorReview.section.takeMorePhotos` | Chụp thêm ảnh |
| `errorReview.button.takePhoto` | Chụp ảnh |
| `errorReview.section.severity` | Mức độ nặng nhẹ |
| `errorReview.section.generalCondition` | Tình trạng chung |
| `errorReview.section.defectTypes` | Các loại phân lỗi |
| `errorReview.section.comments` | Viết nhận xét tại đây |
| `errorReview.button.delete` | Xoá |
| `errorReview.button.saveChanges` | Lưu thay đổi |

---

## Lưu ý quan trọng

1. **`@EnvironmentObject LocalizationManager`** — Bắt buộc inject khi present view, kể cả từ `.sheet`.

2. **`defectTypeSearchableVM` là `@State`** — Khởi tạo một lần khi user tap, không recreate mỗi render cycle.

3. **Xoá ảnh không ảnh hưởng remote URLs** — `deleteImage(at:)` chỉ xoá khỏi `images` array trong memory.

4. **Không có `deleteReview()` ở ViewModel** — Xoá là trách nhiệm của caller qua `onDeleted` callback.

5. **`CameraView` trong sheet cần `LocalizationManager`** — Inject `.environmentObject(localizationManager)` khi present.
