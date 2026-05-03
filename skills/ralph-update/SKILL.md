---
name: ralph-update
description: Update the generic ralph pipeline files in a project from the ralph-loop repo
arguments: [target, ref]
allowed-tools: Bash Read AskUserQuestion
disable-model-invocation: true
---

Update the Ralph pipeline files in a project from the ralph-loop repo.

Target project ralph directory: $target
Ref (tag or branch, default: main): $ref

Default repo: https://github.com/Olunuga/ralph-loop

Generic files to sync (never touches config.sh, AGENTS.md, or specs/):
- loop.sh
- PROMPT_bootstrap.md
- PROMPT_build.md
- PROMPT_plan.md
- PROMPT_plan_work.md
- SETUP.md
- SETUP_SKILLS.md
- scripts/check_architecture.sh
- scripts/consensus_judge.sh
- scripts/hooks/workspace_boundary.sh
- skills/ralph-init/SKILL.md
- skills/ralph/SKILL.md
- skills/ralph-update/SKILL.md
- skills/spec/SKILL.md

## Step 1 — Validate target

Check the target is an active ralph project directory:
```bash
ls "$target/config.sh" 2>/dev/null && echo "has config" || echo "no config"
```

If no config.sh found, warn the user and ask if they want to continue.

## Step 2 — Clone ref into a temp directory

```bash
REF="${ref:-main}"
TMPDIR=$(mktemp -d)
git clone --depth 1 --branch "$REF" https://github.com/Olunuga/ralph-loop "$TMPDIR" 2>&1
```

If the clone fails (bad ref or no network), stop and report the error.

## Step 3 — Show diff

```bash
TMPDIR=$(mktemp -d)
REF="${ref:-main}"
git clone --depth 1 --branch "$REF" https://github.com/Olunuga/ralph-loop "$TMPDIR" 2>/dev/null

for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md \
          scripts/check_architecture.sh scripts/consensus_judge.sh scripts/hooks/workspace_boundary.sh \
          skills/ralph-init/SKILL.md skills/ralph/SKILL.md skills/ralph-update/SKILL.md skills/spec/SKILL.md; do
    src="$TMPDIR/$f"
    tgt="$target/$f"
    if [[ ! -f "$src" ]]; then
        echo "SKIP (not in source): $f"
    elif [[ ! -f "$tgt" ]]; then
        echo "NEW: $f"
    elif diff -q "$src" "$tgt" > /dev/null 2>&1; then
        echo "unchanged: $f"
    else
        echo "CHANGED: $f"
    fi
done
```

Use AskUserQuestion to show the diff summary and ask:
"These files will be updated in '$target' from ralph-loop@${ref:-main}. config.sh, AGENTS.md, and specs/ will not be touched. Proceed? Reply 'yes' to copy or 'no' to cancel."

If the user replies anything other than yes, clean up and stop:
```bash
rm -rf "$TMPDIR"
```

## Step 4 — Copy

```bash
for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md; do
    [[ -f "$TMPDIR/$f" ]] && cp "$TMPDIR/$f" "$target/$f" && echo "copied: $f"
done

mkdir -p "$target/scripts/hooks"
for f in scripts/check_architecture.sh scripts/consensus_judge.sh scripts/hooks/workspace_boundary.sh; do
    [[ -f "$TMPDIR/$f" ]] && cp "$TMPDIR/$f" "$target/$f" && echo "copied: $f"
done

mkdir -p "$target/skills/ralph-init" "$target/skills/ralph" "$target/skills/ralph-update" "$target/skills/spec"
for f in skills/ralph-init/SKILL.md skills/ralph/SKILL.md skills/ralph-update/SKILL.md skills/spec/SKILL.md; do
    [[ -f "$TMPDIR/$f" ]] && cp "$TMPDIR/$f" "$target/$f" && echo "copied: $f"
done

chmod +x "$target/loop.sh" "$target/scripts/check_architecture.sh" \
         "$target/scripts/consensus_judge.sh" "$target/scripts/hooks/workspace_boundary.sh"

rm -rf "$TMPDIR"
```

## Step 5 — Report

Confirm: "Ralph updated in '$target' from ralph-loop@${ref:-main}. config.sh, AGENTS.md, and specs/ were not touched."
