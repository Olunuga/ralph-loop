#!/bin/bash
set -euo pipefail

gate_name() { echo "Color-only state differentiation"; }
gate_category() { echo "accessibility"; }
gate_tier() { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base "${DIFF_BASE_BRANCH:-main}" HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    # Get added lines from .swift files with surrounding context to detect conditionals
    local diff_output
    diff_output=$(git diff "$BASE_REF"...HEAD --diff-filter=ACMR -U0 -- "$src" \
        | awk '
        /^diff --git/ {
            file = $NF; sub(/^b\//, "", file)
            if (file !~ /\.swift$/) file = ""
        }
        /^\+[^+]/ && file != "" { print file ":" $0 }
    ')

    [[ -z "$diff_output" ]] && return 0

    # The colour change and the condition must be on the same added line. Testing them
    # per file flagged any file holding a colour modifier and an `if` anywhere in its diff,
    # and no accessibility fix cleared it: adding an icon removes neither.
    #
    # .tint() is excluded. It sets an accent for a control that already carries its own
    # shape and label, so it is not state conveyed by colour alone.
    local flagged
    flagged=$(echo "$diff_output" \
        | grep -E '\.foregroundColor\(' \
        | grep -E '(\bif\b|\?.*:|\bswitch\b)' \
        | sed 's/^/  /' \
        || true)

    if [[ -n "$flagged" ]]; then
        echo "Possible color-only state differentiation found:"
        echo "$flagged"
        echo ""
        echo "Verify that state changes are not conveyed by color alone. Add icons, labels, or shapes to support users with color vision deficiency (WCAG 1.4.1)."
        return 1
    fi

    return 0
}
