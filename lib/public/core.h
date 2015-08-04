/* 
 * (C) Copyright 2014-2015 Lonely Robot.
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the GNU Lesser General Public License
 * (LGPL) version 3 which accompanies this distribution, and is available at
 * http://www.gnu.org/licenses/lgpl-3.html
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 */

/*
 * This header file contains handles to interact with the Reedb core module.
 * The core module is responsible for starting and terminating running Reedb 
 * instances as well as checking that all other modules are loaded and 
 * running correctly.
 *
 * @author: Katharina 'spacekookie' Sabel <sabel.katharina@gmail.com>
 */

 #include <stdbool.h>

typedef enum ree_os 
{
	LINUX 		= 0xE1, /* Linux systems */
	OSX 		= 0xE2, /* Mac OS X */
	WINDOWS 	= 0xE3, /* Windows */
 	ANDROID 	= 0xE4, /* Mobile: Android */
	IOS 		= 0xE5, /* Mobile: iOS */
	BSD			= 0xE6, /* BSD systems */
} ree_os;

/**
 * This is a container struct that can hold all neccesary fields
 * and parameters to initialise the Reedb core module.
 * 
 * It provides a simple interface to change the runtime parameters
 * of the current Reedb instance without introducing security risk
 * when dealing with a highly customised system.
 */
typedef struct ree_icontainer
{
	/*
	 * Defines the minimum password length for vaults created in this session.
	 * If the passphrase of an already existing vault doesn't meet the 
	 * library instance requirements a warning will be thrown.
	 */
	unsigned int passlength;

	/*
	 * Overrides the operational path of the library. The default values are
	 * defined in a private settings file. Changing path can provide the ability 
	 * to run a more customised setup or multiple setups on the same machine
	 * but also introduce errors more easily.
	 */
	unsigned char *op_path;

	/* Simple boolean that enables verbose logging to master log file */
	bool verbose;

	/* 
	 * Simple boolean that enables the daemon mode and detaches
	 * this instance to run in the background. When running Reedb as
	 * a daemon it is mandatory to use the HTTP(s) interface to interact
	 * with a vault or the daemon itself.
	 */
	bool daemon;

	/*
	 * Very simply specifies what operating system Reedb is running on so it
	 * it can run custom code for certain systems and make the developers
	 * (and users) lives a little easier.
	 *
	 * Needs to be provided as an option because parsing can be prone to errors.
	 * 
	 */
	ree_os os;

	/*
	 * Override the default config set of this Reedb instance that is
	 * available while operating in daemon mode. See the wiki for more
	 * details.
	 */
	unsigned char **override_cfg;

} ree_icontainer;

/** Some global variables that are required for the core module to function */

extern bool active;
extern bool daemon;
extern ree_os core_os;
extern unsigned int pw_length;
extern bool verbose;
extern bool no_token;

/**
 * Initialise Reedb with a set of parameters passed into this method.
 * Please check the wiki to find out what option parameters are
 * available to use here.
 *
 * Takes a ree_icontainer with launch parameters
 *
 * As well as a function pointer of the user code that should be
 * executed in paralell on a seperate thread.
 *
 */
int reedb_init(ree_icontainer *conf, void *user_function);

/**
 * Terminate Reedb with a reason. After calling this function the
 * core functionality (and depending interfaces on the stack)
 * is no longer available.
 *  
 * @param reason [String] Reason why Reedb is being terminated to
 *  							be written into central logs.
 *
 */
int reedb_terminate(char *reason);
