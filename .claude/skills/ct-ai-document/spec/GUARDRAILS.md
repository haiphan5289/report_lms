# Guardrails — ct-ai-document

> **Anti-Hallucination (PRIMARY):** This skill fully inherits all rules from:
> @.claude/skills/ct-anti-hallucination/SKILL.md
>
> Fallback — if @-reference does not resolve:
> ```
> Read /Users/hai.phan/Desktop/haiphan/ct-ios-app--v3/.claude/skills/ct-anti-hallucination/SKILL.md
> ```
>
> The rules below are **document-specific extensions** on top of that base layer.

---

## Inherited Rules (from ct-anti-hallucination — enforced here)

| Rule | Application in this skill |
|------|--------------------------|
| Verify file paths with `Glob` | Every path in Key Files section must exist |
| Verify class/protocol names with `Grep` | Every symbol in Architecture Overview must be declared |
| Verify method signatures by reading the file | Do not describe a method without reading its declaration |
| Verify API endpoints from actual `*Target.swift` | Never infer endpoints from function names or comments |
| Verify DS tokens in CTDesignSystem | Only mention token names found in `Libraries/CTDesignSystem` |
| Never invent a substitute | If something is missing → write `"Not available — add manually"` |

---

## Core Rules (document-specific)

### 1. Never Invent Code Content

- Read actual changed files via git diff or the `Read` tool.
- Do NOT guess class names, method signatures, or API endpoints that are not in the diff.
- If a symbol cannot be found, write `"Not available — add manually"` in that field.

### 2. Never Write Confluence Content

- This skill is **read-only** for Confluence — fetch page content as input only.
- Never call `mcp__Atlassian-MCP__confluence_create_page` or `mcp__Atlassian-MCP__confluence_update_page`.
- Never call `mcp__Atlassian-MCP__jira_add_comment` or any write Jira tool.
- Output is **always local .md files only**.

### 3. Never Auto-Chain Skills

- Print next-step suggestions only.
- Never automatically invoke `/ct-quality-engineer`, `/ct-unittest`, `/review-code`, or any other skill.

### 4. File Path Verification

- Before writing `OUTPUT_PATH`, verify the target directory exists or create it with `mkdir -p`.
- Never overwrite a non-empty existing document without asking the user first:
  > "A document already exists at `<OUTPUT_PATH>`. Overwrite it? (yes/no)"
- If user says no → append a version suffix: `<feature-name>-v2.md`.

### 5. Jira / Confluence Content — Use As-Is

- Copy Jira ticket descriptions verbatim into the PRD Summary section.
- Do NOT add business rules or acceptance criteria that are not present in the source data.
- If the Jira description is empty or very short → note: `> Jira description was minimal — fill this section manually.`

### 6. API Contracts — Only From Actual Targets

- API endpoints must be extracted from real `*Target.swift` files visible in the diff.
- Do NOT infer endpoints from function names or comments.
- If no Target file is changed → API Contracts section reads: `> No new API targets detected in this diff.`

### 7. Architecture Layer Classification

- Use path keywords strictly (see PROMPT.md Step 3).
- If a file's layer is ambiguous → classify as `Config / Other`, never guess.

---

## Common Pitfalls

### Empty git diff
If `git diff <BASE>...HEAD --name-only` returns nothing:
- Report: `ℹ️ No changed files found. Using FILES param or asking user.`
- If `FILES` param also not provided → stop and ask: `"No changed files detected. Which files should I document?"`

### Jira ticket not found
If MCP returns an error for the Jira key:
- Report: `⚠️ Could not fetch Jira ticket <KEY>. Proceeding with git diff only.`
- Continue without Jira content.

### Confluence page not accessible
If MCP returns auth error or not found:
- Report: `⚠️ Could not access Confluence page. Proceeding without it.`
- Continue without Confluence content.

### Branch with no Jira key
If branch name has no `[A-Z]+-[0-9]+` pattern:
- Skip Jira fetch entirely.
- Note in the document header: `> **Jira:** —`

### Large diff (100+ files)
If changed file count exceeds 100:
- Warn: `⚠️ Large diff: <N> files. Documenting top changed module only. Use FILES param to narrow scope.`
- Restrict to the single top-most module by file count.
