#!/bin/bash
# Deterministic architecture check for a single-target SwiftUI app.
# Called per-iteration by ralph/loop.sh before commit.
# Only checks lines introduced on this branch (git diff vs main merge-base),
# so pre-existing violations in unchanged files never trigger a rollback.
# Exit 0 = pass. Exit 1 = violation (details on stdout).

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
FAIL=0

# ── Rule 1: Views must not hold @Environment(\.modelContext) ──────────────────
# SwiftData's modelContext should be owned by ViewModels, not Views.
HITS=$(git diff "$BASE_REF"..HEAD -- "$SOURCE_DIR/Views/" \
    | grep '^+' | grep -v '^+++' \
    | grep -v '^+[[:space:]]*//' \
    | grep '@Environment(\\\.modelContext)' || true)
if [[ -n "$HITS" ]]; then
    echo "VIOLATION: new code in $SOURCE_DIR/Views/ uses @Environment(\\.modelContext)"
    echo "  → Route SwiftData access through a ViewModel instead."
    echo "$HITS"
    FAIL=1
fi

# ── Rule 2: Services and Repositories must not import SwiftUI ─────────────────
for layer in "$SOURCE_DIR/Services" "$SOURCE_DIR/Repositories"; do
    [ -d "$layer" ] || continue
    HITS=$(git diff "$BASE_REF"..HEAD -- "$layer/" \
        | grep '^+' | grep -v '^+++' \
        | grep '^+import SwiftUI' || true)
    if [[ -n "$HITS" ]]; then
        echo "VIOLATION: new code in $layer/ imports SwiftUI"
        echo "$HITS"
        FAIL=1
    fi
done

# ── Rule 3: Services and Repositories must not reference View types ───────────
for layer in "$SOURCE_DIR/Services" "$SOURCE_DIR/Repositories"; do
    [ -d "$layer" ] || continue
    HITS=$(git diff "$BASE_REF"..HEAD -- "$layer/" \
        | grep '^+' | grep -v '^+++' \
        | grep -E 'UIView\b|UIViewController\b|struct[[:space:]].*View\b|some View\b' || true)
    if [[ -n "$HITS" ]]; then
        echo "VIOLATION: new code in $layer/ references UI types"
        echo "$HITS"
        FAIL=1
    fi
done

# ── Rule 4: ViewModels must not reference concrete View types ─────────────────
HITS=$(git diff "$BASE_REF"..HEAD -- "$SOURCE_DIR/ViewModels/" \
    | grep '^+' | grep -v '^+++' \
    | grep -E 'struct[[:space:]].*View\b|some View\b' || true)
if [[ -n "$HITS" ]]; then
    echo "VIOLATION: new code in $SOURCE_DIR/ViewModels/ references SwiftUI View types"
    echo "$HITS"
    FAIL=1
fi

# ── Result ─────────────────────────────────────────────────────────────────────
[ "$FAIL" -eq 1 ] && exit 1
echo "Architecture check: PASS"
