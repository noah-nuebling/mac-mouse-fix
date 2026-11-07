//
// --------------------------------------------------------------------------
// WarpDeltaCompensator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "WarpDeltaCompensator.h"
#import "Logging.h"

void WarpDeltaCompensator_ReportFreeze(WarpDeltaCompensator *self, CGPoint freezeLocation) { /// Report that, for each following `kMFEvent_Sensor` callback, `CGWarpMouseCursorPosition` will be called with the `freezeLocation` [Oct 2026]
    DDLogDebug("WarpDeltaCompensator_ReportFreeze: (%s) (%f, %f)", self->name, freezeLocation.x, freezeLocation.y);
    self->pointerFreezeLocation = freezeLocation;
    self->state = 1;
}
void WarpDeltaCompensator_GetActualDelta(WarpDeltaCompensator *self, int64_t dx, int64_t dy, CGPoint location, int64_t *outDx, int64_t *outDy) {
    *outDx = dx; *outDy = dy;

    DDLogDebug("WarpDeltaCompensator_GetActualDelta: (%s) delta: (%lld, %lld), location: (%f, %f), self: (freezeLoc: (%f, %f), lastLoc: (%f, %f), state: %d)"
        ,self->name ,dx, dy, location.x, location.y
        ,self->pointerFreezeLocation.x, self->pointerFreezeLocation.y, self->lastLocation.x, self->lastLocation.y, self->state);

    if (self->state == 1 || self->state == 2) {
        CGPoint roundedFreezeLocation = CGPointMake(floor(self->pointerFreezeLocation.x), floor(self->pointerFreezeLocation.y)); /// Not sure where the floor() rounding comes from but that's what we see after the warp takes effect [Oct 2026]

        if (!CGPointEqualToPoint(location, roundedFreezeLocation)) { /// Pointer has moved off of the freeze point, after `_ReportFreeze`
            self->lastLocation = location;
            self->state = 2;
        }
        else if (self->state == 2)  { /// `CGWarpMouseCursorPosition` has taken effect - this event's delta will carry the physical mouse's real delta + the warp delta (which we want to compensate for) [Oct 2026]
            self->state = 0;
            int64_t warpDx = floor(roundedFreezeLocation.x - self->lastLocation.x); /// Not sure the `floor()` rounding is right, but 1 px shouldn't be noticeable anyways [Oct 2026]
            int64_t warpDy = floor(roundedFreezeLocation.y - self->lastLocation.y);
            DDLogDebug("WarpDeltaCompensator_GetActualDelta: (%s) compensating by (%lld, %lld)", self->name, -warpDx, -warpDy);
            *outDx = dx - warpDx;
            *outDy = dy - warpDy;
        }
    }
}
