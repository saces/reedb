add_executable(reedbd main.c)

# Sets the lib as a dependency
add_dependencies(reedbd reedb)

#target_include_directories()

# target_link_libraries(reedbd 
# 	libbeispiel
# 	${ORDNER}/irgendwas/bla.a)

install(TARGETS reedbd DESTINATION bin) #sbin/ lib/ etc.