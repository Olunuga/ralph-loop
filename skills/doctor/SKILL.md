---
name: doctor
description: Diagnose baseline health — build, tests, and gates — then delegate specs for fixes
arguments: []
allowed-tools: Bash Read Write AskUserQuestion Agent
disable-model-invocation: true
---

You are diagnosing pre-existing failures in the project baseline, then delegating to the appropriate spec skill to create fix specs.

## Step 0 — Clean up orphaned doctor worktree

Always clean up any leftover doctor worktree from a prior run before doing anything else.

**IMPORTANT:** All `git worktree` commands MUST use `dangerouslyDisableSandbox: true`.

```bash
git worktree remove .worktrees/doctor --force 2>/dev/null; git worktree prune 2>/dev/null; echo "cleanup done"
```

## Step 1 — Select branch and create worktree

List branches and ask the user to select:

```bash
echo "Current branch: $(git branch --show-current)"
echo ""
echo "Recent branches:"
git branch --sort=-committerdate --format='%(refname:short)' | head -10
```

Use AskUserQuestion:
"Which branch should I diagnose?
[list from above]
(default: current branch)"

Create a worktree for the diagnosis so the main working tree stays clean.

**IMPORTANT:** All `git worktree add` and `git worktree remove` commands MUST use `dangerouslyDisableSandbox: true`.

Try creating the worktree. The branch may already be checked out in the main worktree — use `--detach` as fallback:

```bash
SELECTED_BRANCH=<user's choice or current branch>
git worktree add .worktrees/doctor $SELECTED_BRANCH 2>&1
```

If that fails with "already used by worktree", use detached HEAD:
```bash
git worktree add --detach .worktrees/doctor $SELECTED_BRANCH 2>&1
```

All subsequent commands run inside the worktree:
```bash
DOCTOR_WORKTREE="$(pwd)/.worktrees/doctor"
```

Resolve the plugin directory. The gate runners scan both plugin and project directories for gates — they need `RALPH_PLUGIN_DIR` and `PROJECT_ROOT` to find them.

```bash
# Resolve plugin directory from PATH (loop.sh/bin is always on PATH when plugin is loaded)
RALPH_PLUGIN_DIR=""
# 1. Derive from PATH — look for ralph-loop/bin
RALPH_PLUGIN_DIR=$(echo "$PATH" | tr ':' '\n' | grep 'ralph-loop/bin' | head -1 | sed 's|/bin$||' || true)
# 2. Check RALPH_PLUGIN_DIR env var (set by loop.sh during runs)
[[ -z "$RALPH_PLUGIN_DIR" && -n "${RALPH_PLUGIN_DIR:-}" ]] || true
# 3. Local dev mode (--plugin-dir)
[[ -z "$RALPH_PLUGIN_DIR" && -f "scripts/run_static_gates.sh" ]] && RALPH_PLUGIN_DIR="$(pwd)"
echo "RALPH_PLUGIN_DIR=${RALPH_PLUGIN_DIR:-NOT FOUND}"
```

If `RALPH_PLUGIN_DIR` is empty, tell the user: "Cannot find ralph-loop plugin scripts. Gate analysis will be skipped." and continue with build/test results only.

Load config:
```bash
cd "$DOCTOR_WORKTREE" && source ralph/config.sh 2>/dev/null || { echo "ERROR: ralph/config.sh not found. Run /ralph-loop:init first."; exit 1; }
echo "BUILD_CMD=$BUILD_CMD"
echo "UNIT_TEST_CMD=$UNIT_TEST_CMD"
echo "SOURCE_DIR=${SOURCE_DIR:-.}"
```

Read `ralph/AGENTS.md` to understand the project architecture.

## Step 2 — Run baseline checks

**IMPORTANT:** The doctor must see ALL violations, including ones marked SKIP in `gate_context.md`. Temporarily disable SKIPs before running gates:

```bash
[[ -f "$DOCTOR_WORKTREE/ralph/gate_context.md" ]] && mv "$DOCTOR_WORKTREE/ralph/gate_context.md" "$DOCTOR_WORKTREE/ralph/gate_context.md.bak"
```

Run build and tests sequentially (tests depend on build), then run all gates **in parallel using subagents**:

**Sequential — build first:**
```bash
cd "$DOCTOR_WORKTREE" && source ralph/config.sh && eval "$BUILD_CMD" 2>&1 | tail -50
```

**Sequential — unit tests (only if build passes):**
```bash
cd "$DOCTOR_WORKTREE" && source ralph/config.sh && eval "$UNIT_TEST_CMD" 2>&1 | tail -100
```

**Parallel — run gate checks as subagents simultaneously:**

**Only run gates if `RALPH_PLUGIN_DIR` was found.** The runners scan both plugin and project gate directories automatically — just set the env vars.

**Full-codebase scan:** The doctor checks the codebase as-is, not a diff against another branch. Set `DIFF_BASE_BRANCH` to the git empty tree so gates scan ALL code, not just changes from main:

```bash
EMPTY_TREE=$(git hash-object -t tree /dev/null)
echo "DIFF_BASE_BRANCH=$EMPTY_TREE (full codebase scan)"
```

Subagent 1 — static gates (fast):
```bash
cd "$DOCTOR_WORKTREE" && source ralph/config.sh && PROJECT_ROOT="$DOCTOR_WORKTREE" RALPH_PLUGIN_DIR="$RALPH_PLUGIN_DIR" DIFF_BASE_BRANCH="$EMPTY_TREE" bash "$RALPH_PLUGIN_DIR/scripts/run_static_gates.sh" fast 2>&1
```

Subagent 2 — static gates (precise):
```bash
cd "$DOCTOR_WORKTREE" && source ralph/config.sh && PROJECT_ROOT="$DOCTOR_WORKTREE" RALPH_PLUGIN_DIR="$RALPH_PLUGIN_DIR" DIFF_BASE_BRANCH="$EMPTY_TREE" bash "$RALPH_PLUGIN_DIR/scripts/run_static_gates.sh" precise 2>&1
```

Subagents 3+ — LLM gates (chunked by directory):

A full-codebase diff overflows LLM context. Instead of running the LLM gate runner directly, chunk the source code by top-level subdirectory and run each chunk in parallel.

First, discover the directory structure:
```bash
cd "$DOCTOR_WORKTREE" && source ralph/config.sh && find "${SOURCE_DIR:-.}" -name "*.swift" -not -path "*/.*" | sed 's|/[^/]*$||' | sort -u
```

Then read each LLM gate prompt from the plugin:
```bash
ls "$RALPH_PLUGIN_DIR/scripts/gates/llm/"*.md 2>/dev/null
```

For each LLM gate prompt, spawn **one subagent per source directory**. Each subagent:
1. Reads all `.swift` files in that directory
2. Evaluates them against the gate prompt's checklist
3. Returns PASS/FAIL verdicts per checklist item

Use the Agent tool to spawn these in parallel (one message, multiple agent calls). Each agent receives:
- The gate prompt body (from the `.md` file)
- The directory path to scan
- Instruction: "Read all .swift files in [directory]. Evaluate against the checklist. Return verdicts in the format: `1: PASS|FAIL — [reason]`. Only flag concrete issues with file:line references."

After all subagents return, **consolidate**: merge FAIL verdicts across directories. Group by gate category and list unique findings with file paths.

If `RALPH_PLUGIN_DIR` was not found, skip LLM gates and note: "LLM gates skipped — plugin directory not found."

**After all gates complete, restore gate_context.md:**
```bash
[[ -f "$DOCTOR_WORKTREE/ralph/gate_context.md.bak" ]] && mv "$DOCTOR_WORKTREE/ralph/gate_context.md.bak" "$DOCTOR_WORKTREE/ralph/gate_context.md"
```

If everything passes, clean up the worktree (Step 6) and tell the user: "Baseline is clean — no pre-existing failures to fix."

## Step 3 — Analyze and group failures

Read the source files involved in the failures. Use subagents for parallel reads.

Group failures by **root cause**, not by symptom:
- 3 test failures from a renamed property → 1 root cause
- Build error + its test failure → same root cause
- Gate violations in unrelated files → separate root causes
- LLM gate findings (magic numbers, theme violations) → group by category as tech debt

Classify each group:
- **Critical** — build errors, test failures (blocks feature work)
- **Tech debt** — gate violations, LLM gate findings (doesn't block but degrades quality)

## Step 4 — Present findings

Use AskUserQuestion to present the full diagnosis:

```
Baseline Diagnosis:

CRITICAL (blocks pipeline):
1. [Root cause] — [N files], causes [build errors / test failures]
2. ...

TECH DEBT (from gate analysis):
3. [Category: e.g. magic numbers] — [N files], [summary]
4. [Category: e.g. raw colors] — [N files], [summary]
5. ...

Total: N critical issues, M tech debt items

Which would you like to spec?
- "all" — spec everything (critical + tech debt)
- "critical" — only the blocking issues
- "debt" — only the tech debt
- "1,3,4" — pick specific items by number
```

## Step 5 — Delegate to spec skill

Based on the user's selection and the number of root causes selected:

**1 root cause selected** → use `/ralph-loop:spec fix-baseline`
- Tell the user to run it, providing the root cause description as context
- Or if the user prefers, present the fix description directly and ask if they want you to invoke the spec skill

**2+ root causes selected** → use `/ralph-loop:req-prd fix-baseline`
- The root causes become the "topics of concern"
- Tell the user to run it, or invoke it directly

Before delegating, summarize what will be speced:

"Based on your selection, I'll create [N] spec(s) for:
1. [root cause / tech debt description]
2. ...

This will use `/ralph-loop:[spec or req-prd] fix-baseline`. Proceed?"

The spec skill handles branch creation, worktree management, and commit.

## Step 6 — Clean up worktree

Remove the doctor worktree. The doctor makes no changes to the branch — it's read-only diagnosis.

**IMPORTANT:** Use `dangerouslyDisableSandbox: true`.

```bash
git worktree remove .worktrees/doctor --force 2>&1
git worktree prune 2>&1
```

This skill's job is done after cleanup and delegation.
