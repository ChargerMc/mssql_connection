# The Flutter tooling requires that developers have CMake 3.14 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "mssql_connection")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

# Define the plugin library target.
add_library(${PLUGIN_NAME} SHARED
  "mssql_connection_plugin.cpp"
)

# Apply standard settings for the plugin target.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

# Link against Flutter.
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries that are outputs
# of an external build step (e.g., vcpkg).
set(mssql_connection_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/bin/sybdb.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/bin/ct.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/bin/libcrypto-1_1-x64.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/bin/libssl-1_1-x64.dll"
  PARENT_SCOPE
)
