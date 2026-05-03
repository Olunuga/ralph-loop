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
print(os.path.normpath('$path'))
" 2>/dev/null || echo "$path")
    [[ "$resolved" != "$WORKSPACE"* ]]
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

        # Check direct paths in the command string
        check_paths "$CMD" "Bash command"

        # If the command executes a shell script, also check the script's contents.
        # This closes the backdoor where an agent writes a helper script inside the
        # workspace and uses it to reference paths outside without the hook seeing them.
        SCRIPT=$(echo "$CMD" | python3 -c "
import re, sys
m = re.search(r'(?:bash|sh)\s+(?:-\w+\s*)*((?:/|\./)[^\s]+\.sh)', sys.stdin.read())
if m: print(m.group(1))
" 2>/dev/null || true)

        if [[ -n "$SCRIPT" && -f "$SCRIPT" ]]; then
            check_paths "$(cat "$SCRIPT")" "Script '$SCRIPT'"
        fi
        ;;
esac

exit 0
