#!/bin/bash
#
# Test script for Tseitin transformation via backbone comparison
#
# This script:
# 1. Generates Tseitin DIMACS files for all UVL models
# 2. Computes backbones using backbone_solver (default detector)
# 3. Filters auxiliary variables from Tseitin backbones
# 4. Compares feature-only backbones between straightforward and Tseitin modes
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
BACKBONE_SOLVER="$PROJECT_ROOT/backbone_solver/bin/backbone_solver"

# Check if required tools exist
if [ ! -f "$CLI" ]; then
    echo -e "${RED}Error: uvl2dimacs CLI not found at $CLI${NC}"
    echo "Please build the project first with: make"
    exit 1
fi

if [ ! -f "$BACKBONE_SOLVER" ]; then
    echo -e "${RED}Error: backbone_solver not found at $BACKBONE_SOLVER${NC}"
    echo "Please build it first with: make backbone_solver"
    exit 1
fi

# Check if backbone_solver is executable and for the correct architecture
# Use 'file' command to check architecture instead of running the binary
# (backbone_solver returns non-zero exit code for -h)
if [[ "$OSTYPE" == "darwin"* ]]; then
    expected_arch="Mach-O"
else
    expected_arch="ELF"
fi

if ! file "$BACKBONE_SOLVER" | grep -q "$expected_arch"; then
    echo -e "${RED}Error: backbone_solver is not executable or wrong architecture${NC}"
    echo "This usually happens when switching between macOS and Linux."
    echo "Please rebuild with: make clean-backbone && make backbone_solver"
    exit 1
fi

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

# Function to extract and filter backbone
# Args: $1 = DIMACS file path
# Returns: Filtered backbone string (feature variables only, sorted)
extract_and_filter_backbone() {
    local dimacs_file="$1"
    local temp_output="/tmp/bb_output_$$.txt"

    # Run backbone solver
    "$BACKBONE_SOLVER" "$dimacs_file" > "$temp_output" 2>&1
    local exit_code=$?

    # Check for UNSAT (exit code 20)
    if [ $exit_code -eq 20 ]; then
        rm -f "$temp_output"
        echo "UNSAT"
        return 0
    fi

    # Check for other errors
    if [ $exit_code -ne 10 ] && [ $exit_code -ne 0 ]; then
        rm -f "$temp_output"
        echo "ERROR"
        return 1
    fi

    # Use Python to extract and filter backbone
    python3 - "$temp_output" "$dimacs_file" <<'EOF'
import re
import sys

# Get file paths from command line arguments
if len(sys.argv) != 3:
    print("ERROR", file=sys.stderr)
    sys.exit(1)

temp_output = sys.argv[1]
dimacs_file = sys.argv[2]

# Read backbone solver output
try:
    with open(temp_output, 'r') as f:
        output = f.read()
except Exception as e:
    print(f"ERROR reading {temp_output}: {e}", file=sys.stderr)
    sys.exit(1)

# Remove ANSI escape codes
ansi_escape = re.compile(r'\x1b\[[0-9;]*m')
clean = ansi_escape.sub('', output)

# Extract backbone line (starts with 'v ')
backbone = ""
for line in clean.split('\n'):
    if line.startswith('v '):
        backbone = line[2:].strip()
        break

if not backbone:
    # Empty backbone is valid
    print("")
    sys.exit(0)

# Read variable mappings from DIMACS file
var_map = {}
try:
    with open(dimacs_file, 'r') as f:
        for line in f:
            if line.startswith('c '):
                parts = line.split()
                # Format: c <var_id> <var_name>
                if len(parts) >= 3:
                    try:
                        var_id = int(parts[1])
                        var_name = parts[2]
                        var_map[var_id] = var_name
                    except ValueError:
                        pass
except Exception as e:
    print(f"ERROR reading {dimacs_file}: {e}", file=sys.stderr)
    sys.exit(1)

# Filter auxiliary variables and sort
filtered = []
for lit in backbone.split():
    lit = lit.strip()
    if not lit:
        continue
    try:
        var_id = abs(int(lit))
        var_name = var_map.get(var_id, "")

        # Skip auxiliary variables (those starting with "aux_")
        if not var_name.startswith("aux_"):
            filtered.append(int(lit))
    except ValueError:
        pass

# Sort by absolute value of variable ID for consistent comparison
filtered_sorted = sorted(filtered, key=lambda x: abs(x))

# Output as space-separated string
print(' '.join(map(str, filtered_sorted)))
EOF

    local result=$?
    rm -f "$temp_output"
    return $result
}

echo "============================================================"
echo "Testing Tseitin Transformation via Backbone Comparison"
echo "============================================================"
echo "CLI: $CLI"
echo "Backbone Solver: $BACKBONE_SOLVER"
echo "UVL files: $UVL_DIR"
echo "Straightforward DIMACS: $STRAIGHT_DIMACS_DIR"
echo "Tseitin DIMACS output: $TSEITIN_DIMACS_DIR"
echo ""

# Get list of UVL files
uvl_files=("$UVL_DIR"/*.uvl)

if [ ! -e "${uvl_files[0]}" ]; then
    echo -e "${RED}Error: No UVL files found in $UVL_DIR${NC}"
    exit 1
fi

echo "Found ${#uvl_files[@]} UVL files to test"
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

    # Check if straightforward DIMACS exists
    if [ ! -f "$straight_dimacs" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $basename - No straightforward DIMACS file"
        ((skipped++))
        continue
    fi

    # Generate Tseitin DIMACS (suppress verbose output)
    if ! "$CLI" -t "$uvl_file" "$tseitin_dimacs" >/dev/null 2>&1; then
        echo -e "${RED}[FAIL]${NC} $basename - Tseitin conversion failed"
        ((failed++))
        continue
    fi

    # Extract and filter backbones
    bb_straight=$(extract_and_filter_backbone "$straight_dimacs")
    bb_straight_status=$?

    bb_tseitin=$(extract_and_filter_backbone "$tseitin_dimacs")
    bb_tseitin_status=$?

    # Check for errors
    if [ $bb_straight_status -ne 0 ] || [ "$bb_straight" = "ERROR" ]; then
        echo -e "${RED}[FAIL]${NC} $basename - Straightforward backbone computation failed"
        ((failed++))
        continue
    fi

    if [ $bb_tseitin_status -ne 0 ] || [ "$bb_tseitin" = "ERROR" ]; then
        echo -e "${RED}[FAIL]${NC} $basename - Tseitin backbone computation failed"
        ((failed++))
        continue
    fi

    # Handle UNSAT cases
    if [ "$bb_straight" = "UNSAT" ] || [ "$bb_tseitin" = "UNSAT" ]; then
        if [ "$bb_straight" = "UNSAT" ] && [ "$bb_tseitin" = "UNSAT" ]; then
            echo -e "${GREEN}[PASS]${NC} $basename (both UNSAT)"
            ((passed++))
        else
            echo -e "${RED}[FAIL]${NC} $basename - SAT/UNSAT mismatch (straight: $bb_straight, tseitin: $bb_tseitin)"
            ((failed++))
        fi
        continue
    fi

    # Compare backbones
    if [ "$bb_straight" = "$bb_tseitin" ]; then
        echo -e "${GREEN}[PASS]${NC} $basename"
        ((passed++))
    else
        echo -e "${RED}[FAIL]${NC} $basename - Backbones differ"
        echo "  Straightforward: $bb_straight"
        echo "  Tseitin:         $bb_tseitin"
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
if [ $failed -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
