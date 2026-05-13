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

Branch the worktree off `spec/$ref` so the spec file is available inside the worktree.

**IMPORTANT:** All `git worktree add` commands below MUST use `dangerouslyDisableSandbox: true` — the sandbox write allowlist does not cover `.worktrees/` and the command will fail with "Operation not permitted" otherwise.

Try these in order, stopping at the first one that succeeds:

1. Create new branch from spec branch:
```bash
git worktree add .worktrees/$ref -b ralph/$ref spec/$ref 2>&1
```

2. If `spec/$ref` doesn't exist, branch from main:
```bash
git worktree add .worktrees/$ref -b ralph/$ref 2>&1
```

3. If branch `ralph/$ref` already exists, checkout without `-b`:
```bash
git worktree add .worktrees/$ref ralph/$ref 2>&1
```

4. If the worktree directory `.worktrees/$ref` already exists, it's ready — continue to Step 3.

If resuming an existing branch, inform the user: "Branch ralph/$ref already exists from a prior run. Resuming with the existing branch."

## Step 3 — Plan

```bash
PROJECT_ROOT=$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||')
WORKTREE="$PROJECT_ROOT/.worktrees/$ref"
SPEC_FILE=$(find "$WORKTREE/ralph/specs" -name "$ref*.md" 2>/dev/null | head -1)
SPEC_TITLE=$(head -1 "$SPEC_FILE" | sed 's/^# //')
cd "$WORKTREE" && bash ralph/loop.sh plan-work "$SPEC_TITLE" 3 2>&1
```

Wait for it to complete. Read `$WORKTREE/IMPLEMENTATION_PLAN.md` and show it to the user (informational — no approval needed, pipeline continues automatically).

## Step 4 — Build loop (monitored)

Run the build loop using Bash with `run_in_background: true`. You will be notified when it completes.

```bash
PROJECT_ROOT=$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||')
WORKTREE="$PROJECT_ROOT/.worktrees/$ref"
cd "$WORKTREE" && bash ralph/loop.sh 10 2>&1
```

**CRITICAL RULES — do NOT break these:**
- Do NOT edit any source files in the worktree directly. The build agent handles all code changes.
- If the loop exits early or gets stuck, diagnose the problem, write your diagnosis to `$WORKTREE/iteration_context.md`, then restart the loop with `cd "$WORKTREE" && bash ralph/loop.sh [remaining-iters] 2>&1`. The build agent reads iteration_context.md as context for the next iteration.
- Your only roles are: monitoring, diagnosing, writing to iteration_context.md, and restarting the loop.
- **Blast radius policy:** If the user asks you to fix an LLM gate failure directly (after the loop has exited), run `bash ralph/scripts/blast_radius.sh <TypeName> ${SOURCE_DIR:-.}` first. If the verdict is `defer`, do NOT attempt the fix — write the issue to `ralph/deferred_issues.md` in the worktree AND create a GitHub issue (`gh issue create --title "Tech Debt: <TypeName> — <reason>" --label "tech-debt"`). Check for duplicates first (`gh issue list --search "Tech Debt: <TypeName>" --state open --limit 1`). Only attempt fixes with verdict `auto`.

While waiting, periodically check progress by reading files **inside the worktree** (not the background task output):

```bash
cat "$WORKTREE/ralph/.loop_status" 2>/dev/null
```

Report progress to the user as iterations complete:
- If `result` changed to `green`: report — "Iteration N complete. M tasks remaining."
- If `consec_fail` reaches 3 or higher: read `$WORKTREE/iteration_context.md` for error details.
  Alert the user via AskUserQuestion: "Loop is stuck on [last_fail_gate] for [consec_fail] consecutive iterations. Error: [summary from iteration_context.md]. Continue or intervene?"
  - If user says continue: write any additional diagnosis to `$WORKTREE/iteration_context.md` and restart the loop
  - If user wants to intervene: ask the user to cancel the background task, then proceed to Step 4b for manual post-loop
- If `tasks_remaining` reaches 0: the loop will exit on its own.

When notified the loop has finished, proceed to Step 4b.

## Step 4b — Post-loop

The loop runs post-loop gates automatically after all tasks complete. Check if they ran:
```bash
tail -20 "$WORKTREE/progress.txt"
```

If the loop was killed before post-loop, run it manually:
```bash
cd "$WORKTREE" && bash ralph/loop.sh post-loop 2>&1
```

Report each gate outcome to the user.

## Step 5 — Verify branch content

Before cleaning up, verify the branch actually has implementation commits (not just the spec):

```bash
git log ralph/$ref --oneline | head -10
```

If the only commit is the spec commit (no "ralph:" prefixed commits), STOP and alert the user:
"WARNING: Branch ralph/$ref has no implementation commits. The build agent may have failed to commit. Check .worktrees/$ref for uncommitted changes before cleanup."

Only proceed to cleanup after confirming implementation commits exist.

## Step 5a — Post-mortem and operational learnings

Before cleaning up the worktree, review the pipeline run. Read these files:

```bash
PROJECT_ROOT=$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||')
WORKTREE="$PROJECT_ROOT/.worktrees/$ref"
echo "=== progress ===" && cat "$WORKTREE/progress.txt" 2>/dev/null
echo "=== status ===" && cat "$WORKTREE/ralph/.loop_status" 2>/dev/null
echo "=== lessons ===" && cat "$WORKTREE/ralph/lessons.md" 2>/dev/null
echo "=== commits ===" && git -C "$WORKTREE" log --oneline ralph/$ref --not spec/$ref 2>/dev/null | head -20
```

From this data, present a post-mortem to the user:

```
## Post-Mortem: $ref
Date: [today]
Duration: [end - start timestamps from progress.txt]

### Summary
- Iterations: N (M green, K failed)
- Escalations: Sonnet ×A, Opus ×B
- Agent errors: N
- Commits: C

### What went well
- [tasks completed on first try, gates that passed cleanly]

### What didn't go well
- [repeated failures, escalations, agent errors, orchestrator issues]

### What can be improved
- [lessons captured, recurring patterns, pipeline suggestions]
```

Then check if the post-mortem revealed operational learnings about the codebase (e.g. model initializer gotchas, SwiftData threading rules, architecture constraints not yet documented). If so, update `ralph/AGENTS.md` in the worktree and commit:

```bash
cd "$WORKTREE" && git add ralph/AGENTS.md && git -c commit.gpgsign=false commit -m "ralph: update AGENTS.md with operational learnings" 2>/dev/null
```

Do NOT skip this step.

## Step 5b — Worktree cleanup

```bash
git worktree list
```

If `.worktrees/$ref` still appears in the list, remove it:
```bash
PROJECT_ROOT=$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||')
git worktree remove "$PROJECT_ROOT/.worktrees/$ref" --force 2>&1
```

Confirm removal with another `git worktree list`. The branch `ralph/$ref` must still exist — only the working directory is removed.

## Step 6 — Report

When the loop completes, report:
- Branch: `ralph/$ref` (contains spec + implementation — open one PR to main)
- Gates: list which passed
- What was built: summarise from the Done section of IMPLEMENTATION_PLAN.md
- Next step: "Review `ralph/$ref`, then open a PR to main when satisfied."
