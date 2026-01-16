# UVL2Dimacs

A high-performance C++ library and CLI tool for converting Universal Variability Language (UVL) feature models to DIMACS CNF format for SAT solver analysis.

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![C++17](https://img.shields.io/badge/C%2B%2B-17-blue)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## ✨ Features

- 📝 **UVL Parser**: Full support for UVL 2.0 feature model syntax
- 🔄 **Dual Conversion Modes**:
  - **Straightforward** (direct CNF, fewer variables, compact)
  - **Tseitin** (guaranteed 3-CNF with ≤3 literals per clause, uses auxiliary variables)
- 🎯 **Backbone Simplification**: 30-50% formula size reduction while preserving solution counts
- ⚡ **High Performance**: Optimized with -O3, LTO, and native CPU tuning
- 📚 **Library API**: Clean C++ API for integration into other tools
- ✅ **Comprehensive Testing**: 1,533 test models with automated solution count verification

## 🚀 Quick Start

### 🔨 Build

```bash
# Build everything
make

# Build specific targets
make uvl2dimacs        # CLI tool
make api               # API library
make examples          # API examples
```

**Requirements:**
- C++17 compiler (g++ or clang++)
- CMake 3.10+
- GNU Make

### 💻 Basic Usage

```bash
# Convert UVL to DIMACS
./build/uvl2dimacs input.uvl output.dimacs

# With backbone simplification (reduces formula size)
./build/uvl2dimacs -b input.uvl output.dimacs

# Tseitin transformation
./build/uvl2dimacs -t input.uvl output.dimacs
```

## ⚙️ CLI Options

```
Usage: uvl2dimacs [-t|-s] [-b] <input.uvl> <output.dimacs>

Options:
  -s    Use straightforward conversion (default)
  -t    Use Tseitin transformation with auxiliary variables
  -b    Apply backbone simplification to reduce formula size

Examples:
  uvl2dimacs model.uvl output.dimacs              # Basic conversion
  uvl2dimacs -b model.uvl output.dimacs           # With backbone
  uvl2dimacs -t -b model.uvl output.dimacs        # Tseitin + backbone
```

## 🔧 API Usage

### 📦 Basic Conversion

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

### 🔀 Tseitin Mode (3-CNF Guarantee)

```cpp
uvl2dimacs::UVL2Dimacs converter;
converter.set_mode(uvl2dimacs::ConversionMode::TSEITIN);  // Use Tseitin transformation
auto result = converter.convert("model.uvl", "output.dimacs");

// Result will have all clauses with ≤3 literals
// May introduce auxiliary variables for complex expressions
int aux_variables = result.num_variables - result.num_features;
std::cout << "Auxiliary variables: " << aux_variables << std::endl;
```

### 🎯 With Backbone Simplification

```cpp
uvl2dimacs::UVL2Dimacs converter;
converter.set_mode(uvl2dimacs::ConversionMode::STRAIGHTFORWARD);
converter.set_backbone_simplification(true);  // Enable backbone
converter.set_verbose(true);

auto result = converter.convert("model.uvl", "output.dimacs");
```

### 📚 Complete Examples

See [`api/examples/`](api/examples/) for detailed usage:
- 📄 **[`simple_convert.cc`](api/examples/simple_convert.cc)** - Basic conversion with both modes and backbone simplification
- 🔀 **[`tseitin_convert.cc`](api/examples/tseitin_convert.cc)** - Dedicated Tseitin example with 3-CNF verification
- 📂 **[`batch_convert.cc`](api/examples/batch_convert.cc)** - Batch processing with mode comparison and performance metrics

## 🔄 Conversion Modes

UVL2Dimacs supports two CNF transformation strategies, each optimized for different use cases.

### 📊 Straightforward Mode (Default, `-s`)

Direct CNF conversion with 1 variable per feature.

- ✅ Fewer variables, compact representation
- ✅ Best for most models
- ⚠️ May produce longer clauses for complex constraints

**When to use**: General purpose feature models, when minimizing variable count is important, models with simple Boolean constraints.

### 🔀 Tseitin Mode (`-t`)

3-CNF guarantee using auxiliary variables and tree decomposition.

- ✅ All clauses have ≤3 literals (3-CNF)
- ✅ Optimized for modern SAT solvers
- ✅ Prevents exponential clause growth in nested formulas
- ⚠️ More variables and clauses

**When to use**: SAT solvers optimized for 3-CNF, models with deeply nested Boolean expressions, large OR/ALTERNATIVE groups (>5 children).

### Comparison

| Aspect | Straightforward | Tseitin |
|--------|----------------|---------|
| **Variables** | Fewer (n features) | More (n + auxiliaries) |
| **Max clause size** | Unlimited | **≤3 literals** |
| **Best for** | Simple models | 3-CNF requirement, complex formulas |

**Both modes preserve solution counts** (verified by test suite).

See [docs/translation.md](docs/translation.md) for detailed transformation rules, tree decomposition algorithm, and comprehensive examples.

## 🎯 Backbone Simplification

Optional optimization that reduces CNF formula size by 30-50% while preserving solution counts.

**Quick example:**
- Input: 17 variables, 39 clauses
- Output: 17 variables, 18 clauses (54% reduction)
- Solution count: Preserved (verified)

**Works with both modes** (straightforward and Tseitin).

See [docs/translation.md § Backbone Simplification](docs/translation.md#backbone-simplification) for algorithm details, proof of correctness, performance characteristics, and feature model applications (core/dead feature detection).

## 🧪 Testing

UVL2Dimacs includes comprehensive verification suites with **1,533 real-world UVL models** from [uvlhub.io](https://www.uvlhub.io/).

### Prerequisites: SharpSAT-TD Model Counter

Both test suites require [SharpSAT-TD](https://github.com/Laakeri/sharpsat-td) for exact #SAT counting:

```bash
cd tests
git clone https://github.com/Laakeri/sharpsat-td.git
cd sharpsat-td && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release .. && make -j$(nproc)
```

**Dependencies**: GMP and MPFR libraries
- Ubuntu/Debian: `sudo apt-get install libgmp-dev libmpfr-dev`
- macOS: `brew install gmp mpfr`

**Note**: Test scripts automatically detect missing dependencies and provide OS-specific installation instructions.

### ✅ Backbone Simplification Verification

Verifies that backbone simplification preserves exact solution counts:

```bash
# Test 20 models (default)
bash tests/backbone/test_backbone.sh

# Test more models
bash tests/backbone/test_backbone.sh 50
```

**Method**: Generates DIMACS with/without backbone, counts solutions with SharpSAT-TD, verifies equality.

**Expected**: All tests PASS with identical solution counts.

### ✅ Tseitin Transformation Verification

Verifies that Tseitin 3-CNF transformation preserves exact solution counts:

```bash
# Test 20 models (default)
bash tests/tseitin/test_tseitin.sh

# Test specific number
bash tests/tseitin/test_tseitin.sh 100
```

**Method**: Generates DIMACS in both straightforward and Tseitin modes, counts solutions, verifies equality.

**Expected**: All tests PASS with identical counts, confirming full biconditional equivalences (⟺).

### 📊 Test Model Collection

**Location**: `tests/straightforward/` contains 1,533 pure Boolean UVL models

**Coverage**:
- Model sizes: 4 to 500+ features
- Relation types: MANDATORY, OPTIONAL, OR, ALTERNATIVE, CARDINALITY
- Real-world domains: automotive, software product lines, embedded systems

**Note**: Arithmetic constraints filtered out (pure Boolean models only).

## 📖 UVL Grammar Support

### 🌳 Feature Types
- ✔️ **Mandatory**: Child must be selected if parent is selected
- ⭕ **Optional**: Child may be selected when parent is selected

### 👥 Group Types
- 🔀 **Or**: At least one child must be selected
- ⚡ **Alternative**: Exactly one child must be selected
- 🔢 **Cardinality [n..m]**: Between n and m children must be selected

### 🔗 Constraints
- Boolean operators: `&` (AND), `|` (OR), `!` (NOT)
- Implications: `=>` (IMPLIES), `<=>` (IFF)
- Shortcuts: `requires`, `excludes`

**Example UVL Model:**
```
features
    Car
        mandatory
            Engine
        optional
            GPS
        alternative
            Gasoline
            Electric

constraints
    Electric => GPS
```

## 📄 Output Format

DIMACS CNF format with feature mappings:

```
c Generated by UVL2Dimacs
c Feature mapping:
c 1 Car
c 2 Engine
c 3 GPS
c 4 Gasoline
c 5 Electric
p cnf 5 8
1 0
-1 2 0
-2 1 0
-1 4 5 0
-4 -5 0
-4 1 0
-5 1 0
-5 3 0
```

Each clause is a space-separated list of literals (positive/negative integers) terminated by `0`.

## ⚡ Performance

The build uses aggressive optimization:
- 🚀 `-O3` (maximum optimization)
- 💻 `-march=native -mtune=native` (CPU-specific tuning)
- 🔗 `-flto` (link-time optimization)
- ⚙️ `CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON`

**Typical performance:**
- 🟢 Small models (<100 features): <10ms
- 🟡 Medium models (100-500 features): 10-100ms
- 🟠 Large models (500+ features): 100-1000ms
- 🎯 Backbone simplification adds 50-200ms depending on model size

## 📘 API Documentation

Generate full API documentation with Doxygen:

```bash
make docs
open docs/html/index.html
```

**What's included:**
- Complete API reference for all classes
- Usage examples and code snippets
- Implementation details
- UVL grammar overview

## 📁 Project Structure

```
uvl2dimacs/
├── 📚 api/                   # High-level API
│   ├── include/              # Public API headers
│   ├── src/                  # API implementation
│   └── examples/             # Usage examples
├── 💻 cli/                   # Command-line interface
├── ⚙️ generator/             # Core CNF generation
│   ├── include/              # Feature model and CNF classes
│   └── src/                  # Transformation implementation
├── 📝 parser/                # ANTLR-generated UVL parser
├── 🎯 backbone_solver/       # Backbone computation tool
├── 🧪 tests/                 # Test suites
│   ├── sharpsat-td/          # Model counter (shared)
│   ├── backbone/             # Backbone verification tests
│   ├── tseitin/              # Tseitin verification tests
│   └── straightforward/      # 1,533 test models (UVL + DIMACS)
├── 📦 third_party/           # ANTLR4 C++ runtime
├── 📖 docs/                  # Documentation
└── 🔨 build/                 # Build output
```

## ⚠️ Limitations

⚠️ Only Boolean feature models supported (arithmetic constraints require SMT, not SAT)

## 🤝 Contributing

This project is part of academic research. For bug reports or feature requests, please contact the authors.

## 👥 Authors

- 👨‍🎓 Rubén Heradio (rheradio@issi.uned.es)
- 👨‍🎓 David Fernández Amorós (david@issi.uned.es)
- 👨‍🎓 Ismael Abad Cardiel (iabad@issi.uned.es)
- 👨‍🎓 Ernesto Aranda-Escolástico (earandae@issi.uned.es)
## 📜 License

MIT License - see [LICENSE](LICENSE) file for details


## 🔗 Related Tools

- 🌐 [UVL Hub](https://www.uvlhub.io/) - Repository of UVL feature models
- 📘 [UVL Specification](https://universal-variability-language.github.io/) - Official UVL documentation
- 🔬 [SharpSAT-TD](https://github.com/Laakeri/sharpsat-td) - Tree decomposition-based #SAT solver

## 📋 Changelog

### Current Version
- ✅ Full UVL 2.0 support
- ✅ Dual conversion modes (Straightforward/Tseitin)
- ✅ Backbone simplification
- ✅ Comprehensive test suite (1000+ models)
- ✅ High-performance optimizations
- ✅ Clean API for library integration

---

**UVL2Dimacs** - Bridging feature modeling and SAT solving.
