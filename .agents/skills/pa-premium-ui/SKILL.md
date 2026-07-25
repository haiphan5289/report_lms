---
name: pa-premium-ui
description: Upgrade any SwiftUI screen to App Store featured quality — motion-first, premium spacing, spring animations, micro-interactions, layered surfaces. Adapted for report_lms / LMS design system.
model: sonnet
effort: high
---

# Premium UI Enforcer — report_lms (SwiftUI)

**World-class design upgrader** — Transforms any SwiftUI screen from functional to 2026-level App Store quality. Every time users open the screen, they should feel "WOW".

## Problems Solved

After implementing a feature, UI often suffers from:
- ❌ Flat white screen with no depth or visual hierarchy
- ❌ Uniform `.padding(16)` everywhere, no rhythm
- ❌ Zero animation — content appears abruptly
- ❌ Loading = lonely `ProgressView()`
- ❌ Empty state = plain text on white background
- ❌ Generic `List`/`VStack` rows, looks like enterprise CRUD
- ❌ Tap interactions with zero feedback

## Solution

This skill **audits + upgrades** screens in 5 steps:
1. **Audit** — scan file, score 5 questions, determine upgrade level needed
2. **Layout** — apply layered surfaces, gradient hero, cinematic scroll
3. **Motion** — add spring animations, staggered entrance, animated state transitions
4. **Loading & Empty** — `CDSSkeleton` shimmer, progressive reveal, animated empty states
5. **Interactions** — tap scale (0.95), error shake, success feedback

## Files

| File | Purpose |
|---|---|
| [spec/PROMPT.md](spec/PROMPT.md) | Step-by-step execution workflow |
| [spec/AUDIT.md](spec/AUDIT.md) | Audit checklist + scoring |
| [spec/PATTERNS.md](spec/PATTERNS.md) | Copy-paste premium SwiftUI patterns |
| [spec/ANIMATIONS.md](spec/ANIMATIONS.md) | Spring, stagger, micro-interaction code |
| [spec/GUARDRAILS.md](spec/GUARDRAILS.md) | Anti-patterns hard stop list |

## Quick Start

```
# Upgrade entire screen
/pa-premium-ui HomeView

# Upgrade a specific section
/pa-premium-ui InspectionDetailView photo grid section

# Add animations only, no layout changes
/pa-premium-ui ErrorReviewView animations-only
```

## Output

```
✅ Premium UI Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Audit score: 2/5 (upgrade required)
🎨 Layout: gradient hero + layered cards
🎬 Animations: staggered entrance + state transitions
💫 Interactions: tap scale + error shake

Changes applied:
  ✅ Hero section: LinearGradient container + shadow
  ✅ Entry animation: .opacity + .offset, .easeOut 400ms
  ✅ Staggered list: 4 items, 80ms interval
  ✅ Loading state: CDSSkeleton shimmer
  ✅ Empty state: floating icon animation

State vars added → init in .onAppear / .task:
  • heroVisible
  • listVisible
  • floatOffset
```
