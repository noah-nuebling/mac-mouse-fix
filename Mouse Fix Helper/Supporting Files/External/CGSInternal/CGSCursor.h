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

#ifndef CGS_CURSOR_INTERNAL_H
#define CGS_CURSOR_INTERNAL_H

#include "CGSConnection.h"

typedef enum : NSInteger {
	CGSCursorArrow			= 0,
	CGSCursorIBeam			= 1,
	CGSCursorIBeamXOR		= 2,
	CGSCursorAlias			= 3,
	CGSCursorCopy			= 4,
	CGSCursorMove			= 5,
	CGSCursorArrowContext	= 6,
	CGSCursorWait			= 7,
	CGSCursorEmpty			= 8,
} CGSCursorID;


/// Registers a cursor with the given properties.
///
/// - Parameter cid:			The connection ID to register with.
/// - Parameter cursorName:		The system-wide name the cursor will be registered under.
/// - Parameter setGlobally:	Whether the cursor registration can appear system-wide.
/// - Parameter instantly:		Whether the registration of cursor images should occur immediately.  Passing false
///                             may speed up the call.
/// - Parameter frameCount:     The number of images in the cursor image array.
/// - Parameter imageArray:     An array of CGImageRefs that are used to display the cursor.  Multiple images in
///                             conjunction with a non-zero `frameDuration` cause animation.
/// - Parameter cursorSize:     The size of the cursor's images.  Recommended size is 16x16 points
/// - Parameter hotspot:		The location touch events will emanate from.
/// - Parameter seed:			The seed for the cursor's registration.
/// - Parameter bounds:			The total size of the cursor.
/// - Parameter frameDuration:	How long each image will be displayed for.
/// - Parameter repeatCount:	Number of times the cursor should repeat cycling its image frames.
CG_EXTERN CGError CGSRegisterCursorWithImages(CGSConnectionID cid,
											  const char *cursorName,
											  bool setGlobally, bool instantly,
											  NSUInteger frameCount, CFArrayRef imageArray,
											  CGSize cursorSize, CGPoint hotspot,
											  int *seed,
											  CGRect bounds, CGFloat frameDuration,
											  NSInteger repeatCount);


#pragma mark - Cursor Registration


/// Copies the size of data associated with the cursor registered under the given name.
CG_EXTERN CGError CGSGetRegisteredCursorDataSize(CGSConnectionID cid, const char *cursorName, size_t *outDataSize);

/// Re-assigns the given cursor name to the cursor represented by the given seed value.
CG_EXTERN CGError CGSSetRegisteredCursor(CGSConnectionID cid, const char *cursorName, int *cursorSeed);

/// Copies the properties out of the cursor registered under the given name.
CG_EXTERN CGError CGSCopyRegisteredCursorImages(CGSConnectionID cid, const char *cursorName, CGSize *imageSize, CGPoint *hotSpot, NSUInteger *frameCount, CGFloat *frameDuration, CFArrayRef *imageArray);

/// Re-assigns one of the system-defined cursors to the cursor represented by the given seed value.
CG_EXTERN void CGSSetSystemDefinedCursorWithSeed(CGSConnectionID connection, CGSCursorID systemCursor, int *cursorSeed);


#pragma mark - Cursor Display


/// Shows the cursor.
CG_EXTERN CGError CGSShowCursor(CGSConnectionID cid);

/// Hides the cursor.
CG_EXTERN CGError CGSHideCursor(CGSConnectionID cid);

/// Hides the cursor until the cursor is moved.
CG_EXTERN CGError CGSObscureCursor(CGSConnectionID cid);

/// Acts as if a mouse moved event occured and that reveals the cursor if it was hidden.
CG_EXTERN CGError CGSRevealCursor(CGSConnectionID cid);

/// Shows or hides the spinning beachball of death.
///
/// If you call this, I hate you.
CG_EXTERN CGError CGSForceWaitCursorActive(CGSConnectionID cid, bool showWaitCursor);

/// Unconditionally sets the location of the cursor on the screen to the given coordinates.
CG_EXTERN CGError CGSWarpCursorPosition(CGSConnectionID cid, CGFloat x, CGFloat y);


#pragma mark - Cursor Properties


/// Gets the current cursor's seed value.
///
/// Every time the cursor is updated, the seed changes.
CG_EXTERN int CGSCurrentCursorSeed(void);

/// Gets the current location of the cursor relative to the screen's coordinates.
CG_EXTERN CGError CGSGetCurrentCursorLocation(CGSConnectionID cid, CGPoint *outPos);

/// Gets the name (ideally in reverse DNS form) of a system cursor.
CG_EXTERN char *CGSCursorNameForSystemCursor(CGSCursorID cursor);

/// Gets the scale of the current currsor.
CG_EXTERN CGError CGSGetCursorScale(CGSConnectionID cid, CGFloat *outScale);

/// Sets the scale of the current cursor.
///
/// The largest the Universal Access prefpane allows you to go is 4.0.
CG_EXTERN CGError CGSSetCursorScale(CGSConnectionID cid, CGFloat scale);


#pragma mark - Cursor Data


/// Gets the size of the data for the connection's cursor.
CG_EXTERN CGError CGSGetCursorDataSize(CGSConnectionID cid, size_t *outDataSize);

/// Gets the data for the connection's cursor.
CG_EXTERN CGError CGSGetCursorData(CGSConnectionID cid, void *outData);

/// Gets the size of the data for the current cursor.
CG_EXTERN CGError CGSGetGlobalCursorDataSize(CGSConnectionID cid, size_t *outDataSize);

/// Gets the data for the current cursor.
CG_EXTERN CGError CGSGetGlobalCursorData(CGSConnectionID cid, void *outData, int *outDataSize, int *outRowBytes, CGRect *outRect, CGPoint *outHotSpot, int *outDepth, int *outComponents, int *outBitsPerComponent);

/// Gets the size of data for a system-defined cursor.
CG_EXTERN CGError CGSGetSystemDefinedCursorDataSize(CGSConnectionID cid, CGSCursorID cursor, size_t *outDataSize);

/// Gets the data for a system-defined cursor.
CG_EXTERN CGError CGSGetSystemDefinedCursorData(CGSConnectionID cid, CGSCursorID cursor, void *outData, int *outRowBytes, CGRect *outRect, CGPoint *outHotSpot, int *outDepth, int *outComponents, int *outBitsPerComponent);

#endif /* CGS_CURSOR_INTERNAL_H */
