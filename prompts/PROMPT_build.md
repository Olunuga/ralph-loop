0a. If iteration context is provided above the --- separator, read it carefully.
    Do NOT repeat approaches that already failed. If the same task has failed 2+ times,
    consider a fundamentally different approach (different file structure, different pattern).
0b. Read the feature brief with subagents (up to 10 parallel): every text file under
    $RALPH_BRIEF_DIR (defaults to ralph/specs/). Skip the assets/ directory here.
0c. Read ralph/AGENTS.md — understand build commands, architecture rules, gates.
0d. Read IMPLEMENTATION_PLAN.md — pick the FIRST unchecked [ ] item (top-down order).
    **You MUST implement exactly ONE task per iteration. Not two, not "while I'm here."
    Pick one. Implement it. Validate it. Commit it. Stop.**
0d2. Design references. If $RALPH_BRIEF_DIR/assets/ exists, read the images YOURSELF with
    the Read tool. Do NOT delegate this to a subagent: a subagent returns text and cannot
    pass an image back to you.
    - Read at most 2 images per iteration. If assets/ holds more, read only the ones your
      chosen task names, and say which files you skipped.
    - Name every asset file you read, so the iteration output shows which reference you
      followed.
    - If the Read tool cannot render a file (.fig, .sketch, .psd), name it, say you cannot
      read it, and continue from the text brief. Do not fail the iteration over it.
    - If assets/ does not exist, say nothing and continue.
0e. Search the source directory for existing code related to the chosen task before assuming anything is missing.
0f. If ralph/gate_context.md exists, read it. If any gates — static (.sh scripts)
    or LLM (.md prompts) from both plugin and project directories
    (see "Gate scripts" and "LLM gates" paths above the --- separator)
    — are not listed under "Known gates", read those new gates and add them
    to gate_context.md as ENFORCE with a note about what they check.
    **You MUST NOT add SKIP entries.** Only the user can decide to skip a gate
    (via /ralph-loop:doctor or manually). If a gate conflicts with the project's
    patterns, add it as ENFORCE with a note explaining the conflict — the user
    will decide.
    Commit the update separately before implementing the task.

---

1. Implement the chosen task.
  - Follow the reference pattern noted in the task (check IMPLEMENTATION_PLAN.md).
  - Before writing tests, read the initializer signatures of every model/type you will instantiate in the test. Do not guess init parameters — get them from the source.
  - Tests must cover both happy paths (expected inputs, success cases) AND sad paths (nil values, empty collections, invalid inputs, edge cases). Do not write tests that only verify the success case.
  - Use subagents for all reads. Use only 1 subagent for build/test runs.
  - If the task requires a new Swift file:
  a. Create the file in the correct source subdirectory.
  b. Add it to the Xcode target — use whichever method is available:
     • If XCODE_CLI_AVAILABLE=true: use the xcode MCP tool (add_file_to_target).
     • Otherwise: run `xcodeproj add <path/to/NewFile.swift> <TargetName>` via Bash
   (xcodeproj gem is installed; adds the file to the named target).
     Do NOT edit ${XCODEPROJ}/project.pbxproj directly.
2. Validate per AGENTS.md. Fix failures before committing.
  - Run build command from AGENTS.md.
  - Run unit test command from AGENTS.md.
  - If either fails, fix and re-validate. Do not commit a red state.
3. When all validation passes:
  - Mark ONLY the ONE item you implemented as [x] done in IMPLEMENTATION_PLAN.md
  - Verify: count how many [ ] items you changed to [x]. If more than 1, you did too much — revert the extras back to [ ].
  - git add -A && git reset HEAD IMPLEMENTATION_PLAN.md progress.txt 2>/dev/null; git commit -m "ralph: [one-line description of what you did]"
  - **STOP after committing. Do not start the next task. The loop will start a new iteration.**

---

Hard rules (never break these):

- No force unwraps: try!, !., as! — use guard/if let/throws instead
- Never edit ${XCODEPROJ}/project.pbxproj directly — use Xcode MCP tools
- ONE task per iteration — implement exactly one unchecked item, commit, then STOP. Do not continue to the next task.
- Implement completely — no stubs, no TODOs, no placeholder logic
- Update ralph/AGENTS.md if you discover something operationally useful about this codebase
- NEVER ask for permission or confirmation — you are autonomous. Commit immediately when validation passes. Do not ask "should I proceed?" or "should I commit?" — just do it.

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