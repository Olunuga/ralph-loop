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
    local FAIL=0

    # repository and service layers must not import SwiftUI (implies view dependency)
    for role in repository service; do
        local files
        files=$(get_layer_files "$role")
        [[ -z "$files" ]] && continue

        local hits
        hits=$(echo "$files" | xargs grep -ln "^import SwiftUI" 2>/dev/null || true)
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
        hits=$(echo "$vm_files" | xargs grep -ln "^import SwiftUI" 2>/dev/null || true)
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
