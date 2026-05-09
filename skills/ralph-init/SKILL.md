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
find ralph/scripts -name "*.sh" -exec chmod +x {} \;
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

## Step 5 — Update .gitignore

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
- ralph/AGENTS.md — codebase architecture documented

Skills (/spec, /ralph, /ralph-init, /ralph-update) are installed globally
via 'npx skills add Olunuga/ralph-loop'. If not installed yet, run that first.

Next steps:
  /spec TICKET-001   — describe a feature, get a spec
  /ralph TICKET-001  — run the autonomous pipeline"
