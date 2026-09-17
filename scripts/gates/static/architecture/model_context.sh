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
    # Indirect expansion, not an associative array: macOS ships bash 3.2, which has none.
    local var="LAYER_$(echo "$role" | tr '[:lower:]' '[:upper:]')"
    local pattern="${!var:-}"
    if [[ -n "$pattern" ]]; then
        find $pattern -name "*.swift" 2>/dev/null || true
    else
        local fallback
        case "$role" in
            view)       fallback="Views" ;;
            viewmodel)  fallback="ViewModels" ;;
            service)    fallback="Services" ;;
            repository) fallback="Repositories" ;;
            *)          return 0 ;;
        esac
        local dir="${SOURCE_DIR:-.}/$fallback"
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
