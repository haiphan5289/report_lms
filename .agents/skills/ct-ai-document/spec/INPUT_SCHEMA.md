# Input Schema — ct-ai-document

## Invocation Syntax

```
/ct-ai-document
```
Auto-detect Jira key from branch name + read git diff. No additional input needed.

```
/ct-ai-document
JIRA: CRE-13482
```
Override Jira key explicitly (skips branch-name parsing).

```
/ct-ai-document
FEATURE_REQUEST: Add Exit Survey for Job feature
CONTEXT: Users see an exit survey when closing the job posting flow
PRIORITY: Medium
JIRA: CRE-13482
CONFLUENCE: https://701search.atlassian.net/wiki/spaces/...
FILES: AppFeatures/CTJOB/CTJOB/Features/ExitSurvey
```
Full explicit override — uses all provided values, falls back to auto-detect for any omitted fields.

---

## Parameters

| Parameter | Required | Auto-detect | Description |
|-----------|----------|-------------|-------------|
| `FEATURE_REQUEST` | No | From Jira summary | Short description of the feature |
| `CONTEXT` | No | From Jira description | Why this feature exists |
| `PRIORITY` | No | `Medium` | `High` / `Medium` / `Low` — affects document depth |
| `JIRA` | No | From branch name | Jira ticket key (e.g. `CRE-13482`) |
| `CONFLUENCE` | No | None | Confluence page URL to fetch as additional context |
| `FILES` | No | From git diff | Path to specific Swift files or directories to include |

---

## Auto-Detection Logic

### Jira Key — from branch name

```bash
git rev-parse --abbrev-ref HEAD
# e.g. revenue/cre-13482-Add-Exit-Survey-Job → CRE-13482
```

Pattern: extract `[A-Z]+-[0-9]+` from branch name (case-insensitive).

If no ticket key found and no `JIRA` param provided → skip Jira fetch, proceed with other sources.

### Code Context — from git diff

```bash
git diff main...HEAD --name-only
```

Auto-detect base branch in order: `main` → `dev` → `master`.

If diff is empty → use `FILES` param if provided, else ask user.

### Output Path — from changed files

Inspect git diff paths to determine the primary module:
- If majority of changed files are under `AppFeatures/[Module]/` → use that module
- If majority are under `Libraries/[Lib]/` → use that library
- If mixed or unclear → use `docs/` at repo root

---

## Priority Behavior

| Priority | Document depth |
|----------|---------------|
| `High` | Concise — MVP sections only, brief bullet points |
| `Medium` | Standard — all sections, moderate detail |
| `Low` | Thorough — all sections, architecture diagrams, edge cases, test matrix |
