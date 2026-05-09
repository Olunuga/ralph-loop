#!/bin/bash
set -euo pipefail

gate_name()  { echo "Unused import detection"; }
gate_category()  { echo "code_quality"; }
gate_tier()  { echo "precise"; }

gate_check() {
    local base_ref
    base_ref=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    # Get list of changed .swift files
    local changed_files
    changed_files=$(git diff --name-only "$base_ref"..HEAD -- "$src/" 2>/dev/null \
        | grep '\.swift$' || true)

    [[ -z "$changed_files" ]] && return 0

    local hits=""
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        # Extract import statements
        local imports
        imports=$(grep -E '^import\s+' "$file" | sed 's/^import[[:space:]]*//' | sed 's/@[a-zA-Z_]*[[:space:]]*//' || true)

        [[ -z "$imports" ]] && continue

        while IFS= read -r module; do
            # Skip empty
            [[ -z "$module" ]] && continue

            # Handle `import struct Module.Type` style — extract the module name
            local module_name
            module_name=$(echo "$module" | awk '{
                # If starts with class/struct/enum/func/var/let/typealias, take the module part
                if ($1 ~ /^(class|struct|enum|func|var|let|typealias|protocol)$/) {
                    split($2, parts, ".")
                    print parts[1]
                } else {
                    # Plain import — take first word (handles `import Module`)
                    split($1, parts, ".")
                    print parts[1]
                }
            }')

            [[ -z "$module_name" ]] && continue

            # Always-needed imports that may not appear as identifiers
            case "$module_name" in
                Foundation|UIKit|SwiftUI|Combine|os) continue ;;
            esac

            # Check if the module name appears anywhere in the file besides import lines
            local usage_count
            usage_count=$(grep -v '^import ' "$file" \
                | grep -c "$module_name" 2>/dev/null || echo "0")

            if [[ "$usage_count" -eq 0 ]]; then
                hits="${hits}${file}: import ${module_name}"$'\n'
            fi
        done <<< "$imports"
    done <<< "$changed_files"

    hits=$(echo -n "$hits" | sed '/^$/d')
    [[ -z "$hits" ]] && return 0

    local count
    count=$(echo "$hits" | wc -l | tr -d ' ')
    echo "Found $count potentially unused import(s):"
    echo "$hits"
    return 1
}
