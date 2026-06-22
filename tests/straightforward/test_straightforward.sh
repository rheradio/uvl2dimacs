#!/bin/bash
#
# Test script for UVL to DIMACS conversion in STRAIGHTFORWARD mode
#
# This script:
# 1. Runs uvl2dimacs CLI with -s flag on all UVL files in the uvl/ directory
# 2. Compares the generated DIMACS files with the reference DIMACS files in dimacs/
# 3. Reports matches and mismatches
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Directories
UVL_DIR="$SCRIPT_DIR/uvl"
DIMACS_DIR="$SCRIPT_DIR/dimacs"
TEMP_DIR="$SCRIPT_DIR/temp_test_output"
CLI_PATH="$PROJECT_ROOT/build/uvl2dimacs"

# Check if CLI exists
if [ ! -f "$CLI_PATH" ]; then
    echo -e "${RED}Error: CLI not found at $CLI_PATH${NC}"
    echo "Please build the project first with: make"
    exit 1
fi

# Check if directories exist
if [ ! -d "$UVL_DIR" ]; then
    echo -e "${RED}Error: UVL directory not found: $UVL_DIR${NC}"
    exit 1
fi

if [ ! -d "$DIMACS_DIR" ]; then
    echo -e "${RED}Error: DIMACS directory not found: $DIMACS_DIR${NC}"
    exit 1
fi

# Create temp directory for generated files
mkdir -p "$TEMP_DIR"

# Counters
total=0
passed=0
failed=0

echo "============================================================"
echo "Testing UVL to DIMACS conversion (STRAIGHTFORWARD mode)"
echo "============================================================"
echo "CLI: $CLI_PATH"
echo "UVL files: $UVL_DIR"
echo "Reference DIMACS: $DIMACS_DIR"
echo "Temp output: $TEMP_DIR"
echo ""

# Get list of UVL files
uvl_files=("$UVL_DIR"/*.uvl)

if [ ! -e "${uvl_files[0]}" ]; then
    echo -e "${RED}Error: No UVL files found in $UVL_DIR${NC}"
    exit 1
fi

echo "Found ${#uvl_files[@]} UVL files to test"
echo ""

# Process each file
for uvl_file in "${uvl_files[@]}"; do
    # Get basename without extension
    basename=$(basename "$uvl_file" .uvl)

    # Paths
    reference_dimacs="$DIMACS_DIR/${basename}.dimacs"
    generated_dimacs="$TEMP_DIR/${basename}.dimacs"

    ((total++))

    # Check if reference DIMACS exists
    if [ ! -f "$reference_dimacs" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $basename - No reference DIMACS file"
        continue
    fi

    # Run CLI conversion with -s flag
    if "$CLI_PATH" -s "$uvl_file" "$generated_dimacs" >/dev/null 2>&1; then
        # Compare generated with reference
        # Note: We need to compare the actual CNF content, ignoring comment lines that might differ

        # Extract only the CNF content (lines starting with 'p' or containing clause data)
        grep -v "^c " "$reference_dimacs" | grep -v "^$" > "$TEMP_DIR/ref_${basename}.stripped" 2>/dev/null || touch "$TEMP_DIR/ref_${basename}.stripped"
        grep -v "^c " "$generated_dimacs" | grep -v "^$" > "$TEMP_DIR/gen_${basename}.stripped" 2>/dev/null || touch "$TEMP_DIR/gen_${basename}.stripped"

        if diff -q "$TEMP_DIR/ref_${basename}.stripped" "$TEMP_DIR/gen_${basename}.stripped" >/dev/null 2>&1; then
            echo -e "${GREEN}[PASS]${NC} $basename"
            ((passed++))
        else
            echo -e "${RED}[FAIL]${NC} $basename - Generated DIMACS differs from reference"
            ((failed++))
        fi
    else
        echo -e "${RED}[FAIL]${NC} $basename - Conversion failed"
        ((failed++))
    fi
done

# Cleanup
rm -rf "$TEMP_DIR"

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
    echo -e "Failed: $failed"
fi
echo "============================================================"

# Exit with appropriate code
if [ $failed -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
