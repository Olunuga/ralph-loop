#!/bin/bash
# Blast radius analysis — measures the transitive impact surface of a proposed change.
#
# Usage:
#   blast_radius.sh <TypeName> [source_dir]
#
# Outputs:
#   BLAST_SCORE=N           (composite 0-10)
#   BLAST_VERDICT=auto|defer
#   FILE_FANOUT=N
#   TYPE_COUPLING=N
#   LAYERS_CROSSED=N
#   INFRA_REACH=N
#   TEST_COUPLING=N
#   AFFECTED_FILES=file1,file2,...
#   AFFECTED_LAYERS=Models,Views,...
#
# Scoring (5 dimensions, 0-2 each):
#   0-3  → auto (escalate to Opus for careful fix)
#   4-6  → auto only if change stays within one layer, else defer
#   7-10 → defer (create GitHub issue as tech debt)
#
# Thresholds are configurable via ralph/gate_context.md:
#   blast_radius_fanout_thresholds: 5,15
#   blast_radius_coupling_thresholds: 3,10
#   blast_radius_layer_thresholds: 1,2
#   blast_radius_infra_thresholds: 2,4
#   blast_radius_test_thresholds: 1,3
#   blast_radius_auto_max: 3
#   blast_radius_conditional_max: 6
#
# Based on Robert C. Martin's coupling metrics (Ca/Ce), Google's LSC sharding
# practice, and Feathers' seam analysis from Working Effectively with Legacy Code.

set -euo pipefail

TYPE_NAME="${1:?Usage: blast_radius.sh <TypeName> [source_dir]}"
SRC="${2:-.}"

# ── Load configurable thresholds ─────────────────────────────────────────────
# Defaults — override per-project via ralph/gate_context.md
FANOUT_LOW=5;    FANOUT_HIGH=15
COUPLING_LOW=3;  COUPLING_HIGH=10
LAYER_LOW=1;     LAYER_HIGH=2
INFRA_LOW=2;     INFRA_HIGH=4
TEST_LOW=1;      TEST_HIGH=3
AUTO_MAX=3;      CONDITIONAL_MAX=6

# Read overrides from gate_context.md if available
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
GATE_CTX="$PROJECT_ROOT/ralph/gate_context.md"
if [[ -f "$GATE_CTX" ]]; then
    _read_threshold() {
        local key="$1" val
        val=$(grep "^${key}:" "$GATE_CTX" 2>/dev/null | sed "s/^${key}: *//" | tr -d ' ')
        [[ -n "$val" ]] && echo "$val"
    }
    _t=$(_read_threshold "blast_radius_fanout_thresholds") && { FANOUT_LOW="${_t%%,*}"; FANOUT_HIGH="${_t##*,}"; }
    _t=$(_read_threshold "blast_radius_coupling_thresholds") && { COUPLING_LOW="${_t%%,*}"; COUPLING_HIGH="${_t##*,}"; }
    _t=$(_read_threshold "blast_radius_layer_thresholds") && { LAYER_LOW="${_t%%,*}"; LAYER_HIGH="${_t##*,}"; }
    _t=$(_read_threshold "blast_radius_infra_thresholds") && { INFRA_LOW="${_t%%,*}"; INFRA_HIGH="${_t##*,}"; }
    _t=$(_read_threshold "blast_radius_test_thresholds") && { TEST_LOW="${_t%%,*}"; TEST_HIGH="${_t##*,}"; }
    _t=$(_read_threshold "blast_radius_auto_max") && AUTO_MAX="$_t"
    _t=$(_read_threshold "blast_radius_conditional_max") && CONDITIONAL_MAX="$_t"
fi

# ── 1. File Fan-Out (direct dependents) ──────────────────────────────────────
# How many files reference this type?
REFERENCING_FILES=$(grep -rl "$TYPE_NAME" --include="*.swift" "$SRC" 2>/dev/null || true)
FILE_COUNT=0
if [[ -n "$REFERENCING_FILES" ]]; then
    FILE_COUNT=$(echo "$REFERENCING_FILES" | wc -l | tr -d ' ')
fi

if [[ "$FILE_COUNT" -le "$FANOUT_LOW" ]]; then
    FANOUT_SCORE=0
elif [[ "$FILE_COUNT" -le "$FANOUT_HIGH" ]]; then
    FANOUT_SCORE=1
else
    FANOUT_SCORE=2
fi

# ── 2. Type Coupling (afferent coupling Ca) ──────────────────────────────────
# How many distinct types reference this type (protocols, classes, structs)?
COUPLING_COUNT=0
if [[ -n "$REFERENCING_FILES" ]]; then
    # Count unique type declarations in files that reference our type
    COUPLING_COUNT=$(echo "$REFERENCING_FILES" \
        | xargs grep -ohE "(class|struct|enum|protocol|actor)\s+[A-Z][A-Za-z0-9]+" 2>/dev/null \
        | awk '{print $2}' \
        | sort -u \
        | grep -v "^${TYPE_NAME}$" \
        | wc -l | tr -d ' ')
fi

if [[ "$COUPLING_COUNT" -le "$COUPLING_LOW" ]]; then
    COUPLING_SCORE=0
elif [[ "$COUPLING_COUNT" -le "$COUPLING_HIGH" ]]; then
    COUPLING_SCORE=1
else
    COUPLING_SCORE=2
fi

# ── 3. Layers Crossed ────────────────────────────────────────────────────────
# How many distinct architectural layers (top-level subdirectories of SRC)
# contain files that reference this type?
LAYERS=""
LAYER_COUNT=0
if [[ -n "$REFERENCING_FILES" ]]; then
    # Extract the first subdirectory under SRC for each referencing file
    LAYERS=$(echo "$REFERENCING_FILES" \
        | sed "s|^${SRC}/||" \
        | awk -F/ 'NF >= 2 {print $1}' \
        | sort -u)
    if [[ -n "$LAYERS" ]]; then
        LAYER_COUNT=$(echo "$LAYERS" | wc -l | tr -d ' ')
    fi
fi

if [[ "$LAYER_COUNT" -le "$LAYER_LOW" ]]; then
    LAYER_SCORE=0
elif [[ "$LAYER_COUNT" -le "$LAYER_HIGH" ]]; then
    LAYER_SCORE=1
else
    LAYER_SCORE=2
fi

# ── 4. Infrastructure Reach ──────────────────────────────────────────────────
# Is this type used across many feature directories (shared infra) or just one (leaf)?
# Count distinct parent directories (2 levels deep) of referencing files.
DIR_COUNT=0
if [[ -n "$REFERENCING_FILES" ]]; then
    DIR_COUNT=$(echo "$REFERENCING_FILES" \
        | xargs -I{} dirname {} \
        | sort -u \
        | wc -l | tr -d ' ')
fi

if [[ "$DIR_COUNT" -le "$INFRA_LOW" ]]; then
    INFRA_SCORE=0
elif [[ "$DIR_COUNT" -le "$INFRA_HIGH" ]]; then
    INFRA_SCORE=1
else
    INFRA_SCORE=2
fi

# ── 5. Test Coupling ─────────────────────────────────────────────────────────
# How many test files reference this type? If a fix changes the type's interface,
# every test that instantiates or asserts on it will also need updating.
TEST_COUNT=0
if [[ -n "$REFERENCING_FILES" ]]; then
    TEST_COUNT=$(echo "$REFERENCING_FILES" | grep -cE 'Tests?/' || true)
fi

if [[ "$TEST_COUNT" -le "$TEST_LOW" ]]; then
    TEST_SCORE=0
elif [[ "$TEST_COUNT" -le "$TEST_HIGH" ]]; then
    TEST_SCORE=1
else
    TEST_SCORE=2
fi

# ── Composite Score ───────────────────────────────────────────────────────────
BLAST_SCORE=$((FANOUT_SCORE + COUPLING_SCORE + LAYER_SCORE + INFRA_SCORE + TEST_SCORE))

# Verdict: auto-fix or defer
if [[ "$BLAST_SCORE" -le "$AUTO_MAX" ]]; then
    VERDICT="auto"
elif [[ "$BLAST_SCORE" -le "$CONDITIONAL_MAX" && "$LAYER_COUNT" -le 1 ]]; then
    VERDICT="auto"
else
    VERDICT="defer"
fi

# ── Output ────────────────────────────────────────────────────────────────────
AFFECTED_FILES_CSV=""
if [[ -n "$REFERENCING_FILES" ]]; then
    AFFECTED_FILES_CSV=$(echo "$REFERENCING_FILES" | tr '\n' ',' | sed 's/,$//')
fi
AFFECTED_LAYERS_CSV=""
if [[ -n "$LAYERS" ]]; then
    AFFECTED_LAYERS_CSV=$(echo "$LAYERS" | tr '\n' ',' | sed 's/,$//')
fi

cat <<EOF
BLAST_SCORE=$BLAST_SCORE
BLAST_VERDICT=$VERDICT
FILE_FANOUT=$FILE_COUNT (score: $FANOUT_SCORE)
TYPE_COUPLING=$COUPLING_COUNT (score: $COUPLING_SCORE)
LAYERS_CROSSED=$LAYER_COUNT (score: $LAYER_SCORE)
INFRA_REACH=$DIR_COUNT (score: $INFRA_SCORE)
TEST_COUPLING=$TEST_COUNT (score: $TEST_SCORE)
AFFECTED_FILES=$AFFECTED_FILES_CSV
AFFECTED_LAYERS=$AFFECTED_LAYERS_CSV
EOF
