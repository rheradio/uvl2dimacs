# UVL2Dimacs

A C++ library and CLI tool for converting Universal Variability Language (UVL) variability models to DIMACS CNF format.

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![C++17](https://img.shields.io/badge/C%2B%2B-17-blue)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Platform support:** uvl2dimacs runs natively on **Linux** and **macOS**. It also runs on **Windows** via either **WSL2** (install WSL2 with an Ubuntu distribution and follow the Linux instructions below) or **Docker** (see the [Docker](#docker) section, which requires no manual setup). 
>
>*Native Windows builds without WSL2 or Docker are not supported because the build system relies on POSIX tools (`make`, `bash`) and platform-specific compiler detection.*

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Build](#build)
- [Docker](#docker)
- [Basic Usage](#basic-usage)
- [CLI Options](#cli-options)
- [API Usage](#api-usage)
- [Conversion Modes](#conversion-modes)
- [Backbone Simplification](#backbone-simplification)
- [Testing](#testing)
- [UVL Grammar Support](#uvl-grammar-support)
- [Output Format](#output-format)
- [Performance](#performance)
- [API Documentation](#api-documentation)
- [Project Structure](#project-structure)
- [Limitations](#limitations)
- [Authors](#authors)
- [License](#license)
- [Related Tools](#related-tools)

## Features

- **Two Conversion Modes**:
  - **Straightforward** (direct CNF, fewer variables, compact)
  - **Tseitin** (auxiliary variables for cross-tree constraints, preventing exponential clause growth)
- **Backbone Simplification**: Formula size reduction while preserving solution counts
- **High Performance**: Optimized with -O3, LTO, and native CPU tuning
- **Library API**: Clean C++ API for integration into other tools
- **Comprehensive Testing**: 1,533 test models with automated solution count verification

## Requirements

- C++17 compiler (g++ or clang++)
- CMake 3.10+
- GNU Make
- zlib development headers (required by MiniSat)

## Build

uvl2dimacs can be compiled and run natively by following the steps below, or, as the [next section](#docker) shows, it can be run in a Docker container with no manual setup required.

### 1. Install a C++ Compiler

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get update && sudo apt-get install g++
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install gcc-c++
```

**macOS:**
```bash
xcode-select --install
```

### 2. Install zlib Development Headers

zlib is required by MiniSat (the SAT solver embedded in the backbone simplifier).

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get update && sudo apt-get install zlib1g-dev
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install zlib-devel
```

**macOS:** zlib is bundled with Xcode Command Line Tools, so no separate install is needed.

### 3. Install CMake

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get update && sudo apt-get install cmake
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install cmake
```

**macOS:**
```bash
brew install cmake
```

### 4. Compile

```bash
# Build everything
make

# Build specific targets
make uvl2dimacs        # CLI tool
make api               # API library
make examples          # API examples
```

## Docker

Docker provides a self-contained environment with all dependencies pre-installed (compiler, CMake, MiniSat, SharpSAT-TD prerequisites, R), and is the recommended way to run uvl2dimacs on **Windows** (tested on Windows 11 with Docker Desktop and WSL2).

### Build the image

From the project root:

```bash
docker build -t uvl2dimacs .
```

### Run the container

The container is isolated from the host filesystem. To read input files or write output files on the host, a directory must be shared with the container using a **volume mount**: `-v <host-dir>:<container-dir>`. This makes `<host-dir>` visible inside the container at `<container-dir>`. The flag `--rm` removes the container automatically after it exits.

**Convert a bundled test model:**

The 1,533 test models ship inside the image (under `tests/straightforward/uvl/`), so only an output directory needs to be mounted. In this example the host directory `~/results/` is mounted at `/data` inside the container. The converted file is written to `/data/automotive01.dimacs` inside the container, which corresponds to `~/results/automotive01.dimacs` on the host:

```bash
mkdir -p ~/results
docker run --rm -v ~/results:/data uvl2dimacs \
    tests/straightforward/uvl/automotive01.uvl /data/automotive01.dimacs
# Result on host: ~/results/automotive01.dimacs
```

**Convert your own UVL file:**

Suppose your UVL file is at `/home/ruben/models/my_model.uvl`. Mount `/home/ruben/models/` at `/data` so the container can read the input and write the output back to the same host directory:

```bash
docker run --rm -v /home/ruben/models:/data uvl2dimacs \
    /data/my_model.uvl /data/my_model.dimacs
# Result on host: /home/ruben/models/my_model.dimacs
```

On **Windows** (PowerShell), use the Windows path syntax:

```powershell
docker run --rm -v C:\Users\ruben\models:/data uvl2dimacs `
    /data/my_model.uvl /data/my_model.dimacs
```

**With backbone simplification or Tseitin mode:**

```bash
# -b: backbone simplification, reduces clause count and size
docker run --rm -v /home/ruben/models:/data uvl2dimacs \
    -b /data/my_model.uvl /data/my_model.dimacs

# -t: Tseitin transformation, avoids exponential clause growth for complex constraints
docker run --rm -v /home/ruben/models:/data uvl2dimacs \
    -t /data/my_model.uvl /data/my_model.dimacs
```

### Run the test suites and reproduce the experiments

All test scripts and the 1,533 bundled models are pre-installed inside the image, so no volume mount is needed to run the tests. The easiest approach is to open an interactive shell inside the container with the `-it` flags (`-i` keeps stdin open, `-t` allocates a terminal). Because the image declares an `ENTRYPOINT` (the `uvl2dimacs` binary), you must override it with `--entrypoint bash` to get a shell instead of passing `bash` as an argument to the translator:

```bash
docker run --rm -it --entrypoint bash uvl2dimacs
```

You are now inside the container and can run any command from the [Testing](#testing) section exactly as written. For example:

```bash
# Straightforward conversion regression (fast, ~seconds)
bash tests/straightforward/test_straightforward.sh

# Backbone simplification verification (~109 min for all 1,533 models)
bash tests/backbone/test_backbone.sh

# Tseitin transformation verification (run backbone first to build SharpSAT-TD)
bash tests/tseitin/test_tseitin.sh

# Reproduce the paper's clause-reduction statistics
bash tests/nclauses/compare_clause_number.sh
Rscript tests/nclauses/analyze_clause_number.R
```

To copy the statistics CSV to your host machine, mount an output directory before entering the shell:

```bash
docker run --rm -it -v ~/results:/results --entrypoint bash uvl2dimacs
# Inside the container:
bash tests/nclauses/compare_clause_number.sh
Rscript tests/nclauses/analyze_clause_number.R
cp tests/nclauses/results.csv /results/
# results.csv is now available at ~/results/results.csv on the host
```

Type `exit` to leave the container shell. The `--rm` flag ensures the container is deleted automatically when you exit.

## Basic Usage

```bash
# Convert UVL to DIMACS
./build/uvl2dimacs input.uvl output.dimacs

# With backbone simplification (reduces formula size)
./build/uvl2dimacs -b input.uvl output.dimacs

# Tseitin transformation
./build/uvl2dimacs -t input.uvl output.dimacs
```

1,533 ready-to-use UVL models are available in `tests/straightforward/uvl/` and can be used directly as inputs. For example:

```bash
./build/uvl2dimacs tests/straightforward/uvl/automotive01.uvl output.dimacs
```

## CLI Options

```
Usage: uvl2dimacs [-t|-s] [-b] <input.uvl> <output.dimacs>

Options:
  -s    Use straightforward conversion (default)
  -t    Use Tseitin transformation with auxiliary variables
  -b    Apply backbone simplification to reduce formula size
```

## API Usage

### Basic Conversion

```cpp
#include <uvl2dimacs/UVL2Dimacs.hh>

uvl2dimacs::UVL2Dimacs converter;
auto result = converter.convert("model.uvl", "output.dimacs");

if (result.success) {
    std::cout << "Features: " << result.num_features << std::endl;
    std::cout << "Variables: " << result.num_variables << std::endl;
    std::cout << "Clauses: " << result.num_clauses << std::endl;
}
```

### Tseitin Mode

```cpp
uvl2dimacs::UVL2Dimacs converter;
converter.set_mode(uvl2dimacs::ConversionMode::TSEITIN);
auto result = converter.convert("model.uvl", "output.dimacs");

int aux_variables = result.num_variables - result.num_features;
std::cout << "Auxiliary variables: " << aux_variables << std::endl;
```

### With Backbone Simplification

```cpp
uvl2dimacs::UVL2Dimacs converter;
converter.set_mode(uvl2dimacs::ConversionMode::STRAIGHTFORWARD);
converter.set_backbone_simplification(true);
converter.set_verbose(true);

auto result = converter.convert("model.uvl", "output.dimacs");
```

### Complete Examples

See [`api/examples/`](api/examples/) for detailed usage:
- [`simple_convert.cc`](api/examples/simple_convert.cc) - Basic conversion with both modes and backbone simplification
- [`tseitin_convert.cc`](api/examples/tseitin_convert.cc) - Dedicated Tseitin example
- [`batch_convert.cc`](api/examples/batch_convert.cc) - Batch processing with mode comparison and performance metrics
- [`backbone_convert.cc`](api/examples/backbone_convert.cc) - Converts a model with and without backbone simplification and prints a side-by-side reduction summary

## Conversion Modes

UVL2Dimacs supports two CNF transformation strategies, each optimized for different use cases.

### Straightforward Mode (Default, `-s`)

Direct CNF conversion with 1 variable per feature.

- Fewer variables, compact representation
- Best for most models
- May produce longer clauses for complex constraints

**When to use**: General-purpose variability models, when minimizing variable count is important, and models with simple Boolean constraints.

### Tseitin Mode (`-t`)

Auxiliary variables for cross-tree constraint expressions; feature tree relations are emitted directly.

- Prevents exponential clause growth in nested Boolean cross-tree constraints
- Fewer auxiliary variables (only introduced where needed)
- Feature tree relation clauses (OR groups, ALTERNATIVE groups, cardinality) emitted directly as CNF

**When to use**: Models with deeply nested Boolean cross-tree constraint expressions.

### Comparison

| Aspect | Straightforward | Tseitin |
|--------|----------------|---------|
| **Variables** | Fewer (n features) | More (n + auxiliaries for cross-tree constraints) |
| **Feature tree relation clauses** | Direct (arbitrary length) | Direct (arbitrary length) |
| **Cross-tree constraint clauses** | May grow exponentially | Linear size |
| **Best for** | General use | Deeply nested cross-tree constraints |

**Both modes preserve solution counts** (verified by test suite).

See [docs/translation.md](docs/translation.md) for detailed transformation rules, Tseitin encoding, and comprehensive examples.

## Backbone Simplification

Optional optimization that reduces CNF formula size by 30-50% while preserving solution counts.

**Quick example:**
- Input: 17 variables, 39 clauses
- Output: 17 variables, 18 clauses (54% reduction)
- Solution count: Preserved (verified)

See [docs/translation.md § Backbone Simplification](docs/translation.md#backbone-simplification) for algorithm details, proof of correctness, performance characteristics, and variability model applications (core/dead feature detection).

## Testing

UVL2Dimacs includes comprehensive verification suites with **1,533 real-world pure Boolean UVL models** from [uvlhub.io](https://www.uvlhub.io/), located in `tests/straightforward/`.

### Test Model Collection

**Coverage**:
- Model sizes: 4 to 500+ features
- Relation types: MANDATORY, OPTIONAL, OR, ALTERNATIVE, CARDINALITY
- Real-world domains: automotive, software product lines, embedded systems

### Straightforward Conversion Verification

Verifies that the straightforward converter produces the expected DIMACS output:

```bash
bash tests/straightforward/test_straightforward.sh
```

**Method**: Runs `uvl2dimacs -s` on all 1,533 UVL models and compares generated DIMACS files against reference files, ignoring comment lines.

**Expected**: All tests PASS with identical CNF content.

### Prerequisites for Solution-Counting Tests

The Backbone and Tseitin test suites internally use [SharpSAT-TD](https://github.com/Laakeri/sharpsat-td) for exact #SAT counting.

**Install GMP, MPFR, and CMake:**

- Ubuntu/Debian: `sudo apt-get install libgmp-dev libmpfr-dev cmake`
- Fedora/RHEL: `sudo dnf install gmp-devel mpfr-devel cmake`
- macOS: `brew install gmp mpfr cmake`

**Note**: The backbone test scripts automatically build SharpSAT-TD from source for the current platform and provide OS-specific installation instructions if dependencies are missing.

### Backbone Simplification Verification

Verifies that backbone simplification preserves exact solution counts:

```bash
# Test all 1,533 models (default)
bash tests/backbone/test_backbone.sh

# Test a specific number of models
bash tests/backbone/test_backbone.sh 50
```

**Method**: Generates DIMACS with/without backbone, counts solutions with SharpSAT-TD, verifies equality.

**Expected**: All tests PASS with identical solution counts.

**Approximate runtime**: approximately 109 minutes for all 1,533 models on a modern laptop (Intel Core Ultra 7 155H). The dominant cost is running SharpSAT-TD twice per model (once on the original DIMACS and once on the backbone-simplified DIMACS); the `uvl2dimacs` conversion itself takes only a few milliseconds. Progress is printed as `[N/1533] Testing <model> ...` so you can monitor how far the suite has advanced. To get a quick sanity check without waiting for the full run, pass a small number: `bash tests/backbone/test_backbone.sh 20`.

> **Note**: This script automatically builds SharpSAT-TD from source into `tests/sharpsat-td/`. **Run the backbone test before the Tseitin test**, because the Tseitin test expects the binary to already be present.

### Tseitin Transformation Verification

Verifies that the Tseitin transformation preserves exact solution counts.

> **Prerequisite**: Run `bash tests/backbone/test_backbone.sh` first to build SharpSAT-TD.

```bash
# Test all 1,533 models (default)
bash tests/tseitin/test_tseitin.sh

# Test a specific number of models
bash tests/tseitin/test_tseitin.sh 100
```

**Method**: Generates DIMACS in both straightforward and Tseitin modes, counts solutions, and verifies equality.

**Expected**: All tests PASS with identical counts, confirming full biconditional equivalences (⟺).

**Approximate runtime**: approximately 108 minutes for all 1,533 models on a modern laptop (Intel Core Ultra 7 155H). As with the backbone suite, the dominant cost is SharpSAT-TD, which is invoked twice per model (straightforward and Tseitin DIMACS); progress is shown as `[N/1533]`. Pass a numeric argument to test a subset: `bash tests/tseitin/test_tseitin.sh 20`.

### Reproducing the Paper's Clause-Reduction Statistics

The paper reports that backbone simplification reduces the clause count in 99.09% of models (median reduction 40.43%), and that the Tseitin transformation reduces the clause count in 0.65% of models (median reduction 83.11% in those cases). To reproduce these numbers:

**Prerequisites**: the tool must be built (`make`) and R must be installed.

- Ubuntu/Debian: `sudo apt-get install r-base`
- Fedora/RHEL: `sudo dnf install R`
- macOS: `brew install r`

```bash
# Step 1: run all four conversion modes on every model and record clause counts
bash tests/nclauses/compare_clause_number.sh
# Output: tests/nclauses/results.csv

# Step 2: compute and print the statistics from the CSV
Rscript tests/nclauses/analyze_clause_number.R
```

**Approximate runtime**: approximately 7 minutes for all 1,533 models on a modern laptop (Intel Core Ultra 7 155H); this suite calls only `uvl2dimacs` and does not require SharpSAT-TD.

`compare_clause_number.sh` runs all four conversion modes on each of the 1,533 models and writes one row per model to `tests/nclauses/results.csv`. `analyze_clause_number.R` reads that CSV and prints the summary statistics.

## UVL Grammar Support

### Feature Types
- **Mandatory**: Child must be selected if parent is selected
- **Optional**: Child may be selected when parent is selected

### Group Types
- **Or**: At least one child must be selected
- **Alternative**: Exactly one child must be selected
- **Group cardinality [n..m]**: Between n and m children of the group must be selected
  (see the [official UVL documentation](https://universal-variability-language.github.io/#language-levels) for details).
  Example: 0 to 2 of {Cheddar, Gouda, Goat} may be selected (see `[0..2]` under `Cheese`):
  ```
  include
      Boolean.group-cardinality
      Arithmetic.aggregate-function
      Arithmetic.feature-cardinality
      Type

  features
      Sandwich
          mandatory
              Bread {Calories 100, Sugar 20}
          optional
              Sauce
                  or
                      Ketchup {Calories 40, Sugar 35}
                      Mustard {Calories 25, Sugar 5}
              Cheese
                  [0..2] // Group cardinality
                      Cheddar {Calories 60}
                      Gouda {Calories 50}
                      Goat {Calories 35}
              Pickle cardinality [1..3] // Feature cardinality

  constraints
      Ketchup => Cheese
      Bread.Sugar + Ketchup.Sugar + Mustard.Sugar < 60
      sum(Calories) < 160
  ```

  > **Feature cardinality vs. group cardinality.** Do not confuse the `[0..2]`
  > *group* cardinality on `Cheese` (above, fully supported) with the
  > `cardinality [1..3]` annotation on `Pickle`. The latter is *feature*
  > cardinality: it marks `Pickle` as a multi-instance feature that may be
  > instantiated between one and three times. Multi-instance features need
  > numeric variables to represent the instantiation count and cannot be
  > expressed in pure propositional logic, so uvl2dimacs does **not** support
  > them — it warns, ignores the annotation, and treats the feature as a single
  > Boolean feature. See [Limitations](#limitations) for details.

### Constraints
- Boolean operators: `&` (AND), `|` (OR), `!` (NOT)
- Implications: `=>` (IMPLIES), `<=>` (IFF)
- Shortcuts: `requires`, `excludes`

**Example UVL Model:**
```
features
    car
        mandatory
            engine
        optional
            gps
        alternative
            gasoline
            electric

constraints
    electric => gps
```

## Output Format

DIMACS CNF format with feature mappings:

```
c Generated by UVL2Dimacs
c Original features: 5
c Auxiliary variables: 0
c Total variables: 5
p cnf 5 9
c 1 car
c 2 engine
c 3 gps
c 4 gasoline
c 5 electric
1 0
-1 2 0
-2 1 0
-3 1 0
-1 4 5 0
-4 -5 0
-4 1 0
-5 1 0
-5 3 0
```

Each clause is a space-separated list of literals (positive/negative integers) terminated by `0`.

## Performance

The build uses aggressive optimization:
- `-O3` (maximum optimization)
- Architecture-specific tuning (`-march=native` on Xeon, `-march=x86-64-v2` on generic x86-64, `-march=armv8-a` on ARM64)
- `-flto` (link-time optimization)
- `CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON`

**Typical performance:**
- Small models (<100 features): <10ms
- Medium models (100-500 features): 10-100ms
- Large models (500+ features): 100-1000ms
- Backbone simplification adds 50-200ms depending on model size

## API Documentation

Generate full API documentation with Doxygen:

```bash
make docs
xdg-open docs/html/index.html   # Linux
open docs/html/index.html        # macOS
```

## Project Structure

```
uvl2dimacs/
├── api/                   # High-level API
│   ├── include/           # Public API headers
│   ├── src/               # API implementation
│   └── examples/          # Usage examples
├── cli/                   # Command-line interface
├── generator/             # Core CNF generation
│   ├── include/           # Variability model and CNF classes
│   └── src/               # Transformation implementation
├── parser/                # ANTLR-generated UVL parser
│   ├── include/           # Parser/lexer headers
│   └── src/               # Generated ANTLR4 source files
├── backbone_solver/       # Backbone computation tool
│   ├── bin/               # Compiled backbone_solver binary
│   ├── docs/              # Backbone algorithm documentation
│   └── src/               # Source (api, cli, data_structures, detectors, io, minisat, minisat_interface)
├── tests/                 # Test suites
│   ├── sharpsat-td/       # Model counter (shared)
│   ├── backbone/          # Backbone verification tests
│   ├── tseitin/           # Tseitin verification tests (includes dimacs/ reference files)
│   └── straightforward/   # 1,533 test models (UVL + DIMACS)
├── antlr/                 # ANTLR4 C++ runtime
├── docs/                  # Documentation
└── build/                 # Build output
```

## Limitations

- **Boolean language level only**: uvl2dimacs targets the Boolean language level of UVL (propositional feature hierarchies and Boolean cross-tree constraints). Constraints outside this scope are skipped with a warning to stderr; two cases are distinguished:
  - *Arithmetic or non-Boolean operators* (numeric comparisons, equality, etc.): the tool prints a summary warning `Warning: N constraint(s) contain arithmetic or non-Boolean operators … and were skipped.`
  - *Unsupported constructs or undefined feature references* (aggregate functions such as `len`/`sum`, attribute-access expressions such as `Feature.attr`, or features brought in by a UVL `imports` declaration): the tool prints a per-constraint warning naming the exact constraint that could not be processed.

  The total number of skipped constraints is available programmatically via `ConversionResult::num_skipped_constraints`. A model that exercises both warning types is published at <https://www.uvlhub.io/doi/10.5281/zenodo.17308577/>.

  Although these constructs are skipped, the resulting Boolean translation remains *sound*. Dropping the non-Boolean constraints only relaxes the formula, so its set of valid configurations is a *superset* of the complete model's. Every property that the partial translation entails therefore also holds in the complete model: for example, a feature reported as *dead* or *core* on the Boolean projection stays dead or core once the omitted constraints are added back, because additional constraints can only shrink the configuration space, never enlarge it. This is why uvl2dimacs converts the Boolean portion (and warns) instead of rejecting the whole model.

- **No import resolution**: UVL `imports` declarations are parsed but the referenced models are not loaded. Features from imported namespaces are unknown to the converter; any constraint that references them is skipped with a warning (see above).

- **Feature cardinality not expanded**: UVL allows annotating individual features with the `cardinality [n..m]` keyword to mark them as *multi-instance* features, meaning the feature can be instantiated multiple times (see the [official UVL documentation](https://universal-variability-language.github.io/#language-levels) for details). In the example above (see [Group Types](#group-types)), `Pickle cardinality [1..3]` declares `Pickle` as a multi-instance feature that may be instantiated one to three times. Note that this is distinct from *group cardinality* (the `[n..m]` group type), which restricts how many children of a group are selected and is fully supported. Multi-instance features require numeric variables to represent the instantiation count and cannot be encoded in pure propositional logic. The parser recognises this syntax; uvl2dimacs emits a warning to stderr (naming the feature and its declared cardinality), ignores the annotation, and treats the feature as a single Boolean feature.

## Authors

- Rubén Heradio (rheradio@issi.uned.es)
- David Fernández Amorós (david@issi.uned.es)
- Ismael Abad Cardiel (iabad@issi.uned.es)
- Ernesto Aranda-Escolástico (earandae@issi.uned.es)

## License

MIT License - see [LICENSE](LICENSE) file for details

## Related Tools

- [UVL Hub](https://www.uvlhub.io/) - Repository of UVL variability models
- [UVL Specification](https://universal-variability-language.github.io/#language-levels) - Official UVL documentation
- [SharpSAT-TD](https://github.com/Laakeri/sharpsat-td) - Tree decomposition-based #SAT solver

---

**UVL2Dimacs** - Bridging variability modeling and SAT solving.
