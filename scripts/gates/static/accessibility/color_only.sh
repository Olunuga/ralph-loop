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

    # Extract unique files that use color in added lines
    local color_files
    color_files=$(echo "$color_lines" | cut -d: -f1 | sort -u)

    # For each file, check if conditionals with color changes exist
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        # Check if the file has color changes inside conditional blocks
        # Look for if/switch/ternary near foregroundColor/tint
        local conditional_color
        conditional_color=$(grep -n -E '(if |switch |.*\?.*:)' "$file" \
            | while IFS= read -r cond_line; do
                local line_num
                line_num=$(echo "$cond_line" | cut -d: -f1)
                # Check a window of 5 lines after the conditional for color usage
                sed -n "$((line_num)),$((line_num + 5))p" "$file" \
                    | grep -q '\.\(foregroundColor\|tint\)(' && echo "$file:$line_num"
            done || true)

        if [[ -n "$conditional_color" ]]; then
            flagged="$flagged"$'\n'"  $conditional_color"
        fi
    done <<< "$color_files"

    if [[ -n "$flagged" ]]; then
        echo "Possible color-only state differentiation found:"
        echo "$flagged"
        echo ""
        echo "Verify that state changes are not conveyed by color alone. Add icons, labels, or shapes to support users with color vision deficiency (WCAG 1.4.1)."
        return 1
    fi

    return 0
}
