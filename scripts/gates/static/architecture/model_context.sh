#!/bin/bash
# Architecture gate: Views must not directly hold @Environment(\.modelContext).
# SwiftData's modelContext should be owned by ViewModels, not Views.
set -euo pipefail

gate_name()  { echo "Model context ownership — Views must not hold @Environment(\\.modelContext)"; }
gate_category()  { echo "architecture"; }
gate_tier()  { echo "fast"; }

# ---------------------------------------------------------------------------
get_layer_files() {
    local role="$1"
    if [[ -n "${LAYER_MAP[$role]:-}" ]]; then
        local pattern="${LAYER_MAP[$role]}"
        find $pattern -name "*.swift" 2>/dev/null || true
    else
        local -A fallback_dirs=(
            [view]="Views"
            [viewmodel]="ViewModels"
            [service]="Services"
            [repository]="Repositories"
        )
        local dir="$SOURCE_DIR/${fallback_dirs[$role]}"
        [[ -d "$dir" ]] && find "$dir" -name "*.swift" 2>/dev/null || true
    fi
}

gate_check() {
    local files
    files=$(get_layer_files "view")
    [[ -z "$files" ]] && { echo "Model context ownership: PASS (no view files found)"; return 0; }

    # Match @Environment(\.modelContext) ignoring comment lines
    local hits
    hits=$(echo "$files" | xargs grep -n '@Environment(\\\.modelContext)' 2>/dev/null \
        | grep -v "^\s*//" || true)

    if [[ -n "$hits" ]]; then
        echo "VIOLATION: View layer directly uses @Environment(\\.modelContext)"
        echo "  Route SwiftData access through a ViewModel instead."
        echo "$hits"
        return 1
    fi

    echo "Model context ownership: PASS"
    return 0
}
