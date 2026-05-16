---
name: req-prd
description: Requirements gathering for a JTBD spanning multiple topics of concern — produces one spec per topic
arguments: [ref]
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are gathering requirements for a Job to Be Done that spans multiple topics of concern.

Reference / project slug: $ref

Read ralph/AGENTS.md if it exists to understand the project context and architecture.
Read any existing files in ralph/specs/ to understand the spec format and what's already defined.

## Decomposition model

One JTBD breaks into multiple **topics of concern** — distinct capability aspects.
Scope test: can you describe the topic in ONE sentence without "and"?
- ✓ "The color extraction system identifies dominant colors from uploaded images"
- ✗ "The user system handles auth, profiles, and billing" → 3 separate topics

Each topic of concern becomes one spec. There is one JTBD — not one per topic.

## Step 1 — JTBD conversation

Use AskUserQuestion to gather the following in turn. Ask follow-ups if answers are vague.

**Q1.** "What's the job to be done? Describe it as: When [trigger], I want to [action], so I [outcome]."

**Q2.** "What are the distinct topics of concern within this job? Each topic should pass the one-sentence-without-and test."

**Q3 (per topic).** "For [topic]: what should the user be able to do, and what does success look like? Describe the experience and outcome."

**Q4.** "What are the automated acceptance criteria per topic — things the build system can verify?"

**Q5.** "What's explicitly out of scope?"

Do not ask the user about implementation details — structs, classes, methods, wiring. That is Ralph's job.

## Step 2 — Draft specs

Based on the behavioral descriptions, AGENTS.md patterns, and existing codebase, write one spec
per topic. Infer the appropriate implementation approach yourself.

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

[Inferred from behavioral description and codebase patterns]

## Acceptance Criteria — Automated
- [ ] Build passes, zero errors
- [ ] Unit tests pass unaffected
- [ ] No force unwraps (try!, !., as!) in new or modified code
- [ ] [topic-specific criteria]

## Acceptance Criteria — Human
- [ ] [behavioral outcome to verify]

## Out of Scope
- [explicit exclusions]
```

## Step 3 — Approval loop

Use AskUserQuestion with ALL specs pasted in:

"---
[full spec for topic 1]
---
[full spec for topic 2]
---
...
---
Do these look correct? Reply 'yes' to save, or give feedback to revise."

Revise and repeat until the user approves.

## Step 4 — Write to branch

Ask which branch to start from:

```bash
echo "Recent branches:" && git branch --sort=-committerdate --format='%(refname:short)' | head -8
```

Use AskUserQuestion: "Which branch should this spec branch from? (default: main)" with the branch list.

Create a worktree for the spec branch so the current working tree is not affected.

**IMPORTANT:** All `git worktree add` commands MUST use `dangerouslyDisableSandbox: true`.

Try in order, stopping at the first success:

1. Create new branch from selected base:
```bash
git worktree add .worktrees/spec-<slug> -b spec/<slug> <BASE_BRANCH> 2>&1
```

2. If branch already exists, checkout without `-b`:
```bash
git worktree add .worktrees/spec-<slug> spec/<slug> 2>&1
```

3. If worktree directory already exists, continue — it's ready.

Write each spec to `.worktrees/spec-<slug>/ralph/specs/<topic-slug>.md` using the Write tool.

Commit each spec individually (separate Bash calls, no `&&` chains):

```bash
git -C .worktrees/spec-<slug> add ralph/specs/<topic-slug>.md
```

```bash
git -C .worktrees/spec-<slug> -c commit.gpgsign=false commit -m "spec: <topic-slug>"
```

After all specs are committed, clean up the worktree (branch is kept):
```bash
git worktree remove .worktrees/spec-<slug> 2>&1
```

Do NOT suggest a build order or implementation sequence — that is the planning prompt's job, not the spec's.

Confirm: "N specs written to branch spec/<slug> — run /ralph-loop:run <slug> when ready."
