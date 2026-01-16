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
# Prerequisites:
# - GMP and MPFR libraries installed
# - SharpSAT-TD cloned and built in this directory
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

# Directories and executables
DIMACS_DIR="$PROJECT_ROOT/tests/straightforward/dimacs"
UVL_DIR="$PROJECT_ROOT/tests/straightforward/uvl"
CLI="$PROJECT_ROOT/build/uvl2dimacs"
SHARPSAT_DIR="$PROJECT_ROOT/tests/sharpsat-td"
SHARPSAT="$SHARPSAT_DIR/bin/sharpSAT"

# Temporary directory for SharpSAT
TEMP_DIR="/tmp/sharpsat_test_$$"
mkdir -p "$TEMP_DIR"

# Cleanup on exit
trap "rm -rf $TEMP_DIR" EXIT

# Function to detect the operating system
detect_os() {
    # Check for WSL first (before Linux, since WSL also has linux-gnu OSTYPE)
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Function to check if GMP is installed
check_gmp() {
    # Try pkg-config first
    if pkg-config --exists gmp 2>/dev/null; then
        return 0
    fi

    # Try to find the library directly
    if ldconfig -p 2>/dev/null | grep -q libgmp; then
        return 0
    fi

    # Check common locations
    if [ -f "/usr/lib/libgmp.so" ] || [ -f "/usr/lib/libgmp.a" ] || \
       [ -f "/usr/local/lib/libgmp.so" ] || [ -f "/usr/local/lib/libgmp.a" ] || \
       [ -f "/usr/lib/x86_64-linux-gnu/libgmp.so" ] || [ -f "/usr/lib/x86_64-linux-gnu/libgmp.a" ] || \
       [ -f "/opt/homebrew/lib/libgmp.a" ] || [ -f "/opt/homebrew/lib/libgmp.dylib" ] || \
       [ -f "/usr/local/opt/gmp/lib/libgmp.a" ] || [ -f "/usr/local/opt/gmp/lib/libgmp.dylib" ]; then
        return 0
    fi

    # Try compiling a simple test
    echo 'int main() { return 0; }' | cc -x c - -lgmp -o /dev/null 2>/dev/null
    return $?
}

# Function to check if MPFR is installed
check_mpfr() {
    # Try pkg-config first
    if pkg-config --exists mpfr 2>/dev/null; then
        return 0
    fi

    # Try to find the library directly
    if ldconfig -p 2>/dev/null | grep -q libmpfr; then
        return 0
    fi

    # Check common locations
    if [ -f "/usr/lib/libmpfr.so" ] || [ -f "/usr/lib/libmpfr.a" ] || \
       [ -f "/usr/local/lib/libmpfr.so" ] || [ -f "/usr/local/lib/libmpfr.a" ] || \
       [ -f "/usr/lib/x86_64-linux-gnu/libmpfr.so" ] || [ -f "/usr/lib/x86_64-linux-gnu/libmpfr.a" ] || \
       [ -f "/opt/homebrew/lib/libmpfr.a" ] || [ -f "/opt/homebrew/lib/libmpfr.dylib" ] || \
       [ -f "/usr/local/opt/mpfr/lib/libmpfr.a" ] || [ -f "/usr/local/opt/mpfr/lib/libmpfr.dylib" ]; then
        return 0
    fi

    # Try compiling a simple test
    echo 'int main() { return 0; }' | cc -x c - -lmpfr -lgmp -o /dev/null 2>/dev/null
    return $?
}

# Function to show GMP/MPFR installation instructions based on OS
show_dependency_instructions() {
    local os="$1"
    local missing_gmp="$2"
    local missing_mpfr="$3"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Dependency Installation Instructions${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    if [ "$missing_gmp" = "true" ]; then
        echo -e "${RED}Missing: GMP (GNU Multiple Precision Arithmetic Library)${NC}"
    fi
    if [ "$missing_mpfr" = "true" ]; then
        echo -e "${RED}Missing: MPFR (Multiple Precision Floating-Point Reliable Library)${NC}"
    fi
    echo ""

    case "$os" in
        "linux")
            echo -e "${GREEN}For Debian/Ubuntu:${NC}"
            echo "    sudo apt-get update"
            echo "    sudo apt-get install libgmp-dev libmpfr-dev"
            echo ""
            echo -e "${GREEN}For Fedora/RHEL/CentOS:${NC}"
            echo "    sudo dnf install gmp-devel mpfr-devel"
            echo ""
            echo -e "${GREEN}For Arch Linux:${NC}"
            echo "    sudo pacman -S gmp mpfr"
            echo ""
            echo -e "${GREEN}For openSUSE:${NC}"
            echo "    sudo zypper install gmp-devel mpfr-devel"
            ;;
        "macos")
            echo -e "${GREEN}Using Homebrew (recommended):${NC}"
            echo "    brew install gmp mpfr"
            echo ""
            echo -e "${GREEN}Using MacPorts:${NC}"
            echo "    sudo port install gmp mpfr"
            ;;
        "windows")
            echo -e "${GREEN}Using MSYS2:${NC}"
            echo "    pacman -S mingw-w64-x86_64-gmp mingw-w64-x86_64-mpfr"
            echo ""
            echo -e "${GREEN}Using vcpkg:${NC}"
            echo "    vcpkg install gmp mpfr"
            echo ""
            echo -e "${GREEN}Manual installation:${NC}"
            echo "    Download pre-built binaries from:"
            echo "    - GMP: https://gmplib.org/"
            echo "    - MPFR: https://www.mpfr.org/"
            ;;
        "wsl")
            echo -e "${GREEN}For WSL (Windows Subsystem for Linux):${NC}"
            echo "    sudo apt-get update"
            echo "    sudo apt-get install libgmp-dev libmpfr-dev"
            echo ""
            echo "    (Same as Debian/Ubuntu since WSL typically uses Ubuntu)"
            ;;
        *)
            echo -e "${YELLOW}Unknown operating system. Please install GMP and MPFR manually:${NC}"
            echo "    - GMP: https://gmplib.org/"
            echo "    - MPFR: https://www.mpfr.org/"
            ;;
    esac

    echo ""
    echo "After installing the dependencies, run this script again."
    echo ""
}

# Function to show SharpSAT-TD installation instructions
show_sharpsat_instructions() {
    local os="$1"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}SharpSAT-TD Installation Instructions${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${YELLOW}SharpSAT-TD is not found in the expected location:${NC}"
    echo "    $SHARPSAT_DIR"
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

    case "$os" in
        "linux"|"wsl")
            echo -e "${GREEN}Build prerequisites for Linux:${NC}"
            echo "    sudo apt-get install build-essential cmake libgmp-dev libmpfr-dev"
            ;;
        "macos")
            echo -e "${GREEN}Build prerequisites for macOS:${NC}"
            echo "    xcode-select --install"
            echo "    brew install cmake gmp mpfr"
            ;;
        "windows")
            echo -e "${GREEN}Build prerequisites for Windows (MSYS2):${NC}"
            echo "    pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake"
            echo "    pacman -S mingw-w64-x86_64-gmp mingw-w64-x86_64-mpfr"
            ;;
    esac

    echo ""
    echo "For more information, visit: https://github.com/Laakeri/sharpsat-td"
    echo ""
}

# Check if required tools exist
if [ ! -f "$CLI" ]; then
    echo -e "${RED}Error: uvl2dimacs CLI not found at $CLI${NC}"
    echo "Please build the project first with: make"
    exit 1
fi

# Detect operating system
OS=$(detect_os)
echo "Detected operating system: $OS"

# Check for GMP and MPFR
echo "Checking for required dependencies..."

MISSING_GMP="false"
MISSING_MPFR="false"

if ! check_gmp; then
    MISSING_GMP="true"
fi

if ! check_mpfr; then
    MISSING_MPFR="true"
fi

if [ "$MISSING_GMP" = "true" ] || [ "$MISSING_MPFR" = "true" ]; then
    echo -e "${RED}Error: Missing required dependencies${NC}"
    show_dependency_instructions "$OS" "$MISSING_GMP" "$MISSING_MPFR"
    exit 1
fi

echo -e "${GREEN}GMP and MPFR dependencies found.${NC}"

# Check if SharpSAT-TD directory exists
if [ ! -d "$SHARPSAT_DIR" ]; then
    echo -e "${RED}Error: SharpSAT-TD not found${NC}"
    show_sharpsat_instructions "$OS"
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

# Check if SharpSAT is executable
if [ ! -x "$SHARPSAT" ]; then
    echo -e "${RED}Error: SharpSAT-TD binary is not executable${NC}"
    echo "Try: chmod +x $SHARPSAT"
    exit 1
fi

# Note: SharpSAT-TD may fail with -h due to TMPDIR assertion,
# but it works fine when run with actual DIMACS files and -tmpdir flag.
# We skip the health check and let the actual tests proceed.

echo -e "${GREEN}SharpSAT-TD found.${NC}"

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
    local original_dir="$(pwd)"

    # Get absolute path to DIMACS file
    local abs_dimacs_file="$(cd "$(dirname "$dimacs_file")" && pwd)/$(basename "$dimacs_file")"

    # Run SharpSAT from its bin directory (requires flow_cutter_pace17 in same dir)
    cd "$SHARPSAT_DIR/bin" || {
        echo "ERROR"
        return 1
    }

    ./sharpSAT -decot 1 -tmpdir "$TEMP_DIR" "$abs_dimacs_file" > "$output_file" 2>&1
    local exit_code=$?

    # Return to original directory
    cd "$original_dir" || true

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
