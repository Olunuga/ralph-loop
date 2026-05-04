---
name: req-slc
description: Gather requirements for a greenfield project using SLC release discipline — produces AUDIENCE_JTBD.md and activity specs across all capability depths
arguments: [ref]
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are gathering requirements for a greenfield project with SLC (Simple, Lovable, Complete)
release discipline using a Jobs to Be Done approach.

Reference / project slug: $ref

Read ralph/AGENTS.md if it exists to understand the project context.
Read ralph/AUDIENCE_JTBD.md if it exists — it may contain prior audience/JTBD work to build on.
Read any existing files in ralph/specs/ to understand what's already been captured.

## Key principle

This skill captures the FULL activity space — all activities at all capability depths.
SLC slicing (which activities get built first) is the planning prompt's job, not this skill's.
Write specs for everything the product could do, so the planner can recommend the best first slice.

## Decomposition model

**Audience** → defines who has the JTBDs.
**JTBD** → outcome the audience wants ("When [trigger], I want to [action], so I [outcome]").
**Activity** → verb the user performs to accomplish a JTBD ("upload photo", "extract colors").
**Capability depth** → levels of sophistication for an activity (basic → enhanced → advanced).

Activities become columns in a story map. Depths are rows:
```
UPLOAD    →   EXTRACT    →   ARRANGE     →   SHARE
basic         auto           manual          export
bulk          palette        templates       collab
batch         AI themes      auto-layout     embed
```

## Step 1 — Audience and JTBDs

Use AskUserQuestion:

**Q1.** "Who are the audiences? For each: what role or context puts them in front of this product? There may be multiple connected audiences — e.g. 'designer creates, client reviews'."

**Q2.** "For each audience, what are their Jobs to Be Done? Format: 'When [trigger], I want to [action], so I [outcome].'"

## Step 2 — Activities and capability depths

Use AskUserQuestion:

**Q3.** "For each JTBD, what activities does the user perform to accomplish it? Use verbs — e.g. 'upload photo', 'extract colors', 'arrange layout'. List as: JTBD → Activity A, Activity B, Activity C."

**Q4.** "For each activity, what are the capability depths — from basic to advanced? Example for 'upload photo': basic = single file, enhanced = bulk upload, advanced = batch + URL import. List depths per activity."

## Step 3 — Present story map

Construct a text story map grid (activities as columns, depths as rows) and show it to the user:

Use AskUserQuestion:

"Here is the activity story map I've built from your inputs:

[story map table]

Does this capture everything? Are there activities or depths to add or remove? Reply with changes or 'looks good'."

Revise until the user confirms.

## Step 4 — Detail each activity

For each confirmed activity, use AskUserQuestion to gather spec detail:

**Q5 (per activity).** "For [activity]: what needs to be built at each depth? Include structs, methods, UI, services, wiring. What are the automated acceptance criteria at each depth?"

**Q6.** "What's explicitly out of scope for the entire product?"

## Step 5 — Draft AUDIENCE_JTBD.md

Draft the audience/JTBD document:

```markdown
# Audience & Jobs to Be Done

## Audiences

### [Audience Name]
[Role/context description — what puts them in front of this product]

#### Jobs to Be Done
- When [trigger], I want to [action], so I [outcome].
- When [trigger], I want to [action], so I [outcome].

### [Audience Name 2] (if applicable)
...
```

## Step 6 — Draft activity specs

Write one spec per activity using this format:

```markdown
# [activity-slug] — [Activity Name]

## Job to Be Done
When [trigger], [action], so [outcome]. (The JTBD this activity serves)

## Activity
[Verb description of what the user does]

## Capability Depths

### Basic
**What this delivers:** [one sentence — the simplest complete version]

**What to build:**
[structs, methods, UI, services, wiring for basic depth]

**Acceptance Criteria — Automated**
- [ ] [verifiable criterion]

**Acceptance Criteria — Human**
- [ ] [manual verification]

### Enhanced
**What this adds:** [one sentence — what enhanced adds over basic]

**What to build:**
[additions for enhanced depth]

**Acceptance Criteria — Automated**
- [ ] [verifiable criterion]

**Acceptance Criteria — Human**
- [ ] [manual verification]

### Advanced (if applicable)
**What this adds:** [one sentence]

**What to build:**
[additions for advanced depth]

**Acceptance Criteria — Automated**
- [ ] [verifiable criterion]

## Out of Scope
- [explicit exclusions for this activity]
```

## Step 7 — Approval loop

Use AskUserQuestion with ALL content pasted in:

"---
AUDIENCE_JTBD.md:
[full content]
---
[spec for activity 1]
---
[spec for activity 2]
---
...
---
Do these look correct? Reply 'yes' to save, or give feedback to revise."

Revise and repeat until the user approves.

## Step 8 — Write to branch

Derive the branch slug from $ref (kebab-case, under 30 chars).

```bash
git checkout -b spec/<slug>
```

Write AUDIENCE_JTBD.md first (it's not a spec — it lives at ralph/AUDIENCE_JTBD.md):

```bash
git add ralph/AUDIENCE_JTBD.md
git commit -m "spec: audience and JTBDs"
```

Write each activity spec and commit individually:

```bash
git add ralph/specs/<activity-slug>.md
git commit -m "spec: <activity-slug>"
```

After all files committed, return to previous branch:

```bash
git checkout -
```

Confirm: "N activity specs + AUDIENCE_JTBD.md written to branch spec/<slug>.
SLC slicing happens at planning time — run /ralph <slug> when ready."
