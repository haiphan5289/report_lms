# CreateInspectionView

Module cho phép người dùng tạo mới một báo cáo kiểm tra (Inspection).

## Cấu trúc file

```
CreateInspectionView/
├── CreateInspectionView.swift      — SwiftUI View
├── CreateInspectionViewModel.swift — ViewModel + InputFieldType
└── README.md                       — tài liệu này
```

## Kiến trúc

Pattern: **MVVM + SwiftUI**

```
CreateInspectionView
    └── @StateObject CreateInspectionViewModel
            ├── CreateInspectionUseCase   (domain)
            └── InspectionStorageServiceType (data)
```

## Các trường nhập liệu

| Field | Loại input | Bắt buộc |
|---|---|---|
| Tên sản phẩm | Text tự do | Có |
| Mã sản phẩm | Text tự do | Có |
| Mã đơn hàng | Text tự do | Có |
| Biểu mẫu kiểm hàng | Dropdown (SearchableList) | Có |
| Loại kiểm tra | Dropdown (SearchableList) | Có |
| Phương pháp lấy mẫu | Dropdown (SearchableList) | Có |
| Số lượng | Numeric input | Có |
| Nhà máy | **Text tự do** | Có |
| Đơn vị sản xuất | **Text tự do** | Có |

> **Nhà máy** và **Đơn vị sản xuất** là free-text (nhập tay), không dùng dropdown.

## Luồng tạo mới

1. User điền form → `@Published` properties trên ViewModel cập nhật
2. `didSet` chạy validation ngay khi field thay đổi → set `xxxError`
3. Nhấn "Tạo kiểm tra" → `viewModel.createInspection()` async
4. ViewModel tạo `Inspection` entity → lưu qua `InspectionStorageServiceType`
5. `createdInspection` được set → View observe qua `onChange` → dismiss + callback `onInspectionCreated`

## Validation

Mỗi field được validate trong `didSet`. Quy tắc hiện tại: không được để trống.

**Lưu ý bug tiềm ẩn:** `validateInputs()` chỉ kiểm tra errors có `nil` không. Nếu người dùng chưa tương tác với field nào thì error vẫn `nil` dù field trống → có thể submit form rỗng. Cần chạy `validateAll()` trước khi submit.

## Các issues cần lưu ý

- **Date format sai:** `generateInspectionNumber()` dùng `"yyyyMMHHmmss"` thiếu `dd` (ngày). Nên là `"yyyyMMddHHmmss"`.
- **`inspectionForm` / `samplingMethod` không được lưu vào `Inspection` entity** trong `createInspection()` — dữ liệu bị mất.
- `InputField` là `class` trong khi chỉ cần `struct` (không có identity semantics).
- Quá nhiều `print` debug statements trong production code.
- `getFieldType(for:)` dùng string title để map ngược về `InputFieldType` — fragile nếu title thay đổi.

## Dependencies

- `SearchableListView` — sheet picker cho dropdown fields
- `ProductInfoInput` — component render từng field (`.required` / `.dropdown` / `.quantity`)
- `QuantityInputView` — component riêng cho field số lượng
- `LMSButton` — nút submit
- `Container` (Swinject) — DI resolve `CreateInspectionUseCase`, `InspectionStorageServiceType`
