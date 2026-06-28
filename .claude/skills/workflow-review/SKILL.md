---
name: workflow-review
description: "Read and cross-verify any *_WORKFLOW.md doc in report_lms against live Swift source files. Catches inaccuracies, gaps, stale numbers, and missing flows. Produces a scored accuracy report with file:line citations and a prioritised fix list. Use before sharing or after any refactor that touches a documented subsystem."
argument-hint: "[path to WORKFLOW.md or keyword e.g. image-cache] [focus: accuracy | completeness | memory | full (default)]"
model: sonnet
effort: high
---

# Workflow Review Skill — report_lms

Read a `*_WORKFLOW.md` document, locate every referenced Swift file, and cross-verify the documented flow against live code. Produces a scored report identical in format to `/screen-review`.

---

## Input Format

```
TARGET: [path or keyword — e.g. IMAGE_CACHE_WORKFLOW.md or "image cache"]
FOCUS:  [accuracy | completeness | memory | full]   (default: full)
```

When invoked as `/workflow-review <args>`, parse as:
- A `.md` path or `*_WORKFLOW.md` filename → TARGET (locate under `Sources/` or project root)
- A plain keyword → search for `*WORKFLOW*.md` containing that keyword
- Trailing FOCUS keyword → FOCUS
- No trailing keyword → FOCUS = `full`

---

## Execution Steps

### Step 1 — Locate the Workflow Document

```
find . -name "*WORKFLOW*.md" | head -20
```

Read the full document. Extract:
- All Swift file paths mentioned in the "Cấu trúc file" or "File Structure" section
- All actor / class / function names referenced in diagrams
- All numeric claims (RAM sizes, entry counts, eviction thresholds, slot counts)
- All key design decisions listed in "Thiết kế quan trọng" or equivalent

### Step 2 — Read Referenced Source Files

Read every Swift file listed in Step 1. If a file is not found at the listed path, flag it immediately as `[STALE PATH]`.

Also read files discovered by grepping for key symbols:
```bash
grep -r "<ActorName>\|<FunctionName>" Sources/ --include="*.swift" -l
```

List all files read before proceeding.

### Step 3 — Accuracy Audit (see [spec/CHECKLIST.md](spec/CHECKLIST.md) § Accuracy)

For each workflow diagram in the document:
- Trace the documented call chain against actual function bodies
- Verify parameter names, return types, and side effects match

Score each dimension per [spec/CHECKLIST.md](spec/CHECKLIST.md).

### Step 4 — Completeness Audit (see [spec/CHECKLIST.md](spec/CHECKLIST.md) § Completeness)

Check for flows and edge cases present in the code but absent from the doc.

### Step 5 — Memory Budget Audit (see [spec/CHECKLIST.md](spec/CHECKLIST.md) § Memory)

Only when FOCUS includes `memory` or `full`. Verify every MB/entry claim against actual constants in the source.

### Step 6 — Output Report (see [spec/REPORT_FORMAT.md](spec/REPORT_FORMAT.md))

---

## Quick Start

```bash
# Full review of image cache workflow
/workflow-review IMAGE_CACHE_WORKFLOW.md

# Accuracy only
/workflow-review IMAGE_CACHE_WORKFLOW.md accuracy

# Memory budget only
/workflow-review IMAGE_CACHE_WORKFLOW.md memory

# By keyword
/workflow-review image-cache completeness
```
