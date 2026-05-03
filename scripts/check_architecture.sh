#!/bin/bash
# Deterministic architecture check for a single-target SwiftUI app.
# Called per-iteration by ralph/loop.sh before commit.
# Exit 0 = pass. Exit 1 = violation (details on stdout).

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../config.sh"

FAIL=0

# ── Rule 1: Views must not hold @Environment(\.modelContext) ──────────────────
# SwiftData's modelContext should be owned by ViewModels, not Views.
if grep -rn "@Environment(\.modelContext)" \
    "$SOURCE_DIR/Views/" "$SOURCE_DIR/Views/Components/" \
    2>/dev/null | grep -v "//"; then
    echo "VIOLATION: $SOURCE_DIR/Views/ directly uses @Environment(\\.modelContext)"
    echo "  → Route SwiftData access through a ViewModel instead."
    FAIL=1
fi

# ── Rule 2: Services and Repositories must not import SwiftUI ─────────────────
for layer in "$SOURCE_DIR/Services" "$SOURCE_DIR/Repositories"; do
    [ -d "$layer" ] || continue
    HITS=$(grep -rn "^import SwiftUI" "$layer/" 2>/dev/null || true)
    if [ -n "$HITS" ]; then
        echo "VIOLATION: $layer/ imports SwiftUI"
        echo "$HITS"
        FAIL=1
    fi
done

# ── Rule 3: Services and Repositories must not reference View types ───────────
for layer in "$SOURCE_DIR/Services" "$SOURCE_DIR/Repositories"; do
    [ -d "$layer" ] || continue
    HITS=$(grep -rn "UIView\b\|UIViewController\b\|struct.*View\b\|some View\b" \
        "$layer/" 2>/dev/null || true)
    if [ -n "$HITS" ]; then
        echo "VIOLATION: $layer/ references UI types"
        echo "$HITS"
        FAIL=1
    fi
done

# ── Rule 4: ViewModels must not reference concrete View types ─────────────────
HITS=$(grep -rn "struct.*View\b\|some View\b" \
    "$SOURCE_DIR/ViewModels/" 2>/dev/null || true)
if [ -n "$HITS" ]; then
    echo "VIOLATION: $SOURCE_DIR/ViewModels/ references SwiftUI View types"
    echo "$HITS"
    FAIL=1
fi

# ── Result ─────────────────────────────────────────────────────────────────────
[ "$FAIL" -eq 1 ] && exit 1
echo "Architecture check: PASS"
