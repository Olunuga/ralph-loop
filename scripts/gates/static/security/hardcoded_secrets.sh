#!/bin/bash
set -euo pipefail

gate_name() { echo "Hardcoded secrets in Swift source"; }
gate_category() { echo "security"; }
gate_tier() { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"
    local found=0

    # Get added lines in non-test .swift files
    local diff_output
    diff_output=$(git diff "$BASE_REF"...HEAD --diff-filter=ACMR -U0 -- "$src" \
        | awk '
        /^diff --git/ {
            file = $NF; sub(/^b\//, "", file)
            # skip test files
            if (file ~ /Tests?\/|_tests?\.|[Tt]est[Ss]/) file = ""
            # skip non-swift
            if (file !~ /\.swift$/) file = ""
        }
        /^\+[^+]/ && file != "" { print file ":" $0 }
    ')

    [[ -z "$diff_output" ]] && return 0

    # Pattern 1: common secret assignment patterns with literal string values
    local secret_patterns='("sk-|"pk-|apiKey\s*=\s*"|[Ss]ecret\s*=\s*"|[Pp]assword\s*=\s*"|[Tt]oken\s*=\s*")'
    local matches
    matches=$(echo "$diff_output" | grep -iE "$secret_patterns" || true)

    # Pattern 2: base64-ish strings longer than 40 chars (likely keys)
    local b64_matches
    b64_matches=$(echo "$diff_output" | grep -oE '"[A-Za-z0-9+/=]{40,}"' || true)

    local all_matches
    all_matches=$(printf '%s\n%s' "$matches" "$b64_matches" | sed '/^$/d' | sort -u)

    if [[ -n "$all_matches" ]]; then
        echo "Potential hardcoded secrets found in added lines:"
        echo "$all_matches"
        echo ""
        echo "Move secrets to a secure store (Keychain, environment variable, or config file excluded from source control)."
        return 1
    fi

    return 0
}
