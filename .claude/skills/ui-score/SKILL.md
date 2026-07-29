---
name: ui-score
description: "Score SwiftUI code for report_lms across 5 dimensions: LMS Design System adoption, Color tokens, Spacing & layout consistency, Typography, and Performance/Code quality. Produces a scored report (0–50 pts) with grade A–F and actionable fix list. Use before PR or when you want a quick UI health check."
argument-hint: "[file path or module folder — e.g. Sources/Presentation/Modules/SignUp]"
model: sonnet
---

# report_lms — UI Score Skill

> **Anti-Hallucination:** Only flag violations you can see in the code. Never reference `LMS*` components that do not exist in `Sources/Common/`. Verified list is in the scoring rubric below. This is a SwiftUI project (report_lms) — do not apply Flutter/`App*`/CDS (Cho Tot) conventions here.

## Purpose

This skill audits SwiftUI files in report_lms and produces a **scored report** with:
- A numeric score per dimension (0–10)
- An overall score out of 50
- A letter grade (A–F)
- A prioritised fix list with file path and line number

> **UI Pipeline:** Run `/ui-score` before PR for LMS Design System token/component compliance. For visual quality and animation polish, also run `/pa-premium-ui <ScreenName>`. For a fuller feature + UX + code review, use `/screen-review`.

---

## Input Format

```
TARGET: [file path or module folder — e.g. Sources/Presentation/Modules/SignUp]
```

If no target is provided, ask the user for the path before proceeding.

---

## Execution Protocol

Follow these steps **in order**.

### Step 1 — Discover Files

Read the TARGET path. Collect all `.swift` files that contain UI code — i.e. anything declaring a `View`, `ViewModifier`, or `ButtonStyle`:
- Files under `Presentation/Modules/**/Views/` or `**/*View.swift`
- Files under `Common/Components/**`
- Skip `ViewModel.swift`, `UseCase.swift`, `Repository.swift`, `Service.swift`, `Entity.swift` files — those are not UI code (score `/screen-review` covers architecture/logic, not this skill).

List each discovered file before scoring.

### Step 2 — Read Files

Read every file discovered in Step 1. Do not skip any.

### Step 3 — Score Each Dimension

Apply the rubric below to ALL files combined. Tally violations across all files.

### Step 4 — Output Report

Produce the Final Score Report using the format at the bottom of this skill.

---

## Scoring Rubric

Each dimension starts at **10 points**. Deduct points for each violation found.

---

### D1 — LMS Design System Adoption (0–10)

Checks whether `LMS*` components (`Sources/Common/Components/`, `Sources/Common/Colors/`) are used wherever a verified equivalent exists.

**Verified LMS Design System components (these MUST be used):**

| Raw SwiftUI | Required LMS Replacement |
|---|---|
| `Text(...)` (any user-facing string) | `LMSLabel(_:style:color:alignment:)` |
| `Button(...)` styled ad hoc (custom background/cornerRadius/padding) | `LMSButton(_:variant:size:isFullWidth:isLoading:isDisabled:action:)` |
| `TextField(...)` / `SecureField(...)` | `LMSTextField(_:text:icon:size:validationState:helperText:isSecure:keyboardType:autocapitalization:maxLength:onCommit:)` |
| Bare `ProgressView()` as a full-screen/section loading state | `LMSLoadingView` or `LMSLoadingOverlay` |
| Ad-hoc shimmer/gray-box loading placeholder | `LMSSkeleton` / `LMSInspectionCardSkeleton` |
| Ad-hoc bottom toast/snackbar `VStack` | `LMSSnackbar` |
| Ad-hoc "Label: Value" row (`HStack { Text(...); Spacer(); Text(...) }`) | `LMSInfoRow` |
| Ad-hoc bordered/padded section wrapper | `LMSSectionContainer` |
| Ad-hoc upload/progress bar | `LMSUploadProgressBar` |

**Deductions:**
- `-2` per use of raw `Text(...)` for user-facing copy where `LMSLabel` would apply
- `-2` per use of a raw `Button(...)` with custom styling (background/cornerRadius/padding built inline) instead of `LMSButton`
- `-2` per use of raw `TextField`/`SecureField` instead of `LMSTextField`
- `-1` per bare `ProgressView()` used as a loading state instead of `LMSLoadingView`/`LMSLoadingOverlay`
- `-1` per ad-hoc empty/error state (`VStack { Image; Text; Text }` pattern) not matching the project's established empty-state pattern (see e.g. `ReportLMSHomeView.emptyStateView`)

**Acceptable (no deduction):**
- A custom `ButtonStyle` used deliberately for a one-off interaction (e.g. `SignUpChoiceButtonStyle`, `CardPressStyle`) — this is an established project pattern for press effects that `LMSButton` doesn't cover; only flag if it duplicates something `LMSButton` variants already provide (primary/secondary/tertiary/destructive/ghost).
- Native `NavigationLink`, `Toggle`, `Picker` — no LMS wrapper exists for these.

**Minimum score:** 0 (cannot go negative)

---

### D2 — Color Tokens (0–10)

Checks whether color values use `LMSColor.*` (and its nested `LMSColor.Button`/`LMSColor.Shadow`/`LMSColor.Border`) or `LMSTextColor` wherever a token exists.

**Deductions:**
- `-3` per hardcoded custom color: `Color(red:green:blue:)`, `Color(hex:)`, or any literal RGB/hex value
- `-2` per use of a raw semantic color that has a direct `LMSColor` equivalent — e.g. `.red`/`Color.red` for an error state instead of `LMSColor.destructive` / `LMSTextColor.error`, `.green` instead of `LMSColor.success`
- `-1` per repeated inline `Color.blue.opacity(0.1)`-style construction that duplicates an existing `LMSColor` token (e.g. `LMSColor.primaryLight`, `LMSColor.primaryBorder`) instead of reusing it
- `-1` per new custom shadow/border color literal instead of `LMSColor.Shadow.*` / `LMSColor.Border.*`

**Acceptable (no deduction) — these are the established convention in this codebase, including inside the LMS components themselves:**
- `Color(.systemBackground)`, `Color(.systemGray4)`, `.secondary`, `.primary`, `Color(.tertiaryLabel)` — iOS system adaptive colors used directly (this project does not route every system color through `LMSColor`; only flag when a more specific `LMSColor` token exists and was ignored)
- `.foregroundColor(.secondary)` / `.foregroundColor(.accentColor)` for de-emphasized text or standard interactive tint

---

### D3 — Spacing & Layout Consistency (0–10)

This project has **no shared spacing/radius token enum** — the established convention is a `private enum Layout` with named `static let` `CGFloat` constants scoped to each view (see `LoginView.Layout`, `ForgotPasswordView.Layout`). Checks whether that convention is followed and whether values are consistent with the rest of the codebase.

**Deductions:**
- `-2` per view with 3+ raw numeric literals used directly in `.padding(...)`, `VStack(spacing:)`, `HStack(spacing:)` instead of being pulled into a `private enum Layout` (or reusing an existing one)
- `-2` per `.cornerRadius(N)` / `RoundedRectangle(cornerRadius: N)` using a radius outside the codebase's established values (`8` for buttons/text fields/cards, `12` for section cards) without a stated reason
- `-1` per one-off magic number that duplicates a value already named in that same file's `Layout` enum (e.g. `.padding(.horizontal, 24)` used inline right next to `Layout.horizontalPadding = 24`)
- `-1` per inconsistent spacing scale within the same screen (e.g. mixing 6, 10, 14, 18 for similar-purpose gaps instead of the project's common values: 4, 8, 12, 16, 20, 24, 32)

**Acceptable (no deduction):**
- A `private enum Layout` with named constants, even if the file only has 1–2 spacing values — this is the target pattern, not a violation
- One-off framing values tied to a specific asset/icon size (e.g. `.frame(width: 64, height: 64)` for a hero icon)

---

### D4 — Typography (0–10)

Checks whether all text styling goes through `LMSLabel` + `LMSTextStyle`/`LMSTextColor` — never raw `Font`/`TextStyle` construction on a bare `Text`.

**Deductions:**
- `-3` per hardcoded `.font(.system(size: N, weight: .semibold))` (or similar raw `Font` literal) applied directly to a widget
- `-2` per raw `Text(...)` styled with `.font(...)`/`.foregroundColor(...)` manually instead of using `LMSLabel` with an `LMSTextStyle`/`LMSTextColor`
- `-1` per `.fontWeight(.bold)`/`.fontWeight(.semibold)` applied directly to a raw `Text` instead of picking the `LMSTextStyle` case whose `.weight` already matches
- `-1` per text color chosen ad hoc (`.foregroundColor(.gray)`, `.foregroundColor(Color(white: 0.4))`) instead of an `LMSTextColor` case

**Acceptable (no deduction):**
- `Text(...)` used purely as a layout primitive inside a custom component's own internal implementation (e.g. inside `LMSButton`'s `contentView`, inside `LMSTextField`'s helper text) — those ARE the design system, not a consumer of it. Only flag raw `Text` usage in *feature/screen* code, not inside `Common/Components/`.
- Monospaced/system fonts for a deliberately distinct visual (e.g. a join-code display in `.system(.largeTitle, design: .monospaced)`) — flag only if unexplained by the UI's intent.

**LMSTextStyle variants reference:**
`.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption`, `.caption2`

**LMSTextColor variants reference:**
`.primary`, `.secondary`, `.tertiary`, `.success`, `.warning`, `.error`, `.custom(Color)`

---

### D5 — Performance & Code Quality (0–10)

Checks SwiftUI/Swift-specific best practices relevant to this project's MVVM + Clean Architecture (Presentation → Domain → Data).

**Deductions:**
- `-2` per force unwrap (`!`) or force try (`try!`) in view/view-model code on a value that isn't guaranteed non-nil (e.g. `Container.shared.resolve(X.self)!` is an accepted DI convention in this codebase — do NOT flag that specific pattern; DO flag force-unwraps of user input, network responses, or optional model fields)
- `-2` per business logic (data transformation, date math, validation beyond a simple `.isEmpty` check) written inline inside a `View`'s `body` instead of the `ViewModel`
- `-2` per `View` `body`/`private var` exceeding ~80 lines without extraction into a subview or computed property
- `-1` per `print(...)` call in production code path (this project uses `OSLog`'s `Logger` — see `FirestoreInspectionStorageService` for the convention — or is at minimum pre-existing debug logging that should not be copied into new code)
- `-1` per `Task { ... }` performing a `@Published` property mutation after an `await` without being on `@MainActor` (either the enclosing method marked `@MainActor` or an explicit `await MainActor.run { ... }`)
- `-1` per new `ObservableObject`/`ViewModel` whose async mutating methods aren't `@MainActor`-annotated per-method (see `LoginViewModel.login()` for the established pattern — do NOT flag class-level `@MainActor` as required; flag its *absence* on methods that mutate `@Published` state after an await)

**Acceptable (no deduction):**
- `Container.shared.resolve(X.self)!` — this is the project's standard DI resolution pattern, used pervasively; only flag if the resolved type is genuinely unregistered (verify against `DI/Container.swift`)
- `#Preview` blocks constructing dependencies manually with force-unwraps — preview code is exempt from D5

---

## Grade Thresholds

| Score | Grade | Meaning |
|---|---|---|
| 46–50 | **A** | Production-ready. Minor polish only. |
| 38–45 | **B** | Good. A few issues to clean up before PR. |
| 28–37 | **C** | Needs work. Address warnings before merging. |
| 15–27 | **D** | Significant rework needed. Multiple systematic issues. |
| 0–14 | **F** | Critical violations. Do not merge. |

---

## Final Score Report Format

```markdown
# 🎨 UI Score Report — [Feature Name]
**Date**: [today]
**Target**: [path]
**Files reviewed**: [N files]

---

## Score Summary

| Dimension | Score | Issues Found |
|---|---|---|
| D1 · LMS Design System Adoption | N/10 | N violations |
| D2 · Color Tokens | N/10 | N violations |
| D3 · Spacing & Layout Consistency | N/10 | N violations |
| D4 · Typography | N/10 | N violations |
| D5 · Performance & Code Quality | N/10 | N violations |
| **Overall** | **N/50** | **Grade: [A/B/C/D/F]** |

---

## Verdict

[One sentence verdict: what the score means and what to prioritise]

---

## Issues by Dimension

### D1 · LMS Design System Adoption — N/10

- ❌ `[File.swift:line]` — `Text("Tạo công ty")` → use `LMSLabel("Tạo công ty", style: .title)`
- ❌ `[File.swift:line]` — ad-hoc styled `Button(...)` → use `LMSButton(...)`
- ✅ `LMSTextField` used correctly for all form fields in CreateCompanyView.swift
- ✅ `LMSButton` used for primary CTA in JoinCompanyView.swift

### D2 · Color Tokens — N/10

- ❌ `[File.swift:line]` — `Color.red` for an error label → use `LMSTextColor.error` / `LMSColor.destructive`
- ✅ `LMSColor.success` used correctly for the success icon

### D3 · Spacing & Layout Consistency — N/10

- ❌ `[File.swift:line]` — raw `.padding(.horizontal, 24)` repeated 3x without a `Layout` enum → extract `Layout.horizontalPadding`
- ✅ `Layout` enum present and used consistently in CreateCompanyView.swift

### D4 · Typography — N/10

- ❌ `[File.swift:line]` — `Text(...).font(.system(size: 14, weight: .semibold))` → use `LMSLabel(..., style: .subheadline)`
- ✅ Title uses `LMSLabel` with `.title` style

### D5 · Performance & Code Quality — N/10

- ❌ `[File.swift:line]` — `@Published var isSuccess` mutated after `await` inside a non-`@MainActor` method
- ✅ `Container.shared.resolve(...)!` used per established DI convention (not flagged)

---

## Prioritised Fix List

Fix these in order — highest impact first:

1. `[File.swift:line]` [D1-CRITICAL] Replace ad-hoc `Button` with `LMSButton`
2. `[File.swift:line]` [D1-CRITICAL] Replace raw `Text(...)` with `LMSLabel(...)`
3. `[File.swift:line]` [D2-HIGH] Replace `Color.red` with `LMSTextColor.error`
4. `[File.swift:line]` [D3-MEDIUM] Extract repeated padding literals into a `Layout` enum
5. `[File.swift:line]` [D5-LOW] Mark the async mutating method `@MainActor`
```

---

## Anti-Hallucination Checklist

Before outputting the report:
- [ ] Every `LMS*` component flagged as missing **actually exists** in `Sources/Common/Components/` or `Sources/Common/Colors/` — verified list: `LMSLabel`, `LMSButton`, `LMSTextField`, `LMSColor` (+ `.Button`/`.Shadow`/`.Border`), `LMSTextStyle`, `LMSTextColor`, `LMSSectionContainer`, `LMSInfoRow`, `LMSSkeleton`/`LMSInspectionCardSkeleton`, `LMSLoadingView`/`LMSLoadingOverlay`, `LMSSnackbar`, `LMSUploadProgressBar`
- [ ] Every file path and line number cited was read in Step 2
- [ ] No violations invented from assumptions — only from code actually seen
- [ ] Not confusing this project's `LMS*` components with Cho Tot's `CDS*`/`AppDesignSystem`/Flutter `App*` components from other projects/skills — this project has none of those
- [ ] Raw `Text`/`Color`/`Font` usage *inside* `Sources/Common/Components/` itself is NOT flagged — that's the design system's own implementation, not a consumer of it
- [ ] `Container.shared.resolve(X.self)!` is NOT flagged as a force-unwrap violation — it's this project's standard DI pattern
