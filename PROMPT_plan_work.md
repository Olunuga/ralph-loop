You are performing gap analysis scoped to a specific work description.

WORK SCOPE: ${WORK_DESCRIPTION}

TASK: Analyse the codebase relative to the work scope above and generate
IMPLEMENTATION_PLAN.md containing only tasks relevant to that scope.
Do NOT implement anything. Analysis and planning only.

---

STEP 1 — Read inputs (use subagents for all file reads)

- Read every file in ralph/specs/ — look for specs related to the work scope
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
- One atomic task per line
- Order by dependency
- Tests after implementation tasks
- Include target file path and reference pattern per task
- For test tasks: find an existing test file in the project and reference it as the pattern.
  Search for *Tests.swift files. Note the testing framework used (XCTest vs Swift Testing),
  how @MainActor ViewModels are tested, and how ModelContext/ModelContainer is set up.
  The build agent will follow this pattern exactly.

STEP 4 — Commit:
git add IMPLEMENTATION_PLAN.md && git -c commit.gpgsign=false commit -m "ralph: plan — ${WORK_DESCRIPTION}"

---

CONSTRAINTS

- Do not implement anything
- Do not modify any source files
- Do not modify the project file (.xcodeproj)
- Scope is strictly: ${WORK_DESCRIPTION} — ignore anything outside it

