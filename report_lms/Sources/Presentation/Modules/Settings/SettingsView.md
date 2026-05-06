# SettingsView

Màn hình cài đặt — hiện tại chứa một tính năng duy nhất: chuyển đổi ngôn ngữ ứng dụng.

## Cấu trúc file

```
Settings/
├── SettingsView.swift   — UI cài đặt (List + language toggle)
└── SettingsView.md      — Tài liệu này
```

Không có ViewModel riêng — state ngôn ngữ được quản lý bởi `LocalizationManager.shared`.

## Kiến trúc

```
SettingsView
  └── @EnvironmentObject LocalizationManager
        ├── currentLanguage: AppLanguage   (@Published)
        └── setLanguage(_:)               → UserDefaults persist + @Published trigger
```

## Language Toggle Flow

```
User toggle ON (→ English)
  └── Binding.set: localizationManager.setLanguage(.english)
        ├── guard language != currentLanguage (no-op nếu không đổi)
        ├── currentLanguage = .english       ← @Published → toàn bộ View re-render
        └── UserDefaults.set("en", forKey: "app_selected_language")

App restart
  └── LocalizationManager.init()
        └── UserDefaults.string("app_selected_language") ?? "vi"
             └── currentLanguage = AppLanguage(rawValue:) ?? .vietnamese
```

## LocalizationManager

| Property / Method | Mô tả |
|---|---|
| `currentLanguage: AppLanguage` | `@Published` — trigger re-render toàn app khi đổi |
| `setLanguage(_:)` | Set language + persist vào UserDefaults |
| `localize(_ key:)` | Lookup string theo key + currentLanguage |
| `localize(_ key:, _ args:)` | Printf-style format string |

### Lookup logic

```swift
strings[currentLanguage]?[key] ?? key   // fallback = key itself nếu không tìm thấy
```

**Lưu ý:** Nếu một key tồn tại trong VN nhưng thiếu trong EN (hoặc ngược lại), `localize()` trả về **key string** (không phải VN fallback). Cần đảm bảo cả hai language dictionaries luôn đồng bộ key.

## Inspection Section/Field Localization

Khi user switch language, `InspectionDetailView` re-render tự động vì `LocalizationManager` là `@EnvironmentObject`. Labels của section và field được resolve tại render time — không phải từ stored string trong Firestore.

```
InspectionSection.localizedTitle(using: LocalizationManager)
  └── key = "inspection.section.\(section.id)"    e.g. "inspection.section.section1"
        ├── found → localized string              "Outer Carton" / "Thùng carton ngoài"
        └── not found → section.title            (fallback: custom sections user tạo)

InspectionField.localizedLabel(using: LocalizationManager)
  └── key = "inspection.field.\(field.id)"        e.g. "inspection.field.field1_1"
        ├── found → localized string              "Carton overview" / "Tổng quan thùng carton"
        └── not found → field.label              (fallback: custom fields user tạo)
```

### Key mapping (emptyTemplate)

| ID | EN | VN |
|---|---|---|
| `section1` | Outer Carton | Thùng carton ngoài |
| `section2` | Inner Carton | Thùng carton trong |
| `section3` | Product | Sản phẩm |
| `section4` | ANSI/BIFMA X5.5-2014 | ANSI/BIFMA X5.5-2014 |
| `field1_1` | Carton overview | Tổng quan thùng carton |
| `field1_2` | Shipping mark info | Thông tin tem/nhãn vận chuyển |
| `field2_1` | Inner carton overview | Tổng quan thùng carton trong |
| `field2_2` | Packaging (...) | Đóng gói (...) |
| `field3_1` | Product view | Tổng quan sản phẩm |
| `field3_2` | Compare with approved sample (...) | So sánh với mẫu đã duyệt (...) |
| `field3_3` | Product dimension | Kích thước sản phẩm |
| `field3_4` | Logo on product | Logo trên sản phẩm |
| `field3_5` | Product label (...) | Nhãn sản phẩm (...) |
| `field3_6` | Assembly instruction | Hướng dẫn lắp ráp |
| `field3_7` | Moisture Readings | Chỉ số độ ẩm |
| `field3_8` | Sheen Readings | Chỉ số độ bóng |
| `field3_9` | Color Comparison | So sánh màu sắc |
| `field4_1` | Weight of weights | Trọng lượng của quả cân |
| `field4_2` | Pictures of the weights to be applied | Ảnh quả cân cần áp dụng |
| `field4_3` | Pictures of the weights on the table... | Ảnh quả cân đặt trên bàn... |
| `field4_4` | Data to enter should be... | Dữ liệu nhập phải là... |

## Known Issues

- [ ] `SettingsView` không có ViewModel riêng — nếu Settings mở rộng (profile, notifications...) cần tách ra `SettingsViewModel`
- [ ] Language display label (`localizationManager.localize("settings.language.vietnamese")`) dùng chính ngôn ngữ hiện tại để hiển thị tên ngôn ngữ kia — khi đang EN, nút hiển thị "English" (đúng), nhưng khi đang VN, nút hiển thị "Tiếng Anh" thay vì "English" — có thể gây nhầm lẫn
- [ ] Không có confirmation dialog khi đổi ngôn ngữ — toàn bộ app re-render ngay lập tức
- [ ] `LocalizationManager` dùng hardcoded dictionary thay vì `.strings` / `.stringsdict` files — thêm ngôn ngữ mới (e.g. zh-Hans) đòi hỏi sửa trực tiếp file Swift
