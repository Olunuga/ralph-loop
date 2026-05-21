#!/bin/bash
set -euo pipefail

gate_name() { echo "Raw typography values instead of theme styles"; }
gate_category() { echo "code_quality"; }
gate_tier() { echo "fast"; }

gate_check() {
    local base_ref
    base_ref=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    if [[ -z "${RAW_TYPOGRAPHY_EXCLUDES+x}" ]]; then
        RAW_TYPOGRAPHY_EXCLUDES=('#Preview' 'test' 'Test' 'Mock' 'Stub')
    fi

    local diff_output
    diff_output=$(git diff "$base_ref"..HEAD -- "$src/" 2>/dev/null) || true
    [[ -z "$diff_output" ]] && return 0

    local hits
    hits=$(echo "$diff_output" | awk '
        /^diff --git/ {
            split($0, parts, " b/")
            current_file = parts[2]
            next
        }
        /^\+/ && !/^\+\+\+/ {
            line = substr($0, 2)

            if (current_file !~ /\.swift$/) next

            # Strip string literals
            gsub(/"([^"\\]|\\.)*"/, "", line)

            # Strip comments
            gsub(/\/\*[^*]*\*\//, "", line)
            sub(/\/\/.*$/, "", line)

            # Detect .fontWeight with raw values instead of semantic styles
            # e.g. .fontWeight(.semibold) on its own without a theme text style
            # This is a weaker signal — flag .font(.system(...)) combos instead

            # Detect Font.system(size:) with hardcoded size — should use theme text style
            # Already caught by hardcoded_fonts.sh for Dynamic Type, but this gate
            # focuses on theme consistency
            if (match(line, /Font\.system\(size:\s*[0-9]/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect Font.custom with hardcoded size
            if (match(line, /Font\.custom\([^)]+,\s*(fixedSize|size):\s*[0-9]/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect UIFont.systemFont(ofSize:) with hardcoded size
            if (match(line, /UIFont\.systemFont\(ofSize:\s*[0-9]/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect UIFont(name:, size:) with hardcoded size
            if (match(line, /UIFont\(name:[^)]+size:\s*[0-9]/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect inline .font(.system(size: weight:)) — compound literal style
            if (match(line, /\.font\(\s*\.system\(size:\s*[0-9]/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect loose .font(.init(... with numeric size
            if (match(line, /\.font\(\s*Font\(.*size:\s*[0-9]/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect NSAttributedString font attributes with hardcoded sizes
            if (match(line, /\.font:\s*UIFont\.(system|bold)/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect raw lineSpacing as a typography concern
            if (match(line, /\.lineSpacing\(\s*[0-9]{2,}/)) {
                print current_file ": " substr($0, 2)
                next
            }
        }
    ')

    [[ -z "$hits" ]] && return 0

    local filtered="$hits"
    for exclude in "${RAW_TYPOGRAPHY_EXCLUDES[@]}"; do
        filtered=$(echo "$filtered" | grep -v "$exclude" || true)
    done

    [[ -z "$filtered" ]] && return 0

    local count
    count=$(echo "$filtered" | wc -l | tr -d ' ')
    echo "Found $count raw typography value(s) in added lines:"
    echo "$filtered"
    echo ""
    echo "Use theme text styles (e.g. .font(.theme.heading), Text.Style.body) instead of hardcoded font sizes and weights. This ensures consistent typography and easier theme updates."
    return 1
}
