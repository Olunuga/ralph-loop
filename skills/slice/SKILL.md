---
name: slice
description: Choose the next SLC release slice and turn it into one OpenSpec change per cell
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are choosing the next release slice for an SLC product and turning it into OpenSpec
changes. One change per cell. A cell is one activity at one capability depth.

Run each step in order. Tell the user which step you are on.

`--status` reports where the current release stands and creates nothing. If the user passed
it, skip to Step 6.

---

## Step 1: Check the inputs

```bash
[[ -f ralph/AUDIENCE_JTBD.md ]] || echo "MISSING_MAP"
command -v openspec >/dev/null || echo "MISSING_CLI"
grep '^schema:' openspec/config.yaml 2>/dev/null
```

Stop with the matching message and do nothing else:

- `MISSING_MAP`: "No story map. Run `/ralph-loop:req-slc <product>` first."
- `MISSING_CLI`: "OpenSpec is not installed. Run `npm i -g openspec`."
- schema is not `ralph-bridge`: "ralph-bridge is not the active schema. Run `/ralph-loop:init --openspec`."

Then confirm the story map has a table:
```bash
grep -c '^| ' ralph/AUDIENCE_JTBD.md
```
Zero means the file predates the table format. Tell the user: "This story map has no table.
Re-run `/ralph-loop:req-slc`, or add a `## Story Map` table by hand. See the req-slc skill
for the format." Stop.

---

## Step 2: Recommend a slice

Read `ralph/AUDIENCE_JTBD.md`, every file in `ralph/specs/`, and any file in
`ralph/releases/`. Then follow `$RALPH_PLUGIN_DIR/prompts/PROMPT_slice.md` yourself and
produce its report. Do this in your own context: it needs codebase searches and judgement.

---

## Step 3: Confirm

Show the user the PROPOSED SLICE, ALREADY DONE, DEFERRED, and RATIONALE sections in full.

Then use AskUserQuestion:

> "Materialise this slice? It creates one OpenSpec change per cell."

Options: **Yes, create the changes** / **Let me edit the slice first** / **Cancel**.

On edit, ask which cells to remove and which deferred cells to add, then show the revised
slice and ask again. A user may add a deferred cell: warn that its dependency is unmet, and
proceed if they still want it.

On cancel, stop. Create nothing.

**Write nothing before this confirmation.**

---

## Step 4: Name the release

Use AskUserQuestion: "What is this release called? For example `v1` or `first-palette`."

Slugify the answer. Refuse a name that already exists in `ralph/releases/` and ask again.

---

## Step 5: Materialise

For each confirmed cell, in order:

**5a. Check for an existing change.**
```bash
[[ -d "openspec/changes/<cell-id>" ]] && echo EXISTS
git log --oneline --all --grep="<cell-id>" | head -1
```
- Directory exists and the grep found commits: skip it. Say "`<cell-id>` already has work
  against it, skipping." Continue with the next cell.
- Directory exists with no commits: ask whether to replace it. On no, skip.
- No directory: continue.

**5b. Create it.**
```bash
openspec new change "<cell-id>" --schema ralph-bridge
```

**5c. Seed the proposal.**
Write `openspec/changes/<cell-id>/proposal.md` from the activity's spec, using ONLY that
depth. Take the job to be done, the activity, and that depth's success criteria. Do not
carry in deeper depths: they belong to later releases.

Follow the `ralph-bridge` proposal instruction for the format. Name the cell id, the
release, and the depth in the Why section.

**5d. Write the screen prompt.**
Read `$RALPH_PLUGIN_DIR/prompts/SCREEN_PROMPT_TEMPLATE.md` and fill it from the activity
spec, using ONLY this cell's depth:

- `${ACTIVITY}` and `${DEPTH}` from the cell id
- `${DEPTH_DESCRIPTION}` and `${SUCCESS_CRITERIA}` from that depth's section of the spec
- `${JOB_TO_BE_DONE}` from the activity spec

For `${DESIGN_SYSTEM_CITATION}`, check whether the design system exists:
```bash
[[ -d ralph/design/system ]] && echo HAS_SYSTEM
```
- Present: "Import the design system from this repository at `ralph/design/system/`. Use its
  tokens and components exactly. Do not invent new ones."
- Absent: "No design system exists yet. Work from the product context in this change's
  proposal.md, and name the tokens you introduce so they can become the system later."

Write it to `openspec/changes/<cell-id>/design/SCREEN_PROMPT.md`.

Do not describe deeper depths of the same activity. They belong to later releases.

**5e. Record what you created.** Keep the list for Step 7.

---

## Step 6: Release record and status

**When materialising**, write `ralph/releases/<release>.md`:

```markdown
# Release: <release>

Sliced: <date>

| Cell | Change | Activity | Depth |
|---|---|---|---|
| `<cell-id>` | `openspec/changes/<cell-id>` | <activity> | <depth> |
```

Never modify an existing release record. Each slice adds a new file.

**When `--status` was passed**, read every file in `ralph/releases/`. For each change named
in each record, derive its state rather than reading a stored value:

```bash
[[ -d "openspec/changes/<cell-id>" ]] && echo present
[[ -d "openspec/changes/archive/<cell-id>" ]] && echo archived
git log --oneline --all --grep="<cell-id>" | head -1
```

- archived directory exists: **archived**
- change exists and has commits: **in progress**
- change exists, no commits: **pending**
- neither: **missing**

Report each change on its own line. Call a release complete only when every change in it is
archived, and then say it is ready to tag. When `ralph/releases/` is absent or empty, say
"No release has been sliced yet." and stop.

---

## Step 7: Report

Tell the user:

```
Created <N> changes for release <release>:
  openspec/changes/<cell-id>/
  ...

Skipped:
  <cell-id> — already has work against it

Release record: ralph/releases/<release>.md

Design prompts, one per change:
  openspec/changes/<cell-id>/design/SCREEN_PROMPT.md

  Paste each into Claude Design, export the handoff bundle, then unpack it into
  openspec/changes/<cell-id>/assets/design/ and commit the contents. Commit the files,
  not the .tar or .zip: the build agent refuses to read an archive.

Next:
  /ralph-loop:run <cell-id>      build a change autonomously
  /opsx:apply <cell-id>          build it yourself
  /ralph-loop:slice --status     check the release

To undo this slice:
  rm -rf openspec/changes/<cell-id> ... ralph/releases/<release>.md
```

Print the removal command with every path spelled out. A user who sliced wrongly must be
able to copy one line.
