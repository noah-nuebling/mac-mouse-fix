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

#ifndef CGS_SESSION_INTERNAL_H
#define CGS_SESSION_INTERNAL_H

#include "CGSInternal.h"

typedef int CGSSessionID;

/// Creates a new "blank" login session.
///
/// Switches to the LoginWindow. This does NOT check to see if fast user switching is enabled!
CG_EXTERN CGError CGSCreateLoginSession(CGSSessionID *outSession);

/// Releases a session.
CG_EXTERN CGError CGSReleaseSession(CGSSessionID session);

/// Gets information about the current login session.
///
/// As of OS X 10.6, the following keys appear in this dictionary:
///
///     kCGSSessionGroupIDKey		: CFNumberRef
///     kCGSSessionOnConsoleKey		: CFBooleanRef
///     kCGSSessionIDKey			: CFNumberRef
///     kCGSSessionUserNameKey		: CFStringRef
///     kCGSessionLongUserNameKey	: CFStringRef
///     kCGSessionLoginDoneKey		: CFBooleanRef
///     kCGSSessionUserIDKey		: CFNumberRef
///     kCGSSessionSecureInputPID	: CFNumberRef
CG_EXTERN CFDictionaryRef CGSCopyCurrentSessionDictionary(void);

/// Gets a list of session dictionaries.
///
/// Each session dictionary is in the format returned by `CGSCopyCurrentSessionDictionary`.
CG_EXTERN CFArrayRef CGSCopySessionList(void);

#endif /* CGS_SESSION_INTERNAL_H */
