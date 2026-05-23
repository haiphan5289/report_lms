# Audit Checklist

Answer 5 questions. Each YES = +1 point.

## Questions

| # | Question | YES indicator |
|---|---|---|
| 1 | Layout uses raw `VStack`/`List`/`ForEach` rows with no depth? | No shadow, no gradient, no card surface, plain white bg |
| 2 | Zero animation — content appears/disappears abruptly? | No `withAnimation`, no `.transition`, no `.opacity`/`.offset` entrance |
| 3 | Uniform spacing — `.padding(16)` raw values everywhere? | No `DS.Padding.*` or `DS.Gap.*` tokens |
| 4 | Loading state only has `ProgressView()` or `LMSLoadingOverlay()` blocking the whole screen? | No `CDSSkeleton`, no shimmer, no partial skeleton |
| 5 | Empty state is just static text/icon with no animation? | No float/pulse animation, no `.transition` |

## Decision

| Score | Action |
|---|---|
| 0–2 | **Micro-upgrade**: add animations + tap interactions only |
| 3–4 | **Standard upgrade**: layout + animations + loading + empty |
| 5 | **Full premium upgrade**: all steps |

---

## UX Quality Checks (bonus — fix regardless of score)

These don't affect the upgrade level but must be fixed before marking a screen complete.

| # | Check | Flag if… |
|---|---|---|
| U1 | **Single primary CTA per action context** | Two `.cdsButtonStyle(.primary)` filled buttons appear side by side or in the same modal/sheet |
| U2 | **Thumb-zone primary action** | The screen's main CTA (submit, confirm, create) floats mid-screen with no `.safeAreaInset(edge: .bottom)` anchor |
| U3 | **Descriptive input placeholders** | Any `CDSTextField` / `TextField` has a generic placeholder (`"Nhập..."`, `"Tìm kiếm"`, `"Date"`) instead of a format mask or searchable-dimensions hint |
| U4 | **Skeleton matches content shape** | `CDSSkeleton` placeholder(s) don't visually match the shape/count of the real loaded content |

> Fix all flagged UX checks in Step 4, after the main pattern upgrades.
