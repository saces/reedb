add_library(reedb SHARED private/reevault.c
						private/datafile.c )

target_include_directories(reedb PRIVATE private/headers)