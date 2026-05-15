---
name: migrate
description: Migrate an existing ralph/ installation to plugin mode
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

Migrate a project from the legacy ralph/ file-copy installation to plugin mode.
Pipeline code now lives in the plugin — only project-specific files stay in ralph/.

## Step 1 — Verify existing installation

Check for existing ralph installation:
```bash
test -f ralph/config.sh && echo "config: found" || echo "config: missing"
test -f ralph/AGENTS.md && echo "agents: found" || echo "agents: missing"
test -f ralph/loop.sh && echo "loop.sh: found (will be removed)" || echo "loop.sh: already removed"
ls ralph/specs/*.md 2>/dev/null | wc -l | xargs -I{} echo "specs: {} files"
test -d ralph/scripts/gates && echo "gates: found" || echo "gates: not found"
```

If ralph/config.sh is missing, stop: "No existing ralph installation found. Run /ralph-loop:init instead."

## Step 2 — Move custom gates

If the project has custom gates in `ralph/scripts/gates/`, move them to the new location:

```bash
mkdir -p ralph/gates/static ralph/gates/llm

# Move any project-specific static gates (skip default categories that ship with plugin)
PLUGIN_DIR="$(dirname "$(which loop.sh)")/.."
for dir in ralph/scripts/gates/static/*/; do
    [ -d "$dir" ] || continue
    CATEGORY=$(basename "$dir")
    # Check if this category exists in the plugin — if so, only move non-default files
    for gate in "$dir"*.sh; do
        [ -f "$gate" ] || continue
        GATE_NAME=$(basename "$gate")
        if [ -f "$PLUGIN_DIR/scripts/gates/static/$CATEGORY/$GATE_NAME" ]; then
            echo "SKIP (default): $CATEGORY/$GATE_NAME"
        else
            mkdir -p "ralph/gates/static/$CATEGORY"
            mv "$gate" "ralph/gates/static/$CATEGORY/$GATE_NAME"
            echo "MOVED: $CATEGORY/$GATE_NAME → ralph/gates/static/$CATEGORY/"
        fi
    done
done

# Move any custom LLM gates
for gate in ralph/scripts/gates/llm/*.md; do
    [ -f "$gate" ] || continue
    GATE_NAME=$(basename "$gate")
    if [ -f "$PLUGIN_DIR/scripts/gates/llm/$GATE_NAME" ]; then
        echo "SKIP (default): llm/$GATE_NAME"
    else
        mv "$gate" "ralph/gates/llm/$GATE_NAME"
        echo "MOVED: llm/$GATE_NAME → ralph/gates/llm/"
    fi
done
```

## Step 3 — Copy updated hook

```bash
PLUGIN_DIR="$(dirname "$(which loop.sh)")/.."
mkdir -p ralph/scripts/hooks
cp "$PLUGIN_DIR/scripts/hooks/workspace_boundary.sh" ralph/scripts/hooks/workspace_boundary.sh
chmod +x ralph/scripts/hooks/workspace_boundary.sh
echo "Hook updated from plugin."
```

## Step 4 — Delete pipeline files now served by the plugin

```bash
# Core pipeline (now in plugin bin/)
rm -f ralph/loop.sh

# Prompts (now in plugin prompts/)
rm -f ralph/PROMPT_bootstrap.md ralph/PROMPT_build.md ralph/PROMPT_plan.md ralph/PROMPT_plan_work.md

# Setup docs (replaced by plugin README)
rm -f ralph/SETUP.md ralph/SETUP_SKILLS.md

# Scripts (now in plugin scripts/)
rm -f ralph/scripts/run_static_gates.sh ralph/scripts/run_llm_gates.sh ralph/scripts/prepare_diff.sh ralph/scripts/blast_radius.sh

# Default gates (now in plugin scripts/gates/)
rm -rf ralph/scripts/gates

echo "Pipeline files removed."
```

## Step 5 — Update .claude/settings.json

Read the existing `.claude/settings.json` and update permissions:
- Replace `Bash(bash ralph/loop.sh*)` with `Bash(loop.sh*)`
- Replace `Bash(cd .worktrees/* && bash ralph/loop.sh*)` with `Bash(cd .worktrees/* && loop.sh*)`
- Add `Bash(blast_radius.sh*)` if not present
- Remove `Bash(source ralph/config.sh*)` (no longer needed in permissions)

## Step 6 — Commit

```bash
git add -A ralph/ .claude/settings.json
git -c commit.gpgsign=false commit -m "chore: migrate ralph to plugin mode"
```

## Done

Tell the user:

"Migration complete. Pipeline code now comes from the ralph-loop plugin.

What's in ralph/ now (project-specific only):
- ralph/config.sh — build commands
- ralph/AGENTS.md — codebase architecture
- ralph/specs/ — feature specifications
- ralph/gates/ — custom project gates (if any)
- ralph/scripts/hooks/workspace_boundary.sh — sandbox hook

What was removed (served by plugin):
- ralph/loop.sh, ralph/PROMPT_*.md, ralph/scripts/gates/, ralph/scripts/run_*.sh

Next: /ralph-loop:run TICKET-001 to test the pipeline."
