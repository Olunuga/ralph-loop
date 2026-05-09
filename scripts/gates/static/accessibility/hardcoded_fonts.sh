#!/bin/bash
set -euo pipefail

gate_name() { echo "Hardcoded font sizes (no Dynamic Type)"; }
gate_category() { echo "accessibility"; }
gate_tier() { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    # Get added lines from .swift files
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

    # Find hardcoded font sizes: .systemFont(ofSize: or Font.system(size:
    local matches
    matches=$(echo "$diff_output" \
        | grep -E '(\.systemFont\(ofSize:\s*[0-9]|Font\.system\(size:\s*[0-9])' \
        || true)

    if [[ -n "$matches" ]]; then
        echo "Hardcoded font sizes found in added lines:"
        echo "$matches"
        echo ""
        echo "Use UIFont.preferredFont(forTextStyle:) or SwiftUI text styles (Font.body, Font.title, etc.) for Dynamic Type support."
        return 1
    fi

    return 0
}
