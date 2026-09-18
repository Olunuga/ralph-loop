---
name: slice
description: Turn the next SLC release slice into OpenSpec changes
argument-hint: "[--status] [--add-theme]"
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are choosing the next release slice for an SLC product and turning it into OpenSpec
changes. One change per cell. A cell is one activity at one capability depth.

Run each step in order. Tell the user which step you are on.

## Arguments

```
/ralph-loop:slice [--status] [--add-theme]
```

`--status` reports where the current release stands and creates nothing. If the user passed
it, skip to Step 6.

`--add-theme` adds the theme to a release that was sliced without one, and slices nothing
new. If the user passed it, run Step 1, then skip to Step 1b.

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

## Step 1b: A release sliced without the theme

Run this whenever `ralph/releases/` holds a record. It repairs a release made before the
theme step existed, and it creates no new release.

```bash
NEWEST=$(ls -t ralph/releases/*.md 2>/dev/null | head -1)
[[ -n "$NEWEST" ]] && echo "$NEWEST"
grep -rq 'theme-foundation' ralph/releases/ 2>/dev/null && echo THEME_IN_A_RELEASE
compgen -G "openspec/changes/archive/????-??-??-theme-foundation" >/dev/null && echo THEME_DONE
[[ -d ralph/design/system ]] || echo NO_SYSTEM
```

Skip this step, saying nothing, when any of `THEME_IN_A_RELEASE`, `THEME_DONE`, or
`NO_SYSTEM` printed, or when there is no release record. Only a release with a design system
and no theme needs repair.

Otherwise ask the theme question from Step 4b. On **Yes, it exists**, record the answer so
you do not ask again: append `<!-- theme: already in the codebase -->` to the newest release
record and skip.

On **No, build it first**:

1. Create the change exactly as Step 5 does for `theme-foundation`, with
   `ralph/design/system/README.md` and `tokens.json` as the source. Skip 5h.
2. Insert a `theme-foundation` row at Order 1 in the newest release record and renumber the
   rows below it. Set `Needs first` to `theme-foundation` on every row that had `none`.
3. Tell the user:

```
Added theme-foundation to release <release> as change 1.
Every other change in that release now needs it first.

    /ralph-loop:run theme-foundation      the pipeline builds it and opens a pull request
    /opsx:apply theme-foundation          you build it, and it stops to ask
```

Then run `/ralph-loop:status` and stop. Do not slice a new release in the same run.

This is the one case that edits an existing release record. It inserts the theme row and
renumbers; it never removes or reorders a cell.

---

## Step 2: Recommend a slice

Read `ralph/AUDIENCE_JTBD.md`, every file in `ralph/specs/`, and any file in
`ralph/releases/`. Then follow `$RALPH_PLUGIN_DIR/prompts/PROMPT_slice.md` yourself and
produce its report. Do this in your own context: it needs codebase searches and judgement.

---

## Step 3: Confirm

Show the user the PROPOSED SLICE, ALREADY DONE, DEFERRED, FOUNDATIONS, BUILD ORDER, and
RATIONALE sections in full.

A foundation is work every cell needs and no cell owns: the theme, a network client, a local
store. Ask about them separately, because each is a change of its own and the user may
already have it: "Build these first? <list>". Drop any the user says already exists.

Then use AskUserQuestion:

> "Materialise this slice? It creates one OpenSpec change per cell."

Options: **Yes, create the changes** / **Let me edit the slice first** / **Cancel**.

On edit, ask which cells to remove and which deferred cells to add, then recompute BUILD
ORDER, show the revised slice, and ask again. The user may also correct the order directly. A user may add a deferred cell: warn that its dependency is unmet, and
proceed if they still want it.

On cancel, stop. Create nothing.

**Write nothing before this confirmation.**

---

## Step 4: Name the release

Use AskUserQuestion: "What is this release called? For example `v1` or `first-palette`."

Slugify the answer. Refuse a name that already exists in `ralph/releases/` and ask again.

---

## Step 4b: Foundations

Create a change for each foundation the user confirmed in Step 3, before any cell. Each is
built exactly as Step 5 builds a cell, with two differences: its source is the gap named in
FOUNDATIONS rather than an activity spec, and it gets no screen prompt.

Its proposal stays in plain words, like any other. A network foundation says the app can
reach the server and says something useful when it cannot. It does not say it adds a
`URLSession` wrapper. The design and tasks carry the technical shape.

Skip a foundation whose change already exists, is archived, or is named in an earlier release
record. Use the same three checks as the theme below, with the foundation's own slug.

### The theme

The theme has one extra condition, because it has a source of its own.

Skip it when `ralph/design/system/` does not exist. Without a design system there is
nothing to build a theme from.

```bash
[[ -d ralph/design/system ]] || echo NO_SYSTEM
[[ -d openspec/changes/theme-foundation ]] && echo EXISTS
compgen -G "openspec/changes/archive/????-??-??-theme-foundation" >/dev/null && echo DONE
grep -rl 'theme-foundation' ralph/releases/ 2>/dev/null | head -1
```

`DONE`, or the change already named in a release record, or a release record carrying
`<!-- theme: already in the codebase -->`: the theme is handled. Skip.

Otherwise ask the user, because no reliable check tells you whether a codebase already holds
its colours, type sizes and spacing in one place:

> "Does this codebase already have a theme: one place holding the colours, type sizes and
> spacing that every screen reads from?"

Options: **No, build it first** / **Yes, it exists** / **Not sure, show me**.

On **Not sure**, read `ralph/design/system/README.md` for the conventions it names, look for
them in `${SOURCE_DIR}`, report what you found in one line, and ask again.

On **Yes**, skip the rest of this step.

On **No**, add `theme-foundation` to this release ahead of every cell. It is built the same
way as any other change, in Step 5, with one difference: its content comes from
`ralph/design/system/`, not from an activity spec.

**Why the theme is always a change of its own.** The gates require it. `scripts/gates/llm/theme_colors.md`
flags a raw colour value and asks for a theme token; `hardcoded_fonts.sh` flags a fixed font
size. The first screen built without a theme fails both, and the build agent then invents a
theme inside a change whose proposal never mentioned one.

Its proposal is still written for a product user. It says that every screen will use the
same colours, type and spacing, from one place, and that without it each screen invents its
own and they drift. Name the capability `design-tokens`.

Its design and tasks are technical and come from `ralph/design/system/README.md` and
`tokens.json`: the README names the conventions the codebase should use, and `tokens.json`
holds every token with its value in each appearance. Do not restate token values in the
proposal or the specs.

---

## Step 5: Materialise

Work through BUILD ORDER in order, foundations first. Every change is created, whatever its
position: the order decides the build sequence, not what gets written.

For a foundation, 5c to 5g run the same way, with its FOUNDATIONS entry as the source in
place of an activity spec, and 5h is skipped: a foundation has no screens. For
`theme-foundation` the source is `ralph/design/system/README.md` and `tokens.json`.

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

**5c. Write the proposal.**
```bash
openspec instructions proposal --change "<cell-id>"
```
Follow what it returns. Fill it from the activity's spec, using ONLY that depth: the job to
be done, the activity, and that depth's success criteria. Do not carry in deeper depths,
they belong to later releases. Name the cell id, the release, and the depth in the Why
section.

Keep the proposal free of technical detail. The Impact section names affected capabilities,
not file paths, types, APIs, or layers. The gap analysis in Step 2 found where the code
would live; that belongs in design.md at 5e, where an implementation decision is actually
being made. A proposal that names a file has decided the design before anyone reviewed it.

**5d. Write the specs.**
```bash
openspec instructions specs --change "<cell-id>"
```
One file per capability named in the proposal. Turn that depth's success criteria into
requirements and scenarios. Scenarios take exactly four hashtags: three fails silently.

**5e. Write the design.**
```bash
openspec instructions design --change "<cell-id>"
```
The instruction names `ralph/gate_context.md` and the gate directories as required reads.
Read them. A design that a gate rejects wastes a whole build loop. Put the file paths and
layers from the Step 2 gap analysis here.

**5f. Write the tasks.**
```bash
openspec instructions tasks --change "<cell-id>"
```
Order tasks by dependency. Every task is `- [ ] X.Y Description`, because the apply phase
and `bin/loop.sh` both parse that exact form.

**5g. Confirm the change is apply-ready.**
```bash
openspec status --change "<cell-id>" --json
```
Not apply-ready means an artifact is missing or malformed. Name the missing artifact and
stop. `/ralph-loop:run` and `/opsx:apply` both refuse a change that is not apply-ready, so
reporting success here would send the user into a dead end.

`gate-report.md` is written after implementation, not now.

**5h. Write the screen prompt.**
Read `$RALPH_PLUGIN_DIR/prompts/SCREEN_PROMPT_TEMPLATE.md` and fill it from the activity
spec, using ONLY this cell's depth:

- `${ACTIVITY}` and `${DEPTH}` from the cell id
- `${DEPTH_DESCRIPTION}` and `${SUCCESS_CRITERIA}` from that depth's section of the spec
- `${JOB_TO_BE_DONE}` from the activity spec
- `${CHANGE_ID}` the cell id, so the handoff steps name the real path

For `${DESIGN_SYSTEM_CITATION}`, check whether the design system exists:
```bash
if [[ -d ralph/design/system ]]; then
  echo HAS_SYSTEM
else
  find ralph/design -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's/^/UNNAMED: /'
fi
```
- `HAS_SYSTEM`: "Import the design system from this repository at `ralph/design/system/`. Use its
  tokens and components exactly. Do not invent new ones."
- One or more `UNNAMED:` lines: stop the whole skill and tell the user, naming each path
  found: "A design handoff is in `<path>`, but the pipeline reads `ralph/design/system/`
  only. Rename it with `git mv <path> ralph/design/system`, commit, then re-run
  `/ralph-loop:slice`." Create nothing.
- No output at all: "No design system exists yet. Work from the product context in this
  change's proposal.md, and name the tokens you introduce so they can become the system later."

Write it to `openspec/changes/<cell-id>/design/SCREEN_PROMPT.md`.

Do not describe deeper depths of the same activity. They belong to later releases.

**5i. Record what you created.** Keep the list and its build order for Step 7.

---

## Step 6: Release record and status

**When materialising**, write `ralph/releases/<release>.md`:

```markdown
# Release: <release>

Sliced: <date>

| Order | Cell | Change | Activity | Depth | Needs first |
|---|---|---|---|---|---|
| 1 | `<foundation-slug>` | `openspec/changes/<foundation-slug>` | (foundation) | n/a | none |
| 2 | `<cell-id>` | `openspec/changes/<cell-id>` | <activity> | <depth> | `<foundation-slug>` |
```

Include a foundation row only for a foundation Step 4b created.

The Order column is the confirmed BUILD ORDER. `--status` reports against it, so a reader
can see which change is next without re-deriving the dependencies.

Never modify an existing release record. Each slice adds a new file. Step 1b is the one
exception: it inserts the theme row and renumbers below it.

**When `--status` was passed**, read every file in `ralph/releases/`. For each change named
in each record, derive its state rather than reading a stored value:

```bash
[[ -d "openspec/changes/<cell-id>" ]] && echo present
compgen -G "openspec/changes/archive/????-??-??-<cell-id>" >/dev/null && echo archived
git log --oneline --all --grep="<cell-id>" | head -1
```

- archived directory exists: **archived**
- change exists and has commits: **in progress**
- change exists, no commits: **pending**
- neither: **missing**

Report each change on its own line, in the record's Order column. Name the first change
that is not archived as the next one to build. Call a release complete only when every
change in it is archived, and then say it is ready to tag. When `ralph/releases/` is absent or empty, say
"No release has been sliced yet." and stop.

---

## Step 7: Report

Tell the user:

```
Created <N> changes for release <release>, in build order:
  1. openspec/changes/<foundation-slug>/  every cell needs it, no cell owns it
  2. openspec/changes/<cell-id>/          proposal, specs, design, tasks
  3. ...                                  needs <cell-id>

Skipped:
  <cell-id> — already has work against it

Release record: ralph/releases/<release>.md

Design prompts, one per change:
  openspec/changes/<cell-id>/design/SCREEN_PROMPT.md

  Paste each into Claude Design, export the handoff bundle, then unpack it into
  openspec/changes/<cell-id>/assets/design/ and commit the contents. Commit the files,
  not the .tar or .zip: the build agent refuses to read an archive.

Next, starting with change 1:
  /ralph-loop:run <cell-id>      build a change autonomously
  /opsx:apply <cell-id>          build it yourself
  /ralph-loop:slice --status     check the release

Build them in the order above. A later change depends on an earlier one.

To undo this slice:
  rm -rf openspec/changes/<cell-id> ... ralph/releases/<release>.md
```

Then run `/ralph-loop:status` so `ralph/NEXT.md` names the first change to build.
`--status` here reports one release in detail. `/ralph-loop:status` covers the whole
project in plain words.

Print the removal command with every path spelled out. A user who sliced wrongly must be
able to copy one line.
