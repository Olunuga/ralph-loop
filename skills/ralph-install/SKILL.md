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
TMPDIR_RALPH="$TMPDIR/ralph_install_$$"
mkdir -p "$TMPDIR_RALPH"
git clone --depth 1 --branch "$REF" https://github.com/Olunuga/ralph-loop "$TMPDIR_RALPH" 2>&1 \
  && echo "TMPDIR=$TMPDIR_RALPH" && echo "cloned ok" || echo "clone failed"
```

If clone failed, stop and report the error.

## Step 3 — Copy into ralph/

Copy the pipeline files. Do NOT touch config.sh, AGENTS.md, specs/, lessons.md, or gate_context.md — those are project-specific.

```bash
TMPDIR_RALPH="$TMPDIR/ralph_install_$$"

# Create directory structure
mkdir -p ralph/scripts/hooks \
         ralph/scripts/gates/static/code_quality \
         ralph/scripts/gates/static/architecture \
         ralph/scripts/gates/static/security \
         ralph/scripts/gates/static/accessibility \
         ralph/scripts/gates/llm

# Core pipeline files
for f in loop.sh PROMPT_bootstrap.md PROMPT_build.md PROMPT_plan.md PROMPT_plan_work.md SETUP.md SETUP_SKILLS.md; do
    cp "$TMPDIR_RALPH/$f" ralph/$f && echo "copied: $f"
done

# Gate dispatchers and utilities
for f in scripts/run_static_gates.sh scripts/run_llm_gates.sh scripts/prepare_diff.sh scripts/hooks/workspace_boundary.sh; do
    cp "$TMPDIR_RALPH/$f" ralph/$f && echo "copied: $f"
done

# Static gate checks
for f in "$TMPDIR_RALPH"/scripts/gates/static/*/*.sh; do
    [ -f "$f" ] || continue
    REL="${f#$TMPDIR_RALPH/}"
    cp "$f" "ralph/$REL" && echo "copied: $REL"
done

# LLM gate prompts
for f in "$TMPDIR_RALPH"/scripts/gates/llm/*.md; do
    [ -f "$f" ] || continue
    REL="${f#$TMPDIR_RALPH/}"
    cp "$f" "ralph/$REL" && echo "copied: $REL"
done

# Make scripts executable
find ralph/scripts -name "*.sh" -exec chmod +x {} \;
chmod +x ralph/loop.sh

rm -rf "$TMPDIR_RALPH"
```

## Step 4 — Record version

Write the installed version into `ralph/config.sh`. If config.sh already exists, only update the RALPH_VERSION line. If it doesn't exist, create a minimal one:

```bash
REF="${ref:-main}"
if [ -f ralph/config.sh ]; then
    if grep -q "^RALPH_VERSION=" ralph/config.sh; then
        sed -i '' "s|^RALPH_VERSION=.*|RALPH_VERSION=\"$REF\"|" ralph/config.sh
    else
        echo "RALPH_VERSION=\"$REF\"" >> ralph/config.sh
    fi
else
    echo "RALPH_VERSION=\"$REF\"" > ralph/config.sh
fi
echo "RALPH_VERSION set to $REF"
```

## Step 5 — Report

Confirm: "ralph-loop@${ref:-main} installed into ralph/. Run /ralph-init to complete setup."
