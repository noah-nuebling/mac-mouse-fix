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

#ifndef CGS_ACCESSIBILITY_INTERNAL_H
#define CGS_ACCESSIBILITY_INTERNAL_H

#include "CGSConnection.h"


#pragma mark - Display Zoom


/// Gets whether the display is zoomed.
CG_EXTERN CGError CGSIsZoomed(CGSConnectionID cid, bool *outIsZoomed);


#pragma mark - Invert Colors


/// Gets the preference value for inverted colors on the current display.
CG_EXTERN bool CGDisplayUsesInvertedPolarity(void);

/// Sets the preference value for the state of the inverted colors on the current display.  This
/// preference value is monitored by the system, and updating it causes a fairly immediate change
/// in the screen's colors.
///
/// Internally, this sets and synchronizes `DisplayUseInvertedPolarity` in the
/// "com.apple.CoreGraphics" preferences bundle.
CG_EXTERN void CGDisplaySetInvertedPolarity(bool invertedPolarity);


#pragma mark - Use Grayscale


/// Gets whether the screen forces all drawing as grayscale.
CG_EXTERN bool CGDisplayUsesForceToGray(void);

/// Sets whether the screen forces all drawing as grayscale.
CG_EXTERN void CGDisplayForceToGray(bool forceToGray);


#pragma mark - Increase Contrast


/// Sets the display's contrast. There doesn't seem to be a get version of this function.
CG_EXTERN CGError CGSSetDisplayContrast(CGFloat contrast);

#endif /* CGS_ACCESSIBILITY_INTERNAL_H */
