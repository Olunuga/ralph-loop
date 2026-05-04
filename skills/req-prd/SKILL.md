---
name: req-prd
description: Gather requirements for a greenfield project and produce multiple spec files — one per topic of concern
arguments: [ref]
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are gathering requirements for a greenfield project using a Jobs to Be Done approach.

Reference / project slug: $ref

Read ralph/AGENTS.md if it exists to understand the project context.
Read any existing files in ralph/specs/ to understand the spec format.

## Decomposition model

Break JTBDs into **topics of concern** — distinct capability aspects.
Scope test: can you describe it in ONE sentence without "and"?
- ✓ "The color extraction system analyzes images to identify dominant colors"
- ✗ "The user system handles auth, profiles, and billing" → 3 separate topics

## Step 1 — JTBD conversation

Use AskUserQuestion to gather the following. Ask each question in turn; ask follow-ups if vague.

**Q1.** "What is the project? Give it a name and describe its purpose in one sentence."

**Q2.** "Who are the audiences? For each: what role or context puts them in front of this product? (There may be multiple connected audiences — e.g. 'designer creates, client reviews'.)"

**Q3.** "For each audience, what are their Jobs to Be Done? These are outcomes they want — not features. Format: 'When [trigger], I want to [action], so I [outcome].'"

**Q4.** "For each JTBD, what are the distinct topics of concern? Apply the one-sentence-without-and test to each. List them as: JTBD → Topic A, Topic B, Topic C."

**Q5.** "For each topic of concern: walk me through what needs to be built — structs, methods, UI, services, wiring. As much detail as you have."

**Q6.** "What are the automated acceptance criteria per topic? (things the build system can verify)"

**Q7.** "What's explicitly out of scope?"

## Step 2 — Draft specs

Write one spec per topic of concern using this exact format:

```markdown
# <ref>/<topic-slug> — [Topic Name]

## Job to Be Done
When [trigger], [action], so [outcome].

## Scope
- New file: ...
- Modify: ...
- Read-only reference: ...
- Do NOT touch: ...

## What to Build

[Detailed sections — struct definitions, method signatures, UI content, wiring, etc.]

## Acceptance Criteria — Automated
- [ ] Build passes, zero errors
- [ ] Unit tests pass unaffected
- [ ] No force unwraps (try!, !., as!) in new or modified code
- [ ] [topic-specific checks]

## Acceptance Criteria — Human
- [ ] [what to manually verify]

## Out of Scope
- [explicit exclusions]
```

## Step 3 — Approval loop

Use AskUserQuestion with the following format — paste ALL specs into the question:

"---
[full spec for topic 1]
---
[full spec for topic 2]
---
...
---
Do these specs look correct? Reply 'yes' to save, or give feedback to revise."

Revise and repeat until the user approves.

## Step 4 — Write to branch

Derive the branch slug from $ref (kebab-case, under 30 chars).

```bash
git checkout -b spec/<slug>
```

Write each spec to `ralph/specs/<topic-slug>.md` and commit individually:

```bash
git add ralph/specs/<topic-slug>.md
git commit -m "spec: <topic-slug>"
```

After all specs committed, return to previous branch:

```bash
git checkout -
```

Confirm: "N specs written to branch spec/<slug> — run /ralph <slug> when ready."
