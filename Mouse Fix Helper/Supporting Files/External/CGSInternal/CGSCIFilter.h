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

#ifndef CGS_CIFILTER_INTERNAL_H
#define CGS_CIFILTER_INTERNAL_H

#include "CGSConnection.h"

typedef enum {
	kCGWindowFilterUnderlay		= 1,
	kCGWindowFilterDock			= 0x3001,
} CGSCIFilterID;

/// Creates a new filter from a filter name.
///
/// Any valid CIFilter names are valid names for this function.
CG_EXTERN CGError CGSNewCIFilterByName(CGSConnectionID cid, CFStringRef filterName, CGSCIFilterID *outFilter);

/// Inserts the given filter into the window.
///
/// The values for the `flags` field is currently unknown.
CG_EXTERN CGError CGSAddWindowFilter(CGSConnectionID cid, CGWindowID wid, CGSCIFilterID filter, int flags);

/// Removes the given filter from the window.
CG_EXTERN CGError CGSRemoveWindowFilter(CGSConnectionID cid, CGWindowID wid, CGSCIFilterID filter);

/// Invokes `-[CIFilter setValue:forKey:]` on each entry in the dictionary for the window's filter.
///
/// The Window Server only checks for the existence of
///
///    inputPhase
///    inputPhase0
///    inputPhase1
CG_EXTERN CGError CGSSetCIFilterValuesFromDictionary(CGSConnectionID cid, CGSCIFilterID filter, CFDictionaryRef filterValues);

/// Releases a window's CIFilter.
CG_EXTERN CGError CGSReleaseCIFilter(CGSConnectionID cid, CGSCIFilterID filter);

#endif /* CGS_CIFILTER_INTERNAL_H */
