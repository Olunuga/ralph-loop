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

The spec lives on a `spec/<ref>` branch. Find it:
```bash
git show spec/$ref:ralph/specs/$ref*.md 2>/dev/null | head -200
```

If that fails, also try finding it in the current working tree (in case spec was committed to main):
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

If `spec/$ref` doesn't exist (spec was committed to main instead), fall back to branching from main:
```bash
git worktree add .worktrees/$ref -b ralph/$ref 2>&1
```

If the branch `ralph/$ref` already exists, inform the user and continue using the existing worktree.

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
