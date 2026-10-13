//
// --------------------------------------------------------------------------
// ModifiedDragOutputThreeFingerDrag.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputThreeFingerSwipe.h"
#import "CGSSpace.h"
#import "TouchSimulator.h"
@import Cocoa;
#import "PointerFreeze.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "CGSDisplays.h"
#import "Logging.h"
#import "InstantSpaceSwitcher/include/ISS.h"

@implementation ModifiedDragOutputThreeFingerSwipe

/// Vars

static ModifiedDragState *_drag;

static int16_t _nOfSpaces = 1;
static NSSize _screenSize = {};
static BOOL _instantHorizontal = NO;

/// Interface funcs

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
}

+ (void)handleBecameInUse {

    _instantHorizontal = [_drag->type isEqualToString:kMFModifiedDragTypeThreeFingerSwipeInstant]
        && _drag->usageAxis == kMFAxisHorizontal;

    if (_instantHorizontal) {
        // originOffset is the movement that crossed the existing drag threshold.
        // It is still in device coordinates, before ModifiedDrag applies natural scrolling.
        double deltaX = _drag->naturalDirection ? _drag->originOffset.x : -_drag->originOffset.x;
        ISSDirection direction = deltaX < 0 ? ISSDirectionRight : ISSDirectionLeft;
        // One switch per drag, like InstantSpaceSwitcher's trackpad override.
        // No continuous horizontal swipe is opened, so release must not send an Ended event.
        if (!iss_switch(direction)) {
            DDLogDebug("Instant Space switch blocked by a boundary or unavailable Space information");
        }
    }

    NSScreen *screen = [NSScreen mainScreen];

    /// Get `_screenSize`
    ///     For use in `handleMouseInputWhileInUse`. Getting it here in case screen is detached mid-gesture, I guess? Didn't test [Sep 2026]
    _screenSize = [screen frame].size;

    /// Get `_nOfSpaces`
    ///     For use in `handleMouseInputWhileInUse`. Getting it here for performance reasons. Not sure if significant.
    {
        /// Update [Sep 2026] Support multiple displays
        ///     Haven't measured how fast this is. Probably fast. Alternative: Iterate each space (CGSCopySpaces) and ask CGS which display it belongs to.

        NSArray *spacesInfo = CFBridgingRelease(CGSCopyManagedDisplaySpaces(CGSMainConnectionID()));
        NSString *screenUUID = [screen mf_UUIDString];

        /// Find the entry in spacesInfo info for `_screen`
        NSDictionary *entry = nil;
        for (NSDictionary *screenDict in spacesInfo)
            if ([[screenDict objectForKey: @"Display Identifier"] isEqual: screenUUID])
                { entry = screenDict; break; }

        /// Count the spaces for `_screen`
        _nOfSpaces = [[entry objectForKey: @"Spaces"] count];
    }

    /// Freeze pointer
    if (GeneralConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
    }
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY {
    if (_instantHorizontal) return;
    
    /**
     Horizontal dockSwipe scaling
     This makes horizontal dockSwipes (switch between spaces) follow the pointer exactly
     I arrived at these value through testing documented in the NotePlan note "MMF - Scraps - Testing DockSwipe scaling"
     TODO: Test this on a vertical screen
     */
    double originOffsetForOneSpace = _nOfSpaces <= 1 ? 2.0 : 1.0 + (1.0 / (_nOfSpaces-1));
    double spaceSeparatorWidth = 63;
    double threeFingerScaleH = originOffsetForOneSpace / (_screenSize.width + spaceSeparatorWidth);

    /// Vertical dockSwipe scaling
    ///     Not sure if it makes sense to scale this with screen height
    double threeFingerScaleV = 1.0 / _screenSize.height;

    /// Get phase
    
    IOHIDEventPhaseBits eventPhase = _drag->firstCallback ? kIOHIDEventPhaseBegan : kIOHIDEventPhaseChanged;
    
    /// Send events
    
    if (_drag->usageAxis == kMFAxisHorizontal) {
        double delta = -deltaX * threeFingerScaleH;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:eventPhase invertedFromDevice:_drag->naturalDirection];
    } else if (_drag->usageAxis == kMFAxisVertical) {
        double delta = deltaY * threeFingerScaleV;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:eventPhase invertedFromDevice:_drag->naturalDirection];
    }
}

+ (void) handleDeactivationWhileInUseWithCancel:(BOOL)cancel {

    if (_instantHorizontal) {
        if (GeneralConfig.freezePointerDuringModifiedDrag) [PointerFreeze unfreeze];
        return;
    }

    MFDockSwipeType type;
    IOHIDEventPhaseBits phase;
    
    if      (_drag->usageAxis == kMFAxisHorizontal) type = kMFDockSwipeTypeHorizontal;
    else if (_drag->usageAxis == kMFAxisVertical)   type = kMFDockSwipeTypeVertical;
    else                                            assert(false);
    
    phase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
    
    [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:phase invertedFromDevice:_drag->naturalDirection];
    
    /// Unfreeze pointer
    if (GeneralConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze unfreeze];
    }
    
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
