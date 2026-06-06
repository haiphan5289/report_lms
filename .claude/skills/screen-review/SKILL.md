---
name: screen-review
description: "Full feature + code review for any report_lms SwiftUI screen. Audits feature completeness (all UI states present, business logic correct), code quality (MVVM, LMS design system, dark mode, animations), and UX polish. Use before shipping any screen. Produces a scored report with file:line citations and a prioritised fix list."
argument-hint: "[ViewName or file path] [focus: feature | code | dark-mode | full (default)]"
model: sonnet
effort: high
---

# Screen Review Skill — report_lms

Dual-angle review: **does the screen do what it should** + **is the code correct**.

---

## Input Format

```
TARGET: [ViewName or file path — e.g. FinalReportView or Sources/Presentation/.../FinalReportView.swift]
FOCUS:  [feature | code | dark-mode | full]   (default: full)
```

When invoked as `/screen-review <args>`, parse as:
- First PascalCase word or `.swift` path → TARGET
- Trailing keyword matching a FOCUS value → FOCUS
- No trailing keyword → FOCUS = `full`

---

## Execution Steps

### Step 1 — Locate Files

Search for TARGET under `Sources/`. Collect:
- `*View.swift` — screen
- `*ViewModel.swift` — view model
- Any sibling `*UseCase.swift`, `*Repository.swift`, `*Service.swift`

Read all discovered files before proceeding. List them.

### Step 2 — Feature Audit (see [spec/CHECKLIST.md](spec/CHECKLIST.md) § Feature)

Derive expected behaviour from the screen name, property names, and any in-code comments.
Score each UI state and user flow:

| State | Expected | Found |
|---|---|---|
| Loading | skeleton / spinner | ? |
| Empty | message + icon | ? |
| Error | message + retry | ? |
| Success / data | renders correctly | ? |
| Edge cases | nil-safe, 0-count, max | ? |

### Step 3 — Code Quality Audit (see [spec/CHECKLIST.md](spec/CHECKLIST.md) § Code)

Audit 5 dimensions against the LMS standards:

| Dimension | Checks |
|---|---|
| D1 · LMS Design System | LMSColor, LMSSectionContainer, LMSLabel, LMSButton, LMSInfoRow |
| D2 · MVVM | No business logic in View body, @Published, ObservableObject |
| D3 · Dark Mode | No hardcoded Color.white/Color.black, all containers adaptive |
| D4 · Motion & UX | Loading states, entry animations, tap feedback |
| D5 · SwiftUI Patterns | Correct property wrappers, no unnecessary state, no memory leaks |

### Step 4 — Dark Mode Spot-Check

Run the specific dark-mode rules (see [spec/CHECKLIST.md](spec/CHECKLIST.md) § Dark Mode).
Flag any `LMSColor.white` usage inside containers, any `TextEditor` without `.scrollContentBackground(.hidden)`.

### Step 5 — Build Verify

```bash
xcodebuild -scheme report_lms -destination 'id=08315D84-9501-4994-8AD8-A85EABC80C9A' build 2>&1 | tail -5
```

Only run if code changes were proposed.

### Step 6 — Output Report (see [spec/REPORT_FORMAT.md](spec/REPORT_FORMAT.md))

---

## Quick Start

```bash
# Full review
/screen-review FinalReportView

# Feature completeness only
/screen-review OrdersView feature

# Dark mode check only
/screen-review InspectionDetailView dark-mode

# Code quality only
/screen-review DeleteConfirmationView code
```

---

## Output Preview

```
📋 Screen Review — FinalReportView
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Feature score:  4/5  ⚠️ NEEDS WORK
Code score:    18/20  ✅ GOOD
Overall:       22/25

🐛 Issues found: 2 critical, 3 warnings

Critical:
  ❌ [Feature] No error state when sendReport() fails — FinalReportView.swift:316
  ❌ [D3-DarkMode] LMSColor.white used in statusSection background — FinalReportView.swift:219

Warnings:
  ⚠️ [D2-MVVM] availableRecipients computed inline in View — move to ViewModel
  ⚠️ [D4-Motion] savePhotosSection has no tap scale feedback
  ⚠️ [D5-SwiftUI] .sheet modifier duplicated (isShowingMailComposer, isShowingPDFPreview) — consider unified enum

Fix order (highest impact first):
  1. Add error state overlay — FinalReportView.swift:316
  2. Replace LMSColor.white with Color(.systemBackground) — FinalReportView.swift:219
  3. Move availableRecipients to ViewModel — FinalReportView.swift:355
```
