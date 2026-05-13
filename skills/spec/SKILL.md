---
name: spec
description: Create a ralph spec for a new feature through a structured JTBD conversation
arguments: [ref]
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are helping define a Job to Be Done for the Ralph autonomous development pipeline.

Reference: $ref

If $ref is a short slug or ticket ID (e.g. GYM-001, auth-flow), use it as the spec filename prefix.
If $ref is a longer description (e.g. "add workout summary screen"), derive a kebab-case slug from it.

## Step 1 — Load context

Read `ralph/AGENTS.md` to understand the project architecture, layers, and gates.
Read any existing files in `ralph/specs/` to understand the spec format and what's already been defined.

## Step 2 — JTBD conversation

Use AskUserQuestion to gather the following — ask each question in turn, ask follow-ups if the answer is vague, and stop when you have enough to write a complete spec:

1. "What's the job to be done? Describe it as: When [trigger], I want to [action], so I [outcome]."
2. "Which files will be involved? (new files to create, files to modify, files to reference only)"
3. "Walk me through what needs to be built — structs, methods, UI, wiring. As much detail as you have."
4. "What are the automated acceptance criteria? (things the build system can verify)"
5. "What will you manually verify once it's built?"
6. "What's explicitly out of scope?"

## Step 3 — Draft the spec

Write a complete spec following this exact format:

```markdown
# <ref> — [Feature Name]

## Job to Be Done
When [trigger], [action], so [outcome].

## Scope
- New file: ...
- Modify: ...
- Read-only reference: ...
- Do NOT touch: ...

## What to Build

[Detailed sections — struct definitions, method signatures, UI content, sheet wiring, etc.]

## Acceptance Criteria — Automated
- [ ] xcodebuild build passes, zero errors
- [ ] Unit tests pass unaffected
- [ ] All static and LLM gates pass
- [ ] [feature-specific checks]

## Acceptance Criteria — Human
- [ ] [what to manually verify on device/simulator]

## Out of Scope
- [explicit exclusions]
```

## Step 4 — Approval loop

Use AskUserQuestion with the full spec pasted into the question text, followed by the prompt. Format it exactly like this:

"---
<full spec markdown here>
---
Does this spec look correct? Reply 'yes' to save, or give feedback to revise."

Revise and repeat until the user approves.

## Step 5 — Write

Derive the filename slug from $ref:
- If $ref is already a short slug or ID (no spaces, under 30 chars), use it directly as the prefix
- If $ref is a longer description, convert to kebab-case and use that as the full filename

Create a spec branch and commit the spec there — do not write directly to main:
```bash
git checkout -b spec/<slug>
```

Write the approved spec to `ralph/specs/<slug>.md`.

```bash
git add ralph/specs/<slug>.md
git -c commit.gpgsign=false commit -m "spec: <slug>"
git checkout -
```

Confirm: "Spec written to branch spec/<slug> — run /ralph-loop:run <slug> when ready."
