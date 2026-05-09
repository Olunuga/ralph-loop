#!/bin/bash
set -euo pipefail

gate_name()  { echo "Print statement detection"; }
gate_category()  { echo "code_quality"; }
gate_tier()  { echo "fast"; }

gate_check() {
    local base_ref
    base_ref=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    local diff_output
    diff_output=$(git diff "$base_ref"..HEAD -- "$src/" 2>/dev/null) || true
    [[ -z "$diff_output" ]] && return 0

    # Extract added lines with file context, excluding test files and #Preview blocks
    local hits
    hits=$(echo "$diff_output" | awk '
        /^diff --git/ {
            split($0, parts, " b/")
            current_file = parts[2]
            # Skip test files
            if (current_file ~ /Tests\.swift$/ || current_file ~ /Spec\.swift$/) {
                skip = 1
            } else {
                skip = 0
            }
            in_preview = 0
            next
        }
        skip { next }

        # Track #Preview blocks (simple heuristic)
        /^\+.*#Preview/ { in_preview = 1; next }

        # Added lines only
        /^\+/ && !/^\+\+\+/ {
            if (in_preview) next
            line = substr($0, 2)
            # Skip comments
            if (line ~ /^[[:space:]]*\/\//) next
            if (line ~ /print\(/) {
                print current_file ": " line
            }
        }
    ')

    [[ -z "$hits" ]] && return 0

    local count
    count=$(echo "$hits" | wc -l | tr -d ' ')
    echo "Found $count print() call(s) in production code — use os_log or Logger instead:"
    echo "$hits"
    return 1
}
