//
// --------------------------------------------------------------------------
// WarpDeltaCompensator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Compensates for `CGWarpMouseCursorPosition` only taking effect after a few CGEvents, and then reporting the size of the jump as cursor movement (Observed macOS 27)
/// See `warpDeltas` notes for details [Oct 2026]

#pragma once

#import <CoreGraphics/CGEvent.h>

typedef struct {
    char *name;
    CGPoint pointerFreezeLocation;
    CGPoint lastLocation;
    int state;
} WarpDeltaCompensator;

void WarpDeltaCompensator_ReportFreeze(WarpDeltaCompensator *self, CGPoint freezeLocation);
void WarpDeltaCompensator_GetActualDelta(WarpDeltaCompensator *self, int64_t dx, int64_t dy, CGPoint location, int64_t *outDx, int64_t *outDy);
