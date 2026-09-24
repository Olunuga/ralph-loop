---
name: status
description: Show what is done and what to do next, and write it to ralph/NEXT.md
allowed-tools: Bash Read Write
disable-model-invocation: true
---

You are reporting where this project stands and what the user does next.

An SLC product runs for weeks. The user comes back and does not remember which step they
were on. This skill answers that in one screen.

**Derive every fact from the filesystem and git. Never read a stored status value.** A
stored value goes stale the moment someone works outside this skill.

**Write nothing except `ralph/NEXT.md`.** Create no changes, no branches, no commits.

---

## Step 1: Gather

Run each block and keep the output.

```bash
[[ -f ralph/config.sh ]] && echo "SETUP: yes" || echo "SETUP: no"
[[ -f ralph/AUDIENCE_JTBD.md ]] && echo "MAP: yes" || echo "MAP: no"
ls ralph/specs/*.md ralph/specs/*/spec.md 2>/dev/null | wc -l
[[ -d ralph/design/system ]] && echo "DESIGN: yes" || echo "DESIGN: no"
[[ -f ralph/design/SYSTEM_PROMPT.md ]] && echo "DESIGN_PROMPT: yes" || echo "DESIGN_PROMPT: no"
command -v openspec >/dev/null && grep -q '^schema: *ralph-bridge' openspec/config.yaml 2>/dev/null \
  && echo "OPENSPEC: yes" || echo "OPENSPEC: no"
ls ralph/releases/*.md 2>/dev/null
```

When `MAP: no`, skip to Step 3. There is nothing to report yet.

Read every file in `ralph/releases/`. Each has an Order column and a Cell column. For each
change named there, derive its state:

```bash
ID="<cell-id>"
# openspec archive names the folder <YYYY-MM-DD>-<id>, so an exact path never matches.
compgen -G "openspec/changes/archive/????-??-??-$ID" >/dev/null && echo "$ID archived" && continue
[[ -d "openspec/changes/$ID" ]] || { echo "$ID missing"; continue; }
grep -c '^- \[x\]' "openspec/changes/$ID/tasks.md" 2>/dev/null
grep -c '^- \[ \]' "openspec/changes/$ID/tasks.md" 2>/dev/null
git log --oneline --all --grep="$ID" | head -1
```

- archive directory exists: **done**
- no tasks.md: **not planned yet**
- every task checked: **built, waiting to be archived**
- some tasks checked: **in progress, X of Y steps**
- no task checked and no commits: **ready to build**
- directory absent but named in a release: **missing**

For each change that still exists, also check its design files:

```bash
[[ -f "openspec/changes/$ID/design/SCREEN_PROMPT.md" ]] && echo "$ID has a screen prompt"
[[ -d "openspec/changes/$ID/assets/design" ]] && echo "$ID has screen designs"
[[ -d "openspec/changes/$ID/assets/design/design_system" ]] && echo "$ID has a duplicate system"
{ [[ -f "openspec/changes/$ID/design/SCREEN_PROMPT.md" ]] || [[ -d "openspec/changes/$ID/assets/design" ]]; } && \
  echo "$ID has screens: compare its states against its tasks"
```

A change with a screen prompt and no `assets/design/` has a design waiting to be made.
Report it under Optional with its exact path.

A change with a duplicate system has a copy of `ralph/design/system/` inside its own design
files. Claude Design puts it there to make a bundle self-contained. Report it under Optional
with the command to remove it: two copies of the same tokens drift apart.

---

## Step 2: Decide the one next action

Pick the first line that is true. This is the single thing the user does next.

1. `SETUP: no` : run `/ralph-loop:init --openspec`
2. `MAP: no` : run `/ralph-loop:req-slc <product>`
3. No release record : run `/ralph-loop:slice`
4. A change is **missing** : re-run `/ralph-loop:slice`, or remove it from the release record
5. A change is **not planned yet** : run `/ralph-loop:slice` again to finish writing it
6. A change is **in progress** : build it, continuing from where it stopped
7. A change is **ready to build**, lowest Order first : build it

For 6 and 7 the action is one thing, building that change, and there are two ways to do it.
Print both, with the change named:

```
    /ralph-loop:run <cell-id>      the pipeline builds it and opens a pull request
    /opsx:apply <cell-id>          you build it, and it stops to ask
```

Both work through the same `tasks.md`, so a change started one way can be finished the
other. Neither undoes the other's checked items.
8. A change is **built, waiting to be archived** : merge its pull request, then archive it

For 8, print the command with the change named:

```
    /ralph-loop:cleanup <cell-id>
```

`cleanup` detects that this is an OpenSpec change and runs `openspec archive`, which moves
it to `openspec/changes/archive/` and merges its specs into `openspec/specs/`. Until that
happens the change reads as unfinished here and the release never completes.
9. Every change is **done** : run `/ralph-loop:slice` for the next release

Design is never the next action. It is optional and it does not block a build. Report it
under Optional instead, and always name the exact path the files go in. A user who has a
design in hand and no path for it is stuck for no reason.

Two design items can be outstanding, and they are independent:

- The system, when `DESIGN: no` and `DESIGN_PROMPT: yes`. Files go in `ralph/design/system/`.
- One change's screens, when it has a screen prompt and no `assets/design/`. Files go in
  `openspec/changes/<cell-id>/assets/design/`, and the bundle's own `design_system/`
  directory is deleted before committing.
- A duplicate system already committed under a change's `assets/design/design_system/`.

For a change with screens, compare state by state rather than counting keywords. List the
states the design names, from the bundle README or `design/SCREEN_PROMPT.md`, and the states
the tasks name. Report it when a state has no task, a task names a state the design does not
have, or a task and the design disagree about what happens in the same state.

That last case is the one a keyword test cannot find, and it is the common one: tasks are
written at slice time and the screens are drawn weeks later, so a task guesses a treatment
the designer then chooses differently.

Report such a change under **Do this next**, not Optional. Its screens will be built wrong or
not at all, and no gate says so.

One such change: `/ralph-loop:run <cell-id>` stops at its Step 0b, proposes the missing
screen tasks, and appends them once the user confirms.

Two or more: `/ralph-loop:slice --add-design-tasks` repairs every one in a single pass and
builds nothing.

Do not tell the user to run `openspec instructions tasks`: that writes a whole new
`tasks.md` and discards every box already ticked.

When `DESIGN: yes`, say so under Done. The user then knows the system is in place, and that
any remaining design work is per change.

---

## Step 3: Write ralph/NEXT.md

Use the Write tool. Overwrite the file each time.

Rules for the text:

- Plain words. No jargon. No file paths except the ones the user types or opens.
- A `Done` line says what the person now has, not what a command did.
- One line per item. No paragraph.
- Never more than one thing under **Do this next**. Two commands for the same action are
  one thing, so a build step may print both.
- Say the date it was written, so a stale file is obvious.

```markdown
# Where this project stands

Updated <YYYY-MM-DD>. Re-check any time with `/ralph-loop:status`.

## Do this next

<one sentence saying what to do, then the command on its own line>

## Done

- <plain sentence, most recent first>

## Still to come

- <plain sentence, in build order>

## Optional

- <only when something optional is outstanding. Always name the path files go in.>
```

Write `## Optional` only when it has an item. Write `## Still to come` only when something
remains.

Worked example of the tone:

```markdown
## Do this next

Build the first release slice. Start with adding a task, because reviewing a list
needs it first.

    /ralph-loop:run capture-basic      the pipeline builds it and opens a pull request
    /opsx:apply capture-basic          you build it, and it stops to ask

## Done

- Anyone can see their list of tasks. Built and merged.
- The product has a story map with 4 activities and 3 depths.
- The pipeline is set up and the gates run on every commit.
- The design system is in place. Screens can cite it.

## Still to come

- Add a task
- Review the week
- Share a list

## Optional

- Screens for adding a task are not drawn yet. Paste the marked block of
  openspec/changes/capture-basic/design/SCREEN_PROMPT.md into Claude Design, ask it
  for a handoff bundle, then put the files in
  openspec/changes/capture-basic/assets/design/ and commit them. Delete the bundle's
  own design_system/ directory first: the system is already in ralph/design/system/.
- The screens for reviewing the week carry a second copy of the design system.
  Remove it, so the two cannot drift apart:

      git rm -r openspec/changes/review-basic/assets/design/design_system
```

The same shape covers a missing design system, with `ralph/design/SYSTEM_PROMPT.md` as the
prompt and `ralph/design/system/` as the destination.

---

## Step 4: Report

Print the same content to the user, then one line:

```
Saved to ralph/NEXT.md
```

Do not commit the file. The user decides whether it belongs in git.
