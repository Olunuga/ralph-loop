#!/bin/bash
set -euo pipefail

gate_name() { echo "Missing accessibility labels on Image/Button"; }
gate_category() { echo "accessibility"; }
gate_tier() { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    # Get changed .swift files
    local changed_files
    changed_files=$(git diff "$BASE_REF"...HEAD --diff-filter=ACMR --name-only -- "$src" \
        | grep '\.swift$' || true)

    [[ -z "$changed_files" ]] && return 0

    local flagged=""

    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        # Check if file has Image( or Button( calls
        if grep -qE '(Image\(|Button\()' "$file" 2>/dev/null; then
            # Check if file has any .accessibilityLabel usage
            if ! grep -q '\.accessibilityLabel' "$file" 2>/dev/null; then
                flagged="$flagged"$'\n'"  $file"
            fi
        fi
    done <<< "$changed_files"

    if [[ -n "$flagged" ]]; then
        echo "Files with Image/Button but no .accessibilityLabel:"
        echo "$flagged"
        echo ""
        echo "Add .accessibilityLabel() to Image and Button views for VoiceOver support."
        return 1
    fi

    return 0
}
