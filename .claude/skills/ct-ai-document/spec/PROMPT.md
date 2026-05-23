# Prompt — ct-ai-document

> See [GUARDRAILS.md](GUARDRAILS.md) before executing any step.
> Input parameters are defined in [INPUT_SCHEMA.md](INPUT_SCHEMA.md).
> Output format is defined in [OUTPUT_SCHEMA.md](OUTPUT_SCHEMA.md).

---

## Pre-flight — Anti-Hallucination Verification (MANDATORY, runs BEFORE Step 0)

Load and apply all rules from:
@.claude/skills/ct-anti-hallucination/SKILL.md

**Fallback** — if the @-reference does not resolve:
```
Read /Users/hai.phan/Desktop/haiphan/ct-ios-app--v3/.claude/skills/ct-anti-hallucination/SKILL.md
```

Apply the full Pre-Generation Verification Checklist before populating any document section. Specifically for this skill:

| Check | Tool |
|-------|------|
| Every file path in Key Files section | `Glob` to confirm it exists |
| Every class / protocol name | `Grep` for the exact declaration |
| Every API endpoint in API Contracts | Read the actual `*Target.swift` from git diff |
| Every DS token referenced | `Grep` in `Libraries/CTDesignSystem` |
| Any method signature mentioned | Read the declaring file — do not guess from the name |

> **Do NOT write any document section until the symbols referenced in that section have been verified.**  
> If a symbol cannot be found → write `"Not available — add manually"` instead of inventing it.

---

## Step 0 — Parse Inputs

1. Read all provided parameters: `FEATURE_REQUEST`, `CONTEXT`, `PRIORITY`, `JIRA`, `CONFLUENCE`, `FILES`.
2. For any missing parameter, apply auto-detection:

   **Auto-detect Jira key:**
   ```bash
   git rev-parse --abbrev-ref HEAD
   ```
   Extract pattern `[A-Z]+-[0-9]+` from the branch name. Store as `JIRA_KEY`.
   If not found and no `JIRA` param → set `JIRA_KEY = nil`, skip Step 2.

   **Auto-detect base branch:**
   ```bash
   for branch in main dev master; do
     git ls-remote --heads origin $branch | grep -q $branch && echo $branch && break
   done
   ```

   **Auto-detect changed files:**
   ```bash
   git diff <BASE_BRANCH>...HEAD --name-only
   ```
   Store as `CHANGED_FILES`.

3. Set `PRIORITY = Medium` if not provided.

4. Print a one-line confirmation:
   ```
   Documenting: <JIRA_KEY or "no ticket"> | Branch: <current> | Files: <count> changed
   ```

---

## Step 1 — Fetch Jira Ticket (conditional)

**Condition:** Only run if `JIRA_KEY` is set.

1. Parse host and key:
   - `JIRA` param provided: use it directly (may be full URL or just key)
   - Auto-detected: assume host `https://701search.atlassian.net`, key = `JIRA_KEY`
2. Fetch via MCP:
   ```
   mcp__Atlassian-MCP__jira_get_issue(issue_key: "<JIRA_KEY>")
   ```
3. Extract: `summary`, `description`, `acceptance criteria`, `labels`, `components`.
4. Store as `JIRA_CONTENT`.

**If fetch fails:** Log a warning, set `JIRA_CONTENT = nil`, continue with other sources.

---

## Step 2 — Fetch Confluence Page (conditional)

**Condition:** Only run if `CONFLUENCE` param is provided.

1. Extract `page_id` from the Confluence URL.
2. Fetch via MCP:
   ```
   mcp__Atlassian-MCP__confluence_get_page(page_id: "<page_id>")
   ```
3. Extract: page title, body content (convert to plain text).
4. Store as `CONFLUENCE_CONTENT`.

**If fetch fails:** Log a warning, set `CONFLUENCE_CONTENT = nil`, continue.

---

## Step 3 — Read Local Code Context

For each file in `CHANGED_FILES` (or `FILES` param if provided):

1. Classify by architecture layer:

   | Layer | Path keywords |
   |-------|--------------|
   | Presentation | `ViewControllers`, `Views`, `ViewModels`, `Presentation` |
   | Domain | `UseCases`, `Models`, `Domain` |
   | Data | `Repositories`, `Services`, `Targets`, `Data` |
   | Tests | `Tests`, `Spec`, `Mock` |
   | Config | `Assembler`, `Resources`, anything else |

2. For each changed Swift file — read the full git diff to extract:
   - New/modified class and protocol names
   - New/modified function signatures
   - New API targets, endpoints, and HTTP methods
   - New use case class names and action types

3. Store as `CODE_CONTEXT` with structure:
   ```
   {
     presentation: [{ file, symbols }],
     domain: [{ file, symbols }],
     data: [{ file, symbols }],
     tests: [{ file, symbols }],
   }
   ```

---

## Step 4 — Determine Output Path

Inspect `CHANGED_FILES` to find the primary module:

1. Count files per top-level module:
   ```bash
   git diff <BASE_BRANCH>...HEAD --name-only | awk -F'/' '{print $1"/"$2}' | sort | uniq -c | sort -rn | head -5
   ```

2. Apply path rules:
   - Majority under `AppFeatures/[Module]/` → `AppFeatures/[Module]/docs/<feature-name>.md`
   - Majority under `Libraries/[Lib]/` → `Libraries/[Lib]/docs/<feature-name>.md`
   - Under `.claude/skills/[Skill]/` → `.claude/docs/<feature-name>.md`
   - Mixed or root-level → `docs/<feature-name>.md`

3. Derive `feature-name`:
   - Use `FEATURE_REQUEST` if provided → kebab-case it (e.g. `exit-survey-job`)
   - Otherwise use Jira ticket key (e.g. `cre-13482`)
   - Fallback: current branch name sanitized

4. Create `docs/` directory if it does not exist:
   ```bash
   mkdir -p <output-dir>
   ```

5. Store as `OUTPUT_PATH`.

---

## Step 5 — Merge Sources into Unified Context

Combine all fetched data into `UNIFIED_CONTEXT`:

```
UNIFIED_CONTEXT = {
  feature_name: <derived>,
  priority: <PRIORITY>,
  prd_summary: <from JIRA_CONTENT.summary + description, or FEATURE_REQUEST>,
  business_context: <from JIRA_CONTENT.description + CONFLUENCE_CONTENT>,
  acceptance_criteria: <from JIRA_CONTENT.acceptance_criteria>,
  architecture: <from CODE_CONTEXT>,
  key_files: <CHANGED_FILES list with layer classification>,
  api_contracts: <endpoints extracted from CODE_CONTEXT.data>,
  test_files: <CODE_CONTEXT.tests>,
}
```

If a field has no data from any source → mark it as `"Not available — add manually"`.

---

## Step 6 — Generate Document

Using `UNIFIED_CONTEXT`, produce the full document following the exact format in [OUTPUT_SCHEMA.md](OUTPUT_SCHEMA.md).

Depth rules by `PRIORITY`:
- `High` — bullet points only, skip Architecture Diagram and Test Matrix
- `Medium` — all sections with moderate detail
- `Low` — all sections at full depth: include Architecture Diagram (mermaid), full edge case table, test coverage matrix

---

## Step 7 — Write to Local File

Write the generated document to `OUTPUT_PATH`:

```
Write(file_path: "<OUTPUT_PATH>", content: <generated document>)
```

After writing, print the completion block from [OUTPUT_SCHEMA.md](OUTPUT_SCHEMA.md).

---

## Fallback: If MCP Tools Are Unavailable

If `mcp__Atlassian-MCP__jira_get_issue` or `mcp__Atlassian-MCP__confluence_get_page` are not available:
- Skip Steps 1 and 2
- Proceed with git diff and local files only
- Note in the document: `> Jira/Confluence data not fetched — MCP unavailable`
