# InspectionDetail — Feature Document

> **Jira:** — | **Branch:** `feat/login` | **Generated:** 2026-05-23 | **Last Updated:** 2026-05-23

---

## PRD Summary

> Màn hình xem chi tiết, điền kết quả, và nộp một phiếu kiểm tra chất lượng sản phẩm (Inspection).

- **Goal:** Cho phép inspector mở một phiếu kiểm tra, điền kết quả quan sát kèm ảnh theo từng hạng mục, ghi nhận lỗi, và nộp báo cáo hoàn chỉnh.
- **User story:** As an inspector, I want to open an inspection record, fill in field observations with photos, review errors, and submit the completed report so that quality data is captured and persisted.
- **Acceptance criteria:**
  - [ ] Inspector thấy danh sách hạng mục kiểm tra (section/field) được phân nhóm, có thể expand/collapse
  - [ ] Mỗi field có nút chụp ảnh (camera icon) và nút xem/nhập validation (text icon)
  - [ ] Inspector có thể thêm điểm kiểm tra tùy chỉnh qua sheet `AddCustomFieldView`
  - [ ] Inspector có thể ghi nhận lỗi bằng cách chụp ảnh qua nút floating orange (→ `PhotoCaptureErrorReviewView`)
  - [ ] 3 tabs: Kiểm tra / Lỗi / Thông tin đơn hàng, chuyển tab mượt mà
  - [ ] Nút Submit (toolbar checkmark) nộp phiếu và cập nhật status → `.inProgress`
  - [ ] Nút "Hoàn tất kiểm tra" mở `FinalReportView` để xem và xuất PDF
  - [ ] Ảnh chụp được lưu dưới dạng Firebase Storage URL, hiển thị lazy qua `AsyncImage`
  - [ ] Loading overlay `LMSLoadingOverlay` xuất hiện khi submit
  - [ ] Snackbar thành công sau khi submit / lưu ảnh

---

## Business Rules

> Các ràng buộc nghiệp vụ quan trọng mà developer phải tuân thủ.

| Rule | Description |
|------|-------------|
| Cache-first loading | Inspection luôn được load từ local cache (`InspectionStorageServiceType`). Nếu không tìm thấy → fallback về `Inspection.mock()` (cần đổi thành error state trong production) |
| Photo storage | Ảnh được lưu dưới dạng `imageURLs: [String]` (Firebase Storage URL) trong từng `InspectionField`. Không download ngay — `AsyncImage` load on-demand |
| Photo restore | Khi load xong, `restoreCapturedPhotos(from:)` wrap remote URLs thành `InspectionImage.remoteURL` entries — không gọi network |
| Submit flow | `submitInspection()` ghi `remoteURL`s từ `capturedPhotos` ngược vào model, đổi status → `.inProgress`, rồi gọi `storageService.updateInspection()` |
| One-time load guard | `hasLoadedOnce = true` ngăn `loadInspectionDetail()` chạy lại khi view reappear |
| Status transition | Submit luôn set status về `.inProgress`, không phải `.completed`. Completion xảy ra qua `FinalReportView` (luồng khác) |
| PDF inspector name | Tên inspector lấy từ `KeychainManager.getStoredUsername()` — không phải user input |
| Mail guard | PDF email chỉ mở nếu `MailComposerView.canSendMail` == true; nếu không → alert `showMailUnavailableAlert` |

---

## Architecture Overview

> MVVM + SwiftUI với pattern parent-child ViewModel.

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`InspectionDetailView.swift`](InspectionDetailView.swift) | Entry point: tab bar, navigation destinations, submit toolbar |
| Presentation | [`InspectionDetailViewModel.swift`](InspectionDetailViewModel.swift) | State chính: load, submit, photo capture, navigation flags |
| Presentation | [`InspectionDetailContentView.swift`](InspectionDetailContentView.swift) | Tab "Kiểm tra": section list, floating error button, action buttons |
| Presentation | [`InspectionDetailContentViewModel.swift`](InspectionDetailContentViewModel.swift) | Section expand/collapse, PDF generation, computed access to parent state |
| Presentation | [`InspectionValidation/InspectionValidationView.swift`](InspectionValidation/InspectionValidationView.swift) | Nhập kết quả validation + ảnh cho 1 field |
| Presentation | [`FinalReport/FinalReportView.swift`](FinalReport/FinalReportView.swift) | Xem lại toàn bộ báo cáo + xuất PDF |
| Domain | [`GenerateHTMLPDFReportUseCase.swift`](../../../Domain/UseCases/GenerateHTMLPDFReportUseCase.swift) | Tạo HTML-based PDF từ Inspection data + ảnh |
| Domain | [`Inspection.swift`](../../../Domain/Entities/Inspection.swift) | Entity chính: Inspection, InspectionSection, InspectionField |
| Data | [`FirestoreInspectionStorageService.swift`](../../Data/Services/FirestoreInspectionStorageService.swift) | Firestore implementation của InspectionStorageServiceType |
| Data | [`InspectionStorageService.swift`](../../Data/Services/InspectionStorageService.swift) | Local disk implementation |

### Data Flow

```
.task → viewModel.loadInspectionDetail()
  └── storageService.getInspection(by: inspectionId)   (in-memory cache)
      ├── found  → inspection = loaded
      └── not found → inspection = Inspection.mock(...)   ⚠️ fallback mock
  └── contentViewModel.autoExpandFirstSection()
  └── restoreCapturedPhotos(from: loaded)
       └── wrap imageURLs → InspectionImage.remoteURL (no network)

User taps field text
  → contentViewModel.openValidationView(for: fieldId)
  → onTextTap callback → parentViewModel.openValidationView(for:)
  → showValidation = true → navigationDestination → InspectionValidationView

User taps camera icon
  → contentViewModel.openCamera(for: fieldId)
  → onCameraTap callback → parentViewModel.openCamera(for:)
  → showCamera = true → navigationDestination → CameraView
  → handlePhotoSelection([UIImage]) → savePhoto() → capturedPhotos[fieldId].append()

User taps Submit (toolbar)
  → viewModel.submitInspection()
  → flush remoteURLs from capturedPhotos → model.imageURLs
  → current.status = .inProgress
  → storageService.updateInspection(current)
  → snackbarMessage = "Đã nộp báo cáo thành công!"

User taps floating orange button
  → showErrorCamera = true → CameraView(source: .errorReport)
  → capturedErrorImages → showErrorReview = true → PhotoCaptureErrorReviewView
  → onSaved → onSwitchToErrorTab() → selectedTab = .error
```

### Parent ↔ Child ViewModel Relationship

`InspectionDetailContentViewModel` **không tự sở hữu data**. Nó giữ `weak var parentViewModel` và expose data qua computed properties:

```swift
var inspection: Inspection? { parentViewModel?.inspection }
var capturedPhotos: [String: [InspectionImage]] { parentViewModel?.capturedPhotos ?? [:] }
```

`contentViewModel` được khởi tạo `lazy` bởi parent với callbacks `onTextTap` / `onCameraTap` để trigger navigation.

```mermaid
graph TD
    A[InspectionDetailView] -->|@StateObject| B[InspectionDetailViewModel]
    B -->|lazy init + weak ref| C[InspectionDetailContentViewModel]
    A -->|@ObservedObject contentViewModel| D[InspectionDetailContentView]
    D --> C
    B --> E[InspectionStorageServiceType]
    C --> F[GenerateHTMLPDFReportUseCase]
    A --> G[InspectionValidationView]
    A --> H[CameraView]
    D --> I[FinalReportView]
    D --> J[PhotoCaptureErrorReviewView]
```

---

## Key Files & Symbols

### Presentation

- [`InspectionDetailView.swift`](InspectionDetailView.swift) — Tab bar (3 tabs), toolbar submit button, navigation destinations (camera, validation), snackbar
- [`InspectionDetailViewModel.swift`](InspectionDetailViewModel.swift) — `@Published`: `inspection`, `capturedPhotos`, `isLoading`, `showCamera`, `showValidation`, `selectedTab`, `snackbarMessage`; methods: `loadInspectionDetail()`, `submitInspection()`, `handlePhotoSelection()`, `handleValidationSave()`, `refreshInspection()`
- [`InspectionDetailContentView.swift`](InspectionDetailContentView.swift) — Section list, floating error button, "Thêm điểm kiểm tra" button, "Hoàn tất kiểm tra" button, loading skeleton, error view
- [`InspectionDetailContentViewModel.swift`](InspectionDetailContentViewModel.swift) — `expandedSections: Set<String>`, `sortedSections`, `generateAndPreviewPDF()`, `generateAndSendPDF()`, `toggleSection()`, `autoExpandFirstSection()`
- [`InspectionValidation/InspectionValidationView.swift`](InspectionValidation/InspectionValidationView.swift) — Validation input + photo gallery per field
- [`FinalReport/FinalReportView.swift`](FinalReport/FinalReportView.swift) — Final report preview + PDF export + email
- [`AddCustomFieldView.swift`](AddCustomFieldView.swift) — Sheet để thêm field tùy chỉnh (⚠️ callback chưa có logic)

### Domain

- [`GenerateHTMLPDFReportUseCase.swift`](../../../Domain/UseCases/GenerateHTMLPDFReportUseCase.swift) — `execute(detail:images:inspectorName:location:) async throws -> Data`
- [`Inspection.swift`](../../../Domain/Entities/Inspection.swift) — `Inspection`, `InspectionSection`, `InspectionField`, `InspectionImage`, `InspectionStatus`

### Data

- [`FirestoreInspectionStorageService.swift`](../../Data/Services/FirestoreInspectionStorageService.swift) — Production Firestore-backed service
- [`InspectionStorageService.swift`](../../Data/Services/InspectionStorageService.swift) — Local disk JSON-backed service
- [`InspectionStorageServiceType.swift`](../../Domain/Repositories/InspectionStorageServiceType.swift) — Protocol: `getInspection(by:)`, `updateInspection(_:)`

### Common Helpers

- [`Common/Helpers/UIImage+Upload.swift`](../../../Common/Helpers/UIImage+Upload.swift) — `prepareForUpload(maxDimension:compressionQuality:)`: resize ảnh về ≤2048px (aspect-ratio preserved) rồi compress JPEG 0.8; dùng chung cho cả 2 luồng upload

---

## API Contracts

> Không có REST API trực tiếp — dữ liệu được persist qua Firebase Firestore. Ảnh được upload lên Firebase Storage (xử lý trong `InspectionValidationView`, không phải màn hình này).

| Operation | Method | Description |
|-----------|--------|-------------|
| Load inspection | `storageService.getInspection(by: id)` | Synchronous read từ in-memory cache |
| Update inspection | `storageService.updateInspection(_:)` | Async write về Firestore + update cache |
| Generate PDF | `generatePDFUseCase.execute(detail:images:inspectorName:location:)` | Returns `Data` — HTML rendered to PDF |

---

## Edge Cases & Error Handling

| Scenario | Expected Behavior | Handled? |
|----------|------------------|----------|
| Inspection không tìm thấy trong cache | Fallback về `Inspection.mock()` — silent, user không biết | ⚠️ Nên là error state |
| Submit thất bại (network/Firestore error) | Set `errorMessage` — hiển thị ở đâu? (không có error UI trên màn hình submit) | ⚠️ Partial |
| Mail không khả dụng | `showMailUnavailableAlert = true` | ✅ |
| PDF generation thất bại | `pdfError` set trong `contentViewModel` | ⚠️ Consumer là FinalReportView |
| Không có ảnh cho field | Field hiển thị trống — `hasPhoto(for:)` = false | ✅ |
| `loadInspectionDetail()` gọi lại | Blocked bởi `hasLoadedOnce` guard | ✅ |
| `refreshInspection()` sau khi save | Sync read cache, update `inspection` | ✅ |
| ContentView không re-render sau `refreshInspection()` | `contentViewModel.inspection` là computed var, không phát `objectWillChange` | ❌ Bug |

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `InspectionDetailViewModel` | — | ❌ Missing |
| `InspectionDetailContentViewModel` | — | ❌ Missing |
| `GenerateHTMLPDFReportUseCase` | — | ❌ Missing |
| `InspectionStorageService` | — | ❌ Missing |

**Suggested test cases:**
- [ ] `loadInspectionDetail()` — found in cache → `inspection` set correctly
- [ ] `loadInspectionDetail()` — not found → fallback mock loaded
- [ ] `loadInspectionDetail()` — called twice → second call is no-op (hasLoadedOnce guard)
- [ ] `submitInspection()` — remote URLs flushed to model before save
- [ ] `submitInspection()` — status updated to `.inProgress`
- [ ] `submitInspection()` — storage failure → `errorMessage` set
- [ ] `handlePhotoSelection(_:)` — photos appended to correct fieldId
- [ ] `toggleSection(_:)` — expand/collapse state correct
- [ ] `autoExpandFirstSection()` — first section inserted into `expandedSections`

---

## Known Issues

### 1. ❌ Reactivity gap: ContentView không re-render sau `refreshInspection()`
`contentViewModel.inspection` là **computed var** (không phải `@Published`) → khi `parentViewModel.inspection` thay đổi, `InspectionDetailContentView` **không re-render tự động**.

**Fix:** Thêm `@Published var inspectionVersion: Int = 0` vào `contentViewModel` và increment khi parent thay đổi, hoặc expose `inspection` qua Combine sink.

### 2. ⚠️ Fallback về mock data thay vì error state
```swift
} else {
    inspection = Inspection.mock(inspectionId: inspectionId, inspectionNumber: inspectionNumber)
}
```
Trong production: nếu inspection không có trong local cache → nên show error, không nên silent mock.

### 3. ⚠️ `AddCustomFieldView` callback chưa có logic
```swift
print("Custom field: \(label), type: \(type)")
// TODO: Add logic to create custom field
```
Field tùy chỉnh không được lưu vào ViewModel hay persistence layer.

### 4. ⚠️ Duplicate logic trong PDF generation
`generateAndPreviewPDF()` và `generateAndSendPDF()` có ~80% code giống nhau. Nên extract:
```swift
private func generatePDF() async throws -> Data { ... }
```

### 5. ⚠️ PDF state thuộc sai ViewModel
`isGeneratingPDF`, `pdfData`, `isShowingMailComposer`, `isShowingPDFPreview` được set trong `InspectionDetailContentViewModel` nhưng consumed bởi `FinalReportView`. Nên chuyển sang `FinalReportViewModel`.

### 6. ℹ️ `sortedSections` sort mỗi lần access
`sortedSections` là computed var gọi `.sorted()` mỗi lần SwiftUI đọc. Fix: cache trong `@Published var` và recompute chỉ khi `inspection` thay đổi.

### 7. ℹ️ Raw font trong ContentView
`InspectionDetailContentView` dùng `.font(.system(size: 16, weight: .semibold))` trực tiếp. Nên dùng `LMSLabel` với style token.

---

## Dependencies

| Symbol | Source | Purpose |
|--------|--------|---------|
| `InspectionStorageServiceType` | DI Container | Load/update inspection từ local cache |
| `GenerateHTMLPDFReportUseCase` | DI Container | Tạo PDF report |
| `KeychainManager` | Keychain | Lấy tên inspector cho PDF |
| `LocalizationManager` | `@EnvironmentObject` | i18n strings cho tab titles và labels |
| `LMSLoadingOverlay` | Common/Components | Loading overlay khi submit |
| `InspectionSectionView` | Common/Components | Collapsible section container |
| `InspectionFieldItemView` | Common/Components | Field row với camera + text action |
| `LMSSkeleton` / `LMSInspectionCardSkeleton` | Common/Components | Loading skeleton cho content tab |
| `CameraView` | Shared/Camera | Chụp ảnh cho field hoặc error report |
| `InspectionValidationView` | InspectionValidation/ | Nhập kết quả + gallery cho 1 field |
| `FinalReportView` | FinalReport/ | Xem báo cáo hoàn chỉnh + PDF |
| `PhotoCaptureErrorReviewView` | ErrorHome/PhotoCaptureErrorReview | Review + save ảnh lỗi |
| `AddCustomFieldView` | InspectionDetail/ | Sheet thêm field tùy chỉnh |
| `ErrorHomeView` | Home/ErrorHome | Tab "Lỗi" |
| `InformationPurchaseView` | Home/InformationPurchase | Tab "Thông tin đơn hàng" |

---

---

## Bug Fix Log

### 🐛 BUG-008 — Error tab item tap navigated back to Home instead of pushing `PhotoCaptureErrorReviewView`

**Date:** 2026-05-23  
**Branch:** `feat/login`  
**Severity:** Critical (core navigation broken)

#### Root Cause

`navigationDestination(item:)` was placed on `ErrorHomeView.body` — a subview **two levels deep** inside `InspectionDetailView`, which is itself path-pushed onto `LMSHomeView`'s `NavigationStack(path:)`.

SwiftUI rule: in a `NavigationStack(path:)`-driven hierarchy, `navigationDestination(item:)` placed on a **deeply nested subview** (not the direct content of the pushed view) corrupts/pops the entire navigation path back to root.

```
NavigationStack(path: $navPath)   ← LMSHomeView owns this
  └── InspectionDetailView         ← pushed via path (correct scope)
        └── errorTabContent         ← computed var
              └── ErrorHomeView      ← .navigationDestination(item:) here = ❌ WRONG SCOPE
```

The working `navigationDestination(item: $viewModel.selectedValidationField)` was already at the **`InspectionDetailView.body` level** (correct scope) — this proved the fix direction.

#### Fix: Hoist Navigation State & Destination

**Pattern: Hoist navigation destination to the direct content of the pushed view. Use callbacks to propagate user actions upward.**

**4 files changed:**

**1. `ErrorHomeViewModel.swift`** — Added scroll-to-top trigger (replaces `@Binding` need):
```swift
@Published var scrollToTopTrigger: Int = 0
```

**2. `InspectionDetailViewModel.swift`** — Hoisted error item navigation state + ViewModel ownership:
```swift
@Published var selectedErrorItem: SavedErrorItem? = nil

private(set) lazy var errorHomeViewModel: ErrorHomeViewModel = {
    ErrorHomeViewModel(inspectionId: inspectionId)
}()
```

**3. `InspectionDetailView.swift`** — Moved `navigationDestination` to body level; wired callbacks:
```swift
// In body — same level as selectedValidationField destination ✅
.navigationDestination(item: $viewModel.selectedErrorItem) { item in
    PhotoCaptureErrorReviewView(
        inspectionId: viewModel.inspectionId,
        initialImages: ...,
        editingItem: item,
        onSaved: { saved, images in
            viewModel.errorHomeViewModel.upsertErrorItem(saved, thumbnails: images)
            viewModel.errorHomeViewModel.scrollToTopTrigger += 1
        },
        onDeleted: { deletedItem in
            viewModel.errorHomeViewModel.deleteErrorItem(deletedItem)
        }
    )
}

// errorTabContent — uses hoisted ViewModel, passes callback up
private var errorTabContent: some View {
    ErrorHomeView(
        viewModel: viewModel.errorHomeViewModel,
        onItemTapped: { item in viewModel.selectedErrorItem = item }  // ✅ sets state at correct level
    )
}
```

**4. `ErrorHomeView.swift`** — Removed own navigation state; added `onItemTapped` callback:
```swift
// Removed: @State private var selectedErrorItem
// Removed: .navigationDestination(item: $selectedErrorItem) block
// Added:
let onItemTapped: (SavedErrorItem) -> Void

// Button action changed from: selectedErrorItem = item
// To:
Button(action: { onItemTapped(item) }) { ... }

// scrollToTopTrigger now reads from ViewModel:
.onChange(of: viewModel.scrollToTopTrigger) { _ in
    proxy.scrollTo("errorList-top", anchor: .top)
}
```

#### Rule to Remember

> In a `NavigationStack(path:)`-driven app, **always place `navigationDestination` at the direct content level of the pushed view** — never inside a nested subview. Use callback patterns (`onItemTapped`) to bubble user actions up, and `@Published` on parent ViewModel to hold the selected item state.

---

### 🐛 BUG-009 — Nested NavigationStack in PhotoCaptureErrorReviewView breaks push navigation

**Date:** 2026-05-23  
**Branch:** `feat/login`  
**Severity:** Critical (navigation broken when accessed via navigationDestination)

#### Root Cause

`PhotoCaptureErrorReviewView` wrapped its entire body in a `NavigationStack`, which created a conflict when the view was presented via `navigationDestination` (push navigation). The view is used in two contexts:

1. **Sheet presentation** from `ErrorHomeView` (floating button → new error capture) — works fine with NavigationStack
2. **Push navigation** from `InspectionDetailView` via `.navigationDestination(item: $viewModel.selectedErrorItem)` (existing error review) — **breaks with nested NavigationStack**

SwiftUI rule: Views presented via `navigationDestination` are already inside the parent NavigationStack. Adding another NavigationStack creates a nested hierarchy that breaks navigation behavior.

```
NavigationStack(path: $navPath)              ← LMSHomeView owns this
  └── InspectionDetailView                   ← pushed via navigationDestination
        └── .navigationDestination(item:)     ← defines next destination
              └── PhotoCaptureErrorReviewView ← should NOT have NavigationStack ❌
                    └── NavigationStack { }   ← nested stack breaks navigation
```

#### Fix: Remove NavigationStack and Conditionally Wrap for Sheet

**Pattern: Remove NavigationStack from reusable views that can be pushed. Wrap with NavigationStack only when presenting as sheet.**

**2 files changed:**

**1. `PhotoCaptureErrorReviewView.swift`** — Removed NavigationStack wrapper:
```swift
// BEFORE ❌
var body: some View {
    NavigationStack {
        ScrollView { ... }
        .navigationTitle(...)
        .toolbar { ... }
    }
    .safeAreaInset(edge: .bottom) { ... }
}

// AFTER ✅
var body: some View {
    ScrollView { ... }
    .navigationTitle(...)
    .toolbar { ... }
    .safeAreaInset(edge: .bottom) { ... }
}
```

Key changes:
- Removed `NavigationStack` wrapper
- Moved `.safeAreaInset` from outside NavigationStack to end of modifier chain
- All `.navigationTitle`, `.toolbar`, and other navigation modifiers work correctly without NavigationStack wrapper

**2. `ErrorHomeView.swift`** — Wrapped sheet presentation in NavigationStack:
```swift
// Sheet presentation for NEW error captures (floating button)
.sheet(isPresented: $showErrorReview) {
    NavigationStack {  // ✅ Wrap here for sheet context
        PhotoCaptureErrorReviewView(
            inspectionId: viewModel.inspectionId,
            initialImages: capturedImages.map { ImageWithNote(source: .local(image: $0)) },
            onImagesUpdated: { _ in },
            onSaved: { saved, images in
                viewModel.upsertErrorItem(saved, thumbnails: images)
                viewModel.scrollToTopTrigger += 1
            }
        )
    }
}
```

#### Navigation Behavior After Fix

✅ **Push navigation** (via `navigationDestination` from InspectionDetailView):
- User taps error item in ErrorHomeView → `onItemTapped` callback → `viewModel.selectedErrorItem = item`
- PhotoCaptureErrorReviewView is pushed onto existing NavigationStack
- Back button works correctly, returns to ErrorHomeView
- All navigation modifiers (title, toolbar) function properly

✅ **Sheet presentation** (via floating button in ErrorHomeView):
- User taps floating orange button → camera → review screen
- PhotoCaptureErrorReviewView presented as sheet with NavigationStack wrapper
- Dismiss works correctly
- Navigation UI displays properly in sheet context

#### Rule to Remember

> **Never wrap a reusable view's body in NavigationStack** if that view can be both pushed (via `navigationDestination`) and presented (via `.sheet`). Instead, wrap it with NavigationStack **only at the presentation site** for sheets, and keep the view body clean for push navigation. Navigation modifiers (`.navigationTitle`, `.toolbar`) work in both contexts without requiring a NavigationStack wrapper.

#### Debug Enhancements Added

To aid in troubleshooting navigation issues, comprehensive debug logging was added across the navigation flow:

**Files enhanced with debug logging:**

1. **InspectionDetailViewModel.swift** — `selectedErrorItem` didSet observer:
```swift
@Published var selectedErrorItem: SavedErrorItem? = nil {
    didSet {
        print("🔍 [InspectionDetailVM] selectedErrorItem changed:")
        print("   - Old: \(oldValue?.id ?? "nil")")
        print("   - New: \(selectedErrorItem?.id ?? "nil")")
    }
}
```

2. **ErrorHomeView.swift** — Item tap logging:
```swift
Button(action: {
    print("🔍 [ErrorHomeView] Item tapped: \(item.id)")
    print("   - Severity: \(item.severity)")
    print("   - DefectType: \(item.defectType)")
    onItemTapped(item)
    print("   - Callback executed ✅")
})
```

3. **InspectionDetailView.swift** — Navigation destination and callback logging:
```swift
// errorTabContent callback
onItemTapped: { item in
    print("🔍 [InspectionDetailView] errorTabContent onItemTapped callback")
    print("   - Item ID: \(item.id)")
    viewModel.selectedErrorItem = item
}

// navigationDestination
.navigationDestination(item: $viewModel.selectedErrorItem) { item in
    PhotoCaptureErrorReviewView(...)
        .onAppear {
            print("🔍 [InspectionDetailView] navigationDestination appeared")
        }
}

// Callbacks
onSaved: { saved, images in
    print("🔍 [InspectionDetailView] onSaved callback triggered")
    ...
}
```

4. **PhotoCaptureErrorReviewView.swift** — Lifecycle logging:
```swift
.onAppear {
    print("🔍 [PhotoCaptureErrorReviewView] onAppear")
    print("   - EditMode: \(viewModel.isEditMode)")
    print("   - InspectionId: \(viewModel.inspectionId)")
    print("   - EditingItem: \(editingItem?.id ?? "nil")")
}
.onDisappear {
    print("🔍 [PhotoCaptureErrorReviewView] onDisappear")
}
```

5. **PhotoCaptureErrorReviewViewModel.swift** — Access level fix:
```swift
// Changed from private to internal for debug access
let inspectionId: String  // Internal for debug access
```

**Debug flow expected output:**
```
🔍 [ErrorHomeView] Item tapped: <item-id>
   - Severity: medium
   - DefectType: su4
   - Callback executed ✅
🔍 [InspectionDetailView] errorTabContent onItemTapped callback
   - Item ID: <item-id>
   - Setting selectedErrorItem...
   - selectedErrorItem set ✅
🔍 [InspectionDetailVM] selectedErrorItem changed:
   - Old: nil
   - New: <item-id>
🔍 [InspectionDetailView] navigationDestination appeared for item: <item-id>
🔍 [PhotoCaptureErrorReviewView] onAppear
   - EditMode: true
   - InspectionId: <inspection-id>
   - EditingItem: <item-id>
```

---

### 🐛 BUG-010 — Remote image shows black after editing in ImageEditorView

**Date:** 2026-05-23  
**Branch:** `feat/login`  
**Severity:** High (image editing broken for remote images)

#### Root Cause

When editing a remote image:

1. User taps "Edit" on a remote image → `handleEditImage()` downloads it
2. ImageEditorView edits the UIImage
3. Callback `viewModel.replaceImage(at: index, with: editedImage)` changes source from `.remote(url)` to `.local(image)`
4. `ImageWithNote.id` (UUID) remains unchanged
5. SwiftUI doesn't recreate `ImageRowCard` because same `id` in `ForEach`
6. Old `CachedAsyncImage` continues rendering, showing black/empty

SwiftUI rule: When using `ForEach(id:)`, if the identity doesn't change, SwiftUI reuses the view even when content changes. The `ImageSource` change from `.remote` to `.local` was invisible to SwiftUI's identity system.

```
ForEach(images, id: \.id) { imageWithNote in
    ImageRowCard(source: imageWithNote.source, ...)  // ❌ source changes but id doesn't
}
```

#### Fix: Force View Identity Change with `.id()` Modifier

**Pattern: Use composite identity that includes both stable ID and source type.**

**2 files changed:**

**1. `ErrorItem.swift`** — Added `idString` computed property to `ImageSource`:
```swift
enum ImageSource: Equatable {
    case remote(url: String)
    case local(image: UIImage)
    
    var idString: String {
        switch self {
        case .remote(let url):
            return "remote-\(url.hashValue)"
        case .local(let image):
            return "local-\(ObjectIdentifier(image).hashValue)"
        }
    }
}
```

**2. `PhotoCaptureErrorReviewView.swift`** — Added `.id()` modifier to force recreation:
```swift
ForEach(Array(viewModel.images.enumerated()), id: \.element.id) { index, imageWithNote in
    ImageRowCard(
        source: imageWithNote.source,
        index: index,
        total: viewModel.images.count,
        note: ...,
        cornerRadius: ...
    ) {
        selectedImageIndex = index
        showImageMenu = true
    }
    .id("\(imageWithNote.id)-\(imageWithNote.source.idString)")  // ✅ Composite identity
}
```

#### How It Works

**Before (broken):**
```
Remote Image Edit Flow:
1. source = .remote("url123") → id = "uuid-abc"
2. Edit & Save
3. source = .local(UIImage) → id = "uuid-abc" (same!)
4. SwiftUI: "same id, reuse view" → CachedAsyncImage still rendering
5. Result: Black/empty image
```

**After (fixed):**
```
Remote Image Edit Flow:
1. source = .remote("url123") → composite id = "uuid-abc-remote-123456"
2. Edit & Save  
3. source = .local(UIImage) → composite id = "uuid-abc-local-789012" (different!)
4. SwiftUI: "different id, recreate view" → Fresh Image(uiImage:) rendered
5. Result: Edited image displays correctly ✅
```

#### Rule to Remember

> When SwiftUI views depend on enum state that can change (like `ImageSource`), always use composite identity in `.id()` modifier. Combine the stable identifier (UUID) with a string representation of the enum case to force view recreation when the variant changes. For enums with associated values, use `hashValue` or `ObjectIdentifier` to create unique strings per case.

---

### 🐛 BUG-011 — UIGraphicsImageRenderer memory allocation fails for large images (9072x12096 pixels)

**Date:** 2026-05-23  
**Branch:** `feat/login`  
**Severity:** Critical (app crashes with "unable to allocate 7.9GB" error when editing high-res images)

#### Root Cause

Firebase Storage may contain high-resolution images (9072 x 12096 pixels from iPhone Pro Max photos). When compositing in `ImageEditorViewModel.compositeImage()`:

```swift
private func compositeImage(canvasSize: CGSize) -> UIImage {
    let base = rotatedSourceImage()  // 9072x12096
    let imgSize = base.size
    let renderer = UIGraphicsImageRenderer(size: imgSize)  // ❌ Tries to allocate 9072*12096*4 bytes
    
    return renderer.image { _ in
        base.draw(in: CGRect(origin: .zero, size: imgSize))
        // ...PencilKit drawing overlay
    }
}
```

**Memory calculation for 9072 x 12096 pixels:**
- RGBA format: 4 bytes per pixel
- Total: 9072 × 12096 × 4 = **439,205,888 bytes** (~439MB for image data)
- CGBitmapContext overhead: **~7,900,913,664 bytes** (~7.9GB) requested by Core Graphics

**Console output:**
```
🔍 [PhotoCaptureErrorReviewVM] downloadImage()
   - Downloaded 11215207 bytes (~11MB compressed)
   - Original image size: (9072.0, 12096.0)
   
🔍 [ImageEditorViewModel] compositeImage()
   - Base image size: (9072.0, 12096.0)
   - Canvas size: (492.0, 656.0)
   - Scale: (18.4390243902439, 18.4390243902439)

CGBitmapContextInfoCreate: unable to allocate 7900913664 bytes for bitmap data
CGDisplayListDrawInContext: invalid context 0x0
CGBitmapContextCreateImage: invalid context 0x0
   - Result image size: (0.0, 0.0)  ❌
```

iOS **cannot allocate 7.9GB** for a single bitmap context → returns invalid context → result is empty UIImage with size (0.0, 0.0).

#### Fix: Auto-Resize Large Images on Download

**Pattern: Resize images to max 2048x2048 before processing to prevent memory issues.**

**File changed: `PhotoCaptureErrorReviewViewModel.swift`**

```swift
func downloadImage(from url: String) async throws -> UIImage {
    print("🔍 [PhotoCaptureErrorReviewVM] downloadImage()")
    guard let imageURL = URL(string: url) else { throw URLError(.badURL) }
    let (data, _) = try await URLSession.shared.data(from: imageURL)
    guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
    
    print("   - Original image size: \(image.size)")
    
    // ✅ Resize if too large (prevents memory issues in compositing)
    let maxDimension: CGFloat = 2048
    if image.size.width > maxDimension || image.size.height > maxDimension {
        let resized = resizeImage(image, maxDimension: maxDimension)
        print("   - ⚠️ Image too large, resized to: \(resized.size)")
        return resized
    }
    
    return image
}

private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    let aspectRatio = size.width / size.height
    var newSize: CGSize
    
    if size.width > size.height {
        newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
    } else {
        newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
    }
    
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}
```

#### How It Works

**Before (broken - 7.9GB memory request):**
```
Download Flow:
1. Download 11MB JPEG from Firebase
2. Decode to UIImage: (9072.0, 12096.0) pixels
3. Pass to ImageEditorView → compositeImage()
4. UIGraphicsImageRenderer(size: 9072x12096)
5. iOS: "Need 7.9GB RAM" → FAIL ❌
6. Return empty image (0.0, 0.0)
```

**After (fixed - ~16MB memory):**
```
Download Flow:
1. Download 11MB JPEG from Firebase
2. Decode to UIImage: (9072.0, 12096.0) pixels
3. Check: width > 2048? YES → resize
4. Resize to (1536.0, 2048.0) preserving aspect ratio
5. Pass to ImageEditorView → compositeImage()
6. UIGraphicsImageRenderer(size: 1536x2048)
7. iOS: "Need ~16MB RAM" → OK ✅
8. Return valid image (1536.0, 2048.0)
```

**Memory calculation after resize (1536 x 2048):**
- RGBA format: 4 bytes per pixel
- Total: 1536 × 2048 × 4 = **12,582,912 bytes** (~12MB)
- CGBitmapContext overhead: **~16-20MB** (acceptable!)

**Console output after fix:**
```
🔍 [PhotoCaptureErrorReviewVM] downloadImage()
   - Downloaded 11215207 bytes
   - Original image size: (9072.0, 12096.0)
   - ⚠️ Image too large, resized to: (1536.0, 2048.0)  ✅
   - Downloaded image size: (1536.0, 2048.0)

🔍 [ImageEditorViewModel] compositeImage()
   - Base image size: (1536.0, 2048.0)  ✅
   - Canvas size: (492.0, 656.0)
   - Scale: (3.12, 3.12)
   - Result image size: (1536.0, 2048.0)  ✅ SUCCESS
```

#### Why 2048x2048 Max?

1. **Display Quality:** iPhone screen resolutions max out at ~2796x1290 (iPhone 17 Pro Max). 2048px is sufficient for crisp display.
2. **Memory Safe:** 2048×2048×4 = 16MB bitmap (well within iOS memory limits).
3. **Annotation Quality:** PencilKit drawings scale perfectly at 2048px resolution.
4. **Upload Efficiency:** Smaller file size when saving back to Firebase (~2-3MB vs 11MB).

#### Rule to Remember

> Always validate and resize large images (>2048px) when downloading from remote storage before passing to UIKit/Core Graphics compositing operations. High-resolution camera photos (9000+ pixels) exceed iOS memory limits for bitmap contexts. Resize preserving aspect ratio to max 2048x2048 — this maintains excellent visual quality while preventing memory allocation failures.

**Debug pattern to detect oversized images:**
```swift
// Add this check after downloading any remote image
if image.size.width > 2048 || image.size.height > 2048 {
    print("⚠️ Image exceeds safe dimensions: \(image.size)")
    print("   Memory required: ~\(Int(image.size.width * image.size.height * 4 / 1024 / 1024))MB")
}
```

---

---

### ⚡ PERF-001 — Sequential image upload blocks UI (ErrorRepository) + missing isLoading feedback (InspectionValidationView)

**Date:** 2026-06-06
**Branch:** `feat/login`
**Severity:** High (UX blocking — 3 ảnh = ~6s chờ)

#### Root Cause

**Luồng 1 — `ErrorRepository.saveErrorItem()`:**
Sequential `for` loop await từng upload — image N không bắt đầu cho đến khi image N-1 xong. Với 3 ảnh × ~2s/upload = 6s lock UI.

```swift
// ❌ BEFORE: Sequential
for (index, image) in localImages.enumerated() {
    let imageData = image.jpegData(compressionQuality: 0.8)   // CPU block on actor
    let url = try await storageService.uploadImage(imageData, path: path)  // network block
    imageURLs.append(url)
}
```

**Luồng 2 — `InspectionValidationViewModel`:**
Đã dùng `withTaskGroup` (concurrent) nhưng không set `isLoading = true` khi upload bắt đầu → user không có feedback trong suốt quá trình upload.

**Cả 2 luồng:**
`jpegData(compressionQuality: 0.8)` compress ảnh full-size (ví dụ 4032×3024 từ iPhone) mà không resize trước → file ~3-5MB/ảnh thay vì ~500KB sau resize.

#### Fix

**3 files changed:**

**1. `Common/Helpers/UIImage+Upload.swift`** — Shared helper mới:
```swift
extension UIImage {
    func prepareForUpload(maxDimension: CGFloat = 2048, compressionQuality: CGFloat = 0.8) -> Data? {
        let resized = resizedIfNeeded(maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: compressionQuality)
    }
}
```
Resize về ≤2048px trước khi JPEG compress → ~600KB thay vì ~4MB.

**2. `ErrorRepository.swift`** — Sequential → concurrent + dùng helper:
```swift
// ✅ AFTER: Concurrent + resize
let uploadedURLs: [String] = try await withThrowingTaskGroup(of: (Int, String).self) { group in
    for (index, image) in localImages {
        group.addTask {
            guard let imageData = await Task.detached(priority: .userInitiated) {
                image.prepareForUpload()   // resize + compress on background thread
            }.value else { throw UploadError.compressionFailed }
            let url = try await self.storageService.uploadImage(imageData, path: path)
            return (index, url)
        }
    }
    // collect results sorted by index
}
```

**3. `InspectionValidationViewModel.swift`** — isLoading feedback + dùng helper:
```swift
isLoading = true
Task {
    await uploadPhotosAndUpdateField(fieldId: fieldId, images: imagesToUpload)
    await updateInspectionStatus()
    isLoading = false
}
// Trong uploadPhotosAndUpdateField — dùng prepareForUpload thay jpegData trực tiếp
```

#### Kết quả

| | Trước | Sau |
|---|---|---|
| 3 ảnh upload | ~6s sequential | ~2s concurrent |
| File size/ảnh | ~3-5MB | ~500KB-1MB |
| Main thread | JPEG compress trên actor | `Task.detached(priority: .userInitiated)` |
| UI feedback | Không có | `isLoading = true` khi upload |

#### Rule to Remember

> Khi upload nhiều ảnh, luôn dùng `withThrowingTaskGroup` — không dùng sequential `for await`. Luôn resize về ≤2048px trước JPEG compress. Đặt logic resize+compress trong `Task.detached(priority: .userInitiated)` để không block actor executor. Thêm `isLoading = true/false` để user biết trạng thái upload.

---

*Generated by `/ct-ai-document` on 2026-05-23 | Updated 2026-06-06 — PERF-001: concurrent upload + resize-before-compress*
