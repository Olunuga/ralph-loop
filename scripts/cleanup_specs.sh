#!/bin/bash
# Move completed specs to ralph/specs/done/ after a PR is merged.
# Run manually from the project root: bash ralph/scripts/cleanup_specs.sh [slug]
#
# Reads IMPLEMENTATION_PLAN.md to find which specs were used in the build,
# then archives them. AUDIENCE_JTBD.md is never archived — it spans releases.
#
# Optional: pass the slug (ref) to also delete the spec/<slug> branch locally
# and on the remote.

set -euo pipefail

SLUG="${1:-}"
PLAN="IMPLEMENTATION_PLAN.md"
SPECS_DIR="ralph/specs"
DONE_DIR="ralph/specs/done"

if [[ ! -f "$PLAN" ]]; then
    echo "ERROR: $PLAN not found. Run from the project root (not the worktree)." >&2
    exit 1
fi

# Extract spec filenames from the plan header line:
# "# Generated from: ralph/specs/foo.md, ralph/specs/bar.md"
HEADER=$(grep '^# Generated from:' "$PLAN" 2>/dev/null || true)
if [[ -z "$HEADER" ]]; then
    echo "ERROR: No '# Generated from:' line found in $PLAN." >&2
    exit 1
fi

# Parse comma-separated paths, strip leading/trailing whitespace
SPECS=$(echo "$HEADER" \
    | sed 's/^# Generated from://' \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | grep '\.md$' || true)

if [[ -z "$SPECS" ]]; then
    echo "No spec files found in plan header." >&2
    exit 1
fi

mkdir -p "$DONE_DIR"

MOVED=0
MISSING=0
while IFS= read -r SPEC; do
    [[ -z "$SPEC" ]] && continue
    if [[ -f "$SPEC" ]]; then
        DEST="$DONE_DIR/$(basename "$SPEC")"
        mv "$SPEC" "$DEST"
        echo "archived: $SPEC → $DEST"
        MOVED=$((MOVED + 1))
    else
        echo "skip (not found): $SPEC"
        MISSING=$((MISSING + 1))
    fi
done <<< "$SPECS"

# Archive SLC_RELEASE.md if present (release boundary marker)
if [[ -f "$SPECS_DIR/SLC_RELEASE.md" ]]; then
    mv "$SPECS_DIR/SLC_RELEASE.md" "$DONE_DIR/SLC_RELEASE.md"
    echo "archived: $SPECS_DIR/SLC_RELEASE.md → $DONE_DIR/SLC_RELEASE.md"
    MOVED=$((MOVED + 1))
fi

echo ""
echo "Done. $MOVED archived, $MISSING not found."
echo "Note: AUDIENCE_JTBD.md is kept — it spans releases."

# Delete spec branch if slug provided
if [[ -n "$SLUG" ]]; then
    SPEC_BRANCH="spec/$SLUG"
    echo ""
    if git rev-parse --verify "$SPEC_BRANCH" &>/dev/null 2>&1; then
        git branch -d "$SPEC_BRANCH" 2>/dev/null || git branch -D "$SPEC_BRANCH"
        echo "deleted local branch: $SPEC_BRANCH"
    else
        echo "local branch not found: $SPEC_BRANCH (skip)"
    fi
    if git ls-remote --exit-code origin "$SPEC_BRANCH" &>/dev/null 2>&1; then
        git push origin --delete "$SPEC_BRANCH"
        echo "deleted remote branch: $SPEC_BRANCH"
    fi
fi
