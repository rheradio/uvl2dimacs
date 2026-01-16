#!/bin/bash
#
# Test script for Tseitin transformation via solution counting
#
# This script verifies that the Tseitin transformation preserves solution counts:
# 1. Generates Tseitin DIMACS files for UVL models
# 2. Counts solutions using SharpSAT-TD for both straightforward and Tseitin modes
# 3. Verifies that solution counts match exactly
#
# This is a direct test of countability preservation using full Tseitin equivalences (⟺)
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Directories
UVL_DIR="$PROJECT_ROOT/tests/straightforward/uvl"
STRAIGHT_DIMACS_DIR="$PROJECT_ROOT/tests/straightforward/dimacs"
TSEITIN_DIMACS_DIR="$SCRIPT_DIR/dimacs"

# Executables
CLI="$PROJECT_ROOT/build/uvl2dimacs"
SHARPSAT_DIR="$PROJECT_ROOT/tests/sharpsat-td"
SHARPSAT="$SHARPSAT_DIR/bin/sharpSAT"

# Temporary directory for SharpSAT (passed via -tmpdir flag)
TEMP_DIR="/tmp/sharpsat_tseitin_test_$$"
mkdir -p "$TEMP_DIR"

# Cleanup on exit
trap "rm -rf $TEMP_DIR" EXIT

# Check if required tools exist
if [ ! -f "$CLI" ]; then
    echo -e "${RED}Error: uvl2dimacs CLI not found at $CLI${NC}"
    echo "Please build the project first with: make"
    exit 1
fi

# Check if SharpSAT-TD directory exists
if [ ! -d "$SHARPSAT_DIR" ]; then
    echo -e "${RED}Error: SharpSAT-TD not found${NC}"
    echo ""
    echo -e "${YELLOW}SharpSAT-TD is required for this test.${NC}"
    echo "Expected location: $SHARPSAT_DIR"
    echo ""
    echo -e "${GREEN}To install SharpSAT-TD:${NC}"
    echo ""
    echo "1. Clone the repository:"
    echo "    cd $PROJECT_ROOT/tests"
    echo "    git clone https://github.com/Laakeri/sharpsat-td.git"
    echo ""
    echo "2. Build SharpSAT-TD:"
    echo "    cd sharpsat-td"
    echo "    mkdir build && cd build"
    echo "    cmake -DCMAKE_BUILD_TYPE=Release .."
    echo "    make -j\$(nproc)"
    echo ""
    echo "3. Verify the installation:"
    echo "    ../bin/sharpSAT -h"
    echo ""
    echo -e "${BLUE}Prerequisites:${NC}"
    echo "    - GMP library: sudo apt-get install libgmp-dev (Debian/Ubuntu)"
    echo "    - MPFR library: sudo apt-get install libmpfr-dev (Debian/Ubuntu)"
    echo "    - For other systems: brew install gmp mpfr (macOS)"
    echo ""
    echo "For more information: https://github.com/Laakeri/sharpsat-td"
    echo ""
    exit 1
fi

# Check if SharpSAT binary exists
if [ ! -f "$SHARPSAT" ]; then
    echo -e "${RED}Error: SharpSAT-TD binary not found at $SHARPSAT${NC}"
    echo ""
    echo "SharpSAT-TD directory exists but the binary is missing."
    echo "Please build SharpSAT-TD:"
    echo ""
    echo "    cd $SHARPSAT_DIR"
    echo "    mkdir -p build && cd build"
    echo "    cmake -DCMAKE_BUILD_TYPE=Release .."
    echo "    make -j\$(nproc)"
    echo ""
    exit 1
fi

# Note: SharpSAT-TD may fail with -h due to TMPDIR assertion,
# but it works fine when run with actual DIMACS files.
# We skip the health check and let the actual tests proceed.

if [ ! -d "$UVL_DIR" ]; then
    echo -e "${RED}Error: UVL directory not found: $UVL_DIR${NC}"
    exit 1
fi

if [ ! -d "$STRAIGHT_DIMACS_DIR" ]; then
    echo -e "${RED}Error: Straightforward DIMACS directory not found: $STRAIGHT_DIMACS_DIR${NC}"
    exit 1
fi

# Create output directory
mkdir -p "$TSEITIN_DIMACS_DIR"

# Function to check maximum clause size in a DIMACS file
# Args: $1 = DIMACS file path
# Returns: Maximum clause size (number of literals, excluding trailing 0)
check_max_clause_size() {
    local dimacs_file="$1"
    local max_size=0

    # Read all clauses (skip comments and header)
    while IFS= read -r line; do
        # Skip comment lines and header
        if [[ "$line" =~ ^c ]] || [[ "$line" =~ ^p ]]; then
            continue
        fi

        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi

        # Count literals in this clause (excluding trailing 0)
        # Each clause is space-separated integers ending with 0
        local clause_size=0
        for literal in $line; do
            if [ "$literal" != "0" ]; then
                ((clause_size++))
            fi
        done

        # Update max if this clause is larger
        if [ $clause_size -gt $max_size ]; then
            max_size=$clause_size
        fi
    done < "$dimacs_file"

    echo "$max_size"
    return 0
}

# Function to count solutions using SharpSAT-TD
# Args: $1 = DIMACS file path
# Returns: Solution count (or "UNSAT" if unsatisfiable, "ERROR" if failed)
count_solutions() {
    local dimacs_file="$1"

    # Get absolute path to DIMACS file
    local abs_dimacs_file="$(cd "$(dirname "$dimacs_file")" && pwd)/$(basename "$dimacs_file")"

    # SharpSAT must be run from its bin directory (requires flow_cutter_pace17 in same dir)
    cd "$SHARPSAT_DIR/bin" || {
        echo "ERROR"
        return 1
    }

    local output=$(./sharpSAT -decot 1 -tmpdir "$TEMP_DIR" "$abs_dimacs_file" 2>&1)
    local exit_code=$?
    cd - > /dev/null

    # Check for errors
    if [ $exit_code -ne 0 ]; then
        # Check if it's just UNSAT
        if echo "$output" | grep -q "s UNSATISFIABLE"; then
            echo "UNSAT"
            return 0
        fi
        echo "ERROR"
        return 1
    fi

    # Extract solution count
    # Look for line like "c s exact arb int 42"
    local count=$(echo "$output" | grep "c s exact arb int" | awk '{print $NF}')

    if [ -z "$count" ]; then
        echo "ERROR"
        return 1
    fi

    echo "$count"
    return 0
}

echo "============================================================"
echo "Testing Tseitin Transformation (3-CNF + Solution Counting)"
echo "============================================================"
echo ""
echo -e "${BLUE}This test verifies that the Tseitin transformation:"
echo -e "1. Produces valid 3-CNF (all clauses have ≤3 literals)"
echo -e "2. Preserves solution counts using full equivalences (⟺)${NC}"
echo ""
echo "CLI: $CLI"
echo "SharpSAT-TD: $SHARPSAT"
echo "UVL files: $UVL_DIR"
echo "Straightforward DIMACS: $STRAIGHT_DIMACS_DIR"
echo "Tseitin DIMACS output: $TSEITIN_DIMACS_DIR"
echo ""

# Test parameters
NUM_TESTS=${1:-20}  # Default to 20 tests, can override with argument

# Get list of UVL files (sort by size, take smallest ones for faster testing)
echo "Selecting $NUM_TESTS models (preferring smaller ones for speed)..."
uvl_files=($(find "$UVL_DIR" -name "*.uvl" -exec wc -l {} \; 2>/dev/null | sort -n | head -n 100 | awk '{print $2}'))

if [ ${#uvl_files[@]} -eq 0 ]; then
    echo -e "${RED}Error: No UVL files found in $UVL_DIR${NC}"
    exit 1
fi

# Take only NUM_TESTS files
if [ ${#uvl_files[@]} -gt $NUM_TESTS ]; then
    uvl_files=("${uvl_files[@]:0:$NUM_TESTS}")
fi

echo "Selected ${#uvl_files[@]} files to test"
echo ""

# Counters
total=0
passed=0
failed=0
skipped=0

# Process each file
for uvl_file in "${uvl_files[@]}"; do
    # Get basename without extension
    basename=$(basename "$uvl_file" .uvl)

    # Paths
    straight_dimacs="$STRAIGHT_DIMACS_DIR/${basename}.dimacs"
    tseitin_dimacs="$TSEITIN_DIMACS_DIR/${basename}.dimacs"

    ((total++))

    echo -n "[$total/${#uvl_files[@]}] Testing $basename... "

    # Check if straightforward DIMACS exists
    if [ ! -f "$straight_dimacs" ]; then
        echo -e "${YELLOW}SKIP (no straightforward DIMACS)${NC}"
        ((skipped++))
        continue
    fi

    # Generate Tseitin DIMACS (suppress verbose output)
    if ! "$CLI" -t "$uvl_file" "$tseitin_dimacs" >/dev/null 2>&1; then
        echo -e "${RED}FAIL (Tseitin conversion failed)${NC}"
        ((failed++))
        continue
    fi

    # Check that Tseitin DIMACS has all clauses with ≤3 literals
    max_clause_size=$(check_max_clause_size "$tseitin_dimacs")
    if [ $max_clause_size -gt 3 ]; then
        echo -e "${RED}FAIL (3-CNF violated: found clause with $max_clause_size literals)${NC}"
        ((failed++))
        continue
    fi

    # Count solutions for both modes
    count_straight=$(count_solutions "$straight_dimacs")
    count_straight_status=$?

    count_tseitin=$(count_solutions "$tseitin_dimacs")
    count_tseitin_status=$?

    # Check for errors
    if [ $count_straight_status -ne 0 ] || [ "$count_straight" = "ERROR" ]; then
        echo -e "${RED}FAIL (straightforward counting failed)${NC}"
        ((failed++))
        continue
    fi

    if [ $count_tseitin_status -ne 0 ] || [ "$count_tseitin" = "ERROR" ]; then
        echo -e "${RED}FAIL (Tseitin counting failed)${NC}"
        ((failed++))
        continue
    fi

    # Handle UNSAT cases
    if [ "$count_straight" = "UNSAT" ] || [ "$count_tseitin" = "UNSAT" ]; then
        if [ "$count_straight" = "UNSAT" ] && [ "$count_tseitin" = "UNSAT" ]; then
            echo -e "${GREEN}PASS (3-CNF ✓, both UNSAT)${NC}"
            ((passed++))
        else
            echo -e "${RED}FAIL (SAT/UNSAT mismatch)${NC}"
            echo "  Straightforward: $count_straight"
            echo "  Tseitin:         $count_tseitin"
            ((failed++))
        fi
        continue
    fi

    # Compare solution counts
    if [ "$count_straight" = "$count_tseitin" ]; then
        echo -e "${GREEN}PASS (3-CNF ✓, max clause: $max_clause_size, solutions: $count_straight)${NC}"
        ((passed++))
    else
        echo -e "${RED}FAIL (counts differ)${NC}"
        echo "  Straightforward: $count_straight solutions"
        echo "  Tseitin:         $count_tseitin solutions"
        echo "  Difference:      $((count_tseitin - count_straight))"

        # Show variable counts
        straight_vars=$(grep "^p cnf" "$straight_dimacs" | awk '{print $3}')
        tseitin_vars=$(grep "^p cnf" "$tseitin_dimacs" | awk '{print $3}')
        aux_vars=$((tseitin_vars - straight_vars))
        echo "  Variables:       $straight_vars (straight) vs $tseitin_vars (Tseitin, +$aux_vars auxiliary)"

        ((failed++))
    fi
done

# Summary
echo ""
echo "============================================================"
echo "Test Summary"
echo "============================================================"
echo "Total tests: $total"
echo -e "${GREEN}Passed: $passed${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
else
    echo "Failed: 0"
fi
if [ $skipped -gt 0 ]; then
    echo -e "${YELLOW}Skipped: $skipped${NC}"
fi
echo "============================================================"

# Exit with appropriate code
if [ $failed -eq 0 ] && [ $passed -gt 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "This confirms that the Tseitin transformation:"
    echo "  1. Produces valid 3-CNF (all clauses have ≤3 literals)"
    echo "  2. Uses full biconditional equivalences (⟺)"
    echo "  3. Preserves solution counts exactly"
    echo ""
    echo -e "${BLUE}Key insight:${NC} Auxiliary variables are FULLY DETERMINED by the"
    echo "equivalences, so each original solution extends to exactly ONE"
    echo "solution with auxiliaries."
    echo ""
    echo "Therefore: #solutions(straightforward) = #solutions(tseitin)"
    exit 0
elif [ $passed -eq 0 ] && [ $skipped -eq $total ]; then
    echo ""
    echo -e "${YELLOW}⚠ All tests skipped.${NC}"
    echo "This usually means DIMACS files are missing."
    exit 1
else
    echo ""
    echo -e "${RED}✗ Some tests failed!${NC}"
    echo ""
    echo "This suggests a bug in the Tseitin transformation."
    echo "Possible issues:"
    echo "  - 3-CNF violation (clauses with >3 literals)"
    echo "  - Incorrect equivalence encoding"
    echo "  - Solution count preservation failure"
    exit 1
fi
