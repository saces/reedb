/*
 * parameters.h
 *
 *  Created on: 6 Aug 2015
 *      Author: spacekookie
 */

#ifndef SRC_UTILS_H_
#define SRC_UTILS_H_

typedef enum ree_err_t {
	FAILURE = -1, // To be used when cause of error not known.
	SUCCESS = 0, // When something went according to plan
	BIG_SUCCESS = 0, //
	MISSING_PARAMS = 0xA0,
	MISSING_USRCODE = 0xA1,
	MISSING_CONTAINER = 0xA2,
	MALLOC_FAILED = 0xA3,
	ALREADY_INIT = 0xA4,
	OS_PARSE_FAILED = 0xA5,
	ZOMBIE_INSTANCE = 0xA6,
	INVALID_PATH = 0xA7,
	SHORT_PASSPHRASE = 0xA8,
	NOT_INITIALISED = 0xA9,
} ree_err_t;

/** Some constants to use everywhere */
static const unsigned int MIN_PASSLENGTH = 4;
static const char *ERR_INIT_MSG =
		"Can't change this parameter! Reedb was already initialised.\n";

static const char *ERR_NOT_INIT =
		"Reedb module %s wasn't previously initialised\0";

#endif /* SRC_UTILS_H_ */