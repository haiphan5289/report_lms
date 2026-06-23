# Progress Home — Feature Document

> **Jira:** — | **Branch:** `feat/login` | **Generated:** 2026-06-23 | **Last updated:** 2026-06-23

> Jira/Confluence data not fetched — no Jira key found in branch name.

---

## PRD Summary

> Displays the inspector's in-progress inspections, grouped by calendar week, as a scrollable card list within the Home screen's "Progress" tab.

- **Goal:** Give inspectors a real-time view of all active (in-progress) inspections they need to complete, grouped by the week they were created.
- **User story:** As an inspector, I want to see my in-progress inspections sorted by week so that I can track my current workload and quickly navigate to any job.
- **Acceptance criteria:**
  - [ ] Only inspections with status `.inProgress` are shown
  - [ ] Inspections are grouped into week sections (this week / last week / N weeks ago), sorted newest-first
  - [ ] A skeleton loading state appears while the cache loads
  - [ ] An empty state with an animated icon appears when there are no in-progress inspections
  - [ ] An error state with a retry button appears on failure
  - [ ] Pull-to-refresh triggers a full reload
  - [ ] Each card supports swipe/context actions: Delete and Reset
  - [ ] List items animate in with a staggered entrance (up to 6 items delayed by 80 ms each)
  - [ ] The view reacts to `inspectionCacheDidLoad` and `inspectionDidUpdate` notifications automatically

---

## Business Rules

> Key business constraints and logic that developers must respect.

| Rule | Description |
|------|-------------|
| Status filter | Only `.inProgress` inspections are shown; `.plan` and `.completed` are excluded |
| Reset clears photos only | Resetting an inspection nullifies all `photoURL` and `imageURLs` on every field but keeps all other metadata intact |
| Delete is permanent | `deleteInspection` removes the record from the backing store; there is no soft-delete or undo |
| Week grouping is relative to `Date()` at load time | Week buckets (this / last / N weeks ago) are recalculated every time `loadInspections()` is called |
| Notifications drive reactivity | `inspectionCacheDidLoad` triggers the first load; `inspectionDidUpdate` triggers subsequent reloads — no polling |

---

## Architecture Overview

> SwiftUI MVVM with Clean Architecture layers.

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`ProgressView.swift`](../ProgressView.swift) | SwiftUI view — renders skeleton, error, empty, and list states; owns stagger animation |
| Presentation | [`ProgressViewModel.swift`](../ProgressViewModel.swift) | `@MainActor ObservableObject` — owns published state, orchestrates load / delete / reset |
| Domain | [`GroupInspectionsByWeekUseCase.swift`](../../../../../Domain/UseCases/GroupInspectionsByWeekUseCase.swift) | Pure function — groups and titles `[Inspection]` → `[WeekSection]` by ISO week |
| Domain (Entity) | [`WeekSection.swift`](../../../../../Domain/Entities/WeekSection.swift) | Value type grouping inspections for one calendar week |
| Domain (Protocol) | [`InspectionStorageServiceType.swift`](../../../../../Domain/Repositories/InspectionStorageServiceType.swift) | Abstraction over local + Firestore inspection storage |
| Presentation (Shared) | [`InspectionCardView.swift`](../../../../Components/InspectionCardView.swift) | Reusable card rendered for each inspection |
| Presentation (Shared) | [`LMSSkeleton.swift`](../../../../../Common/Components/Loading/LMSSkeleton.swift) | `LMSInspectionCardSkeleton` shimmer used during loading |

### Data Flow

```
User pulls to refresh / view appears
  → LMSProgressView (.task / .refreshable)
  → ProgressViewModel.loadInspections()
  → InspectionStorageServiceType.getAllInspections()  [in-memory cache]
  → filter { $0.status == .inProgress }
  → GroupInspectionsByWeekUseCase.execute([Inspection])
  ← [WeekSection]  assigned to @Published weeklyInspections
  ← LMSProgressView re-renders (inspectionListView)
```

```
User taps "Delete" on card
  → InspectionCardView.onDelete closure
  → ProgressViewModel.deleteInspection(_:)
  → InspectionStorageServiceType.deleteInspection(by: id)
  → ProgressViewModel.loadInspections()  [reload]
```

```
User taps "Reset" on card
  → InspectionCardView.onReset closure
  → ProgressViewModel.resetInspection(_:)
  → clears all field.photoURL & field.imageURLs
  → InspectionStorageServiceType.updateInspection(_:)
  → ProgressViewModel.loadInspections()  [reload]
```

```mermaid
graph TD
    A[LMSProgressView] -->|.task / .refreshable| B[ProgressViewModel]
    B -->|getAllInspections| C[InspectionStorageServiceType]
    C -->|[Inspection]| B
    B -->|execute| D[GroupInspectionsByWeekUseCase]
    D -->|[WeekSection]| B
    B -->|@Published weeklyInspections| A
    N[NotificationCenter<br/>inspectionCacheDidLoad<br/>inspectionDidUpdate] -->|sink| B
```

---

## Key Files & Symbols

> All Swift files for this feature.

### Presentation
- [`ProgressView.swift`](../ProgressView.swift) — `LMSProgressView: View`; four content states (skeleton / error / empty / list); staggered card animation; section header per `WeekSection`
- [`ProgressViewModel.swift`](../ProgressViewModel.swift) — `ProgressViewModel: ObservableObject`; `loadInspections()`, `deleteInspection(_:)`, `resetInspection(_:)`, `visibleInspections(for:)`

### Domain
- [`GroupInspectionsByWeekUseCase.swift`](../../../../../Domain/UseCases/GroupInspectionsByWeekUseCase.swift) — `execute([Inspection]) -> [WeekSection]`; classifies into `this_week`, `last_week`, `N_weeks_ago`; sorted newest-first
- [`WeekSection.swift`](../../../../../Domain/Entities/WeekSection.swift) — `struct WeekSection: Identifiable, Equatable`; properties: `id`, `title`, `weekStartDate`, `inspections: [Inspection]`

### Protocol
- [`InspectionStorageServiceType.swift`](../../../../../Domain/Repositories/InspectionStorageServiceType.swift) — `protocol InspectionStorageServiceType`; `getAllInspections()`, `deleteInspection(by:)`, `updateInspection(_:)`

### Shared Components
- [`InspectionCardView.swift`](../../../../Components/InspectionCardView.swift) — renders a single inspection row; exposes `onDelete` and `onReset` closures
- [`LMSSkeleton.swift`](../../../../../Common/Components/Loading/LMSSkeleton.swift) — provides `LMSInspectionCardSkeleton` shimmer placeholder

### Design Tokens Used
| Token | Value |
|-------|-------|
| `LMSColor.background` | `Color(.systemBackground)` |
| `LMSColor.Shadow.medium` | `LMSColor.shadowStrong` |
| `LMSColor.Border.subtle` | `LMSColor.secondaryBorder` (secondary color @ 20% opacity) |

---

## API Contracts

> No new API targets detected in this feature — the Progress screen is served entirely from the local in-memory cache (`InspectionStorageServiceType`). Network I/O is handled upstream by the Firestore sync layer.

---

## Edge Cases & Error Handling

| Scenario | Expected Behavior | Handled? |
|----------|------------------|----------|
| Cache not yet loaded on appear | Skeleton shown (`isLoading = true`) until first `loadInspections()` completes | ✅ |
| No in-progress inspections | Empty state with floating clock icon and localised subtitle | ✅ |
| Storage read throws | `errorMessage` populated; error view with retry button shown | ✅ (error view) — `loadInspections()` currently doesn't `throw`; filter is synchronous; errors surfaced only from delete/reset |
| Delete fails (storage error) | `errorMessage` set with `error.localizedDescription` | ✅ |
| Reset fails (storage error) | `errorMessage` set with `error.localizedDescription` | ✅ |
| inspectionCacheDidLoad fires before ViewModel init | ViewModel checks `isCacheLoaded` at init and calls load immediately | Not available — add manually (verify in Container.swift DI setup) |
| Rapid pull-to-refresh | Concurrent `loadInspections()` calls — `isLoading` toggled by the last call to finish | ⚠️ No debounce; may cause double-loads in fast refresh scenarios |

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `ProgressViewModel` | — | ❌ Missing |
| `GroupInspectionsByWeekUseCase` | — | ❌ Missing |

**Suggested test cases:**
- [ ] `loadInspections()` filters out `.plan` and `.completed` inspections
- [ ] `loadInspections()` with empty storage → `weeklyInspections` is empty
- [ ] `deleteInspection` removes the item and calls `loadInspections`
- [ ] `resetInspection` clears `photoURL` and `imageURLs` on all fields, preserves other metadata
- [ ] `GroupInspectionsByWeekUseCase.execute` with inspections from this week, last week, 3 weeks ago → correct buckets and titles
- [ ] `GroupInspectionsByWeekUseCase.execute` with empty array → returns `[]`
- [ ] Notifications `inspectionCacheDidLoad` / `inspectionDidUpdate` trigger `loadInspections`

---

## Bug Fixes

### BUG-PROGRESS-001 — Double card / double shadow on inspection cards (Fixed 2026-06-23)

**Symptom:** Each inspection card displayed a double shadow and double border — the card appeared visually doubled / heavier than designed.

**Root cause:** `ProgressView` wrapped `InspectionCardView` (which already has `.cornerRadius(8)` + `.shadow`) in an additional `.background(RoundedRectangle(cornerRadius: 12))` with its own shadow and border, plus applied `.padding(.horizontal, 16)` twice.

**Before (broken):**
```swift
.buttonStyle(.plain)
.padding(.horizontal, 16)          // ← first padding
.background(
    RoundedRectangle(cornerRadius: 12)
        .fill(LMSColor.background)
        .shadow(color: LMSColor.Shadow.medium, radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LMSColor.Border.subtle, lineWidth: 1)
        )
)
.padding(.horizontal, 16)          // ← second padding
.padding(.vertical, 4)
```

**After (fixed):**
```swift
.buttonStyle(.plain)
.padding(.horizontal, 16)
.padding(.vertical, 4)
```

**File:** [`ProgressView.swift`](../ProgressView.swift) — `inspectionListView`, inner `ForEach` block.

---

## Notes

- `ProgressViewModel` uses `nonisolated init` + an inner `Task { @MainActor in }` to subscribe to notifications, avoiding an actor-isolation error on `cancellables`. This is an intentional concurrency pattern.
- Week titles are Vietnamese-language strings hardcoded inside `GroupInspectionsByWeekUseCase.localizedWeekTitle(_:count:)` — these are **not** wired to `LocalizationManager`. If multilingual support is needed, the use case must be updated.
- The stagger animation caps at index 6 (`min(index, 6)`) to avoid excessively long delays on large lists.
- `visibleInspections(for:)` currently returns all inspections in the section with no pagination or truncation limit — could be a performance concern for very large week groups.
- Card styling (shadow, corner radius, border) is owned entirely by `InspectionCardView` — do **not** add a second background/shadow wrapper at the call site in `ProgressView`.

---

*Generated by `/ct-ai-document` on 2026-06-23 | Updated 2026-06-23*
