#!/bin/bash
# Blast radius analysis — measures the transitive impact surface of a proposed change.
#
# Usage:
#   blast_radius.sh <TypeName> [source_dir]
#
# Outputs:
#   BLAST_SCORE=N           (composite 0-8)
#   BLAST_VERDICT=auto|defer
#   FILE_FANOUT=N
#   TYPE_COUPLING=N
#   LAYERS_CROSSED=N
#   INFRA_REACH=N
#   AFFECTED_FILES=file1,file2,...
#   AFFECTED_LAYERS=Models,Views,...
#
# Scoring:
#   0-2  → auto (escalate to Opus for careful fix)
#   3-5  → auto only if change stays within one layer, else defer
#   6-8  → defer (create GitHub issue as tech debt)
#
# Based on Robert C. Martin's coupling metrics (Ca/Ce), Google's LSC sharding
# practice, and Feathers' seam analysis from Working Effectively with Legacy Code.

set -euo pipefail

TYPE_NAME="${1:?Usage: blast_radius.sh <TypeName> [source_dir]}"
SRC="${2:-.}"

# ── 1. File Fan-Out (direct dependents) ──────────────────────────────────────
# How many files reference this type?
REFERENCING_FILES=$(grep -rl "$TYPE_NAME" --include="*.swift" "$SRC" 2>/dev/null || true)
FILE_COUNT=0
if [[ -n "$REFERENCING_FILES" ]]; then
    FILE_COUNT=$(echo "$REFERENCING_FILES" | wc -l | tr -d ' ')
fi

if [[ "$FILE_COUNT" -le 5 ]]; then
    FANOUT_SCORE=0
elif [[ "$FILE_COUNT" -le 15 ]]; then
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

if [[ "$COUPLING_COUNT" -le 3 ]]; then
    COUPLING_SCORE=0
elif [[ "$COUPLING_COUNT" -le 10 ]]; then
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

if [[ "$LAYER_COUNT" -le 1 ]]; then
    LAYER_SCORE=0
elif [[ "$LAYER_COUNT" -le 2 ]]; then
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

if [[ "$DIR_COUNT" -le 2 ]]; then
    INFRA_SCORE=0
elif [[ "$DIR_COUNT" -le 4 ]]; then
    INFRA_SCORE=1
else
    INFRA_SCORE=2
fi

# ── Composite Score ───────────────────────────────────────────────────────────
BLAST_SCORE=$((FANOUT_SCORE + COUPLING_SCORE + LAYER_SCORE + INFRA_SCORE))

# Verdict: auto-fix or defer
if [[ "$BLAST_SCORE" -le 2 ]]; then
    VERDICT="auto"
elif [[ "$BLAST_SCORE" -le 5 && "$LAYER_COUNT" -le 1 ]]; then
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
AFFECTED_FILES=$AFFECTED_FILES_CSV
AFFECTED_LAYERS=$AFFECTED_LAYERS_CSV
EOF
