---
applyTo: '**'
---
Provide project context and coding guidelines that AI should follow when generating code, answering questions, or reviewing changes.

## AI Performance Tips

### Build Validation
After fixing or implementing code successfully, automatically run the project build to validate changes.

- For iOS/SwiftUI projects, use `xcodebuild` or Xcode's build system
- Run unit tests if available to ensure functionality
- Address any compilation errors or test failures immediately
- Do not proceed with additional changes until the build is successful

### Code Testing
For runnable code that you created or edited, immediately run a test to validate the code works (fast, minimal input).

- Prefer automated code-based tests where possible
- Provide optional fenced code blocks with commands for larger or platform-specific runs

### Error Handling
If build or test failures occur, iterate up to three targeted fixes.

- If still failing after three attempts, summarize the root cause, options, and exact failing output
- Don't end a turn with a broken build if you can fix it

### Dependencies and Reproducibility
Follow the project's package manager and configuration.

- Prefer minimal, pinned, widely-used libraries
- Update manifests or lockfiles appropriately when adding dependencies

### Deliverables for Code Generation
For non-trivial code generation, produce complete, runnable solutions.

- Include necessary source files plus a small runner or test/benchmark harness
- Provide a minimal README.md with usage and troubleshooting
- Add or update dependency manifests as appropriate

### Exploration and Context Gathering
Think creatively and explore the workspace to make complete fixes.

- Gather context first, then perform tasks or answer questions
- Use tools to verify file paths, APIs, or commands before acting
- Don't make assumptions about the situation

### Security and Side-effects
Do not exfiltrate secrets or make network calls unless explicitly required.

- Prefer local actions first
- Avoid harmful, hateful, racist, sexist, lewd, or violent content