#!/bin/bash
set -euo pipefail

gate_name() { echo "Sensitive data in NSLog/os_log"; }
gate_category() { echo "security"; }
gate_tier() { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    # Get added lines from .swift files
    local diff_output
    diff_output=$(git diff "$BASE_REF"...HEAD --diff-filter=ACMR -U0 -- "$src" \
        | awk '
        /^diff --git/ {
            file = $NF; sub(/^b\//, "", file)
            if (file !~ /\.swift$/) file = ""
        }
        /^\+[^+]/ && file != "" { print file ":" $0 }
    ')

    [[ -z "$diff_output" ]] && return 0

    # Find NSLog/os_log lines that reference sensitive variable names
    local matches
    matches=$(echo "$diff_output" \
        | grep -iE '(NSLog|os_log)\s*\(' \
        | grep -iE '(password|token|secret|credential|ssn|apiKey)' \
        || true)

    if [[ -n "$matches" ]]; then
        echo "Log statements referencing sensitive data found in added lines:"
        echo "$matches"
        echo ""
        echo "Never log passwords, tokens, secrets, credentials, SSNs, or API keys. Remove or redact sensitive values from log output."
        return 1
    fi

    return 0
}
