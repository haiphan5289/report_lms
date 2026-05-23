---
name: ui-score
description: "Score Flutter UI code for AI Laundry app across 5 dimensions: Design System adoption, Color tokens, Spacing & layout, Typography, and Performance. Produces a scored report (0–50 pts) with grade A–F and actionable fix list. Use before PR or when you want a quick UI health check."
argument-hint: "[file path or feature folder — e.g. lib/features/dashboard/presentation]"
model: sonnet
---

# AI Laundry — UI Score Skill

> **Anti-Hallucination:** Only flag violations you can see in the code. Never reference App* components that do not exist in `lib/core/design_system/`. Verified list is in the scoring rubric below.

## Purpose

This skill audits Flutter UI files and produces a **scored report** with:
- A numeric score per dimension (0–10)
- An overall score out of 50
- A letter grade (A–F)
- A prioritised fix list with file path and line number

> **UI Pipeline:** Run `/ui-score` before PR for token/design system compliance. For visual quality and animation polish, also run `/pa-premium-ui <ScreenName>` — it covers layout depth, motion, loading states, and dark mode issues that ui-score does not catch.

---

## Input Format

```
TARGET: [file path or folder — e.g. lib/features/dashboard/presentation]
```

If no target is provided, ask the user for the path before proceeding.

---

## Execution Protocol

Follow these steps **in order**.

### Step 1 — Discover Files

Read the TARGET path. Collect all `.dart` files that contain UI code:
- `*_screen.dart`, `*_view.dart`, `*_page.dart`
- `*_widget.dart`, `*_card.dart`, `*_tile.dart`, `*_section.dart`

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

### D1 — Design System Adoption (0–10)

Checks whether AppDesignSystem components are used wherever a verified equivalent exists.

**Verified AppDesignSystem components (these MUST be used):**

| Raw Flutter Widget | Required App* Replacement |
|---|---|
| `Text(...)` | `AppText.*` variant |
| `ElevatedButton`, `TextButton`, `OutlinedButton`, `IconButton` | `AppButton` or `AppButton.icon()` |
| `TextField`, `TextFormField` | `AppTextField` |
| `Card(...)` | `AppCard` |
| `CircularProgressIndicator` (for loading states) | `AppLoader` |
| Skeleton placeholders (custom containers) | `AppSkeleton` or `AppOrderCardSkeleton` |
| Ad-hoc empty Column+Icon+Text for empty/error | `AppEmptyState` |
| `Divider()` | `AppDivider` |
| `VerticalDivider()` | `AppVerticalDivider` |

**Deductions:**
- `-2` per use of raw `Text(...)` where AppText would apply
- `-2` per use of raw button widget (ElevatedButton, TextButton, OutlinedButton)
- `-2` per use of raw `TextField` / `TextFormField`
- `-2` per use of raw `Card(...)` where AppCard applies
- `-1` per use of `CircularProgressIndicator` in a loading state instead of AppLoader/AppSkeleton
- `-1` per ad-hoc empty state instead of AppEmptyState

**Minimum score:** 0 (cannot go negative)

---

### D2 — Color Tokens (0–10)

Checks whether all color values use `AppColors.*` tokens.

**Deductions:**
- `-3` per use of `Color(0xFF...)` or `Color(0x...)` in feature code
- `-2` per use of `Colors.*` (e.g. `Colors.blue`, `Colors.grey`) in feature code
- `-1` per hardcoded opacity applied to a non-AppColors value (e.g. `Colors.black.withOpacity(0.5)`)
- `-1` per use of `Theme.of(context).colorScheme.*` directly where an AppColors token exists

**Acceptable (no deduction):**
- `Colors.transparent`
- `Colors.white` / `Colors.black` when no AppColors token maps to it

---

### D3 — Spacing & Layout Tokens (0–10)

Checks whether padding, margin, gap, and border-radius values use design tokens.

**Deductions:**
- `-2` per hardcoded `EdgeInsets` with literal numbers (e.g. `EdgeInsets.all(16)`, `EdgeInsets.only(top: 8)`)
- `-2` per hardcoded `SizedBox(width: 8)` or `SizedBox(height: 16)` where AppSpacing token applies
- `-2` per hardcoded `BorderRadius.circular(N)` where AppRadius token applies
- `-1` per hardcoded `Padding(padding: EdgeInsets.fromLTRB(...))` with literal numbers

**AppSpacing tokens reference:**

| Token | Value |
|---|---|
| `AppSpacing.xs` | 4.0 |
| `AppSpacing.sm` | 8.0 |
| `AppSpacing.md` | 16.0 |
| `AppSpacing.lg` | 24.0 |
| `AppSpacing.xl` | 32.0 |
| `AppSpacing.xxl` | 48.0 |

**AppRadius tokens reference:**

| Token | Value |
|---|---|
| `AppRadius.brSm` | 4px |
| `AppRadius.brMd` | 8px |
| `AppRadius.brLg` | 12px |
| `AppRadius.brXl` | 16px |
| `AppRadius.brFull` | 999px |

---

### D4 — Typography (0–10)

Checks whether all text styling uses AppText variants and AppTypography — never raw TextStyle.

**Deductions:**
- `-3` per hardcoded `TextStyle(fontSize: N, ...)` applied directly on a widget
- `-2` per raw `Text(...)` styled with `style: TextStyle(...)` instead of using an AppText variant
- `-1` per use of `fontWeight: FontWeight.*` directly on a Text widget
- `-1` per missing text color that should reference `AppColors.*` (text using default color when contrast is ambiguous)

**AppText variants reference:**
`display`, `h1`, `h2`, `h3`, `title`, `bodyLg`, `body`, `label`, `caption`, `overline`

---

### D5 — Performance & Code Quality (0–10)

Checks Flutter UI performance best practices.

**Deductions:**
- `-2` per missing `const` constructor on a widget that qualifies (no dynamic data, no callbacks)
- `-2` per business logic inside `build()` (data transformation, calculations, conditionals beyond simple null checks)
- `-2` per large widget tree (>80 lines in a single `build()` method) without widget extraction
- `-1` per `print(...)` call (use `debugPrint()`)
- `-1` per `setState()` inside an async callback without a `mounted` check

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
| D1 · Design System Adoption | N/10 | N violations |
| D2 · Color Tokens | N/10 | N violations |
| D3 · Spacing & Layout Tokens | N/10 | N violations |
| D4 · Typography | N/10 | N violations |
| D5 · Performance & Code Quality | N/10 | N violations |
| **Overall** | **N/50** | **Grade: [A/B/C/D/F]** |

---

## Verdict

[One sentence verdict: what the score means and what to prioritise]

---

## Issues by Dimension

### D1 · Design System Adoption — N/10

- ❌ `[file.dart:line]` — `Text("Doanh thu")` → use `AppText.body("Doanh thu")`
- ❌ `[file.dart:line]` — `ElevatedButton(...)` → use `AppButton(...)`
- ✅ AppCard used correctly in stat_card.dart
- ✅ AppEmptyState used in dashboard_home_view.dart

### D2 · Color Tokens — N/10

- ❌ `[file.dart:line]` — `Color(0xFF2563EB)` → use `AppColors.primary`
- ❌ `[file.dart:line]` — `Colors.grey` → use `AppColors.slate500`
- ✅ All gradient colors use AppColors tokens

### D3 · Spacing & Layout Tokens — N/10

- ❌ `[file.dart:line]` — `EdgeInsets.all(16)` → use `EdgeInsets.all(AppSpacing.md)`
- ❌ `[file.dart:line]` — `SizedBox(height: 8)` → use `SizedBox(height: AppSpacing.sm)`
- ✅ Horizontal padding uses AppSpacing.md throughout

### D4 · Typography — N/10

- ❌ `[file.dart:line]` — `TextStyle(fontSize: 14, fontWeight: FontWeight.bold)` → use `AppText.label(...)`
- ✅ Greeting uses AppText.h2
- ✅ Date uses AppText.body with AppColors.slate500

### D5 · Performance & Code Quality — N/10

- ❌ `[file.dart:line]` — Missing `const` on `SizedBox(height: AppSpacing.lg)`
- ❌ `[file.dart:line]` — Currency formatting inside `build()` → move to ViewModel or `late final` field
- ✅ Animation controllers disposed in dispose()
- ✅ mounted check present before setState after async

---

## Prioritised Fix List

Fix these in order — highest impact first:

1. `[file.dart:line]` [D1-CRITICAL] Replace `ElevatedButton` with `AppButton`
2. `[file.dart:line]` [D1-CRITICAL] Replace `Text(...)` with `AppText.body(...)`
3. `[file.dart:line]` [D2-HIGH] Replace `Color(0xFF...)` with AppColors token
4. `[file.dart:line]` [D3-MEDIUM] Replace hardcoded EdgeInsets with AppSpacing tokens
5. `[file.dart:line]` [D5-LOW] Add `const` to static SizedBox widgets
```

---

## Anti-Hallucination Checklist

Before outputting the report:
- [ ] Every App* component flagged as missing **actually exists** in the verified list above
- [ ] Every file path and line number cited was read in Step 2
- [ ] No violations invented from assumptions — only from code actually seen
- [ ] `AppColors.textSecondary` does NOT exist — use `AppColors.slate500`
- [ ] `AppText` does NOT accept `fontWeight` parameter — use different AppText variant instead
- [ ] `hint` (not `hintText`), `label` (not `text`) for AppTextField parameters
