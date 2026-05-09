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

Generic files to sync (never touches config.sh, AGENTS.md, specs/, lessons.md, or gate_context.md):
- loop.sh
- PROMPT_bootstrap.md
- PROMPT_build.md
- PROMPT_plan.md
- PROMPT_plan_work.md
- SETUP.md
- SETUP_SKILLS.md
- scripts/run_static_gates.sh
- scripts/run_llm_gates.sh
- scripts/prepare_diff.sh
- scripts/hooks/workspace_boundary.sh
- scripts/gates/static/**/*.sh
- scripts/gates/llm/*.md

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
TMPDIR_RALPH="$TMPDIR/ralph_update_$$"
mkdir -p "$TMPDIR_RALPH"
git clone --depth 1 --branch "$REF" https://github.com/Olunuga/ralph-loop "$TMPDIR_RALPH" 2>&1
```

If the clone fails (bad ref or no network), stop and report the error.

## Step 4 — Show diff

Compare all generic pipeline files between the cloned repo and the local ralph/:

```bash
TMPDIR_RALPH="$TMPDIR/ralph_update_$$"

echo "=== Core files ==="
for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md; do
    src="$TMPDIR_RALPH/$f"; tgt="ralph/$f"
    if [[ ! -f "$src" ]]; then echo "REMOVED: $f"
    elif [[ ! -f "$tgt" ]]; then echo "NEW: $f"
    elif diff -q "$src" "$tgt" > /dev/null 2>&1; then echo "unchanged: $f"
    else echo "CHANGED: $f"
    fi
done

echo "=== Scripts ==="
for f in scripts/run_static_gates.sh scripts/run_llm_gates.sh scripts/prepare_diff.sh scripts/hooks/workspace_boundary.sh; do
    src="$TMPDIR_RALPH/$f"; tgt="ralph/$f"
    if [[ ! -f "$src" ]]; then echo "REMOVED: $f"
    elif [[ ! -f "$tgt" ]]; then echo "NEW: $f"
    elif diff -q "$src" "$tgt" > /dev/null 2>&1; then echo "unchanged: $f"
    else echo "CHANGED: $f"
    fi
done

echo "=== Static gates ==="
for f in "$TMPDIR_RALPH"/scripts/gates/static/*/*.sh; do
    [ -f "$f" ] || continue
    REL="${f#$TMPDIR_RALPH/}"
    tgt="ralph/$REL"
    if [[ ! -f "$tgt" ]]; then echo "NEW: $REL"
    elif diff -q "$f" "$tgt" > /dev/null 2>&1; then echo "unchanged: $REL"
    else echo "CHANGED: $REL"
    fi
done

echo "=== LLM gates ==="
for f in "$TMPDIR_RALPH"/scripts/gates/llm/*.md; do
    [ -f "$f" ] || continue
    REL="${f#$TMPDIR_RALPH/}"
    tgt="ralph/$REL"
    if [[ ! -f "$tgt" ]]; then echo "NEW: $REL"
    elif diff -q "$f" "$tgt" > /dev/null 2>&1; then echo "unchanged: $REL"
    else echo "CHANGED: $REL"
    fi
done

# Check for files in local ralph/ that were removed from repo
for f in ralph/scripts/check_architecture.sh ralph/scripts/consensus_judge.sh; do
    [[ -f "$f" ]] && echo "OBSOLETE (will be removed): $f"
done
```

Use AskUserQuestion to show the diff summary and ask:
"Updating 'ralph/' from ralph-loop@$REF (currently ${LOCKED_REF:-unknown}).
config.sh, AGENTS.md, specs/, lessons.md, and gate_context.md will not be touched.

Proceed? Reply 'yes' or 'no'."

If the user replies no, clean up and stop:
```bash
rm -rf "$TMPDIR_RALPH"
```

## Step 5 — Copy

```bash
TMPDIR_RALPH="$TMPDIR/ralph_update_$$"

# Core files
for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md; do
    [[ -f "$TMPDIR_RALPH/$f" ]] && cp "$TMPDIR_RALPH/$f" "ralph/$f" && echo "copied: $f"
done

# Scripts and hooks
mkdir -p "ralph/scripts/hooks"
for f in scripts/run_static_gates.sh scripts/run_llm_gates.sh scripts/prepare_diff.sh scripts/hooks/workspace_boundary.sh; do
    [[ -f "$TMPDIR_RALPH/$f" ]] && cp "$TMPDIR_RALPH/$f" "ralph/$f" && echo "copied: $f"
done

# Static gates
for f in "$TMPDIR_RALPH"/scripts/gates/static/*/*.sh; do
    [ -f "$f" ] || continue
    REL="${f#$TMPDIR_RALPH/}"
    mkdir -p "ralph/$(dirname "$REL")"
    cp "$f" "ralph/$REL" && echo "copied: $REL"
done

# LLM gates
mkdir -p "ralph/scripts/gates/llm"
for f in "$TMPDIR_RALPH"/scripts/gates/llm/*.md; do
    [ -f "$f" ] || continue
    REL="${f#$TMPDIR_RALPH/}"
    cp "$f" "ralph/$REL" && echo "copied: $REL"
done

# Remove obsolete files from old versions
for f in ralph/scripts/check_architecture.sh ralph/scripts/consensus_judge.sh; do
    [[ -f "$f" ]] && rm "$f" && echo "removed obsolete: $f"
done

# Make scripts executable
find ralph/scripts -name "*.sh" -exec chmod +x {} \;
chmod +x ralph/loop.sh

rm -rf "$TMPDIR_RALPH"
```

## Step 6 — Update version lock

```bash
REF="${ref:-main}"
if grep -q "^RALPH_VERSION=" "ralph/config.sh" 2>/dev/null; then
    sed -i '' "s|^RALPH_VERSION=.*|RALPH_VERSION=\"$REF\"|" "ralph/config.sh"
else
    echo "RALPH_VERSION=\"$REF\"" >> "ralph/config.sh"
fi
```

## Step 7 — Report

Confirm: "Ralph updated in 'ralph/' to ralph-loop@$REF. RALPH_VERSION updated in config.sh."
