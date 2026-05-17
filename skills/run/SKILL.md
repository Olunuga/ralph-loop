---
name: run
description: Run the Ralph autonomous development pipeline for a spec
arguments: [ref]
allowed-tools: Bash Read Write Edit AskUserQuestion Monitor TaskCreate TaskUpdate TaskList Agent
disable-model-invocation: true
---

You are running the Ralph autonomous development pipeline.

Reference: $ref

**ALWAYS use TaskCreate and TaskUpdate to track pipeline progress.** Create a task for each major phase (plan, shared deps, each spec build, merge, final gates, post-mortem, PR). Mark tasks as `in_progress` when starting and `completed` when done. This gives the user a live progress view throughout the run.

## Step 1 — Find and show the spec

The spec lives on a `spec/<ref>` branch. Find it:
```bash
git show spec/$ref:ralph/specs/$ref*.md 2>/dev/null | head -200
```

If that fails, also try finding it in the current working tree (in case spec was committed to main):
```bash
find ralph/specs -name "$ref*.md" | head -1
```

If no spec is found either way, tell the user: "No spec found for '$ref'. Run /ralph-loop:spec $ref first." and stop.

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

Detect the planning mode:

```bash
PROJECT_ROOT=$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||')
WORKTREE="$PROJECT_ROOT/.worktrees/$ref"
SPEC_COUNT=$(find "$WORKTREE/ralph/specs" -name "*.md" -not -path "*/done/*" 2>/dev/null | wc -l | tr -d ' ')
test -f "$WORKTREE/ralph/AUDIENCE_JTBD.md" && echo "SLC_MODE" || echo "NO_SLC"
echo "SPEC_COUNT=$SPEC_COUNT"
```

**If 1 spec (no SLC)** → single-spec flow:
```bash
SPEC_FILE=$(find "$WORKTREE/ralph/specs" -name "$ref*.md" 2>/dev/null | head -1)
SPEC_TITLE=$(head -1 "$SPEC_FILE" | sed 's/^# //')
cd "$WORKTREE" && loop.sh plan-work "$SPEC_TITLE" 3 2>&1
```
Then proceed to **Step 4 (Single-spec build)**.

**If 1 spec (SLC)** → SLC flow:
```bash
cd "$WORKTREE" && loop.sh plan-slc 3 2>&1
```
Then proceed to **Step 4 (Single-spec build)**.

**If 2+ specs** → parallel flow:
```bash
cd "$WORKTREE" && loop.sh plan-parallel 3 2>&1
```
Then proceed to **Step 4P (Parallel build)**.

Read `$WORKTREE/IMPLEMENTATION_PLAN.md` and show it to the user (informational — no approval needed).

---

## Step 4 — Single-spec build (monitored)

*Skip this step if in parallel mode — go to Step 4P instead.*

Run the build loop using Bash with `run_in_background: true`. You will be notified when it completes.

```bash
PROJECT_ROOT=$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||')
WORKTREE="$PROJECT_ROOT/.worktrees/$ref"
cd "$WORKTREE" && loop.sh 10 2>&1
```

**CRITICAL RULES — do NOT break these:**
- Do NOT edit any source files in the worktree directly. The build agent handles all code changes.
- If the loop exits early or gets stuck, diagnose the problem, write your diagnosis to `$WORKTREE/iteration_context.md`, then restart the loop with `cd "$WORKTREE" && loop.sh [remaining-iters] 2>&1`. The build agent reads iteration_context.md as context for the next iteration.
- Your only roles are: monitoring, diagnosing, writing to iteration_context.md, and restarting the loop.
- **Blast radius policy:** If the user asks you to fix an LLM gate failure directly (after the loop has exited), run `blast_radius.sh <TypeName> ${SOURCE_DIR:-.}` first. If the verdict is `defer`, do NOT attempt the fix — write the issue to `ralph/deferred_issues.md` in the worktree AND create a GitHub issue (`gh issue create --title "Tech Debt: <TypeName> — <reason>" --label "tech-debt"`). Check for duplicates first (`gh issue list --search "Tech Debt: <TypeName>" --state open --limit 1`). Only attempt fixes with verdict `auto`.

While waiting, check progress by reading files inside the worktree. **Wait at least 3 minutes between checks** — build iterations take 5-10 minutes, so rapid polling just creates noise. Only check more frequently if actively debugging a stuck loop.

```bash
sleep 180 && cat "$WORKTREE/ralph/.loop_status" 2>/dev/null
```

The status file contains: `iteration`, `result`, `consec_fail`, `last_fail_gate`, `tasks_total`, `tasks_done`, `tasks_remaining`, `commits`, `green_iters`, `failed_iters`.

Report progress to the user as iterations complete:
- If `result` changed to `green`: report — "Iteration N: green. Tasks: D done / T total. Commits: C. (G green, F failed iterations so far)."
- On any failure: the loop automatically runs the diagnostician agent (Sonnet) and appends its analysis to `iteration_context.md`. You do NOT need to spawn a separate diagnostician for in-loop failures.
- If `consec_fail` reaches 2 or higher: report the current failure pattern and diagnostician analysis to the user. Do NOT ask the user to intervene — the loop handles model escalation automatically.
- If `tasks_remaining` reaches 0: the loop will exit on its own.

When notified the loop has finished, proceed to Step 4b.

---

## Step 4P — Parallel build (multi-spec)

*Skip this step if in single-spec mode — use Step 4 instead.*

### Phase 1: Split the plan

Read `$WORKTREE/IMPLEMENTATION_PLAN.md`. It contains:
- `## Shared Dependencies` section — tasks needed by 2+ specs
- `## Per-Spec: <name>` sections — tasks unique to each spec

Using the Read and Write tools, split these into separate files in the worktree:
- `$WORKTREE/IMPLEMENTATION_PLAN_shared.md` — shared section (if any tasks)
- `$WORKTREE/IMPLEMENTATION_PLAN_<spec-name>.md` — per-spec section for each spec

### Phase 2: Build shared dependencies + gate-clean base

If `IMPLEMENTATION_PLAN_shared.md` has tasks:

```bash
cp "$WORKTREE/IMPLEMENTATION_PLAN_shared.md" "$WORKTREE/IMPLEMENTATION_PLAN.md"
```

```bash
cd "$WORKTREE" && loop.sh 3 2>&1
```

Monitor as in Step 4 (poll .loop_status, spawn diagnostician if stuck).

After shared deps are built, run a gate-fix pass on the shared base to eliminate pre-existing violations. This prevents parallel agents from wasting budget re-fixing the same gate issues.

```bash
cd "$WORKTREE" && loop.sh post-loop 2>&1
```

Note the shared base commit (this is the clean, gate-passing base all specs fork from):
```bash
git -C "$WORKTREE" rev-parse HEAD
```

If no shared deps, still run the gate-fix pass to clean the base, then note HEAD.

### Phase 3: Spawn parallel spec-builder agents

**Max 4 agents at a time.** If there are more specs, batch them into groups of 4. Run each batch, wait for completion, then start the next batch.

For EACH per-spec plan in the current batch, spawn an `ralph-loop:spec-builder` agent **in parallel**. Use the Agent tool — send all agent spawns in a single message so they run concurrently.

Each agent receives:
- `SPEC_NAME` — the spec name (from the `## Per-Spec:` header)
- `REF` — $ref
- `SHARED_BASE` — commit hash from Phase 2
- `BUDGET` — scale based on task count: `max(5, task_count * 2)` iterations per spec
- `WORKTREE` — `.worktrees/$ref-$SPEC_NAME`
- `PLAN_CONTENT` — the full content of `IMPLEMENTATION_PLAN_<spec-name>.md`

### Phase 3 monitoring

While agents are running, check each worktree's status. **Wait at least 3 minutes between checks** — build iterations take 5-10 minutes:

```bash
for dir in .worktrees/$ref-*/; do
  echo "=== $(basename $dir) ===" && cat "$dir/ralph/.loop_status" 2>/dev/null
done
```

- The loop automatically runs diagnostician on every failure — no need to spawn separately
- Report periodic summary to user:
  ```
  Parallel build status:
    spec-1: iter 3/7, 4/6 tasks done, 2 commits (green)
    spec-2: iter 5/7, 5/8 tasks done, 3 commits (tests failing)
    spec-3: iter 2/7, 1/5 tasks done, 1 commit (building)
  ```

Wait for ALL agents to complete.

### Phase 4: Merge spec branches

Merge each spec branch sequentially into the main feature branch:

```bash
git -C "$WORKTREE" checkout ralph/$ref
```

For each spec branch (in the order they appear in the plan):
```bash
git -C "$WORKTREE" merge ralph/$ref-$SPEC_NAME --no-edit 2>&1
```

If a merge conflict occurs:
1. Read both versions of the conflicting files
2. You have full context from all specs — resolve the conflict
3. Write the resolved file using the Write tool
4. `git -C "$WORKTREE" add -A && git -C "$WORKTREE" -c commit.gpgsign=false commit --no-edit`

### Phase 5: Final gates on merged branch

```bash
cd "$WORKTREE" && loop.sh post-loop 2>&1
```

Then proceed to Step 4b (the existing post-loop section handles the rest).

### Phase 5 cleanup

Remove ALL parallel worktrees (keep the main one for post-mortem):

```bash
for dir in .worktrees/$ref-*/; do
  git worktree remove "$dir" --force 2>&1
done
```

Then proceed to Step 5 (verify branch content) as normal.

## Step 4b — Post-loop

The loop runs post-loop gates automatically after all tasks complete. Check if they ran:
```bash
tail -20 "$WORKTREE/progress.txt"
```

If the loop was killed before post-loop, run it manually:
```bash
cd "$WORKTREE" && loop.sh post-loop 2>&1
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

## Step 6 — Push and create draft PR

Ensure the branch is pushed and a draft PR exists. The loop may not have done this if it exited early.

```bash
git push -u origin ralph/$ref 2>&1
```

Check if a PR already exists:
```bash
gh pr list --head ralph/$ref --json number --jq '.[0].number' 2>/dev/null
```

If no PR exists, create one. Use the post-mortem data to write a meaningful PR body — include what was built, which gates passed, and what's incomplete (if anything):

```bash
gh pr create --draft --title "ralph/$ref" --body "<PR body based on post-mortem>" 2>&1
```

## Step 7 — Report

Report to the user:
- Branch: `ralph/$ref`
- PR: link to the draft PR
- Gates: list which passed
- What was built: summarise from the Done section of IMPLEMENTATION_PLAN.md
- If tasks remain: note what's incomplete and suggest re-running `/ralph-loop:run $ref`
