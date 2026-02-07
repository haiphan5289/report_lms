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

### ⚠️ FORCE UNWRAP (!) USAGE - CRITICAL WARNING ⚠️

**ABSOLUTELY NEVER USE FORCE UNWRAP (!) IN PRODUCTION CODE**

Force unwrap (`!`) is EXTREMELY DANGEROUS and will cause RUNTIME CRASHES if the optional is `nil`. 

**❌ NEVER DO THIS:**
```swift
let value = optionalValue!  // 🚨 WILL CRASH IF NIL
let result = functionThatReturnsOptional()!  // 🚨 WILL CRASH IF NIL
```

**✅ ALWAYS DO THIS INSTEAD:**
```swift
// Use optional binding
if let value = optionalValue {
    // Safe to use value
}

// Or provide default values
let value = optionalValue ?? "default"

// Or use guard statements
guard let value = optionalValue else {
    // Handle nil case
    return
}

// Or use optional chaining
let result = optionalValue?.property?.method()
```

**WHEN FORCE UNWRAP IS ACCEPTABLE:**
- ✅ **ONLY in unit tests** where you control the test data
- ✅ **ONLY when you have 100% certainty** the value cannot be nil
- ✅ **ONLY with clear documentation** explaining why it's safe

**CONSEQUENCES OF MISUSE:**
- 🚨 App crashes in production
- 🚨 Poor user experience
- 🚨 Emergency hotfixes required
- 🚨 Loss of user trust

**REMEMBER:** If you're tempted to use `!`, you're doing something wrong. There is ALWAYS a safer way to handle optionals in Swift.