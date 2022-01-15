# -*- mode: CMake; tab-width: 2; indent-tabs-mode: nil; -*-

# This file is a fairly generic CMake toolchain file for the MC1 computer.
# To use it, run CMake with the argument:
#   -DCMAKE_TOOLCHAIN_FILE=mc1-toolchain.cmake

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR mrisc32)
set(MC1 TRUE)

set(CMAKE_C_COMPILER mrisc32-elf-gcc)
set(CMAKE_CXX_COMPILER mrisc32-elf-g++)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
