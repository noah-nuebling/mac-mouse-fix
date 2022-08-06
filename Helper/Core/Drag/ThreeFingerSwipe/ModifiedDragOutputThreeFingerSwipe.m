//
// --------------------------------------------------------------------------
// ModifiedDragOutputThreeFingerDrag.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputThreeFingerSwipe.h"
#import "CGSSpace.h"
#import "TouchSimulator.h"
@import Cocoa;
#import "PointerFreeze.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation ModifiedDragOutputThreeFingerSwipe

/// Vars

static ModifiedDragState *_drag;

static int16_t _nOfSpaces = 1;

/// Interface funcs

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
}

+ (void)handleBecameInUse {
    /// Get number of spaces
    ///     for use in `handleMouseInputWhileInUse()`. Getting it here for performance reasons. Not sure if significant.
    CFArrayRef spaces = CGSCopySpaces(CGSMainConnectionID(), CGSSpaceIncludesUser | CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent);
    /// Full screen spaces appear twice for some reason so we need to filter duplicates
    NSSet *uniqueSpaces = [NSSet setWithArray:(__bridge NSArray *)spaces];
    _nOfSpaces = uniqueSpaces.count;
    
    CFRelease(spaces);
    
    /// Freeze pointer
    if (OtherConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
    }
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /**
     Horizontal dockSwipe scaling
     This makes horizontal dockSwipes (switch between spaces) follow the pointer exactly
     I arrived at these value through testing documented in the NotePlan note "MMF - Scraps - Testing DockSwipe scaling"
     TODO: Test this on a vertical screen
     */
    CGSize screenSize = NSScreen.mainScreen.frame.size;
    double originOffsetForOneSpace = _nOfSpaces == 1 ? 2.0 : 1.0 + (1.0 / (_nOfSpaces-1));
    double spaceSeparatorWidth = 63;
    double threeFingerScaleH = originOffsetForOneSpace / (screenSize.width + spaceSeparatorWidth);
    
    /// Vertical dockSwipe scaling
    ///     Not sure if it makes sense to scale this with screen height
    double threeFingerScaleV = 1.0 / screenSize.height;
    
    /// Get phase
    
    IOHIDEventPhaseBits eventPhase = _drag->firstCallback ? kIOHIDEventPhaseBegan : kIOHIDEventPhaseChanged;
    
    /// Send events
    
    if (_drag->usageAxis == kMFAxisHorizontal) {
        double delta = -deltaX * threeFingerScaleH;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:eventPhase];
    } else if (_drag->usageAxis == kMFAxisVertical) {
        double delta = deltaY * threeFingerScaleV;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:eventPhase];
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    
    MFDockSwipeType type;
    IOHIDEventPhaseBits phase;
    
    if (_drag->usageAxis == kMFAxisHorizontal) {
        type = kMFDockSwipeTypeHorizontal;
    } else if (_drag->usageAxis == kMFAxisVertical) {
        type = kMFDockSwipeTypeVertical;
    } else {
        assert(false);
    }
    
    phase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
    
    [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:phase];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), _drag->queue, ^{
//        [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:phase];
    });
    
    /// ^ The inital dockSwipe event we post will be ignored by the system when it is under load (I called this the "stuck bug" in other places). Sending the event again with a delay of 200ms (0.2s) gets it unstuck almost always. Sending the event twice gives us the best of both responsiveness and reliability.
    ///     Edit: Should maybe move the second send into TouchSimulator and use an NSTimer - to prevent double sending. (Because postDockSwipeEventWithDelta: is also used through scrolling. See Scroll.m for context.)
    
    /// Unfreeze pointer
    if (OtherConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze unfreeze];
    }
    
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
