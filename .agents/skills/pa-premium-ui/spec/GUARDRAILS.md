# Anti-Patterns — Hard Stop List

These patterns are **strictly banned**. Replace whenever found.

## UI Components

| ❌ Banned | ✅ Replace with |
|---|---|
| `Button("Label") {}` shorthand | `Button("Label", action: { })` or `Button(action: { }, label: { })` |
| Raw `Text(...)` with `.font(.system(size:))` | `.cdsTextStyle(.headerSection / .bodySection / .caption)` |
| Raw `Color.blue`, `Color.red`, `Color(hex:)` | `LMSColor.*` or `theme.*.*` sub-protocol access |
| `cornerRadius(12)` raw value | `DS.BorderRadius.radiusCard.value()` |
| Two `Button` with `.cdsButtonStyle(.primary)` side by side | One `.primary` + one `.secondary` — never two filled primaries |
| Primary CTA floating mid-screen | `.safeAreaInset(edge: .bottom)` (Pattern 10) |
| Generic placeholder `"Nhập..."` / `"Tìm kiếm"` / `"Date"` | Format mask or searchable-dimensions hint (Pattern 11) |
| Force cast `as!` / force try `try!` / force unwrap `!` | `as?` + `guard`, `do/catch`, `guard let` |
| `@Environment(\.presentationMode)` | `@Environment(\.dismiss)` |
| Business logic in View `body` | Move to ViewModel |

## Spacing & Layout

| ❌ Banned | ✅ Replace with |
|---|---|
| `.padding(16)` raw value | `.padding(DS.Padding.paddingMedium)` |
| `.padding(.horizontal, 20)` raw | `.padding(.horizontal, DS.Padding.paddingLarge)` |
| `VStack(spacing: 12)` raw | `VStack(spacing: DS.Gap.gapSmall)` |
| `Spacer().frame(height: 8)` | `Spacer().frame(height: DS.Gap.gapxSmall)` |

## Loading & State

| ❌ Banned | ✅ Replace with |
|---|---|
| `ProgressView()` alone blocking screen | `CDSSkeleton` matching content shape |
| `LMSLoadingOverlay()` for entire list/grid | Per-section `CDSSkeleton` shimmer |
| Blank screen between state changes | `ZStack` + `.opacity` transition + `.animation(.easeInOut)` |
| `if isLoading { view } else { other }` with no animation | `ZStack` + `.transition(.opacity)` + `.animation(...)` |

## Animation

| ❌ Banned | ✅ Replace with |
|---|---|
| Content appears with no entrance animation | `.opacity` + `.offset` + `.onAppear` |
| `GestureDetector` that steals child taps | `simultaneousGesture` for scale feedback |
| `withAnimation` inside View `body` | `.animation(.., value:)` modifier |
| Infinite animation without condition | Only start in `.onAppear`, stop if view disappears |

## Colors (Dark Mode Safety)

| ❌ Banned | ✅ Replace with |
|---|---|
| `.background(Color.white)` hardcoded | `.background(Color(UIColor.systemBackground))` or theme token |
| `.foregroundColor(.black)` hardcoded | `LMSColor.text` or `theme.text.textPrimary` |
| Hardcoded `LMSColor.*` on `NavigationStack` toolbar | Let `NavigationStack` inherit from `.toolbarBackground` / `.toolbarColorScheme` |

## Code Quality

| ❌ Banned | ✅ Replace with |
|---|---|
| `print(...)` | `Logger(subsystem:, category:).debug/error(...)` |
| `DispatchQueue.main.async` in ViewModel | `@MainActor` on ViewModel or `await MainActor.run {}` |
| `@StateObject` created inline in `body` | `init()` or property declaration |
| `Task {}` inside `onAppear` without `[weak self]` check | Use `.task {}` modifier (auto-cancelled on disappear) |
