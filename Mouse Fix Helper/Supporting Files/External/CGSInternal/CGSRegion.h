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

#ifndef CGS_REGION_INTERNAL_H
#define CGS_REGION_INTERNAL_H

typedef CFTypeRef CGSRegionRef;
typedef CFTypeRef CGSRegionEnumeratorRef;


#pragma mark - Region Lifecycle


/// Creates a region from a `CGRect`.
CG_EXTERN CGError CGSNewRegionWithRect(const CGRect *rect, CGSRegionRef *outRegion);

/// Creates a region from a list of `CGRect`s.
CG_EXTERN CGError CGSNewRegionWithRectList(const CGRect *rects, int rectCount, CGSRegionRef *outRegion);

/// Creates a new region from a QuickDraw region.
CG_EXTERN CGError CGSNewRegionWithQDRgn(RgnHandle region, CGSRegionRef *outRegion);

/// Creates an empty region.
CG_EXTERN CGError CGSNewEmptyRegion(CGSRegionRef *outRegion);

/// Releases a region.
CG_EXTERN CGError CGSReleaseRegion(CGSRegionRef region);


#pragma mark - Creating Complex Regions


/// Created a new region by changing the origin an existing one.
CG_EXTERN CGError CGSOffsetRegion(CGSRegionRef region, CGFloat offsetLeft, CGFloat offsetTop, CGSRegionRef *outRegion);

/// Creates a new region by copying an existing one.
CG_EXTERN CGError CGSCopyRegion(CGSRegionRef region, CGSRegionRef *outRegion);

/// Creates a new region by combining two regions together.
CG_EXTERN CGError CGSUnionRegion(CGSRegionRef region1, CGSRegionRef region2, CGSRegionRef *outRegion);

/// Creates a new region by combining a region and a rect.
CG_EXTERN CGError CGSUnionRegionWithRect(CGSRegionRef region, CGRect *rect, CGSRegionRef *outRegion);

/// Creates a region by XORing two regions together.
CG_EXTERN CGError CGSXorRegion(CGSRegionRef region1, CGSRegionRef region2, CGSRegionRef *outRegion);

/// Creates a `CGRect` from a region.
CG_EXTERN CGError CGSGetRegionBounds(CGSRegionRef region, CGRect *outRect);

/// Creates a rect from the difference of two regions.
CG_EXTERN CGError CGSDiffRegion(CGSRegionRef region1, CGSRegionRef region2, CGSRegionRef *outRegion);


#pragma mark - Comparing Regions


/// Determines if two regions are equal.
CG_EXTERN bool CGSRegionsEqual(CGSRegionRef region1, CGSRegionRef region2);

/// Determines if a region is inside of a region.
CG_EXTERN bool CGSRegionInRegion(CGSRegionRef region1, CGSRegionRef region2);

/// Determines if a region intersects a region.
CG_EXTERN bool CGSRegionIntersectsRegion(CGSRegionRef region1, CGSRegionRef region2);

/// Determines if a rect intersects a region.
CG_EXTERN bool CGSRegionIntersectsRect(CGSRegionRef obj, const CGRect *rect);


#pragma mark - Checking for Membership


/// Determines if a point in a region.
CG_EXTERN bool CGSPointInRegion(CGSRegionRef region, const CGPoint *point);

/// Determines if a rect is in a region.
CG_EXTERN bool CGSRectInRegion(CGSRegionRef region, const CGRect *rect);


#pragma mark - Checking Region Characteristics


/// Determines if the region is empty.
CG_EXTERN bool CGSRegionIsEmpty(CGSRegionRef region);

/// Determines if the region is rectangular.
CG_EXTERN bool CGSRegionIsRectangular(CGSRegionRef region);


#pragma mark - Region Enumerators


/// Gets the enumerator for a region.
CG_EXTERN CGSRegionEnumeratorRef CGSRegionEnumerator(CGSRegionRef region);

/// Releases a region enumerator.
CG_EXTERN void CGSReleaseRegionEnumerator(CGSRegionEnumeratorRef enumerator);

/// Gets the next rect of a region.
CG_EXTERN CGRect *CGSNextRect(CGSRegionEnumeratorRef enumerator);


/// DOCUMENTATION PENDING */
CG_EXTERN CGError CGSFetchDirtyScreenRegion(CGSConnectionID cid, CGSRegionRef *outDirtyRegion);

#endif /* CGS_REGION_INTERNAL_H */
