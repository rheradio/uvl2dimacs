#!/usr/bin/env bash
# compare_clause_number.sh — run uvl2dimacs in all four modes on every test model
# and record the clause counts to results.csv.
#
# Usage (from the repo root):
#   bash tests/nclauses/compare_clause_number.sh
#
# Output: tests/nclauses/results.csv
#
# Run analyze_clause_number.R afterwards to extract the statistics reported
# in the paper from that CSV.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UVL_DIR="$REPO_ROOT/tests/straightforward/uvl"
BIN="$REPO_ROOT/build/uvl2dimacs"
OUT_CSV="$SCRIPT_DIR/results.csv"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "compare_clause_number.sh"
echo "========================="
echo "Runs uvl2dimacs in all four modes (straightforward, Tseitin, backbone,"
echo "Tseitin+backbone) on each of the 1,533 UVL models and records the clause"
echo "counts in tests/nclauses/results.csv."
echo ""
echo "Runs uvl2dimacs in all four modes to record clause counts per model."
echo "Run analyze_clause_number.R afterwards to extract the paper's statistics."
echo ""

if [[ ! -x "$BIN" ]]; then
    echo "Error: binary not found at $BIN — run 'make' first" >&2
    exit 1
fi

get_clauses() {
    awk '/^p cnf/ { print $4; exit }' "$1"
}

# Fill the array without `mapfile`, which is unavailable on the Bash 3.2
# that ships with macOS. This while-read loop works on both Bash 3.2 and 4+.
UVL_FILES=()
while IFS= read -r uvl_file; do
    UVL_FILES+=("$uvl_file")
done < <(ls "$UVL_DIR"/*.uvl | sort)
TOTAL=${#UVL_FILES[@]}

echo "model,nclause_straightforward,nclause_tseitin,nclause_backbone,nclause_tseitin_and_backbone" > "$OUT_CSV"

COUNT=0
for uvl in "${UVL_FILES[@]}"; do
    model="$(basename "$uvl" .uvl)"
    COUNT=$((COUNT + 1))
    printf "\r[%d/%d] %s   " "$COUNT" "$TOTAL" "$model"

    "$BIN"          "$uvl" "$TMP/s.dimacs"  > /dev/null 2>&1
    "$BIN" -t       "$uvl" "$TMP/t.dimacs"  > /dev/null 2>&1
    "$BIN"    -b    "$uvl" "$TMP/b.dimacs"  > /dev/null 2>&1
    "$BIN" -t -b    "$uvl" "$TMP/tb.dimacs" > /dev/null 2>&1

    ns=$(get_clauses  "$TMP/s.dimacs")
    nt=$(get_clauses  "$TMP/t.dimacs")
    nb=$(get_clauses  "$TMP/b.dimacs")
    ntb=$(get_clauses "$TMP/tb.dimacs")

    echo "$model,$ns,$nt,$nb,$ntb" >> "$OUT_CSV"
done

printf "\nDone. Results written to %s\n" "$OUT_CSV"
printf "Run 'Rscript tests/nclauses/analyze_clause_number.R' to compute the statistics.\n"
