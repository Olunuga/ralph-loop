#!/bin/bash
set -euo pipefail

gate_name() { echo "Insecure HTTP URLs"; }
gate_category() { echo "security"; }
gate_tier() { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"
    local found=0

    # Get added lines from .swift and Info.plist files
    local diff_output
    diff_output=$(git diff "$BASE_REF"...HEAD --diff-filter=ACMR -U0 -- "$src" \
        | awk '
        /^diff --git/ {
            file = $NF; sub(/^b\//, "", file)
            if (file !~ /\.swift$/ && file !~ /Info\.plist$/) file = ""
        }
        /^\+[^+]/ && file != "" { print file ":" $0 }
    ')

    [[ -z "$diff_output" ]] && return 0

    # Find http:// URLs, excluding localhost and comments
    local matches
    matches=$(echo "$diff_output" \
        | grep -i 'http://' \
        | grep -v 'http://localhost' \
        | grep -v 'http://127\.0\.0\.1' \
        | grep -v 'http://0\.0\.0\.0' \
        | grep -v '^\s*//' \
        | grep -v '^\s*\*' \
        | grep -v '^\s*///' \
        || true)

    if [[ -n "$matches" ]]; then
        echo "Insecure http:// URLs found in added lines:"
        echo "$matches"
        echo ""
        echo "Use https:// instead. If http is required, add an ATS exception with justification."
        return 1
    fi

    return 0
}
