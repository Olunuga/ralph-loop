---
name: doctor
description: Diagnose baseline health — build, tests, and gates — then delegate specs for fixes
arguments: []
allowed-tools: Bash Read Write AskUserQuestion Agent
disable-model-invocation: true
---

You are diagnosing pre-existing failures in the project baseline, then delegating to the appropriate spec skill to create fix specs.

## Step 1 — Load config

```bash
source ralph/config.sh 2>/dev/null || { echo "ERROR: ralph/config.sh not found. Run /ralph-loop:init first."; exit 1; }
echo "BUILD_CMD=$BUILD_CMD"
echo "UNIT_TEST_CMD=$UNIT_TEST_CMD"
echo "SOURCE_DIR=${SOURCE_DIR:-.}"
```

Read `ralph/AGENTS.md` to understand the project architecture.

## Step 2 — Run baseline checks

Run each check and capture output. Use subagents for parallel execution where possible.

**Build:**
```bash
source ralph/config.sh && eval "$BUILD_CMD" 2>&1 | tail -50
```

**Unit tests** (only if build passes):
```bash
source ralph/config.sh && eval "$UNIT_TEST_CMD" 2>&1 | tail -100
```

**Static gates** (fast + precise tiers):
```bash
source ralph/config.sh && bash scripts/run_static_gates.sh fast 2>&1
```
```bash
source ralph/config.sh && bash scripts/run_static_gates.sh precise 2>&1
```

**LLM gates** (semantic review — catches tech debt like magic numbers, raw colors, raw typography):
```bash
source ralph/config.sh && bash scripts/run_llm_gates.sh 2>&1
```

If everything passes, tell the user: "Baseline is clean — no pre-existing failures to fix." and stop.

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

The spec skill handles branch creation, worktree management, and commit. This skill's job is done after delegation.
