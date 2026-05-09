0a. If iteration context is provided above the --- separator, read it carefully.
    Do NOT repeat approaches that already failed. If the same task has failed 2+ times,
    consider a fundamentally different approach (different file structure, different pattern).
0b. Read ralph/specs/* with subagents (up to 10 parallel).
0c. Read ralph/AGENTS.md — understand build commands, architecture rules, guardrails.
0d. Read IMPLEMENTATION_PLAN.md — pick the single most important unchecked [ ] item.
0e. Search Geyns/ for existing code related to the chosen task before assuming anything is missing.
0f. If ralph/gate_context.md exists, read it. If any gate scripts in
    ralph/scripts/gates/static/ are not listed under "Known gates",
    read those new gate scripts, assess whether they conflict with
    this project's patterns, and update gate_context.md with the
    appropriate SKIP/ENFORCE decision and LLM gate notes.
    Commit the update separately before implementing the task.

---

1. Implement the chosen task.
  - Follow the reference pattern noted in the task (check IMPLEMENTATION_PLAN.md).
  - Use subagents for all reads. Use only 1 subagent for build/test runs.
  - If the task requires a new Swift file:
  a. Create the file in the correct Geyns/ subdirectory.
  b. Add it to the Xcode target — use whichever method is available:
     • If XCODE_CLI_AVAILABLE=true: use the xcode MCP tool (add_file_to_target).
     • Otherwise: run `xcodeproj add Geyns/Views/NewFile.swift Geyns` via Bash
   (xcodeproj gem is installed; adds the file to the first target matching "Geyns").
     Do NOT edit ${XCODEPROJ}/project.pbxproj directly.
2. Validate per AGENTS.md. Fix failures before committing.
  - Run build command from AGENTS.md.
  - Run unit test command from AGENTS.md.
  - If either fails, fix and re-validate. Do not commit a red state.
3. When all validation passes:
  - Mark the item as [x] done in IMPLEMENTATION_PLAN.md
  - git add -A && git reset HEAD IMPLEMENTATION_PLAN.md progress.txt 2>/dev/null; git commit -m "ralph: [one-line description of what you did]"

---

Hard rules (never break these):

- No force unwraps: try!, !., as! — use guard/if let/throws instead
- Never edit ${XCODEPROJ}/project.pbxproj directly — use Xcode MCP tools
- One task per iteration — commit only when green
- Implement completely — no stubs, no TODOs, no placeholder logic
- Update ralph/AGENTS.md if you discover something operationally useful about this codebase

---

Gate awareness — your code will be checked by these automated gates after you commit.
Write compliant code upfront so gates pass on the first try:

Code quality gates:
- No force unwraps (try!, !., as!) — use guard/if let/throws
- No ObservableObject — use @Observable (unless AGENTS.md says otherwise)
- No stubs, TODOs, FIXME, fatalError("not implemented"), preconditionFailure
- No print() in production code — use os_log or Logger
- Explicit access control on all type declarations (public/internal/private)
- Use .isEmpty instead of .count == 0
- Keep types under 250 lines

Architecture gates:
- Services and repositories must not import SwiftUI or reference UI types
- ViewModels must not reference concrete View types
- Views must not hold @Environment(\.modelContext) — route through ViewModel
- Lower layers must not import higher layers

Security gates:
- No hardcoded secrets, API keys, or tokens in source
- No http:// URLs (use https://)
- No logging sensitive data (passwords, tokens, credentials)
- No storing credentials in UserDefaults — use Keychain

Accessibility gates:
- Images and Buttons need .accessibilityLabel
- Use Dynamic Type (preferredFont/Font.body) not hardcoded font sizes
- Don't use color alone to convey state