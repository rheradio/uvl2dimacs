#!/bin/bash
#
# Test script for backbone simplification via solution counting
#
# This script verifies that backbone simplification preserves the number
# of satisfying assignments by:
# 1. Counting solutions of original DIMACS files
# 2. Applying backbone simplification (-b flag)
# 3. Counting solutions of simplified DIMACS files
# 4. Comparing that the solution counts match
#
# Uses SharpSAT-TD model counter for exact #SAT computation
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Directories and executables
DIMACS_DIR="$PROJECT_ROOT/tests/straightforward/dimacs"
UVL_DIR="$PROJECT_ROOT/tests/straightforward/uvl"
CLI="$PROJECT_ROOT/build/uvl2dimacs"
SHARPSAT="$PROJECT_ROOT/tests/backbone/sharpsat-td/bin/sharpSAT"

# Temporary directory for SharpSAT
TEMP_DIR="/tmp/sharpsat_test_$$"
mkdir -p "$TEMP_DIR"

# Cleanup on exit
trap "rm -rf $TEMP_DIR" EXIT

# Check if required tools exist
if [ ! -f "$CLI" ]; then
    echo -e "${RED}Error: uvl2dimacs CLI not found at $CLI${NC}"
    echo "Please build the project first with: make"
    exit 1
fi

if [ ! -f "$SHARPSAT" ]; then
    echo -e "${RED}Error: SharpSAT-TD not found at $SHARPSAT${NC}"
    echo "Please build SharpSAT-TD with: make sharpsat"
    exit 1
fi

if [ ! -d "$DIMACS_DIR" ]; then
    echo -e "${RED}Error: DIMACS directory not found: $DIMACS_DIR${NC}"
    exit 1
fi

# Function to count solutions using SharpSAT-TD
# Args: $1 = DIMACS file path
# Returns: Solution count (or "UNSAT" if unsatisfiable)
count_solutions() {
    local dimacs_file="$1"
    local output_file="$TEMP_DIR/sharpsat_output_$$.txt"

    # Run SharpSAT from its bin directory (requires flow_cutter_pace17 in same dir)
    cd "$PROJECT_ROOT/tests/backbone/sharpsat-td/bin"
    ./sharpSAT -decot 1 -tmpdir "$TEMP_DIR" "$dimacs_file" > "$output_file" 2>&1
    local exit_code=$?

    # Return to original directory
    cd - > /dev/null

    # Check if unsatisfiable
    if grep -q "^s UNSATISFIABLE" "$output_file"; then
        echo "UNSAT"
        rm -f "$output_file"
        return 0
    fi

    # Extract exact solution count
    local count=$(grep "^c s exact arb int" "$output_file" | awk '{print $NF}')

    if [ -z "$count" ]; then
        echo "ERROR"
        rm -f "$output_file"
        return 1
    fi

    echo "$count"
    rm -f "$output_file"
    return 0
}

echo "============================================================"
echo "Testing Backbone Simplification via Solution Counting"
echo "============================================================"
echo "CLI: $CLI"
echo "SharpSAT: $SHARPSAT"
echo "DIMACS directory: $DIMACS_DIR"
echo ""

# Get list of DIMACS files (limit to first 20 for reasonable test time)
dimacs_files=($(ls "$DIMACS_DIR"/*.dimacs | head -20))

if [ ${#dimacs_files[@]} -eq 0 ]; then
    echo -e "${RED}Error: No DIMACS files found in $DIMACS_DIR${NC}"
    exit 1
fi

echo "Testing ${#dimacs_files[@]} models (first 20 from collection)"
echo ""

# Counters
total=0
passed=0
failed=0
skipped=0

# Process each file
for dimacs_file in "${dimacs_files[@]}"; do
    # Get basename without extension
    basename=$(basename "$dimacs_file" .dimacs)
    uvl_file="$UVL_DIR/${basename}.uvl"

    ((total++))

    # Check if UVL file exists
    if [ ! -f "$uvl_file" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $basename - No UVL file"
        ((skipped++))
        continue
    fi

    # Count solutions of original DIMACS
    echo -n "Testing $basename... "
    count_original=$(count_solutions "$dimacs_file")

    if [ "$count_original" = "ERROR" ]; then
        echo -e "${RED}[FAIL]${NC} - Failed to count solutions of original"
        ((failed++))
        continue
    fi

    # Generate simplified DIMACS with backbone
    simplified_dimacs="$TEMP_DIR/${basename}_simplified.dimacs"
    "$CLI" -s -b "$uvl_file" "$simplified_dimacs" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${RED}[FAIL]${NC} - Failed to generate simplified DIMACS"
        ((failed++))
        continue
    fi

    # Count solutions of simplified DIMACS
    count_simplified=$(count_solutions "$simplified_dimacs")

    if [ "$count_simplified" = "ERROR" ]; then
        echo -e "${RED}[FAIL]${NC} - Failed to count solutions of simplified"
        ((failed++))
        continue
    fi

    # Compare solution counts
    if [ "$count_original" = "$count_simplified" ]; then
        echo -e "${GREEN}[PASS]${NC} (solutions: $count_original)"
        ((passed++))
    else
        echo -e "${RED}[FAIL]${NC} - Solution counts differ!"
        echo "  Original:   $count_original"
        echo "  Simplified: $count_simplified"
        ((failed++))
    fi

    # Cleanup simplified file
    rm -f "$simplified_dimacs"
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
if [ $failed -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All tests passed! Backbone simplification preserves solution counts.${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
