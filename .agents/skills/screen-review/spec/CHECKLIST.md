# Review Checklists

---

## § Feature — UI State Completeness

Score: 1 point per state found → /5

```
[ ] F1 · Loading state
      • ProgressView, LMSLoadingView, or LMSLoadingOverlay shown while async work runs
      • isSendingToServer / isGeneratingPDF / isLoading drives it
      • UI controls disabled during load (isDisabled modifier present)

[ ] F2 · Empty state
      • Shown when list/data is empty (not just hidden by if-else)
      • Contains icon + explanatory text
      • Optional: CTA to create/add

[ ] F3 · Error state
      • showErrorAlert or inline error view present
      • errorAlertMessage populated before toggling flag
      • Retry / dismiss action wired

[ ] F4 · Success / data state
      • Primary happy-path renders all expected data fields
      • No force-unwraps on displayed data (inspect ?, ??, guard let)
      • Nil or empty values shown as "---" or placeholder (not crash)

[ ] F5 · Edge cases
      • 0-count collections handled (empty list, no photos)
      • Very long strings don't break layout (lineLimit or fixedSize applied)
      • Async tasks cancelled on dismiss (Task stored + .cancel() called, or .task modifier used)
```

**Scoring:**
- 5/5 → Feature score ✅ COMPLETE
- 3–4/5 → Feature score ⚠️ NEEDS WORK
- 0–2/5 → Feature score ❌ INCOMPLETE

---

## § Code — Quality Dimensions (4 points each → /20)

### D1 · LMS Design System Adoption

Deductions from 4:
- `-2` per raw `Text(...)` where `LMSLabel` applies
- `-2` per raw `Button(...)` where `LMSButton` applies
- `-1` per plain `VStack`/`HStack` container where `LMSSectionContainer` is the right fit
- `-1` per `Divider()` without design intent (should be styled separator or removed)
- `+0` when LMSInfoRow, LMSLoadingView, LMSSectionContainer, LMSButton, LMSLabel are used correctly

**Verified LMS components:**
`LMSLabel`, `LMSButton`, `LMSSectionContainer`, `LMSInfoRow`, `LMSLoadingView`,
`LMSLoadingOverlay`, `StatusBadge`, `FilterChip`, `StatCard`, `MailComposerView`,
`PDFPreviewView`, `DeleteConfirmationView`, `SuccessConfirmationView`

**Do NOT flag as violations:**
- `Text(...)` inside a `Label { }` block (SwiftUI Label requires it)
- `Button(action: {}) { Image(...) }` for icon-only toolbar buttons
- `ForEach` / `List` row content bodies

---

### D2 · MVVM Compliance

Deductions from 4:
- `-2` Business logic directly in View `body` (API calls, data transformation, filtering)
- `-2` ViewModel properties mutated directly from View without `@Published`/`func`
- `-1` `@StateObject` created with inline `wrappedValue:` bypassing DI
- `-1` Navigation (`dismiss()`, sheet toggling) driven by side effects in `body` rather than ViewModel flag

**Good patterns:**
```swift
// ✅ ViewModel drives all state
@Published var isLoading = false
// ✅ View reacts
if viewModel.isLoading { LMSLoadingView() }
// ✅ Actions delegated
Button { Task { await viewModel.loadData() } }
```

**Bad patterns:**
```swift
// ❌ Business logic in body
var body: some View {
    let filtered = data.filter { $0.status == .active } // ← move to ViewModel
```

---

### D3 · Dark Mode Color Compliance

Deductions from 4:
- `-2` `LMSColor.white` used as **container background** (it's hardcoded `Color.white`)
- `-2` `Color.white` or `Color.black` used as container background
- `-1` `TextEditor` present without `.scrollContentBackground(.hidden)` (black bg in dark mode)
- `-1` Stroke/border using `LMSColor.secondary` instead of `Color(.systemGray4)`

**Adaptive replacements:**
| ❌ Hardcoded | ✅ Adaptive |
|---|---|
| `LMSColor.white` (as bg) | `Color(.systemBackground)` |
| `Color.white` | `Color(.systemBackground)` |
| `Color.black` | `Color(.label)` |
| `LMSColor.secondary` (stroke) | `Color(.systemGray4)` |

**LMSColor adaptive tokens (safe to use):**
`LMSColor.background`, `LMSColor.backgroundSecondary`, `LMSColor.backgroundGrouped`,
`LMSColor.textPrimary`, `LMSColor.textSecondary`, `LMSColor.primary`, `LMSColor.destructive`

**LMSColor non-adaptive (use carefully):**
`LMSColor.white` = `Color.white` (hardcoded — never use as container background)

---

### D4 · Motion & UX Polish

Deductions from 4:
- `-1` Screen has no entry animation (no `@State contentVisible` or `.onAppear` animation)
- `-1` Primary action button has no loading indicator (`isLoading` binding missing on LMSButton)
- `-1` List rows have no staggered entrance (all appear simultaneously, jarring)
- `-1` Destructive/important actions have no confirmation dialog (bare button → immediate action)

**Good patterns:**
```swift
// ✅ Entry animation
.task { withAnimation(.easeOut(duration: 0.35)) { contentVisible = true } }

// ✅ Loading button
LMSButton("Send", isLoading: $viewModel.isSending) { ... }

// ✅ Staggered list
.animation(.easeOut(duration: 0.35).delay(Double(index) * 0.08), value: listVisible)

// ✅ Destructive confirmation
.sheet(item: $itemToDelete) { DeleteConfirmationView(...) }
```

---

### D5 · SwiftUI Patterns

Deductions from 4:
- `-1` `@ObservedObject` used where `@StateObject` is correct (ownership rule)
- `-1` `@State` used for shared cross-view data that should be in ViewModel
- `-1` Multiple `Bool` flags that could be a single `enum` state
- `-1` `Task {}` called inside `body` without `.task {}` modifier or explicit cancellation

**Common state ownership rules:**
```swift
// ✅ Owns the object → @StateObject
@StateObject private var viewModel: FinalReportViewModel

// ✅ Receives from parent → @ObservedObject
@ObservedObject var viewModel: FinalReportViewModel

// ✅ From environment → @EnvironmentObject
@EnvironmentObject private var localizationManager: LocalizationManager

// ❌ Anti-pattern: @State for business data
@State private var inspections: [Inspection] = []  // ← belongs in ViewModel
```

---

## § Dark Mode — Spot-Check Rules

Run these rules in addition to D3 whenever FOCUS includes `dark-mode`:

1. **Container scan** — grep all `.background(...)` calls; flag any using `LMSColor.white` or `Color.white`
2. **TextEditor scan** — any `TextEditor` must have `.scrollContentBackground(.hidden)` immediately before `.background(...)`
3. **Stroke scan** — any `.stroke(LMSColor.secondary` → replace with `Color(.systemGray4)`
4. **Overlay text** — text on image overlays must use `.white` or `.black` explicitly (not adaptive, by design); these are NOT violations
5. **LMSSectionContainer default** — verify `backgroundColor` default is `Color(.systemBackground)` not `LMSColor.white` (check [LMSSectionContainer.swift](../../../Sources/Common/Components/Containers/LMSSectionContainer.swift))
