add_library(reedb SHARED 
						private/reevault.c
						private/datafile.c
						private/core.c )

target_include_directories(reedb PRIVATE private/headers)
target_include_directories(reedb PUBLIC public)