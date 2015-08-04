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



/* Internal requirements in Reedb */
#include "core.h"

/** Now define extern variables from the core.h and set default values*/
bool active;
bool daemon = true;
ree_os core_os;
unsigned int pw_length;
bool verbose = false;
bool no_token = false;

/** Include parameters and error code returns */
#include "params.h"

/* External requirements */
#include <stdlib.h>
#include <stdio.h>

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
int reedb_init(ree_icontainer *conf, void *user_function)
{
	/* Check that the neccesary parameters on the configuration container are set.*/
	if(!conf->os || conf->passlength)
	{
		fputs("Required parameters not set in init container. Aborting!\n", stderr);
		return REE_ERR_MISSING_PARAMS;
	}

	/* Check that the user provided custom code unless Reedb is running in daemon mode */
	if(!user_function && !conf->daemon)
	{
		fputs("No user code provided to run. Reedb must run in daemon mode to do that. Aborting!\n", stderr);
		return REE_ERR_MISSING_USRCODE;
	}

	/* Then set the relevant fields.
	 * If a value exists it will override the default value */
	if(conf->daemon != NULL) daemon = conf->daemon;
	if(conf->verbose != NULL) verbose = conf->verbose;

	/* These fields need to be set. We checked the above */
	core_os = conf->os;
	pw_length = conf->passlength;

	return 0;
}

/**
 * Terminate Reedb with a reason. After calling this function the
 * core functionality (and depending interfaces on the stack)
 * is no longer available.
 *  
 * @param reason [String] Reason why Reedb is being terminated to
 *  							be written into central logs.
 *
 */
int reedb_terminate(char *reason)
{
	return 0;
}