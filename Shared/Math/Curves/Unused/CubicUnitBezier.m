/*
 * Copyright (C) 2008 Apple Inc. All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 - Excerpts from the old "Fix Scrolling" Apple Note:
    - Make animation curve with visual interface:  http://netcetera.org/camtf-playground.html
    - WebKit Bezier Source Code: https://opensource.apple.com/source/WebCore/WebCore-955.66/platform/graphics/UnitBezier.h
    - [x] Play with with epsilon for best performance-precision balance:
        -> 0.008
 - Would it be better to just use CAMediaTimingFunction?
 */

#import "CubicUnitBezier.h"
#include <math.h>

@implementation CubicUnitBezier

double ax;
double bx;
double cx;

double ay;
double by;
double cy;

- (void) UnitBezierForPoint1x:(double)p1x point1y:(double)p1y point2x:(double)p2x point2y:(double)p2y {
    // Calculate the polynomial coefficients, implicit first and last control points are (0,0) and (1,1).
    /// Noah: I get what they are doing now! They just took the explicit definition for Bezier Curves (find on Wikipedia) and plugged in the known values (n, P0, and P3), and then they rearranged everything so there's only one t^1, one t^2, and one t^3 term. a, b, c are the coefficients of these terms. Then they rearrange the coefficients definitions to reuse the other coefficients for optimization. All they do in this function is precalculated the coefficients using these optimized definitions. I recalculated this and arrived at the same definitions! My Math isn't as rusty as I though it would be! :)
    /// 
    
    cx = 3.0 * p1x;
    bx = 3.0 * (p2x - p1x) - cx;
    ax = 1.0 - cx -bx;
    
    cy = 3.0 * p1y;
    by = 3.0 * (p2y - p1y) - cy;
    ay = 1.0 - cy - by;
}

double sampleCurveX(double t)
{
    // `ax t^3 + bx t^2 + cx t' expanded using Horner's rule.
    return ((ax * t + bx) * t + cx) * t;
}

double sampleCurveY(double t)
{
    return ((ay * t + by) * t + cy) * t;
}

double sampleCurveDerivativeX(double t)
{
    return (3.0 * ax * t + 2.0 * bx) * t + cx;
}

// Given an x value, find a parametric value it came from.
double solveCurveX(double x, double epsilon)
{
    double t0;
    double t1;
    double t2;
    double x2;
    double d2;
    int i;
    
    // First try a few iterations of Newton's method -- normally very fast.
    for (t2 = x, i = 0; i < 8; i++) {
        
//        DDLogDebug(@"Newtons method iteration: %d", i);
        
        x2 = sampleCurveX(t2) - x;
        if (fabs (x2) < epsilon)
            return t2;
        d2 = sampleCurveDerivativeX(t2);
        if (fabs(d2) < 1e-6)
            break;
        t2 = t2 - x2 / d2;
    }
    
    // Fall back to the bisection method for reliability.
    t0 = 0.0;
    t1 = 1.0;
    t2 = x;
    
    if (t2 < t0)
        return t0;
    if (t2 > t1)
        return t1;
    
    while (t0 < t1) {
        x2 = sampleCurveX(t2);
        if (fabs(x2 - x) < epsilon)
            return t2;
        if (x > x2)
            t0 = t2;
        else
            t1 = t2;
        t2 = (t1 - t0) * .5 + t0;
    }
    
    // Failure.
    return t2;
}

- (double)evaluateAt:(double)x epsilon:(double)epsilon {
    return sampleCurveY(solveCurveX(x, epsilon));
}

- (double)evaluateAt:(double)x {
    return sampleCurveY(solveCurveX(x, 0.008)); // Used this epsilon value in the old Unused MomentumScroll.m. Not sure how I arrived at it, but it seems to work well
}

@end
