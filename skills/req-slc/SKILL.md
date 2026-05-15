---
name: req-slc
description: Requirements gathering with SLC release discipline — captures audience, JTBDs, and full activity space across all capability depths
arguments: [ref]
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are gathering requirements using a JTBD → Story Map → SLC approach.

Reference / project slug: $ref

Read ralph/AGENTS.md if it exists to understand the project context.
Read ralph/AUDIENCE_JTBD.md if it exists — build on any prior audience/JTBD work.
Read any existing files in ralph/specs/ to understand what's already been captured.

## Key principle

Capture the FULL activity space — all activities at all capability depths.
SLC slicing (which activities get built first) is the planning prompt's job, not this skill's.
Do not ask the user to choose a slice. Write specs for everything the product could do.

## Decomposition model

**Audience** → who has the JTBDs (role/context, not demographics).
**JTBD** → outcome the audience wants. Format: "When [trigger], I want to [action], so I [outcome]."
**Activity** → verb the user performs to accomplish a JTBD ("upload photo", "extract colors").
**Capability depth** → levels of sophistication for an activity (basic → enhanced → advanced).

Activities are columns in a story map. Depths are rows:
```
UPLOAD    →   EXTRACT    →   ARRANGE     →   SHARE
basic         auto           manual          export
bulk          palette        templates       collab
batch         AI themes      auto-layout     embed
```

## Step 1 — Audience and JTBDs

Use AskUserQuestion:

**Q1.** "Who are the audiences? For each: what role or context puts them in front of this product? There may be multiple connected audiences — e.g. 'designer creates, client reviews'."

**Q2.** "For each audience, what are their Jobs to Be Done — the outcomes they want? Format: 'When [trigger], I want to [action], so I [outcome].'"

## Step 2 — Activities and capability depths

Use AskUserQuestion:

**Q3.** "For each JTBD, what activities does the user perform to accomplish it? Use verbs — e.g. 'upload photo', 'extract colors', 'arrange layout'. List as: JTBD → Activity A, Activity B, Activity C."

**Q4.** "For each activity, what are the capability depths — from basic to advanced? Example for 'upload photo': basic = single file, enhanced = bulk upload, advanced = batch + URL import."

## Step 3 — Present story map

Build a text story map grid and show it to the user:

Use AskUserQuestion:

"Here is the story map I've built from your inputs:

[story map table — activities as columns, depths as rows]

Does this capture everything? Any activities or depths to add or remove? Reply with changes or 'looks good'."

Revise until the user confirms the activity set.

## Step 4 — Success criteria per activity

For each confirmed activity, use AskUserQuestion:

**Q5 (per activity).** "For [activity]: at each depth, what does the user experience and what does success look like? What are the automated acceptance criteria at each depth?"

Do not ask about implementation details — structs, classes, methods, wiring. That is Ralph's job.

## Step 5 — Out of scope

Use AskUserQuestion:

**Q6.** "What's explicitly out of scope for the entire product?"

## Step 6 — Draft AUDIENCE_JTBD.md

```markdown
# Audience & Jobs to Be Done

## Audiences

### [Audience Name]
[Role/context — what puts them in front of this product]

#### Jobs to Be Done
- When [trigger], I want to [action], so I [outcome].
```

## Step 7 — Draft activity specs

Write one spec per activity. Infer implementation details from the behavioral descriptions
and AGENTS.md patterns — do not ask the user.

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
[Inferred from behavioral description and codebase patterns]

**Acceptance Criteria — Automated**
- [ ] [verifiable criterion]

**Acceptance Criteria — Human**
- [ ] [success experience from Q5]

### Enhanced
**What this adds:** [one sentence]

**What to build:**
[Inferred additions for enhanced depth]

**Acceptance Criteria — Automated**
- [ ] [verifiable criterion]

**Acceptance Criteria — Human**
- [ ] [success experience from Q5]

### Advanced (if applicable)
**What this adds:** [one sentence]

**What to build:**
[Inferred additions for advanced depth]

**Acceptance Criteria — Automated**
- [ ] [verifiable criterion]

## Out of Scope
- [explicit exclusions]
```

## Step 8 — Approval loop

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

## Step 9 — Write to branch

```bash
git checkout -b spec/<slug>
```

Write AUDIENCE_JTBD.md first (lives at ralph/AUDIENCE_JTBD.md, not in specs/):

```bash
git add ralph/AUDIENCE_JTBD.md
git commit -m "spec: audience and JTBDs"
```

Write each activity spec and commit individually:

```bash
git add ralph/specs/<activity-slug>.md
git commit -m "spec: <activity-slug>"
```

Return to previous branch:

```bash
git checkout -
```

Confirm: "N activity specs + AUDIENCE_JTBD.md written to branch spec/<slug>.
SLC slicing happens at planning time — run /ralph-loop:run <slug> when ready."
