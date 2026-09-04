#!/bin/bash
# ralph-loop Claude Code Stop hook: reports fast-tier static gate failures in-session.
#
# Opt-in. /ralph-loop:init --openspec registers this only on an explicit yes.
# Runs the fast static tier only. It never runs LLM gates and never makes a model
# call, so its cost stays bounded even though Stop fires after every turn.

set -uo pipefail

if [[ -z "${RALPH_PLUGIN_DIR:-}" ]]; then
    LOOP_PATH=$(command -v loop.sh 2>/dev/null || true)
    [[ -n "$LOOP_PATH" ]] && RALPH_PLUGIN_DIR="$(CDPATH= cd "$(dirname "$LOOP_PATH")/.." && pwd)"
fi
[[ -n "${RALPH_PLUGIN_DIR:-}" && -d "$RALPH_PLUGIN_DIR/scripts" ]] || exit 0
export RALPH_PLUGIN_DIR

PROJECT_ROOT=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||')
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
export PROJECT_ROOT

[[ -f "$PROJECT_ROOT/ralph/config.sh" ]] || exit 0
# shellcheck source=/dev/null
source "$PROJECT_ROOT/ralph/config.sh"

RUNNER="$RALPH_PLUGIN_DIR/scripts/run_static_gates.sh"
[[ -f "$RUNNER" ]] || exit 0

if [[ -z "${DIFF_BASE_BRANCH:-}" && -f "$PROJECT_ROOT/ralph/.diff_base" ]]; then
    DIFF_BASE_BRANCH=$(tr -d '[:space:]' < "$PROJECT_ROOT/ralph/.diff_base")
fi
export DIFF_BASE_BRANCH="${DIFF_BASE_BRANCH:-main}"

OUTPUT=$(bash "$RUNNER" fast 2>&1) || {
    printf '%s' "$OUTPUT" | python3 -c "
import json,sys
print(json.dumps({'systemMessage': 'ralph fast static gates FAILED\n' + sys.stdin.read()}))" 2>/dev/null \
    || echo "ralph fast static gates FAILED"
    exit 0
}
exit 0
