# Execution Workflow

## Input

```
TARGET: [ViewName or file path]
SCOPE: [full | layout-only | animations-only | section: <section name>]  (optional, default: full)
```

### Argument Parsing

When the skill is invoked as `/pa-premium-ui <args>`, parse `<args>` as follows:

| Pattern | TARGET | SCOPE |
|---|---|---|
| `HomeView` | `HomeView` | `full` |
| `HomeView quick action buttons` | `HomeView` | `section: quick action buttons` → find the View/subview responsible |
| `ErrorReviewView animations-only` | `ErrorReviewView` | `animations-only` |
| `Sources/Presentation/.../MyView.swift` | that file path | `full` |

**Rule:** The first PascalCase word or file path is TARGET. Trailing words matching a known SCOPE keyword set SCOPE directly. Otherwise treat trailing words as a section hint and map to `section: <hint>`.

## Step 1 — Read Target File

Read the specified screen file. If no exact path given, search by name under `Sources/Presentation/`.

## Step 2 — Audit (see AUDIT.md)

Score 5 audit questions. Decide upgrade level:
- Score 0–2: targeted micro-upgrade (animations + interactions only)
- Score 3–4: standard upgrade (layout + animations + loading + empty)
- Score 5: full premium upgrade (all steps)

Also run the 4 **UX Quality Checks** (U1–U4). Flag any violations — fix them in Step 4 regardless of the main score.

## Step 3 — Plan Changes

List all changes to apply before writing any code:
```
Layout:       [what changes]
Motion:       [state vars to add + triggers]
Loading:      [skeleton pattern]
Empty:        [animated empty state]
Interactions: [tap scale / error shake / success feedback]
```

## Step 4 — Apply Changes (see PATTERNS.md + ANIMATIONS.md)

Use the Edit tool to apply surgical changes. Do NOT rewrite entire files.

Priority order:
1. `@State` animation vars → declare + trigger in `.onAppear` / `.task`
2. Layout structure → gradient/layered containers
3. Loading state → `CDSSkeleton` replacing `ProgressView()`
4. Empty state → animated widget
5. Tap interactions → `.scaleEffect` + `simultaneousGesture` wrap

## Step 5 — Validate

```bash
xcodebuild -scheme report_lms -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|warning:" | head -20
```

Zero errors required. Fix any issue before reporting complete.

## Step 6 — Output Report (see SKILL.md format)

Print the Premium UI Report using the template in SKILL.md.
