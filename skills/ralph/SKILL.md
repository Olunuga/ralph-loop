---
name: ralph
description: Run the Ralph autonomous development pipeline for a spec
arguments: [ref]
allowed-tools: Bash Read Write Edit AskUserQuestion Monitor
disable-model-invocation: true
---

You are running the Ralph autonomous development pipeline.

Reference: $ref

## Step 1 — Find and show specs

The spec(s) live on a `spec/<ref>` branch. List all specs on the branch:
```bash
git show spec/$ref:ralph/specs/ 2>/dev/null | grep '\.md$' | grep -v '^done/'
```

Count and read them:
- If **0 specs found** on the branch, try the current working tree:
  ```bash
  find ralph/specs -name "*.md" ! -path "*/done/*" 2>/dev/null
  ```
  If still none found, stop: "No spec found for '$ref'. Run /spec $ref, /req-prd $ref, or /req-slc $ref first."

- If **1 spec**: read the full content. Use AskUserQuestion to show it and ask:
  "Proceed with this spec? This will run the full autonomous pipeline (plan → build → test → gates). Reply 'yes' to proceed or 'no' to cancel."

- If **2+ specs**: read the title line (`# ...`) from each. Check for AUDIENCE_JTBD.md:
  ```bash
  git show spec/$ref:ralph/AUDIENCE_JTBD.md 2>/dev/null | head -5
  ```
  Use AskUserQuestion to show the spec titles and ask:
  "Found N specs on spec/$ref:
  - [title 1]
  - [title 2]
  ...
  [If AUDIENCE_JTBD.md exists: 'SLC project detected — planning will recommend the first release slice.']
  Proceed with the full pipeline across all specs? Reply 'yes' to proceed or 'no' to cancel."

If the user replies anything other than yes, stop.

## Step 2 — Create or resume worktree

Check if `ralph/$ref` branch already exists:
```bash
git rev-parse --verify "ralph/$ref" 2>/dev/null && echo "exists" || echo "new"
```

**If "new"**: create worktree from spec branch (normal flow):
```bash
git worktree add .worktrees/$ref -b ralph/$ref spec/$ref 2>&1
```
If `spec/$ref` doesn't exist (spec was committed to main instead), fall back to branching from main:
```bash
git worktree add .worktrees/$ref -b ralph/$ref 2>&1
```

**If "exists"** (ralph branch already exists — resuming after a bug fix or interrupted run):

Check if a worktree is already there:
```bash
git worktree list | grep "worktrees/$ref" || echo "no worktree"
```

If no worktree, recreate it from the existing branch:
```bash
git worktree add ".worktrees/$ref" "ralph/$ref" 2>&1
```

Read the current plan state:
```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cat "$PROJECT_ROOT/.worktrees/$ref/IMPLEMENTATION_PLAN.md" 2>/dev/null || echo "(no plan found)"
```

Use AskUserQuestion:
"Branch ralph/$ref already exists. Here's the current plan:

[IMPLEMENTATION_PLAN.md content]

Choose how to proceed:
- 'continue' — re-run the build loop to finish any remaining tasks
- 'update' — re-plan from the updated spec (picks up new fix tasks), then re-run the loop
- 'cancel' — stop here"

- If 'cancel': stop.
- If 'continue': skip to Step 4 (Build loop).
- If 'update': proceed to Step 3 to re-plan.

## Step 3 — Plan

Detect spec count and AUDIENCE_JTBD.md presence inside the worktree, then choose the planning mode:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
WORKTREE="$PROJECT_ROOT/.worktrees/$ref"

SPEC_COUNT=$(find "$WORKTREE/ralph/specs" -name "*.md" ! -path "*/done/*" 2>/dev/null | wc -l | tr -d ' ')
HAS_AUDIENCE=$([[ -f "$WORKTREE/ralph/AUDIENCE_JTBD.md" ]] && echo "yes" || echo "no")
```

**Single spec** (`SPEC_COUNT == 1`) — scoped plan for one feature:
```bash
SPEC_FILE=$(find "$WORKTREE/ralph/specs" -name "*.md" ! -path "*/done/*" | head -1)
SPEC_TITLE=$(head -1 "$SPEC_FILE" | sed 's/^# //')
cd "$WORKTREE" && bash ralph/loop.sh plan-work "$SPEC_TITLE" 3 2>&1
```

**Multi-spec SLC project** (`SPEC_COUNT > 1` and `HAS_AUDIENCE == yes`) — SLC-aware planning:
```bash
cd "$WORKTREE" && bash ralph/loop.sh plan-slc 3 2>&1
```

**Multi-spec PRD project** (`SPEC_COUNT > 1` and `HAS_AUDIENCE == no`) — full gap analysis:
```bash
cd "$WORKTREE" && bash ralph/loop.sh plan 3 2>&1
```

Wait for planning to complete. Read `$WORKTREE/IMPLEMENTATION_PLAN.md` and show it to the user (informational — no approval needed, pipeline continues automatically).

## Step 4 — Build loop

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT/.worktrees/$ref" && bash ralph/loop.sh 10 2>&1
```

This runs autonomously. Monitor the output for progress. Report each completed iteration and any gate results to the user.

The loop handles: build validation → unit tests → force-unwrap check → architecture check → lint → per-iteration commit.

After all tasks are done, post-loop gates run automatically: LLM consensus judge → UI tests → worktree cleanup.

## Step 5 — Worktree cleanup

After the loop exits, verify the worktree was removed:
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
- Next step: "Review `ralph/$ref`, then open a PR to main when satisfied. After merging, run `/cleanup $ref` to archive completed specs and delete the spec branch."
