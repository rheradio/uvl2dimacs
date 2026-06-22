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

# Common CXX warning suppressions (GCC and Clang/AppleClang)
set(CMAKE_CXX_FLAGS "-std=c++11 -O3 -Wall -Wextra -Wshadow -g -Wfatal-errors -Wno-sign-compare -Wno-shadow -Wno-redundant-move -Wno-unused-variable -Wno-unused-parameter -Wno-unused-result -Wno-unused-but-set-variable -Wno-ignored-qualifiers -Wno-reorder -Wno-array-bounds")
# GCC-only warning suppressions (not recognised on Clang/AppleClang)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-literal-suffix -Wno-stringop-overflow")
endif()
# Clang/AppleClang-only warning suppressions (not recognised on GCC)
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-bitwise-instead-of-logical -Wno-vla-cxx-extension -Wno-unqualified-std-cast-call -Wno-unused-private-field")
endif()

# C flags: -msse4.1/-mpclmul are x86-only; ARM64 uses sse2neon which needs the
# crypto extension for _mm_clmulepi64_si128 (vmull_p64).  Apple Silicon always
# has crypto so no extra flag is needed there.
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    if(APPLE)
        set(CMAKE_C_FLAGS "-std=c99 -Wall")
    else()
        set(CMAKE_C_FLAGS "-std=c99 -Wall -march=armv8-a+crypto")
    endif()
else()
    set(CMAKE_C_FLAGS "-std=c99 -Wall -msse4.1 -mpclmul")
endif()

# Find GMP/MPFR libraries
find_library(GMP_LIB NAMES gmp)
find_library(GMPXX_LIB NAMES gmpxx)
find_library(MPFR_LIB NAMES mpfr)

# Find GMP/MPFR headers — also search Homebrew prefixes on macOS
find_path(GMP_INCLUDE_DIR NAMES gmp.h
    HINTS /opt/homebrew/include /usr/local/include /usr/include)
find_path(GMPXX_INCLUDE_DIR NAMES gmpxx.h
    HINTS /opt/homebrew/include /usr/local/include /usr/include)
find_path(MPFR_INCLUDE_DIR NAMES mpfr.h
    HINTS /opt/homebrew/include /usr/local/include /usr/include)

if(NOT GMP_LIB)
    set(GMP_LIB "gmp")
endif()
if(NOT GMPXX_LIB)
    set(GMPXX_LIB "gmpxx")
endif()
if(NOT MPFR_LIB)
    set(MPFR_LIB "mpfr")
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

# Propagate GMP/MPFR include directories to the sharpSAT target
foreach(_inc GMP_INCLUDE_DIR GMPXX_INCLUDE_DIR MPFR_INCLUDE_DIR)
    if(${_inc})
        target_include_directories(sharpSAT PRIVATE ${${_inc}})
    endif()
endforeach()

# Also find GMP/MPFR library dirs so the linker can locate them on macOS
find_path(GMP_LIB_DIR NAMES libgmp.a libgmp.dylib libgmp.so
    HINTS /opt/homebrew/lib /usr/local/lib /usr/lib)
if(GMP_LIB_DIR)
    target_link_directories(sharpSAT PRIVATE ${GMP_LIB_DIR})
endif()

if(STATIC)
SET_TARGET_PROPERTIES (sharpSAT PROPERTIES LINK_SEARCH_START_STATIC 1)
endif(STATIC)
target_link_libraries (sharpSAT ${MPFR_LIB} ${GMPXX_LIB} ${GMP_LIB})

add_executable (flow_cutter_pace17 flowcutter/pace.cpp)
if(STATIC)
SET_TARGET_PROPERTIES (flow_cutter_pace17 PROPERTIES LINK_SEARCH_START_STATIC 1)
endif(STATIC)
target_link_libraries (flow_cutter_pace17 libflowcutter)

# Copy both binaries to bin/ so the test script can find them regardless of
# which platform built them.  bin/ may contain pre-committed Linux binaries;
# building on any platform replaces them with the native executable.
add_custom_command(TARGET sharpSAT POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_SOURCE_DIR}/bin"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:sharpSAT>" "${CMAKE_SOURCE_DIR}/bin/sharpSAT"
    COMMENT "Copying sharpSAT to bin/"
)
add_custom_command(TARGET flow_cutter_pace17 POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_SOURCE_DIR}/bin"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:flow_cutter_pace17>" "${CMAKE_SOURCE_DIR}/bin/flow_cutter_pace17"
    COMMENT "Copying flow_cutter_pace17 to bin/"
)
