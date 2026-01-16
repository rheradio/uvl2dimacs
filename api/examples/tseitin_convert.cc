/**
 * @file tseitin_convert.cc
 * @brief Example demonstrating Tseitin transformation with 3-CNF guarantee
 *
 * This example shows how to use Tseitin mode to convert UVL feature models
 * to 3-CNF (all clauses have at most 3 literals). This is particularly useful
 * for SAT solvers optimized for 3-CNF formulas.
 */

#include "uvl2dimacs/UVL2Dimacs.hh"
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>

/**
 * @brief Verifies that a DIMACS file contains only 3-CNF clauses
 * @param dimacs_file Path to DIMACS file
 * @return true if all clauses have ≤3 literals, false otherwise
 */
bool verify_3cnf(const std::string& dimacs_file) {
    std::ifstream file(dimacs_file);
    if (!file.is_open()) {
        std::cerr << "Error: Cannot open file " << dimacs_file << std::endl;
        return false;
    }

    std::string line;
    int max_literals = 0;
    int total_clauses = 0;

    while (std::getline(file, line)) {
        // Skip comments and header
        if (line.empty() || line[0] == 'c' || line[0] == 'p') {
            continue;
        }

        // Count literals in this clause (space-separated numbers, ends with 0)
        std::istringstream iss(line);
        int literal;
        int count = 0;

        while (iss >> literal) {
            if (literal == 0) {
                break;  // End of clause
            }
            count++;
        }

        if (count > max_literals) {
            max_literals = count;
        }
        total_clauses++;
    }

    file.close();

    std::cout << "  3-CNF Verification:" << std::endl;
    std::cout << "    - Total clauses: " << total_clauses << std::endl;
    std::cout << "    - Max literals per clause: " << max_literals << std::endl;
    std::cout << "    - Is 3-CNF: " << (max_literals <= 3 ? "YES ✓" : "NO ✗") << std::endl;

    return max_literals <= 3;
}

int main(int argc, char* argv[]) {
    if (argc < 3 || argc > 4) {
        std::cerr << "Usage: " << argv[0] << " [-b] <input.uvl> <output.dimacs>" << std::endl;
        std::cerr << std::endl;
        std::cerr << "Converts UVL feature model to 3-CNF DIMACS using Tseitin transformation." << std::endl;
        std::cerr << "Guarantees that all clauses have at most 3 literals." << std::endl;
        std::cerr << std::endl;
        std::cerr << "Options:" << std::endl;
        std::cerr << "  -b    Apply backbone simplification (preserves 3-CNF property)" << std::endl;
        std::cerr << std::endl;
        std::cerr << "Examples:" << std::endl;
        std::cerr << "  " << argv[0] << " model.uvl model_3cnf.dimacs" << std::endl;
        std::cerr << "  " << argv[0] << " -b model.uvl model_3cnf_simplified.dimacs" << std::endl;
        return 1;
    }

    bool use_backbone = false;
    int arg_index = 1;

    // Parse -b flag
    if (argc == 4 && std::string(argv[1]) == "-b") {
        use_backbone = true;
        arg_index = 2;
    }

    std::string input_file = argv[arg_index];
    std::string output_file = argv[arg_index + 1];

    // Display header
    std::cout << "╔══════════════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║         UVL2Dimacs - Tseitin Transformation Example         ║" << std::endl;
    std::cout << "╚══════════════════════════════════════════════════════════════╝" << std::endl;
    std::cout << std::endl;
    std::cout << "Input:  " << input_file << std::endl;
    std::cout << "Output: " << output_file << std::endl;
    std::cout << "Mode:   Tseitin (3-CNF guarantee)" << std::endl;
    if (use_backbone) {
        std::cout << "Backbone simplification: ENABLED" << std::endl;
    }
    std::cout << std::endl;
    std::cout << "Converting..." << std::endl;
    std::cout << std::string(60, '-') << std::endl;

    // Create converter and configure for Tseitin mode
    uvl2dimacs::UVL2Dimacs converter;
    converter.set_verbose(true);
    converter.set_mode(uvl2dimacs::ConversionMode::TSEITIN);  // Use Tseitin transformation

    if (use_backbone) {
        converter.set_backbone_simplification(true);
    }

    // Perform conversion
    auto result = converter.convert(input_file, output_file);

    std::cout << std::string(60, '-') << std::endl;

    // Check result
    if (result.success) {
        std::cout << std::endl;
        std::cout << "✓ Conversion successful!" << std::endl;
        std::cout << std::endl;
        std::cout << "Statistics:" << std::endl;
        std::cout << "  Input Feature Model:" << std::endl;
        std::cout << "    - Features:    " << result.num_features << std::endl;
        std::cout << "    - Relations:   " << result.num_relations << std::endl;
        std::cout << "    - Constraints: " << result.num_constraints << std::endl;
        std::cout << std::endl;
        std::cout << "  Output CNF Formula:" << std::endl;
        std::cout << "    - Variables:   " << result.num_variables << std::endl;

        // Highlight auxiliary variables if any were introduced
        int aux_variables = result.num_variables - result.num_features;
        if (aux_variables > 0) {
            std::cout << "      * Features:     " << result.num_features << std::endl;
            std::cout << "      * Auxiliary:    " << aux_variables << " (for 3-CNF guarantee)" << std::endl;
        }

        std::cout << "    - Clauses:     " << result.num_clauses << std::endl;
        std::cout << std::endl;

        // Verify 3-CNF property
        verify_3cnf(output_file);

        std::cout << std::endl;
        std::cout << "About Tseitin Transformation:" << std::endl;
        std::cout << "  • Introduces auxiliary variables for complex expressions" << std::endl;
        std::cout << "  • Guarantees 3-CNF: all clauses have ≤3 literals" << std::endl;
        std::cout << "  • Uses tree decomposition for n-ary OR/ALTERNATIVE groups" << std::endl;
        std::cout << "  • Optimal for SAT solvers optimized for uniform clause size" << std::endl;
        std::cout << "  • Prevents exponential clause explosion in complex formulas" << std::endl;

        return 0;
    } else {
        std::cerr << std::endl;
        std::cerr << "✗ Conversion failed!" << std::endl;
        std::cerr << "Error: " << result.error_message << std::endl;
        return 1;
    }
}
