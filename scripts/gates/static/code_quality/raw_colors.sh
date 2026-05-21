#!/bin/bash
set -euo pipefail

gate_name() { echo "Raw color values instead of theme colors"; }
gate_category() { echo "code_quality"; }
gate_tier() { echo "fast"; }

gate_check() {
    local base_ref
    base_ref=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    local src="${SOURCE_DIR:-.}"

    if [[ -z "${RAW_COLOR_EXCLUDES+x}" ]]; then
        RAW_COLOR_EXCLUDES=('#Preview' 'test' 'Test' 'Mock' 'Stub')
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

            # Skip asset catalog color definitions and color set files
            if (line ~ /colorSetName|ColorResource|\.colorSet/) next

            # Detect inline Color init with RGB components
            # Color(red:, Color(.sRGB, Color(hue:, Color(white:
            if (match(line, /Color\(\s*(red:|\.sRGB|\.displayP3|hue:|white:)/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect hex color patterns: Color(hex:, #colorLiteral, 0x[A-Fa-f0-9]{6}
            if (match(line, /(Color\(hex:|#colorLiteral|UIColor\(hex:)/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect UIColor with RGB components
            if (match(line, /UIColor\(\s*(red:|hue:|white:|displayP3Red:)/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect Color.init with raw float/int channels
            if (match(line, /Color\([0-9]*\.[0-9]+,\s*[0-9]*\.[0-9]+,\s*[0-9]*\.[0-9]+/)) {
                print current_file ": " substr($0, 2)
                next
            }

            # Detect local color context creation: UIColor { traitCollection in
            # or creating local Color extensions with raw values
            if (match(line, /UIColor\s*\{\s*trait/)) {
                print current_file ": " substr($0, 2)
                next
            }
        }
    ')

    [[ -z "$hits" ]] && return 0

    local filtered="$hits"
    for exclude in "${RAW_COLOR_EXCLUDES[@]}"; do
        filtered=$(echo "$filtered" | grep -v "$exclude" || true)
    done

    [[ -z "$filtered" ]] && return 0

    local count
    count=$(echo "$filtered" | wc -l | tr -d ' ')
    echo "Found $count raw color value(s) in added lines:"
    echo "$filtered"
    echo ""
    echo "Use asset catalog colors (Color(\"ThemePrimary\")) or theme tokens instead of inline RGB/hex values. This ensures dark mode support and consistent theming."
    return 1
}
