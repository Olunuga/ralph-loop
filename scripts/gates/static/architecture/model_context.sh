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
    local files
    files=$(get_layer_files "view")
    [[ -z "$files" ]] && { echo "Model context ownership: PASS (no view files found)"; return 0; }

    # Match @Environment(\.modelContext) ignoring comment lines
    local hits
    hits=$(grep_layer_files "$files" -Hn '@Environment(\\\.modelContext)' \
        | grep -v "//" || true)

    if [[ -n "$hits" ]]; then
        echo "VIOLATION: View layer directly uses @Environment(\\.modelContext)"
        echo "  Route SwiftData access through a ViewModel instead."
        echo "$hits"
        return 1
    fi

    echo "Model context ownership: PASS"
    return 0
}
