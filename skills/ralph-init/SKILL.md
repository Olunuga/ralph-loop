---
name: ralph-init
description: One-time setup of the Ralph autonomous dev pipeline for a new project
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are setting up the Ralph autonomous development pipeline for this project.

Run each step in order. Tell the user which step you are on.

---

## Step 1 — Confirm ralph/ is present

Check that `ralph/loop.sh` exists. If not, stop and tell the user:
"Copy the `ralph/` directory into this project root first, then re-run /ralph-init."

Make scripts executable:
```bash
chmod +x ralph/loop.sh
chmod +x ralph/scripts/consensus_judge.sh
chmod +x ralph/scripts/hooks/workspace_boundary.sh
```

---

## Step 2 — Discover project info

Before asking the user anything, run these commands to discover what you can:

```bash
# .xcodeproj name
ls *.xcodeproj 2>/dev/null | head -1

# available schemes and test targets
xcodebuild -list 2>/dev/null

# available simulators
xcrun simctl list devices available 2>/dev/null | grep -E "iPhone [0-9]" | tail -5

# top-level directories (to infer source dir)
ls -d */ 2>/dev/null
```

From the output, infer:
- `XCODEPROJ` — the `.xcodeproj` filename
- `SCHEME` — the first non-test scheme listed
- `UNIT_TEST_TARGET` — the target ending in `Tests` (not `UITests`)
- `UI_TEST_TARGET` — the target ending in `UITests`
- `SIMULATOR` — the newest iPhone simulator available (prefer iPhone 16, fallback to highest number)
- `SOURCE_DIR` — the directory matching the scheme name (or xcodeproj name without extension)

If `ralph/config.sh` already exists, read it — use its values as the baseline and only ask about fields that are missing or empty. Read `RALPH_VERSION` from it if present.

Present everything you discovered to the user in a single AskUserQuestion:

"Here's what I found — please confirm or correct:

  Ralph version:   <from config.sh or 'main'>
  App name:        <inferred or 'unknown'>
  Description:     <from config.sh or 'unknown'>
  .xcodeproj:      <discovered>
  Scheme:          <discovered>
  Simulator:       <discovered>
  Unit test target: <discovered>
  UI test target:  <discovered>
  Protocols dir:   <from config.sh or 'unknown — e.g. MyApp/Repositories/Protocols'>
  Source dir:      <discovered>

Reply with any corrections (e.g. 'description: a fitness tracking app, protocols: MyApp/Services') or 'ok' to proceed."

Apply any corrections the user gives, then write `ralph/config.sh`.

---

## Step 3 — Write ralph/config.sh

```bash
#!/bin/bash
# ralph/config.sh — Project build configuration for the Ralph loop.
# Sourced by ralph/loop.sh on every run.

RALPH_VERSION="<ralph_version>"

APP_NAME="<app_name>"
APP_DESCRIPTION="<description>"

XCODEPROJ="<xcodeproj>"
PROTOCOLS_DIR="<protocols_dir>"
SOURCE_DIR="<source_dir>"

BUILD_CMD="xcodebuild \
  -scheme <scheme> \
  -destination 'platform=iOS Simulator,name=<simulator>' \
  build \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath .build \
  -quiet"

UNIT_TEST_CMD="xcodebuild \
  -scheme <scheme> \
  -destination 'platform=iOS Simulator,name=<simulator>' \
  test \
  -only-testing:<unit_test_target> \
  -parallel-testing-enabled NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath .build \
  -quiet"

UI_TEST_CMD="xcodebuild \
  -scheme <scheme> \
  -destination 'platform=iOS Simulator,name=<simulator>' \
  test \
  -only-testing:<ui_test_target> \
  -parallel-testing-enabled NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath .build \
  -quiet"

SNAPSHOT_TEST_CMD=""
LINT_CMD=""
```

---

## Step 4 — Write .claude/settings.json

Check if `.claude/settings.json` already exists. If it does, read it and merge the hooks in — do not overwrite existing keys.

If it does not exist, create `.claude/` and write:

Note: the workspace boundary hook (`ralph/scripts/hooks/workspace_boundary.sh`) enforces two layers:
1. Direct absolute paths in any Bash command
2. Contents of any shell script the agent executes — closing the backdoor where a script is written inside the workspace to reference outside paths

```json
{
  "permissions": {
    "allow": [
      "Bash(bash ralph/loop.sh*)",
      "Bash(cd .worktrees/* && bash ralph/loop.sh*)",
      "Bash(git worktree add*)",
      "Bash(git worktree remove*)",
      "Bash(git worktree list*)",
      "Bash(git checkout -b*)",
      "Bash(git checkout -*)",
      "Bash(git show*)",
      "Bash(git log*)",
      "Bash(git -C .worktrees/*)",
      "Bash(find ralph/*)",
      "Bash(find .worktrees/*)",
      "Bash(git status*)",
      "Bash(git diff*)",
      "Bash(git branch*)",
      "Bash(git merge-base*)",
      "Bash(gh pr list*)",
      "Bash(gh pr view*)",
      "Bash(ls .worktrees/*)",
      "Bash(ls ralph/*)",
      "Bash(source ralph/config.sh*)",
      "Bash(grep * ralph/*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ralph/scripts/hooks/workspace_boundary.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Step 5 — Install global skills

Check whether each skill already exists before writing:

```bash
ls ~/.claude/skills/spec/SKILL.md 2>/dev/null && echo "exists" || echo "missing"
ls ~/.claude/skills/ralph/SKILL.md 2>/dev/null && echo "exists" || echo "missing"
ls ~/.claude/skills/ralph-init/SKILL.md 2>/dev/null && echo "exists" || echo "missing"
```

For any that are missing, create the directory and write the file.

**~/.claude/skills/spec/SKILL.md**

```
---
name: spec
description: Create a ralph spec for a new feature through a structured JTBD conversation
arguments: [ref]
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are helping define a Job to Be Done for the Ralph autonomous development pipeline.

Reference: $ref

If $ref is a short slug or ticket ID (e.g. GYM-001, auth-flow), use it as the spec filename prefix.
If $ref is a longer description (e.g. "add workout summary screen"), derive a kebab-case slug from it.

## Step 1 — Load context

Read `ralph/AGENTS.md` to understand the project architecture, layers, and guardrails.
Read any existing files in `ralph/specs/` to understand the spec format and what's already been defined.

## Step 2 — JTBD conversation

Use AskUserQuestion to gather the following — ask each question in turn, follow up if vague:

1. "What's the job to be done? Describe it as: When [trigger], I want to [action], so [outcome]."
2. "Which files will be involved? (new files to create, files to modify, files to reference only)"
3. "Walk me through what needs to be built — structs, methods, UI, wiring."
4. "What are the automated acceptance criteria?"
5. "What will you manually verify once it's built?"
6. "What's explicitly out of scope?"

## Step 3 — Draft the spec

Write a complete spec following this format:

# <ref> — [Feature Name]

## Job to Be Done
When [trigger], [action], so [outcome].

## Scope
- New file: ...
- Modify: ...
- Read-only reference: ...
- Do NOT touch: ...

## What to Build
[Detailed sections — struct definitions, method signatures, UI content, wiring]

## Acceptance Criteria — Automated
- [ ] xcodebuild build passes, zero errors
- [ ] Unit tests pass unaffected
- [ ] No force unwraps (try!, !., as!) in new or modified code
- [ ] [feature-specific checks]

## Acceptance Criteria — Human
- [ ] [what to manually verify on device/simulator]

## Out of Scope
- [explicit exclusions]

## Step 4 — Approval loop

Use AskUserQuestion to show the full spec and ask: "Does this spec look correct? Reply 'yes' to save, or give feedback to revise."
Revise and repeat until approved.

## Step 5 — Write

Derive the filename slug from $ref:
- If $ref is already a short slug or ID (no spaces, under 30 chars), use it directly as the prefix
- If $ref is a longer description, convert to kebab-case and use that as the full filename

Create a spec branch and commit the spec there — do not write directly to main:
```bash
git checkout -b spec/<slug>
```

Write the approved spec to `ralph/specs/<slug>.md`.

```bash
git add ralph/specs/<slug>.md
git commit -m "spec: <slug>"
git checkout -
```

Confirm: "Spec written to branch spec/<slug> — run /ralph <slug> when ready."
```

**~/.claude/skills/ralph/SKILL.md**

```
---
name: ralph
description: Run the Ralph autonomous development pipeline for a spec
arguments: [ref]
allowed-tools: Bash Read Write Edit AskUserQuestion Monitor
disable-model-invocation: true
---

You are running the Ralph autonomous development pipeline.

Reference: $ref

## Step 1 — Find and show the spec

The spec lives on a `spec/$ref` branch. Find it:
```bash
git show spec/$ref:ralph/specs/$ref*.md 2>/dev/null | head -200
```

If that fails, also try the current working tree:
```bash
find ralph/specs -name "$ref*.md" | head -1
```

If no spec is found either way, tell the user: "No spec found for '$ref'. Run /spec $ref first." and stop.

Read the spec content and use AskUserQuestion to show it and ask:
"Proceed with this spec? This will run the full autonomous pipeline (plan → build → test → gates). Reply 'yes' to proceed or 'no' to cancel."

If the user replies anything other than yes, stop.

## Step 2 — Create worktree from spec branch

Branch the worktree off `spec/$ref` so the spec file is available inside the worktree:
```bash
git worktree add .worktrees/$ref -b ralph/$ref spec/$ref 2>&1
```

If `spec/$ref` doesn't exist, fall back to branching from main:
```bash
git worktree add .worktrees/$ref -b ralph/$ref 2>&1
```

If `ralph/$ref` already exists, inform the user and continue using the existing worktree.

## Step 3 — Plan

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
WORKTREE="$PROJECT_ROOT/.worktrees/$ref"
SPEC_FILE=$(find "$WORKTREE/ralph/specs" -name "$ref*.md" 2>/dev/null | head -1)
SPEC_TITLE=$(head -1 "$SPEC_FILE" | sed 's/^# //')
cd "$WORKTREE" && bash ralph/loop.sh plan-work "$SPEC_TITLE" 3 2>&1
```

Wait for it to complete. Read `$WORKTREE/IMPLEMENTATION_PLAN.md` and show it to the user (informational — no approval needed, pipeline continues automatically).

## Step 4 — Build loop

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT/.worktrees/$ref" && bash ralph/loop.sh 10 2>&1
```

This runs autonomously. Monitor the output for progress. Report each completed iteration and any gate results to the user.

The loop handles: build validation → unit tests → force-unwrap check → architecture check → lint → per-iteration commit.

After all tasks are done, post-loop gates run automatically: LLM consensus judge → UI tests → worktree cleanup.

## Step 5 — Worktree cleanup

After the loop exits, verify the worktree was removed. Check:
```bash
git worktree list
```

If `.worktrees/$ref` still appears in the list, remove it:
```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
git worktree remove "$PROJECT_ROOT/.worktrees/$ref" --force 2>&1
```

Confirm removal with another `git worktree list`. The branch `ralph/$ref` must still exist — only the working directory is removed.

## Step 6 — Report

When the loop completes, report:
- Branch: `ralph/$ref` (contains spec + implementation — open one PR to main)
- Gates: list which passed
- What was built: summarise from the Done section of IMPLEMENTATION_PLAN.md
- Next step: "Review `ralph/$ref`, then open a PR to main when satisfied."
```

---

## Step 5b — Update .gitignore

Ensure the following Ralph pipeline artifacts are gitignored. Check if each entry already exists before appending:

```bash
for entry in ".worktrees/" "IMPLEMENTATION_PLAN.md" "progress.txt"; do
    grep -qF "$entry" .gitignore 2>/dev/null || echo "$entry" >> .gitignore
done
```

---

## Step 6 — Bootstrap AGENTS.md

Run the bootstrap to let Claude discover the codebase architecture:

```bash
bash ralph/loop.sh bootstrap 2>&1
```

This generates `ralph/AGENTS.md`. Wait for it to complete, then read the file and show a summary to the user.

Use AskUserQuestion to ask: "Does this AGENTS.md look correct? Any layers, protocols, or guardrails to add? Reply 'yes' to finish, or describe what to fix."

Apply any corrections the user requests, then save.

---

## Done

Tell the user:

"Ralph is set up. Here's what was configured:
- ralph/config.sh — build commands for <app_name>
- .claude/settings.json — workspace boundary hook active
- ~/.claude/skills/ — /spec, /ralph, /ralph-init installed globally
- ralph/AGENTS.md — codebase architecture documented

Next steps:
  /spec TICKET-001   — describe a feature, get a spec
  /ralph TICKET-001  — run the autonomous pipeline"
