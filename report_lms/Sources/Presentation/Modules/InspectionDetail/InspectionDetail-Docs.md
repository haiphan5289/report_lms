# InspectionDetail Module

Màn hình xem và thao tác chi tiết một phiếu kiểm tra (Inspection).

## Cấu trúc file

```
InspectionDetail/
├── InspectionDetailView.swift              — Entry point, tab bar, navigation
├── InspectionDetailViewModel.swift         — State chính, load/submit data
├── InspectionDetailContentView.swift       — Tab "Kiểm tra": danh sách section/field
├── InspectionDetailContentViewModel.swift  — State của tab kiểm tra + PDF generation
├── AddCustomFieldView.swift                — Sheet thêm điểm kiểm tra tùy chỉnh
├── FinalReport/                            — Màn hình hoàn tất & xuất PDF
└── InspectionValidation/                   — Màn hình nhập kết quả từng field
```

## Kiến trúc

Pattern: **MVVM + SwiftUI, parent-child ViewModel**

```
InspectionDetailView (@StateObject InspectionDetailViewModel)
│
├── tabBar         — 3 tabs: Kiểm tra / Lỗi / Thông tin đơn hàng
│
└── tabContent
     ├── [.inspectionDetail] InspectionDetailContentView
     │       (@ObservedObject InspectionDetailContentViewModel)
     │       — child VM sở hữu bởi parent, truy cập data qua weak ref
     │
     ├── [.error]            ErrorHomeView
     └── [.orderInformation] InformationPurchaseView
```

### Quan hệ parent ↔ child ViewModel

`InspectionDetailContentViewModel` **không tự quản lý data**. Nó giữ `weak var parentViewModel: InspectionDetailViewModel?` và expose data qua computed properties:

```swift
var inspection: Inspection? { parentViewModel?.inspection }
var capturedPhotos: [String: [InspectionImage]] { parentViewModel?.capturedPhotos ?? [:] }
```

`contentViewModel` được khởi tạo lazy bởi parent và truyền callbacks `onTextTap` / `onCameraTap` để navigate.

## Luồng dữ liệu

```
.task → loadInspectionDetail()
    └── storageService.getInspection(by:)  (local cache)
        ├── found  → inspection = loaded
        └── not found → inspection = Inspection.mock(...)   ← fallback mock
    └── autoExpandFirstSection()
    └── restoreCapturedPhotos(from:)        ← wrap Firebase URLs → InspectionImage.remoteURL
         (không download, AsyncImage load on-demand)
```

## Các states của InspectionDetailContentView

| Điều kiện | View hiển thị |
|---|---|
| `contentViewModel.inspection != nil` | `sectionListView()` — danh sách section/field |
| `errorMessage != nil` | `errorView(message:)` — icon lỗi + nút retry |
| Cả hai đều nil | `loadingPlaceholder` — view trống (xem issue #1) |

## Navigation từ field

- **Tap text field** → `openValidationView(for:)` → `showValidation = true` → `InspectionValidationView`
- **Tap camera icon** → `openCamera(for:)` → `showCamera = true` → `CameraView`
- **Nút "Thêm điểm kiểm tra"** → `showAddCustomField = true` → sheet `AddCustomFieldView`
- **Nút "Hoàn tất kiểm tra"** → `showFinalReport = true` → fullScreenCover `FinalReportView`

## PDF Generation

`InspectionDetailContentViewModel` chứa logic PDF nhưng **không được dùng bởi `InspectionDetailContentView`**. PDF được trigger từ `FinalReportView`. Hai phương thức:

| Method | Kết quả |
|---|---|
| `generateAndPreviewPDF()` | Set `pdfData` → `isShowingPDFPreview = true` |
| `generateAndSendPDF()` | Check mail availability → set `pdfData` → `isShowingMailComposer = true` |

---

## Issues cần lưu ý

### 1. `loadingPlaceholder` không có loading indicator (UX)
`loadingPlaceholder` là một `VStack` rỗng — user không biết app đang load hay bị lỗi.

**Fix:** Thay bằng `ProgressView` hoặc skeleton rows.

```swift
private var loadingPlaceholder: some View {
    ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
}
```

### 2. Reactivity gap khi `refreshInspection()` được gọi (Bug tiềm ẩn)
`InspectionDetailContentView` observe `contentViewModel` qua `@ObservedObject`. Nhưng `contentViewModel.inspection` là **computed var** (không phải `@Published`) → khi `parentViewModel.inspection` thay đổi, `contentViewModel` không phát ra `objectWillChange` → `InspectionDetailContentView` **không re-render**.

`InspectionDetailView` re-render (nó observe parent trực tiếp), nhưng view con thì không.

**Fix:** Thêm `@Published var inspectionVersion: Int = 0` vào `contentViewModel` và increment khi parent notify change, hoặc expose `inspection` qua `@Published` bằng Combine sink.

### 3. `submitInspection()` chưa implement (Incomplete)
```swift
try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network call
isSubmitted = true
```
Không thực sự submit dữ liệu. Nút Submit trên toolbar sẽ luôn "thành công" giả.

### 4. `AddCustomFieldView` callback chưa có logic (Incomplete)
```swift
print("Custom field: \(label), type: \(type)")
// TODO: Add logic to create custom field
```
Sheet thêm field không lưu gì vào ViewModel hay persistence layer.

### 5. Trùng lặp logic trong `generateAndPreviewPDF` / `generateAndSendPDF`
~80% code giống nhau. Nên extract:
```swift
private func generatePDF() async throws -> Data {
    guard let detail = inspection else { throw PDFError.noData }
    let name = KeychainManager.getStoredUsername() ?? "Unknown"
    return try await generatePDFUseCase.execute(detail: detail, images: capturedPhotos, inspectorName: name, location: "")
}
```

### 6. `sortedSections` sort mỗi lần access
`sortedSections` là computed var gọi `.sorted()` mỗi lần SwiftUI đọc. Với inspection có nhiều section, đây là unnecessary work.

**Fix:** Cache trong `@Published var sortedSections` và recompute chỉ khi `inspection` thay đổi.

### 7. Comment mồ côi trong ViewModel
```swift
/// Auto-expand first section when data loads
// MARK: - PDF Generation
```
Comment doc cho `autoExpandFirstSection()` bị đặt sai vị trí — method thực tế ở cuối file (line 202), cách xa comment ~90 dòng.

### 8. PDF state trong ContentViewModel không được dùng bởi ContentView
`isGeneratingPDF`, `pdfData`, `isShowingMailComposer`, `isShowingPDFPreview`, `pdfError`, `showMailUnavailableAlert` — tất cả các state này được set trong `InspectionDetailContentViewModel` nhưng `InspectionDetailContentView` không consume chúng. Chúng phục vụ `FinalReportView` nhưng được đặt ở sai ViewModel.

### 9. Raw font/color thay vì design system tokens
`InspectionDetailContentView` dùng `.font(.system(size: 16, weight: .semibold))` và `LMSColor.primary` trực tiếp. Nên dùng `LMSLabel` với style token thống nhất.

### 10. `loadInspectionDetail()` fallback về mock data
```swift
} else {
    inspection = Inspection.mock(inspectionId:inspectionNumber:)
}
```
Nếu không tìm thấy trong local storage, ViewModel tự động dùng mock. Trong production, đây nên là error state thay vì silent mock.

---

## Dependencies

| Symbol | Nguồn | Mục đích |
|---|---|---|
| `InspectionStorageServiceType` | DI Container | Load/refresh inspection từ local cache |
| `GenerateHTMLPDFReportUseCase` | DI Container | Tạo PDF report |
| `KeychainManager` | Keychain | Lấy tên inspector |
| `LocalizationManager` | EnvironmentObject | i18n strings |
| `InspectionSectionView` | Common/Components | Render section có thể collapse |
| `InspectionFieldItemView` | Common/Components | Render từng field với camera/text action |
| `FinalReportView` | FinalReport/ | Màn hình hoàn tất kiểm tra |
| `AddCustomFieldView` | InspectionDetail/ | Sheet thêm field tùy chỉnh |
| `CameraView` | Shared | Chụp ảnh cho field |
| `InspectionValidationView` | InspectionValidation/ | Nhập kết quả validation cho field |
