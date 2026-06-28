# Orders — Feature Document

> **Jira:** — | **Branch:** `feat/login` | **Generated:** 2026-06-25

---

## PRD Summary

> The Orders screen displays all inspection records assigned to the current user, with real-time filtering, full-text search, and quick access to order detail and PDF reports.

- **Goal:** Give inspectors a fast, scannable overview of their inspection queue with status-based filtering and search.
- **User story:** As an inspector, I want to see all my inspection orders in one place so that I can quickly find, filter, and act on them.
- **Acceptance criteria:**
  - [ ] List loads automatically on screen appear and refreshes on pull-to-refresh
  - [ ] Stats strip shows total, plan, in-progress, and completed counts
  - [ ] Filter chips filter the list by `InspectionStatus` (all, plan, inProgress, completed, error, cancelled)
  - [ ] Search bar filters across `inspectionNumber`, `companyName`, `productName`, `orderCode`, `factory`
  - [ ] Tapping a card opens `OrderDetailBottomSheet`
  - [ ] Delete confirmation sheet appears before deletion; rollback on failure
  - [ ] List auto-refreshes when `inspectionCacheDidLoad` or `inspectionDidUpdate` notification fires

---

## Business Rules

| Rule | Description |
|------|-------------|
| Sort order | `filteredInspections` is always sorted by `createdAt` DESC — newest first |
| Filter + Search compose | Status filter and search text are applied together (AND logic) |
| Stats count all statuses | `countAll` includes all statuses; `countCompleted` only `.completed` — errors and cancelled are excluded from `countCompleted` |
| Optimistic delete | `deleteInspection(id:)` removes the item from `inspections` immediately; rolls back on storage failure |
| Cascade delete | Deleting an inspection also deletes: all field photos + `photoURL` from Firebase Storage, `errorItems` subcollection (Firestore + Storage + disk), delivery queue tasks, and evicts `InspectionImageCacheActor` + `PendingUploadStore` |
| Storage delete is fire & forget | Steps 2 (Firestore doc) is awaited and can cause UI rollback on failure. Storage/errorItems deletion (steps 5–7) runs in a separate `Task` with `try?` — failures are silently dropped. Orphaned Storage files are possible if the network drops after Firestore succeeds. |
| Cache-first load | `loadOrders()` reads from `InspectionStorageServiceType.getAllInspections()` (local Firestore cache) — no direct network call |
| Auto-refresh on notification | Subscribes to `Notification.Name.inspectionCacheDidLoad` and `.inspectionDidUpdate` to reload without user action |
| PDF section in detail | Shows the most recently _sent_ delivery task only (`latestSentTask(for:)`); earlier tasks are not shown |
| PDF path guard | "View PDF" button is hidden when `task.pdfStoragePath == nil` — shows a "processing on server" message instead |

---

## Architecture Overview

> SwiftUI + MVVM with Combine. `@MainActor` ViewModel. No UseCase layer — ViewModel calls the storage service protocol directly.

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`OrdersView.swift`](../OrdersView.swift) | Main screen: stats strip, search, filter chips, order list, empty/error states |
| Presentation | [`OrderCardView`](../OrdersView.swift) | Card component (inline in OrdersView.swift) — left accent bar, 5 info rows, press gesture |
| Presentation | [`OrderDetailBottomSheet.swift`](../OrderDetailBottomSheet.swift) | Detail sheet with full inspection info + PDF delivery status + PDF download |
| Presentation | [`Components/FilterChip.swift`](../Components/FilterChip.swift) | Status filter button wrapping `LMSButton` |
| Presentation | [`Components/StatCard.swift`](../Components/StatCard.swift) | Summary count card using `LMSSectionContainer` + `LMSLabel` |
| Presentation | [`Components/StatusBadge.swift`](../Components/StatusBadge.swift) | Color-coded dot + label badge for `InspectionStatus` |
| Presentation | [`Components/InspectionStatus+Orders.swift`](../Components/InspectionStatus+Orders.swift) | `CaseIterable` + `accentColor` extension on `InspectionStatus` |
| ViewModel | [`OrdersViewModel.swift`](../OrdersViewModel.swift) | `@MainActor ObservableObject` — filtering, search, stats computed vars, load/delete |
| Domain | [`Sources/Domain/Entities/Inspection.swift`](../../../../Domain/Entities/Inspection.swift) | `Inspection` model with all display fields |
| Domain | [`Sources/Domain/Entities/ReportDeliveryTask.swift`](../../../../Domain/Entities/ReportDeliveryTask.swift) | `ReportDeliveryTask` — delivery status, PDF path, sent-at date, recipient emails |
| Domain | [`Sources/Domain/Repositories/InspectionStorageServiceType.swift`](../../../../Domain/Repositories/InspectionStorageServiceType.swift) | Protocol abstracted by ViewModel for testability |
| Data | [`Sources/Data/Services/FirestoreInspectionStorageService.swift`](../../../../Data/Services/FirestoreInspectionStorageService.swift) | Live implementation of `InspectionStorageServiceType` |
| Data | [`Sources/Data/Services/ReportDeliveryQueueService.swift`](../../../../Data/Services/ReportDeliveryQueueService.swift) | `latestSentTask(for:)` — fetches last sent PDF task |
| Data | [`Sources/Data/Services/FirebaseStorageService.swift`](../../../../Data/Services/FirebaseStorageService.swift) | `downloadData(fromPath:)` — downloads PDF binary from Firebase Storage |

### Data Flow

```
Screen appear / pull-to-refresh
  → OrdersView (.task / .refreshable)
  → OrdersViewModel.loadOrders()
  → InspectionStorageServiceType.getAllInspections()   ← local Firestore cache
  ← OrdersViewModel.inspections [@Published]
  ← OrdersView re-renders (filteredInspections computed)

User types in search / taps filter chip
  → OrdersViewModel.searchText / selectedStatus [@Published]
  ← filteredInspections recomputed (Combine @Published chain)
  ← OrdersView orderList re-renders

Notification (inspectionCacheDidLoad / inspectionDidUpdate)
  → NotificationCenter publisher in OrdersViewModel.init
  → loadOrders() called automatically

User taps card
  → OrdersView: inspectionToDetail = inspection
  → .sheet(item: $inspectionToDetail) presents OrderDetailBottomSheet
  → OrderDetailBottomSheet.task: loadDeliveryTask() + progressive animation

User requests PDF
  → OrderDetailBottomSheet.downloadAndShowPDF(task:)
  → FirebaseStorageService.downloadData(fromPath:)
  ← pdfData set → PDFPreviewView presented

User taps delete
  → OrdersView: inspectionToDelete = inspection
  → DeleteConfirmationView sheet
  → viewModel.deleteInspection(id:)
  → Optimistic: inspections.removeAll { $0.id == id }
  → InspectionStorageServiceType.deleteInspection(by:)
  ← On error: inspections = backup (rollback) + errorMessage set
```

---

## Key Files & Symbols

### Presentation

- [`OrdersView.swift`](../OrdersView.swift) — Root view. Manages `inspectionToDetail` and `inspectionToDelete` local state for sheet presentation. `@StateObject OrdersViewModel` resolved from DI container.
- [`OrderDetailBottomSheet.swift`](../OrderDetailBottomSheet.swift) — Progressive-reveal bottom sheet. Resolves `ReportDeliveryQueueService` and `FirebaseStorageService` directly from `Container.shared`.
- [`Components/FilterChip.swift`](../Components/FilterChip.swift) — `FilterChip(label:isSelected:action:)` — thin wrapper around `LMSButton`.
- [`Components/StatCard.swift`](../Components/StatCard.swift) — `StatCard(value:label:color:)` — count + label inside `LMSSectionContainer`.
- [`Components/StatusBadge.swift`](../Components/StatusBadge.swift) — `StatusBadge(status:)` — dot + label badge colored by `status.accentColor`.
- [`Components/InspectionStatus+Orders.swift`](../Components/InspectionStatus+Orders.swift) — Adds `CaseIterable` conformance and `accentColor: Color` to `InspectionStatus`.

### ViewModel

- [`OrdersViewModel.swift`](../OrdersViewModel.swift) — Key computed properties:
  - `filteredInspections: [Inspection]` — applies `selectedStatus` filter then `searchText` full-text, sorted by `createdAt` DESC
  - `countAll / countPlan / countInProgress / countCompleted: Int`
  - `loadOrders() async` — sets `isLoading`, reads cache, clears error
  - `deleteInspection(id:) async` — optimistic delete with rollback

### Domain / Data

- `InspectionStorageServiceType` — protocol at [`Sources/Domain/Repositories/InspectionStorageServiceType.swift`](../../../../Domain/Repositories/InspectionStorageServiceType.swift)
- `Inspection` — entity at [`Sources/Domain/Entities/Inspection.swift`](../../../../Domain/Entities/Inspection.swift)
- `ReportDeliveryTask` — entity at [`Sources/Domain/Entities/ReportDeliveryTask.swift`](../../../../Domain/Entities/ReportDeliveryTask.swift); fields used: `sentAt: Date?`, `recipientEmails: [String]`, `pdfStoragePath: String?`

---

## API Contracts

> No new API targets defined in this module. All data reads go through `InspectionStorageServiceType` (Firestore local cache). PDF download uses `FirebaseStorageService.downloadData(fromPath:)`.

| Method | Service | Signature | Notes |
|--------|---------|-----------|-------|
| Read | `InspectionStorageServiceType` | `getAllInspections() -> [Inspection]` | Synchronous cache read |
| Delete | `InspectionStorageServiceType` | `deleteInspection(by id: String) async throws` | Firestore write |
| Query | `ReportDeliveryQueueService` | `latestSentTask(for inspectionId: String) async throws -> ReportDeliveryTask?` | Returns nil when no PDF has been sent |
| Download | `FirebaseStorageService` | `downloadData(fromPath: String) async throws -> Data` | Downloads PDF binary |

---

## Edge Cases & Error Handling

| Scenario | Expected Behavior | Handled? |
|----------|------------------|----------|
| `isLoading && inspections.isEmpty` | Shows `LMSLoadingView` full-screen | ✅ |
| Load error + empty list | Shows error icon + message + retry button | ✅ |
| Load error + non-empty list | Silently discards error — list stays visible | ❌ `errorMessage` not surfaced when inspections non-empty |
| Search yields no results | Shows floating search icon + "Không tìm thấy" + clear filter button | ✅ |
| List is empty (no inspections) | Shows floating cart icon + "Không có đơn hàng" | ✅ |
| Delete fails (Firestore) | Rollback `inspections` array; sets `errorMessage` ("Không thể xóa đơn hàng") | ✅ |
| Storage delete fails silently | Field photos / error-item images remain in Firebase Storage (orphaned). No retry — `try?` discards the error. | ❌ No retry |
| PDF not yet sent | Shows "Chưa có báo cáo PDF nào được gửi" placeholder | ✅ |
| PDF `pdfStoragePath == nil` | Shows "PDF đang được xử lý trên server" (no download button) | ✅ |
| PDF download failure | Inline `downloadError` label below the "Xem PDF" button | ✅ |
| Delivery task load failure | `taskLoadError` label shown in PDF section | ✅ |
| `inspectionCacheDidLoad` fires while screen visible | Auto-reloads list via Combine publisher → `loadOrders()` | ✅ |

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `OrdersViewModel` | Not available — add manually | ❌ Missing |
| `InspectionStorageServiceType` (mock) | Not available — add manually | ❌ Missing |

**Suggested test cases:**
- [ ] `filteredInspections` — status filter alone, search alone, both combined, neither
- [ ] `filteredInspections` — sort order: newer item appears first
- [ ] `loadOrders()` — `isLoading` toggles correctly; `inspections` populated from mock storage
- [ ] `deleteInspection(id:)` — optimistic removal confirmed; rollback on mock throwing error
- [ ] `countPlan / countInProgress / countCompleted` — verify each filters correctly and excludes other statuses
- [ ] Notification `inspectionDidUpdate` triggers `loadOrders()` automatically

---

## Notes

- `OrdersViewModel` has no UseCase layer — it calls `InspectionStorageServiceType` directly. This is intentional for simplicity (read-only screen, no complex business logic beyond filtering).
- `OrderDetailBottomSheet` resolves `ReportDeliveryQueueService` and `FirebaseStorageService` from `Container.shared` at init time (not injected). This limits testability of the bottom sheet in isolation.
- `InspectionStatus.allCases` is defined in `InspectionStatus+Orders.swift` — the extension lives in the Orders module, not in the Domain layer. If a new status is added to `InspectionStatus`, this file must be updated.
- The delete error message is hardcoded in Vietnamese (`"Không thể xóa đơn hàng"`) and is not routed through `LocalizationManager`.
- Load errors when `inspections` is non-empty are silently ignored (see Edge Cases table) — the user sees stale data with no indication of the failure.

---

*Generated by `/ct-ai-document` on 2026-06-25*
