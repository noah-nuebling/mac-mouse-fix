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
 * Ryan Govostes ryan@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_DISPLAYS_INTERNAL_H
#define CGS_DISPLAYS_INTERNAL_H

#include "CGSRegion.h"

typedef enum {
	CGSDisplayQueryMirrorStatus = 9,
} CGSDisplayQuery;

typedef struct {
	uint32_t mode;
	uint32_t flags;
	uint32_t width;
	uint32_t height;
	uint32_t depth;
	uint32_t dc2[42];
	uint16_t dc3;
	uint16_t freq;
	uint8_t dc4[16];
	CGFloat scale;
} CGSDisplayModeDescription;

typedef int CGSDisplayMode;


/// Gets the main display.
CG_EXTERN CGDirectDisplayID CGSMainDisplayID(void);


#pragma mark - Display Properties


/// Gets the number of displays known to the system.
CG_EXTERN uint32_t CGSGetNumberOfDisplays(void);

/// Gets the depth of a display.
CG_EXTERN CGError CGSGetDisplayDepth(CGDirectDisplayID display, int *outDepth);

/// Gets the displays at a point. Note that multiple displays can have the same point - think mirroring.
CG_EXTERN CGError CGSGetDisplaysWithPoint(const CGPoint *point, int maxDisplayCount, CGDirectDisplayID *outDisplays, int *outDisplayCount);

/// Gets the displays which contain a rect. Note that multiple displays can have the same bounds - think mirroring.
CG_EXTERN CGError CGSGetDisplaysWithRect(const CGRect *point, int maxDisplayCount, CGDirectDisplayID *outDisplays, int *outDisplayCount);

/// Gets the bounds for the display. Note that multiple displays can have the same bounds - think mirroring.
CG_EXTERN CGError CGSGetDisplayRegion(CGDirectDisplayID display, CGSRegionRef *outRegion);
CG_EXTERN CGError CGSGetDisplayBounds(CGDirectDisplayID display, CGRect *outRect);

/// Gets the number of bytes per row.
CG_EXTERN CGError CGSGetDisplayRowBytes(CGDirectDisplayID display, int *outRowBytes);

/// Returns an array of dictionaries describing the spaces each screen contains.
CG_EXTERN CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID cid);

/// Gets the current display mode for the display.
CG_EXTERN CGError CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum);

/// Gets the number of possible display modes for the display.
CG_EXTERN CGError CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes);

/// Gets a description of the mode of the display.
CG_EXTERN CGError CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, CGSDisplayModeDescription *desc, int length);

/// Sets a display's configuration mode.
CG_EXTERN CGError CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);

/// Gets a list of on line displays */
CG_EXTERN CGDisplayErr CGSGetOnlineDisplayList(CGDisplayCount maxDisplays, CGDirectDisplayID *displays, CGDisplayCount *outDisplayCount);

/// Gets a list of active displays */
CG_EXTERN CGDisplayErr CGSGetActiveDisplayList(CGDisplayCount maxDisplays, CGDirectDisplayID *displays, CGDisplayCount *outDisplayCount);


#pragma mark - Display Configuration


/// Begins a new display configuration transacation.
CG_EXTERN CGDisplayErr CGSBeginDisplayConfiguration(CGDisplayConfigRef *config);

/// Sets the origin of a display relative to the main display. The main display is at (0, 0) and contains the menubar.
CG_EXTERN CGDisplayErr CGSConfigureDisplayOrigin(CGDisplayConfigRef config, CGDirectDisplayID display, int32_t x, int32_t y);

/// Applies the configuration changes made in this transaction.
CG_EXTERN CGDisplayErr CGSCompleteDisplayConfiguration(CGDisplayConfigRef config);

/// Drops the configuration changes made in this transaction.
CG_EXTERN CGDisplayErr CGSCancelDisplayConfiguration(CGDisplayConfigRef config);


#pragma mark - Querying for Display Status


/// Queries the Window Server about the status of the query.
CG_EXTERN CGError CGSDisplayStatusQuery(CGDirectDisplayID display, CGSDisplayQuery query);

#endif /* CGS_DISPLAYS_INTERNAL_H */
