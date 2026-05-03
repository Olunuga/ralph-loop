---
name: ralph-update
description: Update the generic ralph pipeline files in a project from the ralph-loop repo
arguments: [ref]
allowed-tools: Bash Read AskUserQuestion
disable-model-invocation: true
---

Update the Ralph pipeline files in a project from the ralph-loop repo.
Always run from the project root. Target is always `ralph/`.

Ref (tag or branch — optional, will ask if not provided): $ref

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

Set target to `ralph/`. Check it is an active ralph project directory:
```bash
ls "ralph/config.sh" 2>/dev/null && echo "has config" || echo "no config"
```

If no config.sh found, warn the user and ask if they want to continue.

Read the current locked version:
```bash
LOCKED_REF=$(grep '^RALPH_VERSION=' "ralph/config.sh" 2>/dev/null | cut -d'"' -f2)
echo "Current: ${LOCKED_REF:-unknown}"
```

## Step 2 — Resolve ref

If `$ref` was provided as an argument, use it directly and skip to Step 3.

If no ref was given, fetch available tags and branches from the repo:
```bash
git ls-remote --tags --heads https://github.com/Olunuga/ralph-loop 2>/dev/null \
  | awk '{print $2}' \
  | sed 's|refs/tags/||; s|refs/heads/||' \
  | grep -v '\^{}' \
  | sort -rV
```

Use AskUserQuestion to present the list and ask:
"Current version: ${LOCKED_REF:-unknown}

Available versions:
<list tags and branches>

Which version do you want to update to? Enter a tag, branch name, or 'cancel'."

If the user replies 'cancel', stop.

Use the user's reply as REF.

## Step 3 — Clone ref into a temp directory

```bash
TMPDIR=$(mktemp -d)
git clone --depth 1 --branch "$REF" https://github.com/Olunuga/ralph-loop "$TMPDIR" 2>&1
```

If the clone fails (bad ref or no network), stop and report the error.

## Step 4 — Show diff

```bash
for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md \
          scripts/check_architecture.sh scripts/consensus_judge.sh scripts/hooks/workspace_boundary.sh \
          skills/ralph-init/SKILL.md skills/ralph/SKILL.md skills/ralph-update/SKILL.md skills/spec/SKILL.md; do
    src="$TMPDIR/$f"
    tgt="ralph/$f"
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
"Updating 'ralph/' from ralph-loop@$REF (currently ${LOCKED_REF:-unknown}).
config.sh, AGENTS.md, and specs/ will not be touched.

Proceed? Reply 'yes' or 'no'."

If the user replies no, clean up and stop:
```bash
rm -rf "$TMPDIR"
```

## Step 5 — Copy

```bash
for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md; do
    [[ -f "$TMPDIR/$f" ]] && cp "$TMPDIR/$f" "ralph/$f" && echo "copied: $f"
done

mkdir -p "ralph/scripts/hooks"
for f in scripts/check_architecture.sh scripts/consensus_judge.sh scripts/hooks/workspace_boundary.sh; do
    [[ -f "$TMPDIR/$f" ]] && cp "$TMPDIR/$f" "ralph/$f" && echo "copied: $f"
done

mkdir -p "ralph/skills/ralph-init" "ralph/skills/ralph" "ralph/skills/ralph-update" "ralph/skills/spec"
for f in skills/ralph-init/SKILL.md skills/ralph/SKILL.md skills/ralph-update/SKILL.md skills/spec/SKILL.md; do
    [[ -f "$TMPDIR/$f" ]] && cp "$TMPDIR/$f" "ralph/$f" && echo "copied: $f"
done

chmod +x "ralph/loop.sh" "ralph/scripts/check_architecture.sh" \
         "ralph/scripts/consensus_judge.sh" "ralph/scripts/hooks/workspace_boundary.sh"

rm -rf "$TMPDIR"
```

## Step 6 — Update version lock

```bash
sed -i '' "s|^RALPH_VERSION=.*|RALPH_VERSION=\"$REF\"|" "ralph/config.sh"
```

## Step 7 — Report

Confirm: "Ralph updated in 'ralph/' to ralph-loop@$REF. RALPH_VERSION updated in config.sh."
