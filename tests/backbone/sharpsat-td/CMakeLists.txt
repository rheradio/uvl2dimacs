cmake_minimum_required (VERSION 3.5)
project (SHARPSAT) 

option(STATIC "STATIC" OFF)
set(CMAKE_VERBOSE_MAKEFILE on)

if(STATIC)
set(CMAKE_EXE_LINKER_FLAGS -static)
set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
set(CMAKE_EXE_LINK_DYNAMIC_C_FLAGS)
set(CMAKE_EXE_LINK_DYNAMIC_CXX_FLAGS)
set(CMAKE_SHARED_LIBRARY_C_FLAGS)
set(CMAKE_SHARED_LIBRARY_CXX_FLAGS)
set(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS)
set(CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS)
set(BUILD_SHARED_LIBS OFF)
endif(STATIC)

set(CMAKE_CXX_FLAGS "-std=c++11 -O3 -Wall -Wextra -Wshadow -g -Wfatal-errors -Wno-sign-compare -Wno-literal-suffix")

# Add CPU instruction flags for clhash (PCLMUL, AES, SSSE3 instructions)
# These are x86_64-specific, so only add them on x86/AMD64 processors
SET(CMAKE_C_FLAGS "-std=c99 -Wall")
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64|amd64|i386|i686")
    message(STATUS "Building for x86/AMD64 architecture: ${CMAKE_SYSTEM_PROCESSOR}")
    # Only add advanced instructions on 64-bit x86
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64|amd64")
        SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mpclmul -maes -mssse3")
        message(STATUS "Enabling x86_64 SIMD instructions (PCLMUL, AES, SSSE3)")
    endif()
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
    message(STATUS "Building for ARM64 architecture: ${CMAKE_SYSTEM_PROCESSOR}")
    message(STATUS "Will use sse2neon for x86 intrinsics compatibility")
else()
    message(WARNING "Unknown architecture: ${CMAKE_SYSTEM_PROCESSOR}")
    message(WARNING "Build may fail if clhash.c uses unsupported intrinsics")
endif()

# Look for locally built dependencies first
set(LOCAL_DEPS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/math_libs/install")

if(EXISTS "${LOCAL_DEPS_DIR}/lib/libgmp.a")
    message(STATUS "Using local GMP/MPFR libraries from ${LOCAL_DEPS_DIR}")
    include_directories(${LOCAL_DEPS_DIR}/include)
    set(GMP_LIB "${LOCAL_DEPS_DIR}/lib/libgmp.a")
    set(GMPXX_LIB "${LOCAL_DEPS_DIR}/lib/libgmpxx.a")
    set(MPFR_LIB "${LOCAL_DEPS_DIR}/lib/libmpfr.a")
else()
    # Fall back to system libraries
    message(STATUS "Using system GMP/MPFR libraries")

    # Add Homebrew paths for macOS
    if(APPLE)
        include_directories(/opt/homebrew/include)
        link_directories(/opt/homebrew/lib)
    endif()

    find_library(GMP_LIB gmp REQUIRED)
    find_library(GMPXX_LIB gmpxx REQUIRED)
    find_library(MPFR_LIB mpfr REQUIRED)
endif()

add_definitions( -DMPFR_USE_NO_MACRO )
add_subdirectory(flowcutter)

SET(SOURCES 
	src/preprocessor/graph.cpp 
	src/preprocessor/instance.cpp
	src/preprocessor/oracle.cpp
	src/preprocessor/preprocessor.cpp
	src/preprocessor/subsumer.cpp
	src/preprocessor/treewidth.cpp
	src/preprocessor/twpp.cpp
	src/decomposition.cpp
	src/clhash/clhash.c
)

add_executable (sharpSAT src/main.cpp ${SOURCES})
if(STATIC)
SET_TARGET_PROPERTIES (sharpSAT PROPERTIES LINK_SEARCH_START_STATIC 1)
endif(STATIC)
target_link_libraries (sharpSAT ${MPFR_LIB} ${GMPXX_LIB} ${GMP_LIB})

add_executable (flow_cutter_pace17 flowcutter/pace.cpp)
if(STATIC)
SET_TARGET_PROPERTIES (flow_cutter_pace17 PROPERTIES LINK_SEARCH_START_STATIC 1)
endif(STATIC)
target_link_libraries (flow_cutter_pace17 libflowcutter)

# Install binaries to bin directory for test script compatibility
install(TARGETS sharpSAT flow_cutter_pace17
        RUNTIME DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/bin)

# Add custom command to copy binaries after build (for convenience)
add_custom_command(TARGET sharpSAT POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_SOURCE_DIR}/bin
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:sharpSAT> ${CMAKE_CURRENT_SOURCE_DIR}/bin/
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:flow_cutter_pace17> ${CMAKE_CURRENT_SOURCE_DIR}/bin/
    COMMENT "Copying binaries to bin directory"
)