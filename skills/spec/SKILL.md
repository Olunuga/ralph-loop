---
name: spec
description: Create or update a ralph spec for a feature or bug fix through a structured JTBD conversation
arguments: [ref]
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are helping define or update a Job to Be Done for the Ralph autonomous development pipeline.

Reference: $ref

If $ref is a short slug or ticket ID (e.g. GYM-001, auth-flow), use it as the spec filename prefix.
If $ref is a longer description (e.g. "add workout summary screen"), derive a kebab-case slug from it.

## Step 0 — Detect mode

Check whether a spec branch already exists:
```bash
git rev-parse --verify "spec/$ref" 2>/dev/null && echo "exists" || echo "new"
```

- If **"new"**: proceed to Step 1 (new spec flow).
- If **"exists"**: proceed to **Update mode** below.

---

## Update mode

An existing spec was found. Enter update mode to add a bug fix or change.

Find the spec file(s) on the branch:
```bash
git show "spec/$ref:ralph/specs/" 2>/dev/null | grep '\.md$' | grep -v '^done/'
```

Read the spec file(s). If there are multiple, read each one's title line.

Show the current spec content to the user and use AskUserQuestion:
"Found existing spec for '$ref'. Here's what it currently says:

---
[full current spec content]
---

What needs to change? Describe the bug, regression, or update you want to address."

Ask follow-up questions as needed to understand the change fully. Then update the spec — revising affected sections, adding new acceptance criteria, or extending the scope list as appropriate.

Use AskUserQuestion with the updated spec:
"---
[updated spec content]
---
Does this look right? Reply 'yes' to save, or give feedback to revise."

Revise and repeat until approved.

Check out the existing spec branch and commit the update:
```bash
git checkout "spec/$ref"
```

Write the updated spec file to its existing path (`ralph/specs/<slug>.md`).

```bash
git add ralph/specs/
git commit -m "spec: update $ref"
git checkout -
```

Confirm: "Spec updated on branch spec/$ref. Run /ralph $ref to resume the pipeline with the fix."

---

## Step 1 — Load context

Read `ralph/AGENTS.md` to understand the project architecture, layers, and guardrails.
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
- [ ] No force unwraps (try!, !., as!) in new or modified code
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
git checkout -b "spec/<slug>"
```

Write the approved spec to `ralph/specs/<slug>.md`.

```bash
git add ralph/specs/<slug>.md
git commit -m "spec: <slug>"
git checkout -
```

Confirm: "Spec written to branch spec/<slug> — run /ralph <slug> when ready."
