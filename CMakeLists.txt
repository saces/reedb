cmake_minimum_required(VERSION 2.8)

# Global project name
project(reedb)

set(Reedb_VERSION_MAJOR 0)
set(Reedb_VERSION_MINOR 12)
set(Reedb_VERSION_PATCH 0)

configure_file (
	"${PROJECT_SOURCE_DIR}/include/ReedbConfig.h.in"
	"${PROJECT_BINARY_DIR}/include/ReedbConfig.h"
)

include_directories("${PROJECT_BINARY_DIR}/include")

add_subdirectory(lib)
add_subdirectory(src)