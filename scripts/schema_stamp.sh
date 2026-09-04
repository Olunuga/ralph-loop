#!/bin/bash
# Version stamp for the installed ralph-bridge schema bundle.
#
# Usage:
#   schema_stamp.sh write   [project_root]   # stamp the installed bundle
#   schema_stamp.sh check   [project_root]   # warn on plugin drift or CLI change
#   schema_stamp.sh require-min              # exit 1 if the CLI is below the bundle minimum
#
# check exits 0 even when it warns: drift is not a hard failure.
# require-min exits 1 when the CLI is too old; init uses this to refuse the wiring.

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RALPH_PLUGIN_DIR="${RALPH_PLUGIN_DIR:-$SCRIPT_DIR/..}"
BUNDLE_SRC="$RALPH_PLUGIN_DIR/schemas/ralph-bridge"

ACTION="${1:?Usage: schema_stamp.sh <write|check|require-min> [project_root]}"
PROJECT_ROOT="${2:-${PROJECT_ROOT:-$(pwd)}}"
STAMP="$PROJECT_ROOT/openspec/schemas/ralph-bridge/.stamp.json"

json_field() { grep -o "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$1" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/'; }

plugin_version() { json_field "$RALPH_PLUGIN_DIR/.claude-plugin/plugin.json" version; }
cli_version()    { openspec --version 2>/dev/null | tr -d '[:space:]'; }
min_version()    { json_field "$BUNDLE_SRC/bundle.json" minOpenspecVersion; }

# lowest version first; equal returns the same string twice
version_lt() { [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]; }

case "$ACTION" in
    write)
        PV=$(plugin_version); CV=$(cli_version)
        mkdir -p "$(dirname "$STAMP")"
        printf '{\n  "pluginVersion": "%s",\n  "openspecVersion": "%s",\n  "installedAt": "%s"\n}\n' \
            "$PV" "$CV" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STAMP"
        echo "Stamped ralph-bridge: plugin $PV, openspec $CV"
        ;;

    check)
        [[ -f "$STAMP" ]] || { echo "NOTE: ralph-bridge is not stamped. Run: /ralph-loop:init --openspec"; exit 0; }
        SP=$(json_field "$STAMP" pluginVersion); SC=$(json_field "$STAMP" openspecVersion)
        PV=$(plugin_version); CV=$(cli_version)

        if [[ -n "$SP" && -n "$PV" ]] && version_lt "$SP" "$PV"; then
            echo "WARN: installed ralph-bridge is from plugin $SP, but the plugin is $PV."
            echo "      Re-run /ralph-loop:init --openspec to refresh the schema."
        fi

        if [[ -n "$SC" && -n "$CV" && "$SC" != "$CV" ]]; then
            echo "NOTE: openspec changed since the schema was validated ($SC -> $CV). Re-validating."
            if ! openspec schema validate ralph-bridge >/dev/null 2>&1; then
                echo "WARN: ralph-bridge no longer validates against openspec $CV."
                echo "      Re-run /ralph-loop:init --openspec, or pin openspec to $SC."
            else
                echo "OK: ralph-bridge still validates against openspec $CV."
            fi
        fi
        exit 0
        ;;

    require-min)
        MIN=$(min_version); CV=$(cli_version)
        [[ -z "$CV" ]] && { echo "ERROR: openspec is not on PATH. Install with: npm i -g openspec"; exit 1; }
        [[ -z "$MIN" ]] && exit 0
        if version_lt "$CV" "$MIN"; then
            echo "ERROR: ralph-bridge needs openspec >= $MIN. Installed: $CV."
            echo "       Upgrade with: npm i -g openspec@latest"
            exit 1
        fi
        ;;

    *) echo "Unknown action: $ACTION"; exit 1 ;;
esac
