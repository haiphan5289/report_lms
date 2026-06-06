# Report Home Feature — Feature Document

> **Jira:** — | **Branch:** `feat/login` | **Generated:** 2026-06-06

---

## PRD Summary

> Hiển thị danh sách các inspection đã hoàn thành (`status == .completed`), nhóm theo tuần. Người dùng có thể xem chi tiết và xoá một inspection từ bottom sheet.

- **Goal:** Cho phép người dùng tra cứu lịch sử inspection đã hoàn thành và quản lý (xoá) từng mục.
- **User story:** As a QC inspector, I want to see all completed inspections grouped by week so that I can review and manage past inspection records.
- **Acceptance criteria:**
  - [x] Hiển thị skeleton loading khi dữ liệu chưa sẵn sàng
  - [x] Hiển thị empty state có icon + message khi không có inspection hoàn thành
  - [x] Hiển thị error state có nút Retry khi load thất bại
  - [x] Danh sách inspection nhóm theo tuần, mỗi section có header ngày
  - [x] Tap card → mở `InspectionDetailBottomSheet`
  - [x] Bottom sheet hiển thị: inspection number, company, product, product code, factory, date, status badge
  - [x] Bottom sheet có nút "Xoá" với confirmation alert
  - [x] Sau khi xoá, danh sách tự reload
  - [x] Pull-to-refresh được hỗ trợ
  - [x] Dark mode / Light mode adaptive

---

## Business Rules

| Rule | Description |
|------|-------------|
| Completed only | Chỉ hiển thị `Inspection` có `status == .completed` |
| Weekly grouping | Nhóm theo `WeekSection` dùng `GroupInspectionsByWeekUseCase` |
| Auto-reload | Subscribe `Notification.Name.inspectionCacheDidLoad` + `.inspectionDidUpdate` — reload tự động khi cache thay đổi |
| Delete confirmation | Xoá phải qua confirmation alert trước khi gọi `storageService.deleteInspection(by:)` |
| No navigation | Tap card mở bottom sheet, không navigate sang màn hình khác |

---

## Architecture Overview

> SwiftUI MVVM — View → ViewModel → UseCase → StorageService (local cache + Firestore)

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`ReportLMSHomeView.swift`](ReportLMSHomeView.swift) | Danh sách inspection, skeleton/empty/error states, wire sheet |
| Presentation | [`ReportViewModel.swift`](ReportViewModel.swift) | Load & delete inspections, `@Published` state |
| Presentation | [`InspectionDetailBottomSheet.swift`](InspectionDetailBottomSheet.swift) | Bottom sheet: hero header, info section, delete action |
| Domain | [`GroupInspectionsByWeekUseCase.swift`](../../../../../../Domain/UseCases/GroupInspectionsByWeekUseCase.swift) | Nhóm `[Inspection]` thành `[WeekSection]` theo tuần |
| Domain | [`WeekSection.swift`](../../../../../../Domain/Entities/WeekSection.swift) | Entity: `{ id, title: String, inspections: [Inspection] }` |
| Domain | [`Inspection.swift`](../../../../../../Domain/Entities/Inspection.swift) | Core entity cho inspection record |
| Data | [`FirestoreInspectionStorageService.swift`](../../../../../../Data/Services/FirestoreInspectionStorageService.swift) | Firestore implementation của `InspectionStorageServiceType` |
| Data | [`InspectionStorageService.swift`](../../../../../../Data/Services/InspectionStorageService.swift) | Local cache implementation |

### Data Flow

```
User mở Report tab
  → ReportLMSHomeView.task
  → ReportViewModel.loadInspections()
  → storageService.getAllInspections().filter { $0.status == .completed }
  → GroupInspectionsByWeekUseCase.execute([Inspection]) → [WeekSection]
  → @Published weeklyInspections cập nhật → UI render danh sách

User tap một card
  → @State selectedInspection = inspection
  → .sheet(item: $selectedInspection) present InspectionDetailBottomSheet

User tap "Xoá" trong bottom sheet
  → showingDeleteConfirm = true
  → Confirmation alert "Xác nhận xoá"
  → Confirmed → onDelete() → viewModel.deleteInspection(inspection)
  → storageService.deleteInspection(by: inspection.id)
  → Notification.inspectionDidUpdate posted
  → viewModel.loadInspections() auto-reload
  → sheet dismissed
```

```mermaid
graph TD
    A[ReportLMSHomeView] -->|task / refreshable| B[ReportViewModel]
    B -->|getAllInspections filter completed| C[InspectionStorageServiceType]
    B -->|execute| D[GroupInspectionsByWeekUseCase]
    D -->|WeekSection array| B
    B -->|@Published weeklyInspections| A
    A -->|selectedInspection = inspection| E[InspectionDetailBottomSheet]
    E -->|onDelete callback| B
    B -->|deleteInspection by id| C
    C -->|Notification.inspectionDidUpdate| B
```

---

## Key Files & Symbols

### Presentation

- [`ReportLMSHomeView.swift`](ReportLMSHomeView.swift) — Main list screen. State: `isLoading`, `weeklyInspections`, `errorMessage`. Sheet trigger: `@State selectedInspection: Inspection?`
- [`ReportViewModel.swift`](ReportViewModel.swift) — `@MainActor ObservableObject`. Methods: `loadInspections() async`, `deleteInspection(_ inspection: Inspection) async`
- [`InspectionDetailBottomSheet.swift`](InspectionDetailBottomSheet.swift) — `.sheet` view. Callbacks: `onDelete: () -> Void`. Detents: `.medium`, `.large`

### Domain

- [`GroupInspectionsByWeekUseCase.swift`](../../../../../../Domain/UseCases/GroupInspectionsByWeekUseCase.swift) — `func execute(_ inspections: [Inspection]) -> [WeekSection]`
- [`WeekSection.swift`](../../../../../../Domain/Entities/WeekSection.swift) — `struct WeekSection: Identifiable, Equatable { id, title: String, inspections: [Inspection] }`
- [`Inspection.swift`](../../../../../../Domain/Entities/Inspection.swift) — `struct Inspection: Identifiable, Equatable, Hashable, Codable`
- [`InspectionStatus.swift`](../../../../../../Domain/Entities/InspectionStatus.swift) — `enum InspectionStatus { plan, inProgress, error, completed, cancelled }`

### Data

- [`InspectionStorageServiceType`](../../../../../../Data/Services/InspectionStorageService.swift) — Protocol: `getAllInspections()`, `deleteInspection(by:)`, `getCompletedInspections()`
- [`FirestoreInspectionStorageService.swift`](../../../../../../Data/Services/FirestoreInspectionStorageService.swift) — Firestore-backed implementation
- [`InspectionStorageService.swift`](../../../../../../Data/Services/InspectionStorageService.swift) — Local cache implementation

---

## API Contracts

> Không có REST API trực tiếp — dữ liệu được đọc/ghi qua `InspectionStorageServiceType` (Firestore).

| Operation | Method | Description |
|-----------|--------|-------------|
| Load inspections | `storageService.getAllInspections()` | Sync read từ local cache |
| Delete inspection | `storageService.deleteInspection(by: id)` | Async write đến Firestore + local cache |

---

## UI Components & Design System

| Component | Usage | File |
|-----------|-------|------|
| `LMSSectionContainer` | Wrapper cho info rows trong bottom sheet | `InspectionDetailBottomSheet.swift:170` |
| `LMSInfoRow` | Từng dòng label-value trong bottom sheet | `InspectionDetailBottomSheet.swift:172–176` |
| `LMSLabel` | Text component trong hero và badge | `InspectionDetailBottomSheet.swift:119, 152` |
| `LMSButton(.destructive)` | Nút xoá trong action bar | `InspectionDetailBottomSheet.swift:225` |
| `LMSInspectionCardSkeleton` | Skeleton loading placeholder | `ReportLMSHomeView.swift:81` |
| `LMSColor.primary` | Brand blue — gradient hero, badge dot | Toàn bộ feature |
| `CardPressStyle` | Tap scale (0.97) trên card button | `ReportLMSHomeView.swift:188` |

### Dark Mode

| Element | Light | Dark |
|---------|-------|------|
| Hero gradient | `primary → primary 72%` | `primary 82% → primary 55%` |
| Hero shadow opacity | `0.35` | `0.18` |
| Hero noise overlay | `LMSColor.white 6%` | `LMSColor.black 12%` |
| Info section border | `LMSColor.black 4%` | `LMSColor.white 7%` |
| Share button bg | `.ultraThinMaterial` (auto-adaptive) | `.ultraThinMaterial` |

---

## Animation & UX

| Interaction | Behaviour |
|-------------|-----------|
| Card tap | `CardPressStyle` → `scaleEffect(0.97)`, spring `response: 0.2` |
| Bottom sheet open | Progressive reveal: header → info → actions, 150ms stagger, `.easeOut(0.4s)` |
| Delete button tap | `@GestureState` scale `0.96` via `simultaneousGesture` |
| List entrance | `.opacity + .offset(y: 16)`, stagger `index * 80ms`, capped at index 6 |
| Sheet presentation | `.presentationDetents([.medium, .large])`, drag indicator visible |

---

## Edge Cases & Error Handling

| Scenario | Expected Behaviour | Handled? |
|----------|--------------------|----------|
| Empty completed list | Empty state: `checkmark.seal` icon + message | ✅ |
| Load error | Error state + Retry button | ✅ |
| Delete failure | `errorMessage = "Xoá thất bại. Vui lòng thử lại."` | ✅ |
| Inspection number empty | Hiển thị `"---"` thay vì chuỗi rỗng | ✅ |
| Cache not ready | Skeleton hiển thị khi `isLoading && weeklyInspections.isEmpty` | ✅ |
| Pull-to-refresh | `.refreshable` modifier gọi lại `loadInspections()` | ✅ |
| Background cache update | Subscribe `inspectionCacheDidLoad` + `inspectionDidUpdate` notification | ✅ |

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `ReportViewModel` | Not available — add manually | ❌ Missing |
| `GroupInspectionsByWeekUseCase` | Not available — add manually | ❌ Missing |
| `InspectionDetailBottomSheet` | Not available — add manually | ❌ Missing |

**Suggested test cases:**
- [ ] `loadInspections()`: chỉ trả về inspection có `status == .completed`
- [ ] `loadInspections()`: gọi `GroupInspectionsByWeekUseCase.execute()` với kết quả filter
- [ ] `deleteInspection()`: gọi `storageService.deleteInspection(by: id)` với đúng id
- [ ] `deleteInspection()`: gọi `loadInspections()` sau khi delete thành công
- [ ] `deleteInspection()` failure: `errorMessage` được set đúng
- [ ] `GroupInspectionsByWeekUseCase`: inspections trong cùng tuần → cùng 1 section
- [ ] `GroupInspectionsByWeekUseCase`: inspections khác tuần → sections khác nhau

---

## Notes

- `ReportLMSHomeView` không còn dùng `onInspectionTapped` callback (đã xoá). Navigation thay bằng `@State selectedInspection: Inspection?` + `.sheet(item:)`.
- `InspectionDetailBottomSheet` là pure View — không có ViewModel riêng. Callback `onDelete` được inject từ `ReportLMSHomeView`.
- `InspectionStatus.badgeColor` được định nghĩa trong `private extension` bên trong `InspectionDetailBottomSheet.swift` (không phải trong `InspectionStatus.swift`).
- DI container (`Container.shared.resolve(ReportViewModel.self)`) dùng `guard let` + `fatalError` thay vì force unwrap `!`.

---

*Generated by `/ct-ai-document` on 2026-06-06*
