You are performing gap analysis scoped to a specific work description.

WORK SCOPE: ${WORK_DESCRIPTION}

TASK: Analyse the codebase relative to the work scope above and generate
IMPLEMENTATION_PLAN.md containing only tasks relevant to that scope.
Do NOT implement anything. Analysis and planning only.

---

STEP 1 — Read inputs (use subagents for all file reads)

- Read every file in ralph/specs/ — look for specs related to the work scope
- If a spec directory has an assets/ subdirectory, a task whose result is visual MUST name
  the asset file it has to match. The build agent reads at most 2 images per iteration and
  uses the task text to pick which.
- Read ralph/AGENTS.md — understand build system, architecture, and gates
- Survey source files relevant to the work scope only
- Read protocols/interfaces in the relevant layer

STEP 2 — For each acceptance criterion relevant to the work scope:

- Search to determine status: DONE / PARTIAL / MISSING
- Note WHERE it would live (file path, layer)
- Note the reference pattern to follow

STEP 3 — Write IMPLEMENTATION_PLAN.md scoped to: ${WORK_DESCRIPTION}

Format:

```
# Implementation Plan — ${WORK_DESCRIPTION}
# Generated from: ralph/specs/[filenames]
# [date]

## Tasks

- [ ] [task description] — [target file path] — follow [reference file]
...

## Done

(empty — build loop moves items here as it commits)
```

Rules:

- Only include tasks relevant to the work scope
- One atomic task per line — the build loop picks ONE per iteration
- **Each task must leave the build green on its own.** If a rename touches 15 files, that's one task, not 15. If adding a protocol requires a conformer, both go in the same task. The test: "if the loop stops after this task, does the project still compile and tests still pass?"
- Order by dependency
- Tests after implementation tasks
- Include target file path and reference pattern per task
- For test tasks: find an existing test file in the project and reference it as the pattern.
  Search for *Tests.swift files. Note the testing framework used (XCTest vs Swift Testing),
  how @MainActor ViewModels are tested, and how ModelContext/ModelContainer is set up.
  The build agent will follow this pattern exactly.

STEP 4 — Commit (best-effort — the file may be gitignored by design):
git add -f IMPLEMENTATION_PLAN.md 2>/dev/null && git -c commit.gpgsign=false commit -m "ralph: plan — ${WORK_DESCRIPTION}" 2>/dev/null || true

---

CONSTRAINTS

- Do not implement anything
- Do not modify any source files
- Do not modify the project file (.xcodeproj)
- Scope is strictly: ${WORK_DESCRIPTION} — ignore anything outside it

