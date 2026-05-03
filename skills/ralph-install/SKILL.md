---
name: ralph-install
description: Pull the ralph-loop pipeline into ralph/ in the current project
arguments: [ref]
allowed-tools: Bash AskUserQuestion
disable-model-invocation: true
---

Pull the ralph-loop pipeline into the current project directory.

Ref (tag or branch, default: main): $ref

## Step 1 — Check

Verify you are in a project root (not inside ralph/ itself):
```bash
pwd && ls 2>/dev/null | head -20
```

If `ralph/loop.sh` already exists, use AskUserQuestion to ask:
"ralph/ already exists in this project. Run /ralph-update instead to sync changes. Proceed anyway and overwrite? Reply 'yes' or 'no'."

If the user replies no, stop.

## Step 2 — Pull

```bash
REF="${ref:-main}"
TMPDIR=$(mktemp -d)
git clone --depth 1 --branch "$REF" https://github.com/Olunuga/ralph-loop "$TMPDIR" 2>&1 \
  && echo "cloned ok" || echo "clone failed"
```

If clone failed, stop and report the error.

## Step 3 — Copy into ralph/

```bash
mkdir -p ralph/scripts/hooks ralph/skills/ralph-init ralph/skills/ralph ralph/skills/ralph-update ralph/skills/spec

for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md; do
    cp "$TMPDIR/$f" ralph/$f && echo "copied: $f"
done

for f in scripts/check_architecture.sh scripts/consensus_judge.sh scripts/hooks/workspace_boundary.sh; do
    cp "$TMPDIR/$f" ralph/$f && echo "copied: $f"
done

for f in skills/ralph-init/SKILL.md skills/ralph/SKILL.md skills/ralph-update/SKILL.md skills/spec/SKILL.md; do
    cp "$TMPDIR/$f" ralph/$f && echo "copied: $f"
done

chmod +x ralph/loop.sh ralph/scripts/check_architecture.sh \
         ralph/scripts/consensus_judge.sh ralph/scripts/hooks/workspace_boundary.sh

rm -rf "$TMPDIR"
```

## Step 4 — Record version

Write the installed version into `ralph/config.sh` so the project tracks which version it is pinned to:

```bash
REF="${ref:-main}"
echo "RALPH_VERSION=\"$REF\"" > ralph/config.sh
```

## Step 5 — Report

Confirm: "ralph-loop@${ref:-main} installed into ralph/. RALPH_VERSION recorded in ralph/config.sh. Run /ralph-init to complete setup."
