/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_MISC_INTERNAL_H
#define CGS_MISC_INTERNAL_H

#include "CGSConnection.h"

/// Is someone watching this screen? Applies to Apple's remote desktop only?
CG_EXTERN bool CGSIsScreenWatcherPresent(void);

#pragma mark - Error Logging

/// Logs an error and returns `err`.
CG_EXTERN CGError CGSGlobalError(CGError err, const char *msg);

/// Logs an error and returns `err`.
CG_EXTERN CGError CGSGlobalErrorv(CGError err, const char *msg, ...);

/// Gets the error message for an error code.
CG_EXTERN char *CGSErrorString(CGError error);

#endif /* CGS_MISC_INTERNAL_H */
