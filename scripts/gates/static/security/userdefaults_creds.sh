#!/bin/bash
set -euo pipefail

gate_name() { echo "Credentials stored in UserDefaults"; }
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

    # Find UserDefaults usage with sensitive key names
    local matches
    matches=$(echo "$diff_output" \
        | grep -i 'UserDefaults' \
        | grep -iE '(password|token|secret|credential|apiKey|accessToken|refreshToken)' \
        || true)

    if [[ -n "$matches" ]]; then
        echo "Sensitive data stored in UserDefaults found in added lines:"
        echo "$matches"
        echo ""
        echo "Use Keychain Services instead of UserDefaults for passwords, tokens, secrets, and credentials."
        return 1
    fi

    return 0
}
