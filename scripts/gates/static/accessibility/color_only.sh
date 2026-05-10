#!/bin/bash
set -euo pipefail

gate_name() { echo "Color-only state differentiation"; }
gate_category() { echo "accessibility"; }
gate_tier() { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
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

    # Pragmatic approach: flag .foregroundColor( or .tint( inside conditional blocks
    # Look for lines with color changes that also have conditional keywords
    local flagged=""

    # Collect files that have color inside conditionals in added lines
    local color_lines
    color_lines=$(echo "$diff_output" \
        | grep -E '\.(foregroundColor|tint)\(' \
        || true)

    [[ -z "$color_lines" ]] && return 0

    # Check if added lines contain both conditionals and color — entirely within the diff
    local conditional_color_files
    conditional_color_files=$(echo "$color_lines" | cut -d: -f1 | sort -u)

    while IFS= read -r file; do
        # Get all added lines for this file
        local file_added
        file_added=$(echo "$diff_output" | grep "^${file}:" || true)

        # Check if added lines contain conditionals near color
        local has_conditional
        has_conditional=$(echo "$file_added" | grep -E '(if |switch |.*\?.*:)' || true)

        if [[ -n "$has_conditional" ]]; then
            flagged="$flagged"$'\n'"  $file (conditional + color in added lines)"
        fi
    done <<< "$conditional_color_files"

    if [[ -n "$flagged" ]]; then
        echo "Possible color-only state differentiation found:"
        echo "$flagged"
        echo ""
        echo "Verify that state changes are not conveyed by color alone. Add icons, labels, or shapes to support users with color vision deficiency (WCAG 1.4.1)."
        return 1
    fi

    return 0
}
