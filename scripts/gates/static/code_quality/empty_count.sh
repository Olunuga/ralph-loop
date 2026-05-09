#!/bin/bash
set -euo pipefail

gate_name()  { echo "Prefer .isEmpty over .count comparison"; }
gate_category()  { echo "code_quality"; }
gate_tier()  { echo "fast"; }

gate_check() {
    local base_ref
    base_ref=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    local hits
    hits=$(git diff "$base_ref"..HEAD -- "$src/" 2>/dev/null \
        | grep -E '^\+' \
        | grep -v '^\+\+\+' \
        | grep -E '\.count\s*(==|!=|>)\s*0' \
        || true)

    [[ -z "$hits" ]] && return 0

    local count
    count=$(echo "$hits" | wc -l | tr -d ' ')
    echo "Found $count .count comparison(s) with 0 — use .isEmpty instead:"
    echo "$hits" | sed 's/^\+//'
    return 1
}
