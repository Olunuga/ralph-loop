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

Note: `git worktree add` writes files (e.g. `.mcp.json`) into the new worktree directory.
If the Claude Code sandbox blocks this with "Operation not permitted", retry with
`dangerouslyDisableSandbox: true` — the sandbox write allowlist does not cover `.worktrees/`.

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

## Step 4 — Build loop (monitored)

Run the full build loop in the background. The loop runs autonomously — do not interrupt it unless it's struggling.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
WORKTREE="$PROJECT_ROOT/.worktrees/$ref"
cd "$WORKTREE" && bash ralph/loop.sh 10 > ralph/.loop_output 2>&1 &
LOOP_PID=$!
```

While the loop is running, poll `ralph/.loop_status` every 30 seconds:

```bash
while kill -0 $LOOP_PID 2>/dev/null; do
    sleep 30
    cat "$WORKTREE/ralph/.loop_status" 2>/dev/null || continue
done
wait $LOOP_PID
```

After each poll, read the status file and act:

- If `result` changed to `green`: report to user — "Iteration N complete. M tasks remaining."
- If `consec_fail` reaches 3 or higher: read `$WORKTREE/iteration_context.md` for error details.
  Alert the user via AskUserQuestion: "Loop is stuck on [last_fail_gate] for [consec_fail] consecutive iterations. Error: [summary from iteration_context.md]. Continue or intervene?"
  - If user says continue: let the loop keep running (it will escalate models automatically)
  - If user wants to intervene: `kill $LOOP_PID 2>/dev/null` and let the user fix manually
- If `tasks_remaining` reaches 0: the loop will exit on its own. Wait for it.
- When the loop process exits: read final output and proceed to Step 4b.

```bash
cat "$WORKTREE/ralph/.loop_output"
```

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

## Step 5b — Worktree cleanup

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
