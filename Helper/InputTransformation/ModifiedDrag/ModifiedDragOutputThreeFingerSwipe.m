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

@implementation ModifiedDragOutputThreeFingerSwipe

/// Vars

static ModifiedDragState *_drag;

static int16_t _nOfSpaces = 1;

/// Interface funcs

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    
    _drag = dragStateRef;
}

+ (void)handleMouseInputWhileInitialized {
    /// Get number of spaces
    ///     for use in `handleMouseInputWhileInUse()`. Getting it here for performance reasons. Not sure if significant.
    CFArrayRef spaces = CGSCopySpaces(CGSMainConnectionID(), CGSSpaceIncludesUser | CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent);
    /// Full screen spaces appear twice for some reason so we need to filter duplicates
    NSSet *uniqueSpaces = [NSSet setWithArray:(__bridge NSArray *)spaces];
    _nOfSpaces = uniqueSpaces.count;
    
    CFRelease(spaces);
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /**
     Horizontal dockSwipe scaling
     This makes horizontal dockSwipes (switch between spaces) follow the pointer exactly. (If everything works)
     I arrived at these value through testing documented in the NotePlan note "MMF - Scraps - Testing DockSwipe scaling"
     TODO: Test this on a vertical screen
     */
    double originOffsetForOneSpace = _nOfSpaces == 1 ? 2.0 : 1.0 + (1.0 / (_nOfSpaces-1));
    /// ^ I've seen this be: 1.25, 1.5, 2.0. Not sure why. Restarting, attaching displays, or changing UI scaling don't seem to change it from my testing. It just randomly changes after a few weeks.
    ///     I think I finally see the pattern:
    ///         It's 2.0 for 2 spaces
    ///         It's 1.5 for 3 spaces
    ///         It's 1.25 for 5 spaces
    ///         So the patterns is: 1 + 1 / (nOfSpaces-1)
    ///            (Except for 1 cause you can't divide by zero)
    
    CGFloat screenWidth = NSScreen.mainScreen.frame.size.width;
    double spaceSeparatorWidth = 63;
    double threeFingerScaleH = originOffsetForOneSpace / (screenWidth + spaceSeparatorWidth);
    
    /// Vertical dockSwipe scaling
    /// We should maybe use screenHeight to scale vertical dockSwipes (Mission Control and App Windows), but since they don't follow the mouse pointer anyways, this is fine;
    double threeFingerScaleV = threeFingerScaleH * 1.0;
    
    /// Send events
    
    if (_drag->usageAxis == kMFAxisHorizontal) {
        double delta = -deltaX * threeFingerScaleH;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:_drag->phase];
    } else if (_drag->usageAxis == kMFAxisVertical) {
        double delta = deltaY * threeFingerScaleV;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:_drag->phase];
    }
    //        _drag.phase = kIOHIDEventPhaseChanged;
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancelation {
    
    MFDockSwipeType type;
    IOHIDEventPhaseBits phase;
    
    ModifiedDragState localDrag = *_drag;
    if (localDrag.usageAxis == kMFAxisHorizontal) {
        type = kMFDockSwipeTypeHorizontal;
    } else if (localDrag.usageAxis == kMFAxisVertical) {
        type = kMFDockSwipeTypeVertical;
    } else assert(false);
    
    phase = cancelation ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
    
    [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:phase];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), _drag->queue, ^{
        [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:phase];
    });
    // ^ The inital dockSwipe event we post will be ignored by the system when it is under load (I called this the "stuck bug" in other places). Sending the event again with a delay of 200ms (0.2s) gets it unstuck almost always. Sending the event twice gives us the best of both responsiveness and reliability.
    
    /// Revert cursor back to normal
    //        if (inputIsPointerMovement) [NSCursor.closedHandCursor pop];
}


/// Helper functions

@end
