# Report Format

## Score Summary

```
📋 Screen Review — [ScreenName]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files reviewed: [list]

Feature Score
  F1 · Loading state       [✅ / ❌]
  F2 · Empty state         [✅ / ❌]
  F3 · Error state         [✅ / ❌]
  F4 · Success / data      [✅ / ❌]
  F5 · Edge cases          [✅ / ❌]
  Feature total:  N/5

Code Score
  D1 · LMS Design System   N/4
  D2 · MVVM                N/4
  D3 · Dark Mode           N/4
  D4 · Motion & UX         N/4
  D5 · SwiftUI Patterns    N/4
  Code total:    N/20

Overall:  N/25
Verdict:  ✅ APPROVED | ⚠️ NEEDS WORK | ❌ REJECTED
```

**Grade thresholds:**
| Score | Verdict |
|---|---|
| 22–25 | ✅ APPROVED — ready to ship |
| 15–21 | ⚠️ NEEDS WORK — fix warnings before merge |
| 0–14  | ❌ REJECTED — critical issues block merge |

---

## Issues Section

### Critical Issues (must fix before merge)

```
❌ [Category] Short description
   File: ScreenName.swift:line
   Problem: What exactly is wrong
   Fix: Concrete 1-line fix
```

### Warnings (should fix before merge)

```
⚠️ [Category] Short description
   File: ScreenName.swift:line
   Problem: What exactly is wrong  
   Fix: Suggested improvement
```

### Passing Checks

```
✅ [Category] What is correct
```

---

## Prioritised Fix List

```
Fix order (highest impact first):
  1. [❌ Critical]  Short description — File.swift:line
  2. [❌ Critical]  Short description — File.swift:line
  3. [⚠️ Warning]  Short description — File.swift:line
  4. [⚠️ Warning]  Short description — File.swift:line
```

---

## Example Full Report

```
📋 Screen Review — FinalReportView
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files reviewed:
  • FinalReportView.swift
  • FinalReportViewModel.swift

Feature Score
  F1 · Loading state    ✅  isSendingToServer + isGeneratingPDF both disable UI
  F2 · Empty state      ❌  No empty state when inspection == nil
  F3 · Error state      ✅  showErrorAlert + errorAlertMessage wired
  F4 · Success / data   ✅  All quantity/status/location fields rendered
  F5 · Edge cases       ✅  totalPhotosCount == 0 disables save button
  Feature total: 4/5

Code Score
  D1 · LMS Design System  4/4  All containers use LMSSectionContainer, LMSButton, LMSLabel
  D2 · MVVM               3/4  ⚠️ availableRecipients computed in View (minor)
  D3 · Dark Mode          4/4  TextEditor has .scrollContentBackground(.hidden), all containers adaptive
  D4 · Motion & UX        3/4  ⚠️ savePhotosSection has no tap feedback
  D5 · SwiftUI Patterns   4/4  @StateObject, @EnvironmentObject correct
  Code total: 18/20

Overall: 22/25
Verdict: ✅ APPROVED

Issues:

⚠️ [Feature] No empty state when inspection == nil
   File: FinalReportView.swift — body (no explicit check)
   Problem: inspection is Optional but screen renders blank if nil rather than a user-facing message
   Fix: Wrap ScrollView content with `if let inspection = viewModel.inspection` + else empty state

⚠️ [D2-MVVM] availableRecipients computed inline
   File: FinalReportView.swift:355 (recipientsPickerView)
   Problem: ForEach iterates viewModel.availableRecipients which calls FinalReportRecipient.mockRecipients — view-layer knowledge
   Fix: Already in ViewModel as `var availableRecipients` — no change needed (false alarm on review)

⚠️ [D4-Motion] Save photos button has no tap scale feedback
   File: FinalReportView.swift:341 (savePhotosSection)
   Problem: LMSButton handles tap scale internally — already fine
   Fix: No action needed

Prioritised Fix List:
  1. [⚠️ Feature]  Add nil-inspection empty state — FinalReportView.swift body
```
