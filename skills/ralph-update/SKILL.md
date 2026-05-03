---
name: ralph-update
description: Update the generic ralph pipeline files in a project from a ralph source repo
arguments: [source, target]
allowed-tools: Bash Read AskUserQuestion
disable-model-invocation: true
---

Update the Ralph pipeline in a project directory from a source ralph repo.

Source: $source
Target: $target

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
- skills/spec/SKILL.md

## Step 1 — Validate

Check source exists and is a ralph repo:
```bash
ls "$source/loop.sh" 2>/dev/null && echo "ok" || echo "missing"
```

If missing, tell the user: "No ralph repo found at '$source'. Pass the path to your ralph repo." and stop.

Check target exists:
```bash
ls "$target/config.sh" 2>/dev/null && echo "has config" || echo "no config"
```

If no config.sh found, warn: "No config.sh found in '$target' — are you sure this is an active ralph project directory?"

## Step 2 — Show diff

Run a dry-run diff to show what would change:
```bash
for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md \
          scripts/check_architecture.sh scripts/consensus_judge.sh scripts/hooks/workspace_boundary.sh \
          skills/ralph-init/SKILL.md skills/ralph/SKILL.md skills/spec/SKILL.md; do
    src="$source/$f"
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
"These files will be updated in '$target'. config.sh, AGENTS.md, and specs/ will not be touched. Proceed? Reply 'yes' to copy or 'no' to cancel."

If the user replies anything other than yes, stop.

## Step 3 — Copy

```bash
for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md; do
    [[ -f "$source/$f" ]] && cp "$source/$f" "$target/$f" && echo "copied: $f"
done

mkdir -p "$target/scripts/hooks"
for f in scripts/check_architecture.sh scripts/consensus_judge.sh scripts/hooks/workspace_boundary.sh; do
    [[ -f "$source/$f" ]] && cp "$source/$f" "$target/$f" && echo "copied: $f"
done

mkdir -p "$target/skills/ralph-init" "$target/skills/ralph" "$target/skills/spec"
for f in skills/ralph-init/SKILL.md skills/ralph/SKILL.md skills/spec/SKILL.md; do
    [[ -f "$source/$f" ]] && cp "$source/$f" "$target/$f" && echo "copied: $f"
done

chmod +x "$target/loop.sh" "$target/scripts/check_architecture.sh" \
         "$target/scripts/consensus_judge.sh" "$target/scripts/hooks/workspace_boundary.sh"
```

## Step 4 — Report

Confirm: "Ralph updated in '$target'. config.sh, AGENTS.md, and specs/ were not touched. Run /ralph-init if any new settings.json permissions are needed."
