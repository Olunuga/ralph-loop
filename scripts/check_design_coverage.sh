#!/bin/bash
# Report screen states the design names that no task covers.
#
# Usage: check_design_coverage.sh <change_dir>
#
# Exit 0 = every named state has a task, or the change has no screens.
# Exit 1 = at least one state has no task.
#
# This is deliberately NOT a gate under scripts/gates/. A gate failure is handed to an
# agent to fix, and the only fix here is editing tasks.md, the ledger both the loop and a
# human tick off. It runs once, before the pull request opens, and edits nothing.
#
# It answers one question: does every state label appear somewhere in tasks.md? Whether a
# task describes the state correctly needs judgement and is not attempted here.

set -euo pipefail

CHANGE_DIR="${1:?Usage: check_design_coverage.sh <change_dir>}"
TASKS="$CHANGE_DIR/tasks.md"
BUNDLE="$CHANGE_DIR/assets/design"
PROMPT="$CHANGE_DIR/design/SCREEN_PROMPT.md"

[[ -f "$TASKS" ]] || { echo "No tasks.md in $CHANGE_DIR. Skipping."; exit 0; }

if [[ ! -d "$BUNDLE" && ! -f "$PROMPT" ]]; then
    echo "No screens in this change. Skipping."
    exit 0
fi

if [[ ! -d "$BUNDLE" ]]; then
    echo "Designs have not arrived for this change. Skipping."
    echo "  A state named only in SCREEN_PROMPT.md is a promise, not a drawing."
    exit 0
fi

# State labels come from the bundle README, which Claude Design writes for a coding agent.
# Its state tables use a leading "| <label> |" cell, and its headings use "### <label>".
README=$(find "$BUNDLE" -maxdepth 2 -iname "README.md" | head -1)
if [[ -z "$README" ]]; then
    echo "No README in $BUNDLE. Cannot list the states without one."
    echo "  Ask Claude Design for a bundle README, or check the states by hand."
    exit 0
fi

STATES=$(
    {
        grep -E '^\| [^|]+ \|' "$README" 2>/dev/null | sed 's/^| *//; s/ *|.*//'
        grep -E '^#{3,4} ' "$README" 2>/dev/null | sed 's/^#* *//'
    } | sed 's/[*`]//g; s/^ *//; s/ *$//' \
      | grep -vEi '^(states?|treatments?|files?|purpose|overview|assets|rules|contrast|screens?|notes?|decisions?|-+)$' \
      | grep -vE '^$' | sort -u
)

[[ -z "$STATES" ]] && { echo "No state labels found in $README. Skipping."; exit 0; }

TASK_TEXT=$(tr '[:upper:]' '[:lower:]' < "$TASKS")
MISSING=""
TOTAL=0
while IFS= read -r state; do
    [[ -n "$state" ]] || continue
    TOTAL=$((TOTAL + 1))
    # Match on the distinctive words of the label, not the whole string: a task rarely
    # repeats a label verbatim. Any one word matching is enough. This check blocks a pull
    # request, so it errs towards passing: the skill-level comparison in run Step 0b is the
    # thorough one, and a false failure here would block work that is actually correct.
    KEY=$(echo "$state" | tr '[:upper:]' '[:lower:]' \
        | tr -cs '[:alnum:]' ' ' \
        | tr ' ' '\n' \
        | grep -vE '^(a|an|the|and|or|of|in|on|at|to|is|it|its|with|for|no|not|first|from|that|this|then|when|into|over|same|full|only|more|each)$' \
        | grep -E '.{4,}' | sort -u)
    [[ -z "$KEY" ]] && continue
    FOUND=0
    for word in $KEY; do
        if echo "$TASK_TEXT" | grep -q "$word"; then FOUND=1; break; fi
    done
    [[ "$FOUND" -eq 0 ]] && MISSING="$MISSING
  - $state"
done <<< "$STATES"

if [[ -n "$MISSING" ]]; then
    echo "Design coverage: FAIL"
    echo ""
    echo "$README names $TOTAL states. No task covers these:$MISSING"
    echo ""
    echo "Reconcile the tasks with the drawn screens, then re-run:"
    echo "    /ralph-loop:run $(basename "$CHANGE_DIR")"
    exit 1
fi

echo "Design coverage: PASS ($TOTAL states, each named by a task)"
exit 0
