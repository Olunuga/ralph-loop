You are performing SLC-aware gap analysis for an autonomous build pipeline.

TASK: Sequence activities into a user journey, recommend the next SLC release slice,
and generate a scoped IMPLEMENTATION_PLAN.md.
Do NOT implement anything. Analysis and planning only.

---

STEP 1 — Read inputs (use subagents for all file reads)

- Read ralph/AUDIENCE_JTBD.md — who we're building for and their Jobs to Be Done
- Read every file in ralph/specs/ — activities and their capability depths
- Read ralph/AGENTS.md — build system, architecture, guardrails
- Survey the source directory structure (list files, do not read every file)
- Read the protocols/interfaces layer — these define what must be conformed to

STEP 2 — Sequence activities into a user journey

Using the activities in ralph/specs/ and the JTBDs in ralph/AUDIENCE_JTBD.md, arrange
activities as columns in a user journey (left = earlier in journey, right = later):

Example structure:
  ACTIVITY_A  →  ACTIVITY_B  →  ACTIVITY_C  →  ACTIVITY_D
  basic            basic          basic           basic
  enhanced         enhanced       enhanced        enhanced
  advanced                        advanced

Note cross-activity dependencies: which activities must exist before others can be useful.

STEP 3 — Gap analysis per activity and capability depth

For each activity at each capability depth defined in its spec:
- Search the codebase to determine status: DONE / PARTIAL / MISSING
- Note WHERE in the codebase it would live (file path, layer)
- Note the reference pattern to follow (existing sibling implementation)

STEP 4 — Recommend next SLC slice

Using the journey map and gap analysis, recommend which activities at which capability
depth form the most valuable next release. Apply SLC criteria:

- Simple  — narrow scope, achievable fast. Not every activity, not every depth.
- Lovable — people actually want to use it within that scope. Delightful.
- Complete — fully accomplishes a meaningful job. Not a broken preview.

Prefer thin horizontal slices. A slice with two activities done fully beats four activities
done partially. Activities with unsatisfied dependencies must be deferred.

STEP 5 — Write IMPLEMENTATION_PLAN.md using this exact format:

```
# Implementation Plan — [SLC Release Name]
# Generated from: ralph/specs/[comma-separated filenames included in this slice]
# [date]

## SLC Release
[2–3 sentences: what's included, why this forms a Simple/Lovable/Complete release,
and what makes it meaningful for the audience in AUDIENCE_JTBD.md]

## Deferred
- [activity or depth]: [one-line reason — dependency, scope, complexity]
...

## Tasks

- [ ] [task description] — [target file path] — follow [reference file]
...

## Done

(empty — build loop moves items here as it commits)
```

Rules for tasks:
- Only include tasks for the recommended SLC slice
- One atomic task per line — the build loop picks ONE per iteration
- Order by dependency (things needed by other things go first)
- Tests are separate tasks from implementation (list them last)
- Include target file path and reference pattern per task

STEP 6 — Commit:
git add IMPLEMENTATION_PLAN.md && git commit -m "ralph: generate SLC plan from specs"

---

CONSTRAINTS

- Do not implement anything
- Do not modify any source files
- Tasks must cover only the recommended SLC slice — exclude deferred activities entirely
- Update ralph/AGENTS.md only if you discover something operationally important
