#!/bin/bash
# LLM consensus judge — runs 3 independent reviews, requires 2/3 PASS.
# Called post-loop by ralph/loop.sh.
# Exit 0 = consensus pass. Exit 1 = consensus fail.

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

PROTOCOLS=$(find "$PROTOCOLS_DIR" -name "*.swift" 2>/dev/null \
    | xargs cat 2>/dev/null || echo "(no protocols found)")

BASE=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
DIFF=$(git diff "$BASE"...HEAD -- "$SOURCE_DIR/" 2>/dev/null)

if [ -z "$DIFF" ]; then
    echo "JUDGE: No diff against main — nothing to review."
    exit 0
fi

PROMPT="You are reviewing an iOS SwiftUI app ($APP_NAME — $APP_DESCRIPTION).

PROTOCOLS (source of truth for data access):
$PROTOCOLS

CODE CHANGES:
$DIFF

Answer PASS or FAIL for each question, then give an OVERALL verdict:

1. New repository types conform to their protocol in $PROTOCOLS_DIR/?
2. New ViewModel types use @Observable (not ObservableObject)?
3. Views reference only ViewModels — no direct Repository or Service usage?
4. No force unwraps (try!, !., as!) in new or modified code?
5. No placeholder logic, stubs, or TODO comments in new code?
6. New types have explicit access control (public/internal — no implicit)?

Respond with exactly:
1: PASS|FAIL
2: PASS|FAIL
3: PASS|FAIL
4: PASS|FAIL
5: PASS|FAIL
6: PASS|FAIL
OVERALL: PASS|FAIL
[One sentence explaining any FAILs, or 'All checks passed.' if none]"

PASS_COUNT=0
DETAILS=""

for i in 1 2 3; do
    RESULT=$(echo "$PROMPT" | claude -p --model claude-sonnet-4-6 2>/dev/null)
    if echo "$RESULT" | grep -q "^OVERALL: PASS"; then
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        DETAILS="$RESULT"
    fi
done

if [ "$PASS_COUNT" -ge 2 ]; then
    echo "JUDGE CONSENSUS: PASS ($PASS_COUNT/3)"
    exit 0
fi

echo "JUDGE CONSENSUS: FAIL ($PASS_COUNT/3)"
echo "$DETAILS"
exit 1
