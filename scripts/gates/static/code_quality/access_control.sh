#!/bin/bash
set -euo pipefail

gate_name()  { echo "Missing access control modifier"; }
gate_category()  { echo "code_quality"; }
gate_tier()  { echo "fast"; }

gate_check() {
    local base_ref
    base_ref=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    # Match added lines that declare a type without an explicit access modifier.
    # Only match lines where the type keyword appears at the start (after optional
    # whitespace), meaning top-level or type-level declarations — not local types
    # nested inside function bodies (which would be indented deeper, but we keep
    # the heuristic simple: no preceding access modifier on the same line).
    local hits
    hits=$(git diff "$base_ref"..HEAD -- "$src/" 2>/dev/null \
        | grep -E '^\+' \
        | grep -v '^\+\+\+' \
        | grep -E '^\+[[:space:]]*(class |struct |enum |protocol )' \
        | grep -Ev '^\+[[:space:]]*(public |internal |private |fileprivate |open |package |\/\/|\/\*|@|final public |final internal |final private |final fileprivate |final open |final package )' \
        | grep -Ev '^\+[[:space:]]*(public|internal|private|fileprivate|open|package)[[:space:]]' \
        || true)

    [[ -z "$hits" ]] && return 0

    local count
    count=$(echo "$hits" | wc -l | tr -d ' ')
    echo "Found $count type declaration(s) missing an explicit access control modifier:"
    echo "$hits" | sed 's/^\+//'
    return 1
}
