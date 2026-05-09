#!/bin/bash
set -euo pipefail

gate_name() { echo "ATS exceptions (NSAllowsArbitraryLoads)"; }
gate_category() { echo "security"; }
gate_tier() { echo "fast"; }

gate_check() {
    local src="${SOURCE_DIR:-.}"

    # Project-wide check: scan all .plist files for NSAllowsArbitraryLoads = true
    # This is a config concern — we check the full file, not just diff lines.
    local flagged_files=""

    while IFS= read -r plist; do
        # Check if the plist contains NSAllowsArbitraryLoads followed by <true/>
        if grep -q 'NSAllowsArbitraryLoads' "$plist" 2>/dev/null; then
            # In plist XML, the key is followed by a <true/> or <false/> on the next line
            if grep -A1 'NSAllowsArbitraryLoads' "$plist" | grep -q '<true/>' 2>/dev/null; then
                flagged_files="$flagged_files"$'\n'"  $plist"
            fi
        fi
    done < <(find "$src" -name '*.plist' -not -path '*/Pods/*' -not -path '*/.build/*' 2>/dev/null)

    if [[ -n "$flagged_files" ]]; then
        echo "NSAllowsArbitraryLoads is set to true in:"
        echo "$flagged_files"
        echo ""
        echo "App Transport Security should not be disabled globally. Add per-domain exceptions with justification instead."
        return 1
    fi

    return 0
}
