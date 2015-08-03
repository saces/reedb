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
 * This header file contains handles to interact with the Reedb
 * config module. The config module is responsible for tweaking 
 * the operational behaviour of Reedb to the liking of the user.
 *
 * Some config functions might not be available when using Reedb
 * in daemon mode. However that functionality can be overwritten
 * on launch.
 *
 * @author: Katharina 'spacekookie' Sabel <sabel.katharina@gmail.com>
 */

/* Only link stdlib if neccesary */
#ifndef __STD_LIB__
#include <stdlib.h>
#endif

/* Enum to describe the state of a logger. Used for both
 * global app and local vault logging
 */
typedef enum {

} ree_logstate;

/**
 * Set the global time out for a vault file before it is uncached by 
 * a debouncer. Returns a 0 if the new timeout was set successfully
 * and an error code when or if errors occured.
 * 
 */
unsigned int rcfg_gltimeout(unsigned int tout);

/**
 * 
 */
unsigned int rcfg_get_gltimeout();

/**
 *
 */
unsigned int rcfg_logstate(ree_logstate state);

/**
 *
 */
unsigned int rcfg_pwlength(size_t length);

/**
 *
 */
unsigned char *rcfg_oppath();

/**
 *
 */
unsigned int rcfg_ocdcfg(bool state);