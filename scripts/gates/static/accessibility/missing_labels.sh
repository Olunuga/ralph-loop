#!/bin/bash
set -euo pipefail

gate_name() { echo "Missing accessibility labels on Image/Button"; }
gate_category() { echo "accessibility"; }
gate_tier() { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    # Get added lines from .swift files, grouped by file
    local diff_added
    diff_added=$(git diff "$BASE_REF"...HEAD --diff-filter=ACMR -U0 -- "$src" \
        | awk '
        /^diff --git/ {
            file = $NF; sub(/^b\//, "", file)
            if (file !~ /\.swift$/) file = ""
        }
        /^\+[^+]/ && file != "" { print file ":" $0 }
    ')

    [[ -z "$diff_added" ]] && return 0

    # Check if added lines contain Image( or Button(
    local image_button_lines
    image_button_lines=$(echo "$diff_added" | grep -E '(Image\(|Button\()' || true)

    [[ -z "$image_button_lines" ]] && return 0

    # Get files that added Image/Button
    local files_with_new_widgets
    files_with_new_widgets=$(echo "$image_button_lines" | cut -d: -f1 | sort -u)

    # Check if added lines in those files also include .accessibilityLabel
    local flagged=""
    while IFS= read -r file; do
        local file_added_lines
        file_added_lines=$(echo "$diff_added" | grep "^${file}:" || true)
        if ! echo "$file_added_lines" | grep -q '\.accessibilityLabel'; then
            flagged="$flagged"$'\n'"  $file"
        fi
    done <<< "$files_with_new_widgets"

    if [[ -n "$flagged" ]]; then
        echo "Added Image/Button in diff without .accessibilityLabel:"
        echo "$flagged"
        echo ""
        echo "Add .accessibilityLabel() to new Image and Button views for VoiceOver support."
        return 1
    fi

    return 0
}
