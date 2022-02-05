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

#ifndef CGS_TRANSITIONS_INTERNAL_H
#define CGS_TRANSITIONS_INTERNAL_H

#include "CGSConnection.h"

typedef enum {
	/// No animation is performed during the transition.
	kCGSTransitionNone,
	/// The window's content fades as it becomes visible or hidden.
	kCGSTransitionFade,
	/// The window's content zooms in or out as it becomes visible or hidden.
	kCGSTransitionZoom,
	/// The window's content is revealed gradually in the direction specified by the transition subtype.
	kCGSTransitionReveal,
	/// The window's content slides in or out along the direction specified by the transition subtype.
	kCGSTransitionSlide,
	///
	kCGSTransitionWarpFade,
	kCGSTransitionSwap,
	/// The window's content is aligned to the faces of a cube and rotated in or out along the
	/// direction specified by the transition subtype.
	kCGSTransitionCube,
	///
	kCGSTransitionWarpSwitch,
	/// The window's content is flipped along its midpoint like a page being turned over along the
	/// direction specified by the transition subtype.
	kCGSTransitionFlip
} CGSTransitionType;

typedef enum {
	/// Directions bits for the transition. Some directions don't apply to some transitions.
	kCGSTransitionDirectionLeft		= 1 << 0,
	kCGSTransitionDirectionRight	= 1 << 1,
	kCGSTransitionDirectionDown		= 1 << 2,
	kCGSTransitionDirectionUp		=	1 << 3,
	kCGSTransitionDirectionCenter	= 1 << 4,
	
	/// Reverses a transition. Doesn't apply for all transitions.
	kCGSTransitionFlagReversed		= 1 << 5,
	
	/// Ignore the background color and only transition the window.
	kCGSTransitionFlagTransparent	= 1 << 7,
} CGSTransitionFlags;

typedef struct CGSTransitionSpec {
	int version; // always set to zero
	CGSTransitionType type;
	CGSTransitionFlags options;
	CGWindowID wid; /* 0 means a full screen transition. */
	CGFloat *backColor; /* NULL means black. */
} *CGSTransitionSpecRef;

/// Creates a new transition from a `CGSTransitionSpec`.
CG_EXTERN CGError CGSNewTransition(CGSConnectionID cid, const CGSTransitionSpecRef spec, CGSTransitionID *outTransition);

/// Invokes a transition asynchronously. Note that `duration` is in seconds.
CG_EXTERN CGError CGSInvokeTransition(CGSConnectionID cid, CGSTransitionID transition, CGFloat duration);

/// Releases a transition.
CG_EXTERN CGError CGSReleaseTransition(CGSConnectionID cid, CGSTransitionID transition);

#endif /* CGS_TRANSITIONS_INTERNAL_H */
