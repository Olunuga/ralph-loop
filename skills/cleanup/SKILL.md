---
name: cleanup
description: Archive completed specs and delete spec/<slug> branch after merging a ralph PR
arguments: [ref]
allowed-tools: Bash Read AskUserQuestion
disable-model-invocation: true
---

You are cleaning up after a merged ralph PR.

Reference: $ref

## Step 1 — Preview

Gather what will be cleaned up.

Read the generated-from header from IMPLEMENTATION_PLAN.md:
```bash
grep '^# Generated from:' IMPLEMENTATION_PLAN.md 2>/dev/null || echo "(IMPLEMENTATION_PLAN.md not found or missing header)"
```

Check which branches exist:
```bash
git rev-parse --verify "spec/$ref" 2>/dev/null && echo "spec/$ref: exists" || echo "spec/$ref: not found"
git rev-parse --verify "ralph/$ref" 2>/dev/null && echo "ralph/$ref: exists" || echo "ralph/$ref: not found"
```

Use AskUserQuestion with a summary of what will happen:
"Cleanup preview for '$ref':

Spec files (from IMPLEMENTATION_PLAN.md):
  [list the spec filenames from the Generated from: header]
  → will be moved to ralph/specs/done/

Branches:
  spec/$ref → [exists: will be deleted / not found: skip]
  ralph/$ref → kept (delete it yourself after closing the PR)

Confirm? Reply 'yes' to proceed or 'no' to cancel."

If the user replies anything other than yes, stop.

## Step 2 — Run cleanup

```bash
bash ralph/scripts/cleanup_specs.sh "$ref"
```

## Step 3 — Confirm

Report the output: how many specs were archived, whether the spec branch was deleted.

Remind the user: "Run `git branch -d ralph/$ref` (and `git push origin --delete ralph/$ref` if needed) once you've closed the PR."
