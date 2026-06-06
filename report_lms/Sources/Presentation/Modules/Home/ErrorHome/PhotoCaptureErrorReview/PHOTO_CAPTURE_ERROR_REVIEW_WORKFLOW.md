# Photo Capture Error Review Workflow

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
│   ├── imagesSection       (LazyVGrid 2-col, delete)        │
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
│   ├── defectTypeSearchableData() → [ListItemProtocol]      │
│   ├── selectDefectType(from:)                              │
│   ├── saveReview() async → SavedErrorItem?                 │
│   └── updateReview() async → SavedErrorItem?               │
└────────────────────────────────┬───────────────────────────┘
                                 │ async/await
┌────────────────────────────────▼───────────────────────────┐
│                      Domain Layer                           │
│                                                            │
│   ErrorRepositoryType (protocol)                           │
│   └── saveErrorItem(_:imageSources:for:) async throws      │
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
    initialImages: capturedImages.map { .local(image: $0) },
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
            └── images = initialImages  [@Published → UI update]
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
                                    │       └── images.append(contentsOf: …map { .local })
                                    └── onImagesUpdated(viewModel.images)  [callback lên caller]
```

---

### Bước 3: Chọn phân loại lỗi (Defect Type)

```
User tap defectTypesSection
    └── defectTypeSearchableVM = SearchableListViewModel(
    │       sections: viewModel.defectTypeSearchableData(),
    │       title: "Các loại phân lỗi"
    │   )
    └── showingDefectTypeList = true   [sheet present]
            └── SearchableListView(viewModel: defectTypeSearchableVM) { selectedItem in
                    viewModel.selectDefectType(from: selectedItem)
                        └── code = selectedItem.name.split(" - ").first
                            selectedDefectType = DefectType(rawValue: code)
                    showingDefectTypeList = false
                }
```

> `defectTypeSearchableVM` là `@State` — được khởi tạo **một lần khi tap**, không bị recreate mỗi render cycle.

---

### Bước 4: Lưu (New mode)

```
User tap "Hoàn thành" (toolbar)
    └── Task { await viewModel.saveReview() }
            ├── guard !images.isEmpty   → errorMessage nếu không có ảnh
            ├── buildSavedErrorItem()   → SavedErrorItem (ID mới, remote URLs + form data)
            └── errorRepository.saveErrorItem(item, imageSources: images, for: inspectionId)
                    ├── withThrowingTaskGroup → upload TẤT CẢ local images CONCURRENT
                    │     └── Task.detached { image.prepareForUpload() }
                    │           ├── Resize to ≤2048px
                    │           └── JPEG 0.8 → ~500KB/ảnh
                    ├── success → onImagesUpdated(viewModel.images)
                    │            onSaved(saved, viewModel.localImages)
                    │            dismiss()
                    └── failure → errorMessage = "Không thể lưu…"
```

> **Performance:** Upload concurrent — 3 ảnh mất ~2s thay vì ~6s sequential.

---

### Bước 5: Cập nhật (Edit mode)

```
User tap "Lưu thay đổi" (actionButtonsSection)
    └── Task { await viewModel.updateReview() }
            ├── buildSavedErrorItem()  → SavedErrorItem (editingItemId preserved)
            └── errorRepository.saveErrorItem(…)
                    ├── success → onImagesUpdated / onSaved / dismiss()
                    └── failure → errorMessage
```

---

### Bước 6: Xoá (Edit mode)

```
User tap "Xoá"
    └── showDeleteConfirmation = true   [confirmationDialog]
            └── User xác nhận "Xoá lỗi"
                    └── onDeleted?(editingItem)   [callback lên caller]
                        dismiss()
```

> Xoá không đi qua repository — trách nhiệm thuộc về caller (ví dụ: `ErrorHomeViewModel`).

---

## Computed Properties quan trọng

### `localImages: [UIImage]`

```swift
var localImages: [UIImage] {
    images.compactMap { if case .local(let img) = $0 { return img } else { return nil } }
}
```

Được dùng trong callback `onSaved(saved, viewModel.localImages)` để caller có thể upload hoặc hiển thị ảnh ngay mà không cần phân biệt lại `ImageSource`.

### `isEditMode: Bool`

```swift
var isEditMode: Bool { editingItemId != nil }
```

Điều khiển:
- Navigation title: "Đánh giá ảnh chụp" ↔ "Chỉnh sửa lỗi"
- Toolbar button "Hoàn thành" (chỉ hiện ở new mode)
- `actionButtonsSection` (chỉ hiện ở edit mode)

---

## ImageSource

```swift
enum ImageSource {
    case local(image: UIImage)    // ảnh vừa chụp, chưa upload
    case remote(url: String)      // ảnh đã upload, load qua URL
}
```

`buildSavedErrorItem()` chỉ extract `.remote(url:)` vào `imageURLs` — ảnh local sẽ được upload bởi tầng repository.

---

## Localization

Tất cả chuỗi UI đều đi qua `LocalizationManager`. View **yêu cầu** `LocalizationManager` được inject qua `@EnvironmentObject` — thiếu sẽ crash ở runtime.

| Key | VI | EN |
|---|---|---|
| `errorReview.title.new` | Đánh giá ảnh chụp | Review Photos |
| `errorReview.title.edit` | Chỉnh sửa lỗi | Edit Error |
| `errorReview.section.images` | Ảnh đã chụp | Captured Photos |
| `errorReview.images.empty` | Chưa có ảnh nào | No photos yet |
| `errorReview.section.takeMorePhotos` | Chụp thêm ảnh | Take More Photos |
| `errorReview.button.takePhoto` | Chụp ảnh | Take Photo |
| `errorReview.section.severity` | Mức độ nặng nhẹ | Severity Level |
| `errorReview.section.generalCondition` | Tình trạng chung | General Condition |
| `errorReview.section.defectTypes` | Các loại phân lỗi | Defect Types |
| `errorReview.section.comments` | Viết nhận xét tại đây | Add comments here |
| `errorReview.button.delete` | Xoá | Delete |
| `errorReview.button.saveChanges` | Lưu thay đổi | Save Changes |
| `errorReview.delete.title` | Bạn có chắc muốn xoá lỗi này không? | Are you sure you want to delete this error? |
| `errorReview.delete.confirm` | Xoá lỗi | Delete Error |

---

## Design System

Tất cả màu sắc dùng LMS tokens — không dùng raw `Color.*`:

| Token | Dùng ở đâu |
|---|---|
| `LMSColor.primary` | Selected severity icon, selected chip border |
| `LMSColor.primaryLight` | Selected chip background |
| `LMSColor.background` | Card section background |
| `LMSColor.backgroundSecondary` | Unselected chip background, TextEditor background, remote image placeholder |
| `LMSColor.secondary` | Unselected chip border, TextEditor border |
| `LMSColor.textTertiary` | Unselected severity icon, defect chevron/xmark |
| `LMSColor.shadow` | Section card shadow |
| `LMSTextColor.secondary.color` | Empty state text, defect type display name |

---

## Thread Safety

| Thao tác | Queue |
|---|---|
| `@Published` property updates | Main thread (`@MainActor`) |
| `saveReview()` / `updateReview()` | Async task, awaits on `@MainActor` |
| `errorRepository.saveErrorItem` | `actor ErrorRepository` — serial actor executor |
| JPEG resize + compress | `Task.detached(priority: .userInitiated)` — background thread |
| Firebase Storage upload | Concurrent — `withThrowingTaskGroup` (N images upload song song) |

---

## Lưu ý quan trọng

1. **`@EnvironmentObject LocalizationManager`** — Bắt buộc inject khi present `PhotoCaptureErrorReviewView`. Bao gồm cả khi present từ `.sheet`.

2. **`defectTypeSearchableVM` là `@State`** — Được khởi tạo một lần khi user tap vào section, không bị recreate mỗi lần render. Sheet chỉ hiện khi VM đã sẵn sàng.

3. **Xoá ảnh không ảnh hưởng remote URLs** — `deleteImage(at:)` chỉ xoá khỏi `images` array. `buildSavedErrorItem()` sẽ chỉ đưa các `.remote` URLs còn lại vào `imageURLs`.

4. **Không có `deleteReview()` ở ViewModel** — Xoá `SavedErrorItem` là trách nhiệm của caller qua `onDeleted` callback, không phải ViewModel.

5. **`CameraView` trong sheet cần `LocalizationManager`** — Sheet `CameraView` được inject `localizationManager` qua `.environmentObject(localizationManager)` để đảm bảo localization hoạt động đúng.

---

## Sơ đồ state

```
                    ┌─────────────┐
                    │    Init     │
                    │ (no images) │
                    └──────┬──────┘
                           │ .onAppear → setInitialImages
                    ┌──────▼──────┐
                    │  Review     │
                    │  Screen     │◄──── chụp thêm / xoá ảnh
                    └──────┬──────┘
              ┌────────────┤
              │            │
       ┌──────▼──────┐ ┌───▼─────────┐
       │  Edit mode  │ │  New mode   │
       │ (editingItem│ │             │
       │  != nil)    │ │             │
       └──────┬──────┘ └──────┬──────┘
              │               │
       ┌──────▼──────┐ ┌──────▼──────┐
       │ updateReview│ │ saveReview  │
       │    async    │ │   async     │
       └──────┬──────┘ └──────┬──────┘
              │               │
              └───────┬───────┘
                      │ success
               ┌──────▼──────┐
               │  callbacks  │
               │ onSaved /   │
               │ onImagesUpdated│
               └──────┬──────┘
                      │
               ┌──────▼──────┐
               │   dismiss() │
               └─────────────┘
```
