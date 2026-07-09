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

@implementation ModifiedDragOutputThreeFingerSwipe

/// Vars

static ModifiedDragState *_drag;

static int16_t _nOfSpaces = 1;
static BOOL _didFreezePointer = NO;
static BOOL _dockSwipeBegan = NO;
static BOOL _dockSwipeSuppressedUntilRelease = NO;
static CGRect _dragOriginScreenBounds;

static BOOL shouldUseAnchoredDockSwipeEvents(void) {

    return [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){27, 0, 0}];
}

static CGRect screenBoundsContainingPoint(CGPoint point) {

    uint32_t displayCount = 0;
    CGDirectDisplayID displays[16];
    if (CGGetActiveDisplayList(16, displays, &displayCount) == kCGErrorSuccess) {
        for (uint32_t i = 0; i < displayCount; i++) {
            CGRect bounds = CGDisplayBounds(displays[i]);
            if (CGRectContainsPoint(bounds, point)) {
                return bounds;
            }
        }
    }

    return CGDisplayBounds(CGMainDisplayID());
}

static CGSize screenSizeForDragOrigin(void) {

    return screenBoundsContainingPoint(_drag->usageOrigin).size;
}

static CGPoint eventLocation(CGEventRef event) {

    if (event != NULL) {
        return CGEventGetLocation(event);
    }

    CGEventRef currentEvent = CGEventCreate(NULL);
    CGPoint location = currentEvent ? CGEventGetLocation(currentEvent) : _drag->usageOrigin;
    if (currentEvent) CFRelease(currentEvent);
    return location;
}

static MFDockSwipeType currentDockSwipeType(void) {

    if (_drag->usageAxis == kMFAxisHorizontal) {
        return kMFDockSwipeTypeHorizontal;
    } else if (_drag->usageAxis == kMFAxisVertical) {
        return kMFDockSwipeTypeVertical;
    } else {
        assert(false);
        return kMFDockSwipeTypeHorizontal;
    }
}

static void endDockSwipeAtDragOrigin(void) {

    if (!_dockSwipeBegan) return;

    [TouchSimulator postDockSwipeEventWithDelta:0.0 type:currentDockSwipeType() phase:kIOHIDEventPhaseEnded invertedFromDevice:_drag->naturalDirection atPosition:_drag->usageOrigin];
    _dockSwipeBegan = NO;
}

static BOOL endDockSwipeIfPointerLeftOriginScreen(CGEventRef event) {

    if (!shouldUseAnchoredDockSwipeEvents()) return NO;

    CGPoint currentLocation = eventLocation(event);
    if (!_dockSwipeSuppressedUntilRelease && CGRectContainsPoint(_dragOriginScreenBounds, currentLocation)) return NO;

    endDockSwipeAtDragOrigin();
    _dockSwipeSuppressedUntilRelease = YES;
    return YES;
}

/// Interface funcs

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
}

+ (void)handleBecameInUse {

    _didFreezePointer = NO;
    _dockSwipeBegan = NO;
    _dockSwipeSuppressedUntilRelease = NO;
    _dragOriginScreenBounds = screenBoundsContainingPoint(_drag->usageOrigin);

    /// Get number of spaces
    ///     for use in `handleMouseInputWhileInUse()`. Getting it here for performance reasons. Not sure if significant.
    CFArrayRef spaces = CGSCopySpaces(CGSMainConnectionID(), CGSSpaceIncludesUser | CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent);
    /// Full screen spaces appear twice for some reason so we need to filter duplicates
    NSSet *uniqueSpaces = [NSSet setWithArray:(__bridge NSArray *)spaces];
    _nOfSpaces = uniqueSpaces.count;
    
    CFRelease(spaces);
    
    /// Freeze pointer only when the user configured it. The macOS 27 Dock-swipe path keeps the real pointer free and
    /// anchors only the synthetic event position; if the real pointer crosses displays, we end this gesture stream.
    if (GeneralConfig.freezePointerDuringModifiedDrag && !shouldUseAnchoredDockSwipeEvents()) {
        [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
        _didFreezePointer = YES;
    }
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /**
     Horizontal dockSwipe scaling
     This makes horizontal dockSwipes (switch between spaces) follow the pointer exactly
     I arrived at these value through testing documented in the NotePlan note "MMF - Scraps - Testing DockSwipe scaling"
     TODO: Test this on a vertical screen
     */
    CGSize screenSize = screenSizeForDragOrigin();
    double originOffsetForOneSpace = _nOfSpaces == 1 ? 2.0 : 1.0 + (1.0 / (_nOfSpaces-1));
    double spaceSeparatorWidth = 63;
    double threeFingerScaleH = originOffsetForOneSpace / (screenSize.width + spaceSeparatorWidth);
    
    /// Vertical dockSwipe scaling
    ///     Not sure if it makes sense to scale this with screen height
    double threeFingerScaleV = 1.0 / screenSize.height;

    if (endDockSwipeIfPointerLeftOriginScreen(event)) return;
    
    /// Get phase
    
    IOHIDEventPhaseBits eventPhase = _dockSwipeBegan ? kIOHIDEventPhaseChanged : kIOHIDEventPhaseBegan;
    
    /// Send events
    
    if (_drag->usageAxis == kMFAxisHorizontal) {
        double delta = -deltaX * threeFingerScaleH;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:eventPhase invertedFromDevice:_drag->naturalDirection atPosition:_drag->usageOrigin];
        _dockSwipeBegan = YES;
    } else if (_drag->usageAxis == kMFAxisVertical) {
        double delta = deltaY * threeFingerScaleV;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:eventPhase invertedFromDevice:_drag->naturalDirection atPosition:_drag->usageOrigin];
        _dockSwipeBegan = YES;
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    
    MFDockSwipeType type = currentDockSwipeType();
    IOHIDEventPhaseBits phase;
    
    phase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
    
    if (_dockSwipeBegan) {
        [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:phase invertedFromDevice:_drag->naturalDirection atPosition:_drag->usageOrigin];
        _dockSwipeBegan = NO;
    }
    _dockSwipeSuppressedUntilRelease = NO;
    
    /// Unfreeze pointer
    if (_didFreezePointer) {
        [PointerFreeze unfreeze];
        _didFreezePointer = NO;
    }
    
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
