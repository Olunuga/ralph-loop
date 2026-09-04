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

## Story Map

Activities are columns. Capability depths are rows. Each cell holds the cell id and what
that depth delivers. `/ralph-loop:slice` reads this table to enumerate cells, so keep the
format exact: one table, cell ids in backticks, `-` for a depth an activity does not have.

| Depth | [Activity A] | [Activity B] |
|---|---|---|
| **Basic** | `activity-a-basic` single file | `activity-b-basic` top 5 |
| **Enhanced** | `activity-a-enhanced` bulk upload | `activity-b-enhanced` adjustable count |
| **Advanced** | `activity-a-advanced` URL import | - |
```

The cell id is `<activity-slug>-<depth>`, lowercase and hyphenated. It becomes the OpenSpec
change name when a slice is materialised, so it must be stable and unique.

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

## Step 8b — Design system prompt

Read `$RALPH_PLUGIN_DIR/prompts/DESIGN_SYSTEM_PROMPT_TEMPLATE.md` and fill its placeholders
from what you just captured:

- `${PLATFORM}` from `ralph/config.sh`, or ask if it is not set
- `${PRODUCT_SUMMARY}` two or three sentences on what the product is
- `${AUDIENCES}` and `${JOBS_TO_BE_DONE}` from AUDIENCE_JTBD.md
- `${ACTIVITIES}` every activity in the story map, all depths, because the system has to
  cover the whole product and not one release

Hold the filled text. Step 9 writes it to
`.worktrees/spec-<slug>/ralph/design/SYSTEM_PROMPT.md` once the worktree exists, and
Step 10 tells the user what to do with it.

Do not create `ralph/design/system/` yourself. It exists once the user places a handoff.

## Step 9 — Write to branch

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

If BASE_BRANCH is not `main`, record it so gates diff against the correct base:
```bash
echo "<BASE_BRANCH>" > .worktrees/spec-<slug>/ralph/.diff_base
```

Write AUDIENCE_JTBD.md first (lives at `.worktrees/spec-<slug>/ralph/AUDIENCE_JTBD.md`, not in specs/) using the Write tool.

Then write the Step 8b text to `.worktrees/spec-<slug>/ralph/design/SYSTEM_PROMPT.md` using
the Write tool. The worktree exists only from this point, so an earlier write lands outside it.

Commit (separate Bash calls):
```bash
git -C .worktrees/spec-<slug> add ralph/AUDIENCE_JTBD.md ralph/design/SYSTEM_PROMPT.md
```
```bash
git -C .worktrees/spec-<slug> -c commit.gpgsign=false commit -m "spec: audience and JTBDs"
```

Write each activity spec to `.worktrees/spec-<slug>/ralph/specs/<activity-slug>.md` using the Write tool.

### Design references

Ask whether any topic has a design reference. For each one supplied, verify the path exists,
warn above 2 MB, then write that spec as a directory instead of a single file:
`ralph/specs/<slug>/spec.md` with the image in `ralph/specs/<slug>/assets/`. The spec text
MUST name each asset and say what it shows. A spec with no reference stays a single file,
and gets no empty `assets/` directory.


Commit each individually:
```bash
git -C .worktrees/spec-<slug> add ralph/specs/
```
```bash
git -C .worktrees/spec-<slug> -c commit.gpgsign=false commit -m "spec: <activity-slug>"
```

After all specs are committed, clean up the worktree (branch is kept):
```bash
git worktree remove .worktrees/spec-<slug> 2>&1
```

Do NOT suggest a build order or implementation sequence. That is the planning prompt's job.

---

## Step 10: Report, then get the branch into the working tree

Every downstream command reads the checked-out working tree, not the branch. The specs
are on `spec/<slug>` and the worktree is gone, so nothing sees them yet. Say this first.

```bash
git rev-parse --abbrev-ref HEAD
```

That is `<CURRENT_BRANCH>`. Report what was written:

```
N activity specs + AUDIENCE_JTBD.md written to branch spec/<slug>.
Design system prompt written to ralph/design/SYSTEM_PROMPT.md on that branch.

Nothing reads them yet. /ralph-loop:slice and /ralph-loop:run both read the checked-out
working tree, and this tree is still on <CURRENT_BRANCH>.
```

Use AskUserQuestion: "Bring the specs into this working tree now?" with these options.

- **Merge into <CURRENT_BRANCH>**: run `git merge --no-ff spec/<slug>`. Pick this when the
  specs belong on the branch you are on.
- **Check out spec/<slug>**: run `git checkout spec/<slug>`. Pick this to work on the spec
  branch itself.
- **Leave it**: do neither. Say plainly that `slice` and `run` will not find the story map
  until one of the two is done.

Run the command the user picks, then confirm `ralph/AUDIENCE_JTBD.md` is present:

```bash
[[ -f ralph/AUDIENCE_JTBD.md ]] && echo READY || echo NOT_IN_TREE
```

---

## Step 11: Offer the next command

Skip this step when Step 10 printed `NOT_IN_TREE`. Say instead: "Bring the branch into
this tree first, then run `/ralph-loop:slice` or `/ralph-loop:run <activity-slug>`."

Detect which build routes are available:

```bash
command -v openspec >/dev/null && grep -q '^schema: *ralph-bridge' openspec/config.yaml 2>/dev/null \
  && echo "OPENSPEC_READY" || echo "OPENSPEC_NOT_WIRED"
```

Use AskUserQuestion with these options. Include the OpenSpec option only when the check
printed `OPENSPEC_READY`.

- **Slice into OpenSpec changes**: run `/ralph-loop:slice`. It picks one capability depth
  per activity and creates one OpenSpec change per cell, each with the five bridge
  artifacts. Pick this when you want the change reviewed before any code is written.
- **Build one activity now**: run `/ralph-loop:run <activity-slug>`, naming one file in
  `ralph/specs/`. `run` takes a single spec name or OpenSpec change name. It does not take
  the product slug and it does not take a branch name. List the activity slugs so the user
  can pick one.
- **Hand off the design first**: do the Claude Design steps below, then choose a build
  route. Pick this when the screens have to match a design system.

When the OpenSpec option is absent, say why in one line: "OpenSpec is not wired. Run
`/ralph-loop:init --openspec` to add that route."

Whichever option the user picks, print the design handoff steps once:

```
Design handoff (optional, do it before the screens are built):

  1. Paste ralph/design/SYSTEM_PROMPT.md into Claude Design.
  2. Export the handoff bundle.
  3. Unpack it into ralph/design/system/ and commit the contents.
     The directory name must be exactly ralph/design/system. Claude Design unpacks to its
     own name, so rename it. /ralph-loop:slice reads that path only.
     Commit the files, not the .tar or .zip. An archive is opaque to review, and the
     build agent refuses to read one.

Screen prompts are generated later, per release, by /ralph-loop:slice. They point Claude
Design at ralph/design/system/, so screens match the system you already built.
```

Do not run the chosen build command yourself. Name it and stop.
