You are performing parallel build decomposition for a multi-spec autonomous pipeline.

TASK: Read ALL specs, identify shared dependencies vs per-spec tasks, and output
a structured plan that the orchestrator will split into separate build phases.
Do NOT implement anything. Analysis and planning only.

---

STEP 1 — Read inputs (use subagents for all file reads)

- Read every file in ralph/specs/ — understand ALL specs to be built
- Read ralph/AGENTS.md — build system, architecture, gates
- Survey the source directory structure (list files, do not read every file)
- Read protocols/interfaces layer — what already exists

STEP 2 — Identify shared dependencies

For EACH spec, list the types, protocols, repository methods, and models it needs.
Cross-reference across specs. A dependency is SHARED if 2+ specs need it.

Examples of shared dependencies:
- A repository method both specs call (e.g. fetchSets(from:to:))
- A protocol both specs conform to
- A model extension both specs use
- A utility both specs import

STEP 3 — Gap analysis

For each task (shared and per-spec):
- Search the codebase to determine status: DONE / PARTIAL / MISSING
- Note WHERE it would live (file path, layer)
- Note the reference pattern to follow (existing sibling implementation)

Skip DONE tasks entirely — do not include them in the output.

STEP 4 — Write the combined plan

Output format — use EXACTLY this structure with these headers:

```
# Parallel Implementation Plan
# Generated from: ralph/specs/[comma-separated filenames]
# [date]

## Shared Dependencies
[Tasks needed by 2+ specs. Built first, before parallel phase.]

- [ ] [task] — [target file] — follow [reference file] — needed by: [spec-1, spec-2]
...

(If no shared dependencies, write: "(none)")

## Per-Spec: [spec-filename-without-extension]

- [ ] [task] — [target file] — follow [reference file]
...

## Per-Spec: [next-spec-filename-without-extension]

- [ ] [task] — [target file] — follow [reference file]
...

(repeat for each spec)
```

Rules:
- One atomic task per line — the build loop picks ONE per iteration
- Order by dependency within each section
- Tests are separate tasks from implementation (list them last in each section)
- Include target file path and reference pattern per task
- For test tasks: find an existing test file and reference it as the pattern
- SHARED section only contains tasks needed by 2+ specs — do not over-share
- Each Per-Spec section is INDEPENDENT — buildable without the other specs (assuming shared deps are done)

STEP 5 — Commit:
git add IMPLEMENTATION_PLAN.md && git -c commit.gpgsign=false commit -m "ralph: parallel plan from specs"

---

CONSTRAINTS

- Do not implement anything
- Do not modify any source files
- Every task must be in exactly ONE section (shared or one per-spec, never duplicated)
- Per-Spec sections must be buildable independently after shared deps are done
