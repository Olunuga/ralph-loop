# Ralph Pipeline — New Machine / New Project Setup

## Prerequisites

Install on the new machine:

```bash
# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# xcodeproj gem (fallback for adding files to Xcode targets)
gem install xcodeproj
```

---

## 1. Copy the pipeline into the new project

Copy the `ralph/` directory from an existing project into the root of the new project:

```
your-project/
├── ralph/
│   ├── loop.sh
│   ├── config.sh
│   ├── AGENTS.md
│   ├── PROMPT_build.md
│   ├── PROMPT_plan.md
│   ├── PROMPT_plan_work.md
│   ├── PROMPT_bootstrap.md
│   └── scripts/
│       ├── consensus_judge.sh
│       └── hooks/
│           └── workspace_boundary.sh
```

Make scripts executable:

```bash
chmod +x ralph/loop.sh
chmod +x ralph/scripts/consensus_judge.sh
chmod +x ralph/scripts/hooks/workspace_boundary.sh
```

---

## 2. Configure the project

Edit `ralph/config.sh`:

```bash
APP_NAME="YourApp"
APP_DESCRIPTION="a short description of the app"
XCODEPROJ="YourApp.xcodeproj"
PROTOCOLS_DIR="YourApp/Repositories/Protocols"
SOURCE_DIR="YourApp"

# Run `xcodebuild -list` to confirm scheme names
# Run `xcrun simctl list devices available | grep iPhone` for simulator names

BUILD_CMD="xcodebuild \
  -scheme YourApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -quiet"

UNIT_TEST_CMD="xcodebuild \
  -scheme YourApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test \
  -only-testing:YourAppTests \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -quiet"

UI_TEST_CMD="xcodebuild \
  -scheme YourApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test \
  -only-testing:YourAppUITests \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -quiet"

SNAPSHOT_TEST_CMD=""
LINT_CMD=""
```

---

## 3. Set up project-level Claude Code config

Create `.claude/settings.json` in the project root:

```json
{
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

## 4. Install global skills (once per machine)

```bash
mkdir -p ~/.claude/skills/spec ~/.claude/skills/ralph
```

Create `~/.claude/skills/spec/SKILL.md`:

```
---
name: spec
description: Create a ralph spec for a new feature through a structured JTBD conversation
arguments: [ticket_id]
allowed-tools: Read Write AskUserQuestion
disable-model-invocation: true
---

You are helping create a feature spec for the Ralph autonomous development pipeline.

Ticket ID: $ticket_id

## Step 1 — Load context

Read `ralph/AGENTS.md` to understand the project architecture, layers, and guardrails.
Read any existing files in `ralph/specs/` to understand the spec format.

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

# $ticket_id — [Feature Name]

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
- [ ] Tests pass unaffected
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

Derive a short kebab-case slug from the feature name.
Write the approved spec to `ralph/specs/$ticket_id-<slug>.md`.
Confirm: "Spec written to ralph/specs/$ticket_id-<slug>.md — run /ralph $ticket_id when ready."
```

Create `~/.claude/skills/ralph/SKILL.md`:

```
---
name: ralph
description: Run the Ralph autonomous development pipeline for a ticket
arguments: [ticket_id]
allowed-tools: Bash Read Write Edit AskUserQuestion Monitor
disable-model-invocation: true
---

You are running the Ralph autonomous development pipeline.

Ticket: $ticket_id

## Step 1 — Find and show the spec

```bash
find ralph/specs -name "$ticket_id*.md" | head -1
```

If no file is found: "No spec found for $ticket_id. Run /spec $ticket_id first." and stop.

Read the spec. Use AskUserQuestion to show the full spec content and ask:
"Proceed with this spec? This will run the full autonomous pipeline (plan → build → test → gates). Reply 'yes' to proceed or 'no' to cancel."

If not yes, stop.

## Step 2 — Create worktree

```bash
git worktree add .worktrees/$ticket_id -b ralph/$ticket_id 2>&1
```

## Step 3 — Plan

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
WORKTREE="$PROJECT_ROOT/.worktrees/$ticket_id"
SPEC_TITLE=$(head -1 "$PROJECT_ROOT"/ralph/specs/$ticket_id*.md | sed 's/^# //')
cd "$WORKTREE" && bash ralph/loop.sh plan-work "$SPEC_TITLE" 3 2>&1
```

Read `$WORKTREE/IMPLEMENTATION_PLAN.md` and show it to the user (informational — pipeline continues automatically).

## Step 4 — Build loop

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT/.worktrees/$ticket_id" && bash ralph/loop.sh 15 2>&1
```

Monitor output. Report each completed iteration and gate result to the user.

## Step 5 — Report

When complete, report:
- Branch: `ralph/$ticket_id`
- Gates passed
- What was built (from the Done section of IMPLEMENTATION_PLAN.md)
- Next step: "Review `ralph/$ticket_id`, then merge when satisfied."
```

---

## 5. Bootstrap AGENTS.md (first time per project)

```bash
./ralph/loop.sh bootstrap
```

Review the generated `ralph/AGENTS.md` and fill in anything the bootstrap missed.

---

## 6. Verify baseline build passes

```bash
./ralph/loop.sh post-loop   # dry run — confirms config and build are healthy
```

Fix any failures before running the pipeline.

---

## Daily usage

```bash
/spec TICKET-001    # JTBD conversation → writes ralph/specs/TICKET-001-*.md
/ralph TICKET-001   # shows spec → you approve → autonomous pipeline runs
```

The only human decisions:
1. **Spec approval** — confirm what to build before the pipeline starts
2. **Branch review** — inspect `ralph/TICKET-001` and merge when satisfied
