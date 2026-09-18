#!/bin/bash
# Architecture gate: Lower layers must not depend on higher layers.
#
# Dependency order (innermost to outermost):
#   repository -> service -> viewmodel -> view
#
# Pragmatic approach:
#   - repository and service layers must not `import SwiftUI` (view-layer indicator).
#   - viewmodel layer must not `import SwiftUI` (it should use Combine/Observation).
#   - Cross-module import checks (e.g. "import SomeServiceModule" in a repository)
#     are skipped because module names cannot be reliably inferred from directory
#     structure alone. Projects using explicit Swift module boundaries should add
#     a project-specific check or use a precise-tier build-graph analysis.
set -euo pipefail

gate_name()  { echo "Dependency direction — lower layers must not import higher layers"; }
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
    local FAIL=0

    # repository and service layers must not import SwiftUI (implies view dependency)
    for role in repository service; do
        local files
        files=$(get_layer_files "$role")
        [[ -z "$files" ]] && continue

        local hits
        hits=$(grep_layer_files "$files" -ln "^import SwiftUI")
        if [[ -n "$hits" ]]; then
            echo "VIOLATION: ${role} layer imports SwiftUI (depends on view layer)"
            echo "$hits"
            FAIL=1
        fi
    done

    # viewmodel layer must not import SwiftUI
    local vm_files
    vm_files=$(get_layer_files "viewmodel")
    if [[ -n "$vm_files" ]]; then
        local hits
        hits=$(grep_layer_files "$vm_files" -ln "^import SwiftUI")
        if [[ -n "$hits" ]]; then
            echo "VIOLATION: viewmodel layer imports SwiftUI (depends on view layer)"
            echo "$hits"
            FAIL=1
        fi
    fi

    # NOTE: Cross-module import checks (e.g. repository importing a service module)
    # are intentionally skipped. Module names vary per project and cannot be reliably
    # derived from directory names. A precise-tier check using build-graph analysis
    # would be needed for full enforcement.

    [[ "$FAIL" -eq 1 ]] && return 1
    echo "Dependency direction: PASS"
    return 0
}
