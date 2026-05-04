# Multi-Spec Enhancement — Implementation Plan

**Date:** 2026-05-04
**Branch:** feature/multi-spec
**Reference:** The Ralph Playbook (Clayton Farr) — JTBD → Story Map → SLC Release

---

## What's Already Ready — Do Not Touch

| File | Why it's fine |
|---|---|
| `PROMPT_plan.md` | Reads all of `ralph/specs/*`, does full gap analysis across every spec |
| `PROMPT_build.md` | Reads all of `ralph/specs/*`, uses up to 10 parallel subagents |
| `PROMPT_plan_work.md` | Scoped planning for single feature — unchanged |
| `loop.sh plan` mode | Full gap analysis, no scope filter |
| `loop.sh plan-work` mode | Scoped planning — unchanged |

---

## Decomposition Models

Two distinct decomposition approaches, one per skill:

**Req-PRD** — decomposes JTBDs into **topics of concern** (capability-oriented nouns).
Scope test: can you describe it in one sentence without "and"?
- ✓ "The color extraction system analyzes images to identify dominant colors"
- ✗ "The user system handles auth, profiles, and billing" → 3 topics

**Req-SLC** — decomposes JTBDs into **activities** (journey-oriented verbs) with capability depths.
Activities sequence into a user journey (story map). Depths are rows in the map.
```
UPLOAD    →   EXTRACT    →   ARRANGE     →   SHARE
basic         auto           manual          export
bulk          palette        templates       collab
batch         AI themes      auto-layout     embed
```
SLC slicing (which activities at which depth) is the **planning prompt's job**, not the skill's.

---

## What Needs Changing

### `/ralph` skill — two problems

1. **Step 1** — finds one spec file matching `$ref*.md`. Fails silently for multi-spec branches.
2. **Step 3** — always calls `loop.sh plan-work`. For multi-spec should use `plan` or `plan-slc`.

### `loop.sh` — needs a new mode

`plan-slc` mode: same as `plan` but pipes `PROMPT_plan_slc.md` instead of `PROMPT_plan.md`.
Needed for SLC projects where planning must reason about AUDIENCE_JTBD.md and recommend a slice.

---

## Tasks

### Task 1 — Cleanup script `scripts/cleanup_specs.sh` *(new)*

**Behaviour:**
- Read `IMPLEMENTATION_PLAN.md` header: `# Generated from: ralph/specs/[filenames]`
- Parse filenames and move them to `ralph/specs/done/` (create dir if absent)
- Also move `ralph/AUDIENCE_JTBD.md` if present
- Print confirmation per file moved
- Exit non-zero if `IMPLEMENTATION_PLAN.md` not found

**Usage:** user runs manually after confirming PR is merged. Not called from `loop.sh`.

Add to `PR_BODY` in `loop.sh` (after reviewer checklist):
```
After merging, run \`bash ralph/scripts/cleanup_specs.sh\` to archive specs.
```

---

### Task 2 — `Req-PRD` skill `skills/req-prd/SKILL.md` *(new)*

**Purpose:** greenfield requirements gathering with no release discipline. Produces one spec per topic of concern.

**Decomposition unit:** topic of concern — a distinct capability aspect of a JTBD. Scoped by the "one sentence without and" test.

**Interview flow (AskUserQuestion for each):**
1. What is the project? (name + one-sentence purpose)
2. Who are the audiences? (role/context — may list multiple)
3. For each audience: what are their JTBDs? (outcomes they want, not features)
4. For each JTBD: break into topics of concern — apply scope test to each
5. For each topic: what needs to be built? (structs, views, services, wiring)
6. What are the automated acceptance criteria per topic?
7. What's explicitly out of scope?

**Outputs:** one `ralph/specs/<topic>.md` per topic of concern.
Spec format: same as existing `/spec` skill (see `skills/spec/SKILL.md`).

**Branch strategy:**
- Create `spec/<slug>` before writing any files
- One commit per spec: `spec: <topic>`
- After all committed: show titles + summary, ask user to confirm full set

No `AUDIENCE_JTBD.md` — no SLC planning needed for this skill.

---

### Task 3 — `Req-SLC` skill `skills/req-slc/SKILL.md` *(new)*

**Purpose:** greenfield requirements gathering with SLC release discipline. Produces AUDIENCE_JTBD.md + activity specs for ALL activities at ALL capability depths. SLC slicing is deferred to the planning prompt.

**Key principle:** specs are a permanent reference spanning multiple releases. The planning prompt recommends the next SLC slice given what's already done. Do NOT gate on a slice during the interview — capture everything.

**Interview flow:**
1. Who are the audiences? (role/context — may be multiple connected audiences e.g. "designer creates, client reviews")
2. For each audience: what are their JTBDs? (outcomes, not features)
3. For each JTBD: what activities does the user do? (verbs — "upload photo", "extract colors")
4. For each activity: what are the capability depths? (basic → advanced levels)
5. Present story map grid to user for validation (text table: activities × depths)
6. Ask user to confirm the activity set — add or remove activities before writing specs
7. Write specs for ALL confirmed activities at ALL depth levels

**Outputs (all on `spec/<slug>` branch):**
- `ralph/AUDIENCE_JTBD.md` — audiences, JTBDs, and the connections between them. Reused in every future planning loop — do not archive.
- `ralph/specs/<activity>.md` — one per activity; each spec documents all capability depths as acceptance criteria tiers

**Spec format for activity specs:**
```markdown
# <activity> — [name]

## Job to Be Done
When [trigger], [action], so [outcome].

## Capability Depths

### Basic
[What basic accomplishes + acceptance criteria]

### Enhanced
[What enhanced adds + acceptance criteria]

### Advanced (optional)
[What advanced adds + acceptance criteria]

## Out of Scope
[explicit exclusions]
```

**Branch strategy:** `spec/<slug>`, one commit per output file.

**Note on SLC scoping:** The `Req-SLC` skill captures the full activity space. On the first `/ralph` run, the planning prompt reads `AUDIENCE_JTBD.md` and recommends the narrowest slice that is Simple, Lovable, and Complete. On subsequent releases, re-run planning — it picks the next slice from what's still MISSING/PARTIAL.

---

### Task 4 — `PROMPT_plan_slc.md` *(new)*

SLC-aware planning prompt. Used when `AUDIENCE_JTBD.md` is present.

Differences from `PROMPT_plan.md`:
- Reads `AUDIENCE_JTBD.md` first (who, JTBDs)
- Sequences activities into a user journey map (columns = journey steps, rows = capability depths)
- Applies SLC criteria to recommend the next slice:
  - **Simple** — narrowest scope achievable fast
  - **Lovable** — people actually want to use it within that scope
  - **Complete** — fully accomplishes a meaningful job, not a broken preview
- Scopes `IMPLEMENTATION_PLAN.md` to that slice only
- Begins the plan with a brief SLC release summary (what's in, what's explicitly deferred)

```markdown
0a. Read ralph/AUDIENCE_JTBD.md to understand who we're building for and their Jobs to Be Done.
0b. Read every file in ralph/specs/ — these are the source of truth for all activities and capability depths.
0c. Read ralph/AGENTS.md — understand build system, architecture, and guardrails.
0d. Survey the source directory structure (list files, do not read every file).
0e. Read the protocols/interfaces layer — these define what must be conformed to.

STEP 1 — Sequence the activities in ralph/specs/ into a user journey for the audience in
ralph/AUDIENCE_JTBD.md. Consider how activities flow into each other and what dependencies exist.

STEP 2 — Determine the next SLC release. For each activity at each capability depth:
- Search the codebase to determine status: DONE / PARTIAL / MISSING
- Note WHERE it would live (file path, layer) and the reference pattern to follow

Use the gap analysis to recommend which activities at which capability depth form the most
valuable next release. Prefer thin horizontal slices — the narrowest scope that still delivers
real value. A good slice is:
- Simple: narrow scope, achievable fast. Not every activity, not every depth.
- Lovable: people actually want to use it. Delightful within its scope.
- Complete: fully accomplishes a meaningful job. Not a broken preview.

STEP 3 — Write IMPLEMENTATION_PLAN.md using this exact format:

\`\`\`
# Implementation Plan — [SLC Release Name]
# Generated from: ralph/specs/[filenames in this slice]
# [date]

## SLC Release
[2-3 sentence summary: what's included and why it forms a Simple, Lovable, Complete release]

## Deferred
[bullet list of activities/depths explicitly not included in this slice]

## Tasks

- [ ] [task description] — [target file path] — follow [reference file]
...

## Done

(empty — build loop moves items here as it commits)
\`\`\`

STEP 4 — Commit:
git add IMPLEMENTATION_PLAN.md && git commit -m "ralph: generate SLC plan from specs"

---

CONSTRAINTS

- Do not implement anything
- Do not modify any source files
- Tasks must only cover the recommended SLC slice — exclude deferred activities
- Update ralph/AGENTS.md only if you discover something operationally important
```

---

### Task 5 — `loop.sh plan-slc` mode *(modify)*

Add `plan-slc` as a new mode alongside `plan`:

```bash
plan-slc)  MODE="plan-slc"; MAX_ITERATIONS="${2:-0}" ;;
```

In the planning loop section:
```bash
if [[ "$MODE" == "plan-slc" ]]; then
    ITER=0
    while true; do
        [[ "$MAX_ITERATIONS" -gt 0 && "$ITER" -ge "$MAX_ITERATIONS" ]] && break
        echo "=== Plan-SLC iteration $((ITER + 1)) ==="
        cat ralph/PROMPT_plan_slc.md | claude_run
        ITER=$((ITER + 1))
    done
    exit 0
fi
```

---

### Task 6 — Update `/ralph` skill `skills/ralph/SKILL.md` *(modify)*

**Step 1 — multi-file spec discovery:**

List all specs on the branch instead of finding one:
```bash
SPEC_FILES=$(git show spec/$ref:ralph/specs/ 2>/dev/null | grep '\.md$' | grep -v '^done/' || true)
SPEC_COUNT=$(echo "$SPEC_FILES" | grep -c '\.md' 2>/dev/null || echo 0)
```

- `SPEC_COUNT == 0`: fallback to working tree; if still zero → error and stop
- `SPEC_COUNT == 1`: existing behaviour — show full spec, ask user to confirm
- `SPEC_COUNT > 1`: show titles + first 20 lines of each, ask: "Found N specs on spec/$ref. Proceed? Reply 'yes' or 'no'."

**Step 3 — choose planning mode by spec count and AUDIENCE_JTBD.md presence:**

```bash
SPEC_COUNT=$(find "$WORKTREE/ralph/specs" -name "*.md" ! -path "*/done/*" 2>/dev/null | wc -l | tr -d ' ')
HAS_AUDIENCE=$([[ -f "$WORKTREE/ralph/AUDIENCE_JTBD.md" ]] && echo "yes" || echo "no")

if [[ "$SPEC_COUNT" -eq 1 ]]; then
    # Single spec — scoped plan-work
    SPEC_FILE=$(find "$WORKTREE/ralph/specs" -name "*.md" ! -path "*/done/*" | head -1)
    SPEC_TITLE=$(head -1 "$SPEC_FILE" | sed 's/^# //')
    cd "$WORKTREE" && bash ralph/loop.sh plan-work "$SPEC_TITLE" 3 2>&1
elif [[ "$HAS_AUDIENCE" == "yes" ]]; then
    # Multi-spec SLC project — SLC-aware planning
    cd "$WORKTREE" && bash ralph/loop.sh plan-slc 3 2>&1
else
    # Multi-spec PRD project — full gap analysis
    cd "$WORKTREE" && bash ralph/loop.sh plan 3 2>&1
fi
```

No changes to `loop.sh` build mode.

---

## Files Summary

| File | Action |
|---|---|
| `scripts/cleanup_specs.sh` | Create |
| `skills/req-prd/SKILL.md` | Create |
| `skills/req-slc/SKILL.md` | Create |
| `PROMPT_plan_slc.md` | Create |
| `loop.sh` | Add `plan-slc` mode + PR_BODY cleanup note |
| `skills/ralph/SKILL.md` | Modify Steps 1 and 3 |

**Unchanged:** `PROMPT_plan.md`, `PROMPT_build.md`, `PROMPT_plan_work.md`

---

## Sequencing

1. **Task 1** — `cleanup_specs.sh` — standalone, zero blast radius
2. **Task 4** — `PROMPT_plan_slc.md` — new file, no dependencies
3. **Task 5** — `loop.sh plan-slc` — small addition, depends on Task 4
4. **Task 2** — `Req-PRD` — additive, no existing code touched
5. **Task 3** — `Req-SLC` — additive, depends on Task 4/5 design being settled
6. **Task 6** — `/ralph` skill update — touches existing skill; do last

---

## Key Design Decisions

**Why specs cover all activities/depths (not just the slice):**
Specs are a permanent reference. Release 2 re-runs planning — it picks the next slice from
what's still MISSING. No need to re-run `Req-SLC`. The build agent follows `IMPLEMENTATION_PLAN.md`
(scoped to slice), not raw specs, so full specs don't cause scope creep.

**Why SLC slicing is the planning prompt's job (not the skill's):**
The planning prompt has full context: specs, AUDIENCE_JTBD.md, and current code state (gap analysis).
It can recommend what's actually missing vs already done. The skill runs before any code exists.

**Why AUDIENCE_JTBD.md is never archived:**
It's audience context, not feature context. It's referenced every planning loop to anchor
SLC slice reasoning. Only activity specs get archived to `specs/done/`.

---

## Reference Files

- Existing spec format: `skills/spec/SKILL.md`
- Existing ralph skill: `skills/ralph/SKILL.md`
- Planning prompts: `PROMPT_plan.md`, `PROMPT_plan_work.md`
- Loop modes: `loop.sh` lines 23–33 (mode parsing), 196–218 (plan/plan-work)
- Script patterns: `scripts/check_architecture.sh`, `scripts/consensus_judge.sh`
