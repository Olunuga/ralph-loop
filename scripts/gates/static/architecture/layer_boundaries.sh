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
    if [[ -z "$pattern" ]]; then
        local fallback
        case "$role" in
            view)       fallback="Views" ;;
            viewmodel)  fallback="ViewModels" ;;
            service)    fallback="Services" ;;
            repository) fallback="Repositories" ;;
            *)          return 0 ;;
        esac
        pattern="${SOURCE_DIR:-.}/$fallback"
    fi

    # compgen expands a glob and keeps a path with a space intact. An unquoted `find
    # $pattern` splits "Another Todo/Views" into two arguments, finds nothing, and the
    # gate passes without checking.
    local -a dirs=()
    local d
    while IFS= read -r d; do
        [[ -n "$d" ]] && dirs[${#dirs[@]}]="$d"
    done < <(compgen -G "$pattern" 2>/dev/null || true)

    [[ ${#dirs[@]} -eq 0 ]] && return 0
    find "${dirs[@]}" -name "*.swift" 2>/dev/null || true
}

# Grep each file by name. `xargs` splits on whitespace, so a path with a space became two
# nonexistent files and matched nothing. BSD xargs has no -d, so read the list instead.
grep_layer_files() {
    local files="$1"; shift
    local f
    printf '%s\n' "$files" | while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        grep "$@" "$f" 2>/dev/null || true
    done
}

gate_check() {
    local FAIL=0

    for role in service repository; do
        local files
        files=$(get_layer_files "$role")
        [[ -z "$files" ]] && continue

        # Rule 1: Must not import SwiftUI
        local hits
        hits=$(grep_layer_files "$files" -ln "^import SwiftUI")
        if [[ -n "$hits" ]]; then
            echo "VIOLATION: ${role} layer imports SwiftUI"
            echo "$hits"
            FAIL=1
        fi

        # Rule 2: Must not reference UI types
        hits=$(grep_layer_files "$files" -ln 'UIView\b\|UIViewController\b\|struct.*View\b\|some View\b')
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
        hits=$(grep_layer_files "$vm_files" -ln 'struct.*View\b\|some View\b')
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
