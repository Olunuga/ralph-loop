#!/bin/bash
# PreToolUse hook — blocks file operations outside the current workspace.
#
# Install via .claude/settings.json:
#   "hooks": { "PreToolUse": [{ "matcher": "Write|Edit|Bash",
#     "hooks": [{ "type": "command",
#       "command": "bash ralph/scripts/hooks/workspace_boundary.sh" }] }] }
#
# Receives full tool call JSON on stdin:
#   { "tool_name": "Write", "tool_input": { "file_path": "...", ... } }
# Exit 0 = allow. Exit 2 = block (stderr shown to Claude as reason).

set -euo pipefail

INPUT=$(cat)
WORKSPACE=$(realpath "$(pwd)")

# Resolve the main project root (handles both main worktree and git worktrees).
# If we're inside a worktree, PROJECT_WORKSPACE is the main repo root.
# This allows the orchestrator in the main repo to reference .worktrees/ paths.
PROJECT_WORKSPACE=$(git -C "$WORKSPACE" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||' || echo "$WORKSPACE")

# Extract field from the JSON input
json_get() {
    local field="$1"
    echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    val = d.get('tool_input', d).get('$field', '')
    print(val)
except Exception:
    print('')
" 2>/dev/null
}

TOOL=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null)

is_outside_workspace() {
    local path="$1"
    [[ -z "$path" ]] && return 1          # empty path — allow
    [[ "$path" != /* ]] && return 1       # relative path — allow
    [[ "$path" == /dev/* ]] && return 1   # standard devices (/dev/null etc) — allow
    local resolved
    resolved=$(python3 -c "
import os, sys
print(os.path.realpath('$path'))
" 2>/dev/null || echo "$path")
    # Allow paths within the workspace itself
    [[ "$resolved" == "$WORKSPACE"* ]] && return 1
    # Allow paths within worktrees of the same project (sibling .worktrees/)
    [[ "$resolved" == "$PROJECT_WORKSPACE"/.worktrees/* ]] && return 1
    # Outside workspace
    return 0
}

block() {
    echo "WORKSPACE BOUNDARY: $1" >&2
    echo "  Workspace: $WORKSPACE" >&2
    exit 2
}

# Check all standalone absolute paths in a block of text.
# Uses negative lookbehind so path components inside relative refs
# (e.g. /banner from ralph/banner) are not extracted as absolute paths.
check_paths() {
    local text="$1"
    local label="${2:-command}"
    while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        if is_outside_workspace "$token"; then
            block "$label references path outside workspace: '$token'"
        fi
    done < <(echo "$text" | python3 -c "
import re, sys
for m in re.finditer(r'(?<![\w:])/[a-zA-Z0-9_.][^\s|&;\"\'> ]*', sys.stdin.read()):
    print(m.group())
" 2>/dev/null || true)
}

case "$TOOL" in
    Write|Edit)
        FILE=$(json_get "file_path")
        if is_outside_workspace "$FILE"; then
            block "$TOOL attempted on '$FILE' — outside workspace"
        fi
        ;;

    Bash)
        CMD=$(json_get "command")

        # Expand known env vars before path checking
        EXPANDED_CMD=$(echo "$CMD" | python3 -c "
import os, sys
text = sys.stdin.read()
for var in ['HOME', 'TMPDIR']:
    val = os.environ.get(var, '')
    if val:
        text = text.replace('~', val, 1) if var == 'HOME' else text
        text = text.replace('\$' + var, val).replace('\${' + var + '}', val)
print(text)
" 2>/dev/null || echo "$CMD")

        # Check for cd to relative paths that resolve outside workspace
        CD_TARGET=$(echo "$EXPANDED_CMD" | python3 -c "
import re, os, sys
text = sys.stdin.read()
workspace = '$WORKSPACE'
for m in re.finditer(r'\bcd\s+([^\s;&|]+)', text):
    target = m.group(1).strip('\"').strip(\"'\")
    if not os.path.isabs(target):
        resolved = os.path.realpath(os.path.join(workspace, target))
        if not resolved.startswith(workspace):
            print(resolved)
            break
" 2>/dev/null || true)

        if [[ -n "$CD_TARGET" ]]; then
            block "Bash cd resolves to path outside workspace: '$CD_TARGET'"
        fi

        # Check direct paths in the command string
        check_paths "$EXPANDED_CMD" "Bash command"

        # If the command executes a shell script, also check the script's contents.
        # This closes the backdoor where an agent writes a helper script inside the
        # workspace and uses it to reference paths outside without the hook seeing them.
        SCRIPT=$(echo "$CMD" | python3 -c "
import re, sys
m = re.search(r'(?:bash|sh|zsh|source|\.)\s+(?:-\w+\s*)*((?:/|\./)[^\s]+\.sh)', sys.stdin.read())
if m: print(m.group(1))
" 2>/dev/null || true)

        if [[ -n "$SCRIPT" && -f "$SCRIPT" ]]; then
            check_paths "$(cat "$SCRIPT")" "Script '$SCRIPT'"
        fi
        ;;
esac

exit 0
