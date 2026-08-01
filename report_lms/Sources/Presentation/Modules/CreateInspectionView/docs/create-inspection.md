# Create Inspection — Feature Document

> **Jira:** — | **Branch:** `feat/login` | **Generated:** 2026-07-31

---

## PRD Summary

> Jira/Confluence data not fetched — no ticket key found in branch name `feat/login` and no `JIRA`/`CONFLUENCE` override provided. Summary below is derived from code + the module's existing `README.md`.

- **Goal:** Let a user create a new inspection record (product info, inspection type/form, sampling method, quantity, factory, production unit) and persist it as a draft (`status == .plan`).
- **User story:** As an inspector, I want to fill in a product/order form and submit it so that a new inspection is created and I can proceed to fill in its checklist sections.
- **Acceptance criteria:**
  - [ ] Not available — add manually (no Jira ticket linked to this branch)

---

## Business Rules

| Rule | Description |
|------|-------------|
| Required fields | All 9 fields (`productName`, `productCode`, `orderCode`, `inspectionForm`, `inspectionType`, `samplingMethod`, `quantity`, `factory`, `productionUnit`) are validated as non-empty via `validateField` — [`CreateInspectionViewModel.swift:306`](../CreateInspectionViewModel.swift#L306) |
| New inspection status | Created inspections always start as `status: .plan` — [`CreateInspectionViewModel.swift:188`](../CreateInspectionViewModel.swift#L188) |
| Empty sections template | New inspections get `Inspection.emptyTemplate()` as their `sections` — checklist items are filled in later, not at creation time |
| Free-text fields | `factory` (Nhà máy) and `productionUnit` (Đơn vị sản xuất) are plain text inputs (`ProductInfoInputType.required`), not dropdowns — [`CreateInspectionViewModel.swift:264-271`](../CreateInspectionViewModel.swift#L264-L271) |
| Dropdown fields | `inspectionForm`, `inspectionType`, `samplingMethod` use `SearchableListView` with hardcoded option lists defined inline in the View — [`CreateInspectionView.swift:155-262`](../CreateInspectionView.swift#L155-L262) |
| Company scoping | `companyId` is resolved once at init from `UserManager.companyId` (defaults to `""` if unavailable) — [`CreateInspectionView.swift:33`](../CreateInspectionView.swift#L33) |

---

## Architecture Overview

> SwiftUI + MVVM. `@MainActor ObservableObject` ViewModel. **`CreateInspectionUseCase` is injected but never invoked** — see [Notes](#notes).

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`CreateInspectionView.swift`](../CreateInspectionView.swift) | Form screen: input fields, dropdown sheet, submit button, entrance animation |
| Presentation | [`CreateInspectionViewModel.swift`](../CreateInspectionViewModel.swift) | `@Published` form fields + per-field errors, `createInspection()`, `resetForm()` |
| Domain | [`CreateInspectionUseCase.swift`](../../../../Domain/UseCases/CreateInspectionUseCase.swift) | Builds an `Inspection` from `InspectionCreationParameters` and calls `InspectionRepositoryType.createInspection`. **Injected into the ViewModel but not called anywhere in this feature** |
| Domain | [`InspectionStorageServiceType.swift`](../../../../Domain/Repositories/InspectionStorageServiceType.swift) | Protocol — `saveInspection(_:) async throws` is the method this feature actually uses |
| Domain | [`Inspection.swift`](../../../../Domain/Entities/Inspection.swift) | Entity persisted on submit |
| Data | [`FirestoreInspectionStorageService.swift`](../../../../Data/Services/FirestoreInspectionStorageService.swift) / [`InspectionStorageService.swift`](../../../../Data/Services/InspectionStorageService.swift) | Concrete `InspectionStorageServiceType` implementations (Firestore + local cache) |

### Data Flow

```
User điền form
  → @Published field trên CreateInspectionViewModel cập nhật
  → didSet chạy validateField() ngay → set <field>Error

User tap "Tạo kiểm tra"
  → CreateInspectionView.createButtonSection action
  → viewModel.createInspection() (async)
  → validateInputs() — chỉ kiểm tra fieldErrors.allSatisfy { $0 == nil }
  → build Inspection(status: .plan, sections: Inspection.emptyTemplate(), ...)
  → storageService.saveInspection(inspection)   ← CreateInspectionUseCase KHÔNG được gọi
  ← createdInspection = inspection [@Published]

CreateInspectionView.onChange(of: viewModel.createdInspection)
  → onInspectionCreated?(inspection) callback
  → dismiss()

User tap dropdown field (inspectionForm / inspectionType / samplingMethod)
  → currentDropdownField set, showingSearchableList = true
  → .sheet trình SearchableListView(viewModel: SearchableListViewModel(items:))
  → chọn item → handleDropdownSelection → viewModel.<field> = selectedItem.name
```

---

## Key Files & Symbols

### Presentation

- [`CreateInspectionView.swift`](../CreateInspectionView.swift) — `@MainActor struct CreateInspectionView: View`. Local `@State`: `showingSearchableList`, `currentDropdownField: InputFieldType?`, `formVisible`, `buttonVisible`. Optional callback: `onInspectionCreated: ((Inspection) -> Void)?`. Dropdown data (`createInspectionTypeData()`, `createInspectionFormData()`, `createSamplingMethodData()`) is hardcoded inline, not fetched from any service.
- [`CreateInspectionViewModel.swift`](../CreateInspectionViewModel.swift) — `@MainActor final class CreateInspectionViewModel: ObservableObject`. 9 `@Published` form fields + 9 matching `<field>Error: String?` properties. `fieldErrors: [String?]` computed var. Methods: `createInspection() async`, `resetForm()`. Private: `generateInspectionNumber() -> String`, `validateInputs() -> Bool`.

### Domain

- [`InputFieldType`](../CreateInspectionViewModel.swift#L5) — `enum InputFieldType: CaseIterable` with 9 cases; extension provides `.title`, `.inputType`, `.binding(for:)`, `.errorMessage(for:)`.
- [`InputField`](../CreateInspectionViewModel.swift#L18) — `class` (not `struct`) holding `title`, `placeholder`, `type: ProductInfoInputType`, `text: Binding<String>`.
- [`CreateInspectionUseCase.swift`](../../../../Domain/UseCases/CreateInspectionUseCase.swift) — `final class CreateInspectionUseCase { func execute(parameters: InspectionCreationParameters) async throws -> Inspection }`. Depends on `InspectionRepositoryType`, not `InspectionStorageServiceType`. **Dead dependency in this feature** — see [Notes](#notes).
- [`Inspection.swift`](../../../../Domain/Entities/Inspection.swift) — entity has no `inspectionForm` or `samplingMethod` field; only `inspectionType` is stored.

### Data / Shared Components

- [`InspectionStorageServiceType.swift`](../../../../Domain/Repositories/InspectionStorageServiceType.swift) — `func saveInspection(_ inspection: Inspection) async throws`
- [`LMSButton.swift`](../../../../Common/Components/Buttons/LMSButton.swift) — `LMSButton(_:variant:isFullWidth:isLoading:action:)`, used with `variant: .primary`
- [`ProductInfoInput.swift`](../../../../Common/Components/ProductInfoInput.swift) — `ProductInfoInput(title:text:type:onDropdownTap:errorMessage:)`; `ProductInfoInputType` cases `.normal/.required/.dropdown/.quantity`
- [`QuantityInputView.swift`](../../../../Common/Components/QuantityInputView.swift) — `QuantityInputView(labelText:placeholder:text:)`. Has **no error-message parameter**.
- [`SearchableListView.swift`](../../../../Common/Components/SearchableList/SearchableListView.swift) / [`SearchableListViewModel.swift`](../../../../Common/Components/SearchableList/SearchableListViewModel.swift) — `SearchableListView(viewModel:onItemSelected:)`, `SearchableListViewModel(items: ListItemProtocol?)`
- [`ListItemProtocol.swift`](../../../../Domain/Entities/ListItemProtocol.swift) — `ListItemProtocol { title: String?, datas: [ListDataItem] }`, `ListDataItem(id: Int, name: String)`

---

## API Contracts

> No REST API targets in this feature. Data is written via `InspectionStorageServiceType` (Firestore-backed).

| Operation | Method | Notes |
|-----------|--------|-------|
| Create | `storageService.saveInspection(_ inspection: Inspection) async throws` | Writes the full `Inspection` document to Firestore + updates local cache |

---

## Edge Cases & Error Handling

| Scenario | Expected Behavior | Handled? |
|----------|--------------------|----------|
| Field left untouched (never edited) | `validateInputs()` only checks `fieldErrors.allSatisfy { $0 == nil }`; an untouched field's error is `nil` by default → form can be submitted with empty fields | ❌ Documented as a known bug in the module `README.md` |
| `storageService.saveInspection` throws | `errorMessage` is set on the ViewModel, `isLoading` reset to `false` | ❌ `errorMessage` is never read or displayed anywhere in `CreateInspectionView.swift` — user sees no feedback on failure |
| Quantity field non-numeric | `Int(quantity) ?? 0` silently defaults `orderQuantity` to `0` | ❌ No numeric validation, no error shown |
| Quantity field validation error | `quantityError` is computed via `didSet` | ❌ Never displayed — `QuantityInputView` has no error-message slot, and `inputFieldsSection` doesn't pass `fieldErrors` into it |
| `createdInspection` is `nil` after save attempt | Logs `"🔴 ... newInspection is nil - not dismissing"` | ✅ (debug-only; no user-facing message) |
| Dropdown title doesn't match any known case | `getFieldType(for:)` falls back to `.inspectionType` | ⚠️ Silent fallback, not surfaced as an error |
| Inspection number format | `generateInspectionNumber()` uses `dateFormat = "yyyyMMHHmmss"` — missing `dd` (day) | ❌ Known bug per module `README.md`; two inspections created on different days in the same hour/minute/second can collide |

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `CreateInspectionViewModel` | Not available — add manually | ❌ Missing |
| `CreateInspectionUseCase` | Not available — add manually | ❌ Missing |

**Suggested test cases:**
- [ ] `createInspection()` with all fields valid → `storageService.saveInspection` called with expected `Inspection`, `createdInspection` set
- [ ] `createInspection()` with an untouched required field → currently succeeds (regression test for the known validation bug — should fail once fixed)
- [ ] `createInspection()` when `storageService.saveInspection` throws → `errorMessage` set, `isLoading` returns to `false`
- [ ] `generateInspectionNumber()` — verify format includes day (`dd`) once fixed
- [ ] `resetForm()` — all fields and errors cleared back to initial state

---

## Notes

- **`createInspectionUseCase` is a dead dependency.** `CreateInspectionViewModel` stores it (`CreateInspectionViewModel.swift:106`) and requires it in `init`, but `createInspection()` never calls `createInspectionUseCase.execute(...)` — it builds the `Inspection` inline and calls `storageService.saveInspection(inspection)` directly (`CreateInspectionViewModel.swift:174-197`). `CreateInspectionUseCase` builds a different (incompatible) `Inspection` via `InspectionRepositoryType`, which is a separate abstraction from `InspectionStorageServiceType` used everywhere else in the app.
- **`inspectionForm` and `samplingMethod` are collected but not persisted** — the `Inspection` entity has no fields for them; only `inspectionType` is passed into the entity initializer at `CreateInspectionViewModel.swift:174-194`. This matches the issue already flagged in the module `README.md`.
- Numerous debug `print(...)` statements remain in `createInspection()` (`CreateInspectionViewModel.swift:146-208`).
- `Container.shared.resolve(...)!` force-unwraps are used in `CreateInspectionView.init` (`CreateInspectionView.swift:31-33`) — a missing DI registration would crash at view construction instead of failing gracefully.
- `InputField` is declared as a `class` (`CreateInspectionViewModel.swift:18`) though it has no identity semantics that would require reference type behavior.
- `getFieldType(for:)` (`CreateInspectionView.swift:128`) maps a dropdown's display title string back to its `InputFieldType` — fragile if a title string changes without updating this switch.
- Dropdown option lists (`createInspectionTypeData()`, `createInspectionFormData()`, `createSamplingMethodData()`) are hardcoded directly in the View file rather than sourced from a service/config — any change to available checklist forms requires a code change and app release.

---

*Generated by `/ct-ai-document` on 2026-07-31*
