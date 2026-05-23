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

*Generated by `/ct-ai-document` on 2026-05-23*
