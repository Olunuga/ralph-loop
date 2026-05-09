#!/bin/bash
set -euo pipefail

gate_name()  { echo "Large type body detection (>250 lines)"; }
gate_category()  { echo "code_quality"; }
gate_tier()  { echo "fast"; }

gate_check() {
    local base_ref
    base_ref=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"
    local max_lines=250

    # Get list of changed .swift files
    local changed_files
    changed_files=$(git diff --name-only "$base_ref"..HEAD -- "$src/" 2>/dev/null \
        | grep '\.swift$' || true)

    [[ -z "$changed_files" ]] && return 0

    local hits=""
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        # Use awk to find type bodies exceeding max_lines
        local result
        result=$(awk -v max="$max_lines" '
            /^[[:space:]]*(public |internal |private |fileprivate |open |package |final )*(class |struct |enum )[A-Za-z]/ {
                type_name = $0
                gsub(/^[[:space:]]+/, "", type_name)
                brace_count = 0
                start_line = NR
                found_open = 0

                # Check if opening brace is on this line
                if (index($0, "{") > 0) {
                    brace_count = 1
                    found_open = 1
                }
            }

            found_open && brace_count > 0 && NR > start_line {
                n = split($0, chars, "")
                for (i = 1; i <= n; i++) {
                    if (chars[i] == "{") brace_count++
                    if (chars[i] == "}") brace_count--
                }
                if (brace_count == 0) {
                    body_lines = NR - start_line
                    if (body_lines > max) {
                        print type_name " (" body_lines " lines)"
                    }
                    found_open = 0
                }
            }

            # Handle opening brace on next line
            !found_open && brace_count == 0 && /^[[:space:]]*\{/ && type_name != "" {
                brace_count = 1
                found_open = 1
                start_line = NR
            }
        ' "$file")

        if [[ -n "$result" ]]; then
            while IFS= read -r line; do
                hits="${hits}${file}: ${line}"$'\n'
            done <<< "$result"
        fi
    done <<< "$changed_files"

    hits=$(echo -n "$hits" | sed '/^$/d')
    [[ -z "$hits" ]] && return 0

    local count
    count=$(echo "$hits" | wc -l | tr -d ' ')
    echo "Found $count type(s) exceeding $max_lines lines — consider splitting:"
    echo "$hits"
    return 1
}
