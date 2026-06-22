# BoneDigger API

A simple C++ API for computing backbones of Boolean formulas in DIMACS CNF format.

## Table of Contents

1. [Overview](#overview)
2. [API Functions](#api-functions)
   - a. [read_dimacs](#1-bool-read_dimacsconst-string-file_name)
   - b. [create_backbone_detector](#2-bool-create_backbone_detectorconst-string-bb_detector--simple)
   - c. [compute_backbone](#3-vectorint-compute_backbone)
   - d. [get_max_variable](#4-int-get_max_variable-const)
   - e. [is_satisfiable](#5-bool-is_satisfiable-const)
   - f. [print_backbone](#6-void-print_backbone-const)
3. [Usage Example](#usage-example)
4. [Building with the API](#building-with-the-api)
5. [Notes](#notes)

## Overview

The BoneDigger API provides a clean interface to read DIMACS files, create backbone detectors, and compute backbones of Boolean formulas.

## API Functions

### 1. `bool read_dimacs(const string& file_name)`

Reads a DIMACS CNF file.

- **Parameters**:
  - `file_name`: Path to the DIMACS file
- **Returns**:
  - `true` if the file is valid and successfully read
  - `false` otherwise

### 2. `bool create_backbone_detector(const string& bb_detector = "rush")`

Creates a backbone detector for the last read DIMACS file.

- **Parameters**:
  - `bb_detector`: Type of detector to create
    - `"rush"` - RushAndPray (default, fast detection algorithm)
    - `"one"` - CheckCandidatesOneByOne (checks candidates one by one with activity bumping)
    - `"flatland"` - FastOnCliffsSlowOnPlains (advanced with flatland detection)
- **Returns**:
  - `true` if detector is successfully created
  - `false` if no DIMACS file has been read or detector type is invalid

### 3. `vector<int> compute_backbone()`

Computes the backbone of the formula using the created detector.

- **Returns**:
  - A vector of integers representing backbone literals
    - Positive values indicate the variable must be true
    - Negative values indicate the variable must be false
  - Empty vector if no file has been read or no detector has been created

### 4. `int get_max_variable() const`

Returns the maximum variable ID from the last read file.

### 5. `bool is_satisfiable() const`

Returns whether the last computed formula is satisfiable.

### 6. `void print_backbone() const`

Prints the backbone to standard output.

- **Output**:
  - If formula is unsatisfiable: prints "Formula is UNSATISFIABLE"
  - If formula is satisfiable: prints satisfiability status, backbone size, and all backbone literals
  - If no backbone has been computed yet: prints "No backbone computed yet"

## Usage Example

```cpp
#include "api/BoneDiggerAPI.hh"
#include <iostream>
#include <string>

using namespace bonedigger;
using std::cout;
using std::cerr;
using std::endl;
using std::string;

int main(int argc, char** argv) {
  if (argc < 2) {
    cerr << "Usage: " << argv[0] << " <dimacs_file> [rush|one|flatland]" << endl;
    return 1;
  }

  string filename = argv[1];
  string detector_type = (argc >= 3) ? argv[2] : "rush";

  BoneDiggerAPI api;

  cout << "Reading DIMACS file: " << filename << endl;
  if (!api.read_dimacs(filename)) {
    cerr << "Error: Failed to read DIMACS file" << endl;
    return 1;
  }
  cout << "Successfully read file with " << api.get_max_variable() << " variables" << endl;

  cout << "Creating " << detector_type << " backbone detector..." << endl;
  if (!api.create_backbone_detector(detector_type)) {
    cerr << "Error: Failed to create backbone detector" << endl;
    return 1;
  }

  cout << "Computing backbone..." << endl;
  auto backbone = api.compute_backbone();

  cout << "\nBackbone results:" << endl;
  cout << "Backbone size: " << backbone.size() << " literals" << endl;
  
  if (!backbone.empty()) {
    cout << "Backbone literals: ";
    for (size_t i = 0; i < backbone.size(); ++i) {
      cout << backbone[i];
      if (i < backbone.size() - 1) {
        cout << " ";
      }
    }
    cout << endl;
  }
  
  cout << "\nUsing print_backbone() method:" << endl;
  api.print_backbone();

  return 0;
}
```

## Building with the API

To build the example program using the BoneDigger API, run from the `src/` directory:

```bash
make api
```

This will build the `api_example` executable in the `bin/` directory. You can run it with:

```bash
../bin/api_example <dimacs_file> [rush|one|flatland]
```

Or from the project root:

```bash
./bin/api_example <dimacs_file> [rush|one|flatland]
```

## Notes

- The API uses the PIMPL (Pointer to Implementation) pattern for clean separation
- Memory is automatically managed - no manual cleanup required
- The API is thread-safe for separate instances but not for shared instances
- All detector types produce the same correct backbone results but may have different performance characteristics

## Authors

- Ruben Heradio, rheradio@issi.uned.es
- Luis Cambelo, lcambelo1@alumno.uned.es
- Dictino Chaos, dchaos@dia.uned.es
