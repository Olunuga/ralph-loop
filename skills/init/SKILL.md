---
name: init
description: One-time setup of the Ralph autonomous dev pipeline for a new project
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are setting up the Ralph autonomous development pipeline for this project.

Run each step in order. Tell the user which step you are on.

---

## Step 1 — Create project directories

Create the ralph project shell if it doesn't exist:
```bash
mkdir -p ralph/specs ralph/gates/static ralph/gates/llm ralph/scripts/hooks
```

Copy the workspace boundary hook from the plugin:
```bash
PLUGIN_DIR="$(dirname "$(which loop.sh)")/.."
cp "$PLUGIN_DIR/scripts/hooks/workspace_boundary.sh" ralph/scripts/hooks/workspace_boundary.sh
chmod +x ralph/scripts/hooks/workspace_boundary.sh
```

---

## Step 2 — Discover project info

Before asking the user anything, run these commands to discover what you can.

Note: `xcrun simctl` and `xcodebuild -list` require access to system services that the
Claude Code sandbox may block. If these commands fail with "Operation not permitted" or
"CoreSimulatorService connection" errors, retry with `dangerouslyDisableSandbox: true`.

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

If `ralph/config.sh` already exists, read it — use its values as the baseline and only ask about fields that are missing or empty.

Present everything you discovered to the user in a single AskUserQuestion:

"Here's what I found — please confirm or correct:

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
# Sourced by loop.sh on every run.

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

```json
{
  "permissions": {
    "allow": [
      "Bash(loop.sh*)",
      "Bash(blast_radius.sh*)",
      "Bash(cd .worktrees/* && loop.sh*)",
      "Bash(git worktree add*)",
      "Bash(git worktree remove*)",
      "Bash(git worktree list*)",
      "Bash(git checkout -b*)",
      "Bash(git checkout -*)",
      "Bash(git show*)",
      "Bash(git log*)",
      "Bash(git -C .worktrees/*)",
      "Bash(git add*)",
      "Bash(git commit*)",
      "Bash(git push*)",
      "Bash(git reset*)",
      "Bash(git clean*)",
      "Bash(find ralph/*)",
      "Bash(find .worktrees/*)",
      "Bash(git status*)",
      "Bash(git diff*)",
      "Bash(git branch*)",
      "Bash(git merge-base*)",
      "Bash(gh pr list*)",
      "Bash(gh pr view*)",
      "Bash(gh pr create*)",
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
loop.sh bootstrap 2>&1
```

This generates `ralph/AGENTS.md`. Wait for it to complete, then read the file and show a summary to the user.

Use AskUserQuestion to ask: "Does this AGENTS.md look correct? Any layers, protocols, or gate rules to add? Reply 'yes' to finish, or describe what to fix."

Apply any corrections the user requests, then save.

---

## Step 7 — Commit ralph/ to git

Ralph project files must be tracked in git so that worktrees include them.

```bash
git add ralph/ .claude/settings.json .gitignore
git -c commit.gpgsign=false commit -m "chore: configure ralph autonomous pipeline"
```

---

## Done

Tell the user:

"Ralph is set up and committed. Here's what was configured:
- ralph/config.sh — build commands for <app_name>
- ralph/gates/ — directory for custom project gates
- .claude/settings.json — workspace boundary hook active
- ralph/AGENTS.md — codebase architecture documented

Next steps:
  /ralph-loop:spec TICKET-001   — describe a feature, get a spec
  /ralph-loop:run TICKET-001    — run the autonomous pipeline

To add custom gates, drop .sh files into ralph/gates/static/<category>/
or .md files into ralph/gates/llm/. See the plugin README for details."
