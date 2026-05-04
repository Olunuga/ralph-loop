# Multi-Spec Enhancement — Implementation Plan

**Date:** 2026-05-03
**Branch:** feature/multi-spec

---

## What's Already Ready — Do Not Touch

| File | Why it's fine |
|---|---|
| `PROMPT_plan.md` | Reads all of `ralph/specs/*`, does full gap analysis across every spec |
| `PROMPT_build.md` | Reads all of `ralph/specs/*`, uses up to 10 parallel subagents |
| `loop.sh plan` mode | Full gap analysis, no `WORK_DESCRIPTION` scope filter |

No changes to `loop.sh`, `PROMPT_plan.md`, `PROMPT_build.md`, or `PROMPT_plan_work.md`.

---

## What Needs Changing

### `/ralph` skill (`skills/ralph/SKILL.md`)

1. **Step 1** — `git show spec/$ref:ralph/specs/$ref*.md` looks for a single file matching the ref prefix. Fails silently when the spec branch holds multiple files.
2. **Step 3** — always calls `loop.sh plan-work "$SPEC_TITLE"`, which scopes the plan to one feature. For multi-spec should call `loop.sh plan` instead.

### `loop.sh` line 49 — `SPEC_TITLE`

`head -1` picks an arbitrary title when multiple specs exist. The `$BRANCH` fallback is the correct behaviour for multi-spec. Fix belongs in the `/ralph` skill (detect spec count, choose mode), not in `loop.sh`.

---

## Tasks

### Task 1 — Cleanup script `scripts/cleanup_specs.sh` *(new)*

**Behaviour:**
- Read `IMPLEMENTATION_PLAN.md` header: `# Generated from: ralph/specs/[filenames]`
- Parse filenames and move them to `ralph/specs/done/` (create dir if absent)
- Also move `ralph/AUDIENCE_JTBD.md` and `ralph/specs/SLC_RELEASE.md` if present
- Print confirmation per file moved
- Exit non-zero if `IMPLEMENTATION_PLAN.md` not found

**Usage:** user runs manually after confirming PR is merged. Not called from `loop.sh`.

Add to `PR_BODY` in `loop.sh` (after reviewer checklist):
```
After merging, run \`bash ralph/scripts/cleanup_specs.sh\` to archive specs.
```

---

### Task 2 — `/prd` skill `skills/prd/SKILL.md` *(new)*

**Purpose:** interview-driven, produces multiple spec files for greenfield projects with no release discipline.

**Interview flow (AskUserQuestion for each):**
1. What is the project? (name + one-sentence purpose)
2. Who are the audiences? (role/context — may list multiple)
3. For each audience: what are their JTBDs? (outcomes, not features)
4. For each JTBD: what activities does the user do? (verbs in the journey)
5. For each activity: what needs to be built? (structs, views, services, wiring)
6. What are the automated acceptance criteria per activity?
7. What's explicitly out of scope?

**Outputs:** one `ralph/specs/<activity>.md` per activity, same format as `/spec`.

**Branch strategy:**
- Create `spec/<slug>` before writing any files
- One commit per spec file: `spec: <activity>`
- After all committed, show titles summary and ask user to confirm the full set

---

### Task 3 — `/slc` skill `skills/slc/SKILL.md` *(new)*

**Purpose:** interview-driven with SLC reasoning. Produces a curated slice of specs plus supporting audience/release files.

**Interview flow:**
1. Who are the audiences? (role/context — may be multiple connected audiences)
2. For each audience: what are their JTBDs?
3. Map JTBDs to activities — what does the user actually DO?
4. For each activity: what are the capability depths? (basic → advanced)
5. Present story map grid to user for validation (text table: activities × depths)
6. Recommend SLC slice — which activities at which depth form the most valuable first release:
   - **Simple:** narrow scope, achievable fast
   - **Lovable:** people actually want to use it within that scope
   - **Complete:** fully accomplishes a meaningful job
7. User confirms or adjusts slice
8. Write specs only for confirmed slice activities

**Outputs (all on `spec/<slug>` branch):**
- `ralph/AUDIENCE_JTBD.md` — audience + JTBDs, reused in future SLC loops
- `ralph/specs/<activity>.md` — one per activity in the slice
- `ralph/specs/SLC_RELEASE.md` — what's in, what's explicitly deferred

---

### Task 4 — Update `/ralph` skill `skills/ralph/SKILL.md` *(modify)*

**Step 1 — multi-file spec discovery:**

List all specs on the branch instead of finding one:
```bash
SPEC_FILES=$(git show spec/$ref:ralph/specs/ 2>/dev/null | grep '\.md$' | grep -v '^done/' || true)
SPEC_COUNT=$(echo "$SPEC_FILES" | grep -c '\.md' || echo 0)
```

- `SPEC_COUNT == 0`: fallback to working tree; if still zero → error and stop
- `SPEC_COUNT == 1`: existing behaviour — show full spec, ask to confirm
- `SPEC_COUNT > 1`: show titles + first 20 lines of each, ask to confirm full set

**Step 3 — choose planning mode by spec count:**
```bash
SPEC_COUNT=$(find "$WORKTREE/ralph/specs" -name "*.md" ! -path "*/done/*" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$SPEC_COUNT" -eq 1 ]]; then
    SPEC_FILE=$(find "$WORKTREE/ralph/specs" -name "*.md" ! -path "*/done/*" | head -1)
    SPEC_TITLE=$(head -1 "$SPEC_FILE" | sed 's/^# //')
    cd "$WORKTREE" && bash ralph/loop.sh plan-work "$SPEC_TITLE" 3 2>&1
else
    cd "$WORKTREE" && bash ralph/loop.sh plan 3 2>&1
fi
```

No changes to `loop.sh` — `plan` mode already handles multi-spec correctly.

---

## Files Summary

| File | Action |
|---|---|
| `scripts/cleanup_specs.sh` | Create |
| `skills/prd/SKILL.md` | Create |
| `skills/slc/SKILL.md` | Create |
| `skills/ralph/SKILL.md` | Modify (Steps 1 and 3) |
| `loop.sh` | One-line addition to `PR_BODY` only |

**Unchanged:** `PROMPT_plan.md`, `PROMPT_build.md`, `PROMPT_plan_work.md`

---

## Sequencing

1. **Task 1** (`cleanup_specs.sh`) — standalone, zero blast radius
2. **Task 2** (`/prd`) — additive, no existing code touched
3. **Task 3** (`/slc`) — additive, builds on /prd patterns
4. **Task 4** (`/ralph` update) — touches existing skill; do last

---

## Reference Files

- Spec format reference: `skills/spec/SKILL.md`
- Existing ralph skill: `skills/ralph/SKILL.md`
- Planning prompts: `PROMPT_plan.md`, `PROMPT_plan_work.md`
- Loop modes: `loop.sh` lines 23–33 (mode parsing), 196–218 (plan/plan-work), 49–51 (SPEC_TITLE)
- Script patterns: `scripts/check_architecture.sh`, `scripts/consensus_judge.sh`
