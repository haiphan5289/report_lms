---
name: ct-ai-document
description: "Bi-directional feature documentation skill for Cho Tot iOS. Reads from Confluence, Jira, local files, and git diff — then writes a structured .md document co-located with the feature. Use when you want to document a feature with PRD + business context + code."
argument-hint: "[JIRA: <key>] [CONFLUENCE: <url>] [FILES: <path>] [FEATURE_REQUEST: ...] [CONTEXT: ...] [PRIORITY: ...]"
---

# ct-ai-document — Feature Documentation Skill

Generate a structured feature document by reading from multiple sources (Jira, Confluence, git diff, local files) and writing a co-located `.md` file inside the repo.

> **Anti-Hallucination:** Apply ALL rules from [@.Codex/skills/ct-anti-hallucination/SKILL.md](.Codex/skills/ct-anti-hallucination/SKILL.md) before writing any content. Every file path, symbol name, API endpoint, and DS token referenced in the generated document must be verified against the live codebase — never from memory or assumed naming patterns. See also [spec/GUARDRAILS.md](spec/GUARDRAILS.md) for document-specific guardrails.

---

## How to Use

**Minimal — auto-detect from current branch:**
```
/ct-ai-document
```
The skill reads the branch name (e.g. `revenue/cre-13482-Add-Exit-Survey-Job`), extracts the Jira key (`CRE-13482`), fetches the ticket, and reads the current git diff automatically.

**With explicit overrides:**
```
/ct-ai-document
FEATURE_REQUEST: Add Exit Survey for Job feature
CONTEXT: Users see an exit survey when closing the job posting flow
PRIORITY: Medium
JIRA: CRE-13482
CONFLUENCE: https://701search.atlassian.net/wiki/spaces/...
FILES: AppFeatures/CTJOB/CTJOB/Features/ExitSurvey
```

All parameters are optional overrides — omit any to fall back to auto-detection.

---

## File Structure

| File | Purpose |
|------|---------|
| [spec/INPUT_SCHEMA.md](spec/INPUT_SCHEMA.md) | Invocation syntax and parameter reference |
| [spec/PROMPT.md](spec/PROMPT.md) | Step-by-step execution workflow (Steps 0–7) |
| [spec/OUTPUT_SCHEMA.md](spec/OUTPUT_SCHEMA.md) | Document sections and formatting |
| [spec/GUARDRAILS.md](spec/GUARDRAILS.md) | Anti-hallucination rules and common pitfalls |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## Output Location Rules

| Feature location | Document path |
|---|---|
| `AppFeatures/[Module]/...` | `AppFeatures/[Module]/docs/[feature-name].md` |
| `Libraries/[Lib]/...` | `Libraries/[Lib]/docs/[feature-name].md` |
| `.Codex/skills/[Skill]/...` | `.Codex/docs/[feature-name].md` |
| Cross-cutting / root | `docs/[feature-name].md` |

---

## Execution

Load and execute: **[spec/PROMPT.md](spec/PROMPT.md)**

Fallback — if @-references do not resolve, use the Read tool:
```
Read /Users/hai.phan/Desktop/haiphan/ct-ios-app--v3/.Codex/skills/ct-ai-document/spec/PROMPT.md
```
