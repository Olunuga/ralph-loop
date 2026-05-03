You are performing gap analysis for an autonomous build pipeline.

TASK: Compare specs against the current codebase and generate IMPLEMENTATION_PLAN.md.
Do NOT implement anything. Analysis and planning only.

---

STEP 1 — Read inputs (use subagents for all file reads)

- Read every file in ralph/specs/ — these are the source of truth
- Read ralph/AGENTS.md — understand build system, architecture, and guardrails
- Survey the source directory structure (list files, do not read every file)
- Read the protocols/interfaces layer — these define what must be conformed to

STEP 2 — For each acceptance criterion in every spec:

- Search the codebase to determine its status:
  - DONE: fully implemented and testable
  - PARTIAL: exists but incomplete or missing tests
  - MISSING: not present at all
- Note WHERE in the codebase each criterion would live (file path, layer)
- Note the reference pattern to follow (existing sibling implementation)

STEP 3 — Write IMPLEMENTATION_PLAN.md using this exact format:

```
# Implementation Plan
# Generated from: ralph/specs/[filenames]
# [date]

## Tasks

- [ ] [task description] — [target file path] — follow [reference file]
- [ ] [task description] — [target file path] — follow [reference file]
...

## Done

(empty — build loop moves items here as it commits)
```

Rules for tasks:

- One atomic task per line — the build loop picks ONE per iteration
- Order by dependency (things needed by other things go first)
- Tests are separate tasks from implementation (list them last)
- Include the target file path so the build agent knows exactly where to work
- Include the reference file so the build agent knows exactly what pattern to follow

STEP 4 — Commit:
git add IMPLEMENTATION_PLAN.md && git commit -m "ralph: generate plan from specs"

---

CONSTRAINTS

- Do not implement anything
- Do not modify any source files
- Do not modify the project file (Geyns.xcodeproj)
- Update ralph/AGENTS.md only if you discover something operationally important about the build/test setup

