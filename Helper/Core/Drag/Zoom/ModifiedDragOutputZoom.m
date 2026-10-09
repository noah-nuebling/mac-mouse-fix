//
// --------------------------------------------------------------------------
// ModifiedDragOutputZoom.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputZoom.h"
#import "TouchSimulator.h"
#import "PointerFreeze.h"
#import "HelperUtility.h"
#import "SharedUtility.h"

@implementation ModifiedDragOutputZoom

static ModifiedDragState *_drag;

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
}

+ (void)handleBecameInUse {
    /// Always freeze, since apps zoom around the pointer.
    [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY {
    
    /// ModifiedDrag flips deltas to follow the system scroll direction. Zoom direction shouldn't depend on that.
    if (!_drag->naturalDirection) {
        deltaX = -deltaX;
        deltaY = -deltaY;
    }
    
    double magnification = (deltaX - deltaY) / 400.0;
    if (magnification == 0) return;
    
    if (_drag->firstCallback) {
        [TouchSimulator postMagnificationEventWithMagnification:magnification phase:kIOHIDEventPhaseBegan]; /// First delta seems to be ignored
        if ([HelperUtility appUnderMousePointerIsChromium]) {
            /// Chromium needs a lot of delta before it starts zooming. See Scroll.m.
            magnification += mfsign(magnification) > 0 ? 380/800.0 : -250/800.0;
        }
    }
    [TouchSimulator postMagnificationEventWithMagnification:magnification phase:kIOHIDEventPhaseChanged];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    [TouchSimulator postMagnificationEventWithMagnification:0.0 phase:cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded];
    [PointerFreeze unfreeze];
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
