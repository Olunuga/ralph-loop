#!/bin/bash
set -euo pipefail

gate_name()  { echo "Force unwrap detection"; }
gate_category()  { echo "code_quality"; }
gate_tier()  { echo "fast"; }

gate_check() {
    local base_ref
    base_ref=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    # Exclusion patterns from config or defaults
    if [[ -z "${FORCE_UNWRAP_EXCLUDES+x}" ]]; then
        FORCE_UNWRAP_EXCLUDES=('#Preview' 'isStoredInMemoryOnly')
    fi

    local diff_output
    diff_output=$(git diff "$base_ref"..HEAD -- "$src/" 2>/dev/null) || true
    [[ -z "$diff_output" ]] && return 0

    local hits
    hits=$(echo "$diff_output" | awk '
        # Track current file from diff headers
        /^diff --git/ {
            split($0, parts, " b/")
            current_file = parts[2]
            next
        }
        # Only process added lines
        /^\+/ && !/^\+\+\+/ {
            line = substr($0, 2)

            # Strip string literals (naive: remove "..." segments)
            gsub(/"([^"\\]|\\.)*"/, "", line)

            # Strip block comments /* ... */ within a single line
            gsub(/\/\*[^*]*\*\//, "", line)

            # Strip line comments //...
            sub(/\/\/.*$/, "", line)

            # Check for force unwrap patterns: try!, !. (not !== or !=), as!
            if (match(line, /try!/) || match(line, /as!/) || match(line, /[a-zA-Z0-9_\]\)]\!\./) ) {
                print current_file ": " substr($0, 2)
            }
        }
    ')

    [[ -z "$hits" ]] && return 0

    # Apply exclusion patterns
    local filtered="$hits"
    for exclude in "${FORCE_UNWRAP_EXCLUDES[@]}"; do
        filtered=$(echo "$filtered" | grep -v "$exclude" || true)
    done

    [[ -z "$filtered" ]] && return 0

    local count
    count=$(echo "$filtered" | wc -l | tr -d ' ')
    echo "Found $count force unwrap(s) in added lines:"
    echo "$filtered"
    return 1
}
