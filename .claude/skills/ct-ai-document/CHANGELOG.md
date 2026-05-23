# Changelog — ct-ai-document

## v1.0.0 — 2026-04-21

### Added
- Initial release of `ct-ai-document` skill
- Bi-directional documentation: reads from Jira (MCP), Confluence (MCP), local files, git diff
- Writes structured `.md` file co-located with the feature module
- Auto-detection of Jira key from branch name (`[A-Z]+-[0-9]+` pattern)
- Auto-detection of base branch (`main` → `dev` → `master`)
- Output path rules: AppFeatures, Libraries, `.claude/`, root `docs/`
- Priority-aware document depth: High (concise), Medium (standard), Low (thorough with mermaid)
- Document sections: PRD Summary, Business Rules, Architecture Overview, Key Files & Symbols, API Contracts, Edge Cases & Error Handling, Test Coverage Notes
- Guardrails: no Confluence/Jira writes, no hallucinated symbols, overwrite protection
