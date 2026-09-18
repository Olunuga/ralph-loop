---
name: cleanup
description: Archive a completed change or spec after its pull request is merged
arguments: [ref]
argument-hint: "<ref>"
allowed-tools: Bash Read AskUserQuestion
disable-model-invocation: true
---

You are cleaning up after a merged pull request.

Reference: $ref

**Run this from the project root on the branch the pull request merged into, not from a
worktree.** Archiving writes to the main specs, and that belongs on the merged branch.

---

## Step 1 — Find out what `$ref` is

```bash
[[ -d "openspec/changes/$ref" ]] && echo OPENSPEC
compgen -G "openspec/changes/archive/????-??-??-$ref" >/dev/null && echo ALREADY_ARCHIVED
ls ralph/specs/"$ref".md ralph/specs/"$ref"/spec.md 2>/dev/null
[[ -f IMPLEMENTATION_PLAN.md ]] && echo HAS_PLAN
```

- `ALREADY_ARCHIVED`: say "`$ref` is already archived." and stop.
- `OPENSPEC`: go to Step 2a.
- A spec file, or `HAS_PLAN` with no OpenSpec change: go to Step 2b.
- Neither: stop with "No OpenSpec change and no ralph spec named '$ref'. Checked
  openspec/changes/$ref/ and ralph/specs/$ref*."

---

## Step 2a — An OpenSpec change

Check the work is actually finished and merged:

```bash
grep -c '^- \[ \]' "openspec/changes/$ref/tasks.md" 2>/dev/null
git log --oneline -1 --grep="$ref" 2>/dev/null
git branch --contains HEAD 2>/dev/null | head -3
```

Unchecked tasks remain: say how many and ask whether to archive anyway. Archiving an
unfinished change hides work that was never done. On anything but an explicit yes, stop.

Use AskUserQuestion:

"Archive `$ref`?

  openspec/changes/$ref/  ->  openspec/changes/archive/<today>-$ref/
  Its specs are merged into openspec/specs/.

  Branch ralph/$ref: [exists / not found]

Confirm? Reply 'yes' to proceed or 'no' to cancel."

On yes:

```bash
openspec archive "$ref" -y 2>&1
```

If it fails because the change has no spec deltas, which happens for an infrastructure change
such as `theme-foundation` or `restructure-source`, say so and re-run with `--skip-specs`.
Never pass `--no-validate`: a change that fails validation is not ready to archive.

Commit the result, because `openspec archive` moves files but does not commit:

```bash
git add openspec/
```
```bash
git -c commit.gpgsign=false commit -m "ralph: archive $ref"
```

Then go to Step 3.

---

## Step 2b — A legacy ralph spec

Read the header that names which specs the build used:

```bash
grep '^# Generated from:' IMPLEMENTATION_PLAN.md 2>/dev/null || echo "(no header)"
git rev-parse --verify "spec/$ref" 2>/dev/null && echo "spec/$ref: exists" || echo "spec/$ref: not found"
```

Use AskUserQuestion:

"Cleanup preview for '$ref':

Spec files (from IMPLEMENTATION_PLAN.md):
  [list the spec filenames from the Generated from: header]
  -> will be moved to ralph/specs/done/

Branches:
  spec/$ref -> [exists: will be deleted / not found: skip]
  ralph/$ref -> kept (delete it yourself after closing the pull request)

Confirm? Reply 'yes' to proceed or 'no' to cancel."

On yes:

```bash
cleanup_specs.sh "$ref"
```

Report how many specs were archived and whether the spec branch was deleted.

---

## Step 3 — Report

Say what was archived, in one line.

Remind the user about the build branch, which neither path deletes:

```
Run `git branch -d ralph/$ref` once the pull request is closed, and
`git push origin --delete ralph/$ref` if it was pushed.
```

Finally, run `/ralph-loop:status` to refresh `ralph/NEXT.md`. On an SLC product that file
names the next change to build, and a release is complete only when every change in it is
archived.
