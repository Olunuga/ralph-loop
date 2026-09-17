#!/bin/bash
# Architecture gate: Services and Repositories must not use SwiftUI or UI types.
set -euo pipefail

gate_name()  { echo "Layer boundaries — no SwiftUI in service/repository layers"; }
gate_category()  { echo "architecture"; }
gate_tier()  { echo "fast"; }

# ---------------------------------------------------------------------------
# Helper: expand the configured layer path (or fall back to legacy hardcoded paths)
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
    local FAIL=0

    for role in service repository; do
        local files
        files=$(get_layer_files "$role")
        [[ -z "$files" ]] && continue

        # Rule 1: Must not import SwiftUI
        local hits
        hits=$(echo "$files" | xargs grep -ln "^import SwiftUI" 2>/dev/null || true)
        if [[ -n "$hits" ]]; then
            echo "VIOLATION: ${role} layer imports SwiftUI"
            echo "$hits"
            FAIL=1
        fi

        # Rule 2: Must not reference UI types
        hits=$(echo "$files" | xargs grep -ln 'UIView\b\|UIViewController\b\|struct.*View\b\|some View\b' 2>/dev/null || true)
        if [[ -n "$hits" ]]; then
            echo "VIOLATION: ${role} layer references UI types"
            echo "$hits"
            FAIL=1
        fi
    done

    # Rule 3: ViewModels must not reference concrete View types
    local vm_files
    vm_files=$(get_layer_files "viewmodel")
    if [[ -n "$vm_files" ]]; then
        hits=$(echo "$vm_files" | xargs grep -ln 'struct.*View\b\|some View\b' 2>/dev/null || true)
        if [[ -n "$hits" ]]; then
            echo "VIOLATION: viewmodel layer references SwiftUI View types"
            echo "$hits"
            FAIL=1
        fi
    fi

    [[ "$FAIL" -eq 1 ]] && return 1
    echo "Layer boundaries: PASS"
    return 0
}
