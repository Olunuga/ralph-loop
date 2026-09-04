#!/bin/bash
set -euo pipefail

gate_name()      { echo "Missing tests for new behaviour"; }
gate_category()  { echo "code_quality"; }
gate_tier()      { echo "fast"; }

gate_check() {
    local test_dir="${TEST_DIR:-}"
    local test_pattern="${TEST_FILE_PATTERN:-}"
    local func_pattern="${FUNCTION_DECL_PATTERN:-}"

    # Unset config means pass. Failing closed would block every project that
    # updates the plugin before re-running init.
    if [[ -z "$test_dir" ]]; then
        echo "TEST_DIR is not set in ralph/config.sh. Skipping."
        return 0
    fi
    if [[ -z "$test_pattern" ]]; then
        echo "TEST_FILE_PATTERN is not set in ralph/config.sh. Skipping."
        return 0
    fi
    [[ -z "$func_pattern" ]] && \
        func_pattern='^[[:space:]]*((public|private|internal|open|static|final|override)[[:space:]]+)*(func|def|function)[[:space:]]'

    local base_ref
    base_ref=$(git merge-base "${DIFF_BASE_BRANCH:-main}" HEAD 2>/dev/null || echo "HEAD~1")

    local changed
    changed=$(git diff --name-only "$base_ref"..HEAD 2>/dev/null) || true
    [[ -z "$changed" ]] && return 0

    # Did any test file change? Match on the configured pattern, anywhere under TEST_DIR.
    local test_touched=0
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        case "$f" in
            "$test_dir"/*|"$test_dir")
                # shellcheck disable=SC2254
                case "$(basename "$f")" in $test_pattern) test_touched=1; break ;; esac
                ;;
        esac
    done <<< "$changed"
    [[ "$test_touched" -eq 1 ]] && return 0

    # No test changed. Look for an added function declaration outside TEST_DIR.
    local src="${SOURCE_DIR:-.}"
    local hits=""
    local current_file=""
    while IFS= read -r line; do
        case "$line" in
            "diff --git "*)
                current_file="${line##* b/}"
                ;;
            "+"*)
                [[ "$line" == "+++"* ]] && continue
                [[ -z "$current_file" ]] && continue
                case "$current_file" in "$test_dir"/*) continue ;; esac
                local added="${line:1}"
                if echo "$added" | grep -qE "$func_pattern"; then
                    case "$hits" in
                        *"$current_file"*) ;;
                        *) hits="${hits}${current_file}"$'\n' ;;
                    esac
                fi
                ;;
        esac
    done < <(git diff "$base_ref"..HEAD -- "$src/" 2>/dev/null || true)

    [[ -z "$hits" ]] && return 0

    local count
    count=$(echo "$hits" | grep -c . || echo 0)
    echo "Added functions in $count file(s), but no test file under $test_dir changed:"
    echo "$hits" | grep . | sed 's/^/  /'
    echo "Add a test with the behaviour, or record an exception:"
    echo "  - missing_tests: SKIP — <reason>"
    return 1
}
