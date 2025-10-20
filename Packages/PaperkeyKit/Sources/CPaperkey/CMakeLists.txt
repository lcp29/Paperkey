# CMakeLists.txt for paperkey project
# This file configures the build process for the paperkey application using CMake.

# Require CMake version 3.10 or higher
cmake_minimum_required(VERSION 3.10)

# Define the project name
project(paperkey)

# Set C standard to C99
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Add compiler flags for warnings and pedantic mode (equivalent to original Makefile)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -W -pedantic")

# List of source files for the paperkeytest executable
set(TEST_SOURCES
    paperkeytest.c
    extract.c
    restore.c
    parse.c
    packets.c
    output.c
    stream.c
    sha1.c
)

# Create the paperkeytest executable from the test source files
add_executable(paperkeytest ${TEST_SOURCES})

# Run the test executable automatically after building
# add_custom_command(TARGET paperkeytest POST_BUILD
#     COMMAND $<TARGET_FILE:paperkeytest>
#     COMMENT "Running paperkeytest after build"
# )

# Note: No external libraries are linked as per the original Makefile analysis.
# If additional libraries are needed in the future, add them here using target_link_libraries().