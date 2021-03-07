//
// --------------------------------------------------------------------------
// ModifyingActions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Constants.h"

#import "ModifiedDrag.h"
#import "ScrollModifiers.h"
#import "TouchSimulator.h"
#import "GestureScrollSimulator.h"
#import "ModifierManager.h"

#import "SubPixelator.h"
#import <Cocoa/Cocoa.h>

#import "Utility_Transformation.h"

@implementation ModifiedDrag

struct ModifiedDragState {
    CFMachPortRef eventTap;
    int64_t usageThreshold;
    
    MFStringConstant type;

    MFModifiedInputActivationState activationState;
    MFDevice *modifiedDevice;
    
    CGPoint origin;
    MFVector originOffset;
    MFAxis usageAxis;
    IOHIDEventPhaseBits phase;
    
    SubPixelator *subPixelatorX;
    SubPixelator *subPixelatorY;
    
    MFMouseButtonNumber fakeDragButtonNumber; // Button number for the fake drag type
};

static struct ModifiedDragState _drag;

#define scrollDispatchDelay 0 // In ms // Thought this would help when using pointer movement as input, but it doesn't
#define inputIsPointerMovement YES
// There are two different modes for how we receive mouse input, toggle to switch between the two for testing
// Set to no, if you want input to be raw mouse input, set to yes if you want input to be mouse pointer delta
// Raw input has better performance (?) and allows for blocking mouse pointer movement. Mouse pointer input makes all the animation follow the pointer, but it has some issues with the pointer jumping when the framerate is low which I'm not quite sure how to fix.
//      When the pointer jumps that sometimes leads to scrolling in random directions and stuff.

+ (void)load {
    
    if (inputIsPointerMovement) {
        // Create mouse pointer moved input callback
        if (_drag.eventTap == nil) {
            CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDragged); // TODO: Check which of the two is necessary
            _drag.eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, otherMouseDraggedCallback, NULL);
            NSLog(@"_eventTap: %@", _drag.eventTap);
            CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _drag.eventTap, 0);
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
            CFRelease(runLoopSource);
            CGEventTapEnable(_drag.eventTap, false);
        }
        _drag.usageThreshold = 20;
    } else {
        _drag.usageThreshold = 50;
    }
}

+ (void)initializeithModifiedDragDict:(NSDictionary *)dict onDevice:(MFDevice *)dev {
    
    // Get values from dict
    MFStringConstant type = dict[kMFModifiedDragDictKeyType];
    MFMouseButtonNumber fakeDragButtonNumber = -1;
    if ([type isEqualToString:kMFModifiedDragDictTypeFakeDrag]) {
        fakeDragButtonNumber = ((NSNumber *)dict[kMFModifiedDragDictKeyFakeDragVariantButtonNumber]).intValue;
    }
    
    #if DEBUG
        NSLog(@"INITIALIZING MODIFIED DRAG WITH TYPE %@ ON DEVICE %@", type, dev);
    #endif
    
    // Init _drag struct
    _drag.modifiedDevice = dev;
    _drag.activationState = kMFModifiedInputActivationStateInitialized;
    _drag.type = type;
    _drag.origin = CGEventGetLocation(CGEventCreate(NULL));
    _drag.originOffset = (MFVector){0};
    _drag.subPixelatorX = [SubPixelator alloc];
    _drag.subPixelatorY = [SubPixelator alloc];
    _drag.fakeDragButtonNumber = fakeDragButtonNumber;
    
    if (inputIsPointerMovement) {
        CGEventTapEnable(_drag.eventTap, true);
    } else {
        [dev receiveAxisInputAndDoSeizeDevice:NO];
    }
}

static CGEventRef __nullable otherMouseDraggedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef  event, void * __nullable userInfo) {
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
    [ModifiedDrag handleMouseInputWithDeltaX:dx deltaY:dy];
    return event;
}

+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY {
#if DEBUG
    NSLog(@"handle mouse input. dx: %lld, dy: %lld", deltaX, deltaY);
#endif
    
    MFModifiedInputActivationState st = _drag.activationState;
            
    if (st == kMFModifiedInputActivationStateNone) {
        // Disabling the callback triggers this function one more time apparently, aside form that case, this should never happen
        
    } else if (st == kMFModifiedInputActivationStateInitialized) {
        
        _drag.originOffset.x += deltaX;
        _drag.originOffset.y += deltaY;
        
        MFVector ofs = _drag.originOffset;
        
        // Activate the modified drag if the mouse has been moved far enough from the point where the drag started
        if (MAX(fabs(ofs.x), fabs(ofs.y)) > _drag.usageThreshold) {
            
            MFDevice *dev = _drag.modifiedDevice;
            if (inputIsPointerMovement) {
                [NSCursor.closedHandCursor set]; // Doesn't work for some reason
            } else {
                if ([_drag.type isEqualToString:kMFModifiedDragDictTypeTwoFingerSwipe]) { // Only seize when drag scrolling // TODO: Would be cleaner to call this further down where we check for kMFModifiedDragVariantTwoFingerSwipe anyways. Does that work too?
                    [dev receiveAxisInputAndDoSeizeDevice:YES];
                }
            }
            _drag.activationState = kMFModifiedInputActivationStateInUse; // Activate modified drag input!
            [ModifierManager handleModifiersHaveHadEffect:dev.uniqueID];
            
            if (fabs(ofs.x) < fabs(ofs.y)) {
                _drag.usageAxis = kMFAxisVertical;
            } else {
                _drag.usageAxis = kMFAxisHorizontal;
            }
            
            if ([_drag.type isEqualToString:kMFModifiedDragDictTypeThreeFingerSwipe]) {
                _drag.phase = kIOHIDEventPhaseBegan;
            } else if ([_drag.type isEqualToString:kMFModifiedDragDictTypeTwoFingerSwipe]) {
//                [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0.0 deltaY:0.0 phase:kIOHIDEventPhaseMayBegin];
                    // ^ Always sending this at the start breaks swiping between pages on some websites (Google search results)
                _drag.phase = kIOHIDEventPhaseBegan;
            } else if ([_drag.type isEqualToString:kMFModifiedDragDictTypeFakeDrag]) {
                [Utility_Transformation postMouseButton:_drag.fakeDragButtonNumber down:YES];
                disableMouseTracking();
            }
        }
        
    } else if (st == kMFModifiedInputActivationStateInUse) {
        
        double sTwoFinger;
        double sThreeFingerH;
        double sThreeFingerV;
        
        if (inputIsPointerMovement) { // With these values, the scrolling/changing spaces will follow the mouse pointer almost exactly
            CGFloat screenHeight = [[NSScreen mainScreen] frame].size.height;
            sThreeFingerH = sThreeFingerV = 0.8 / screenHeight;
            sThreeFingerV *= 3; // Vertical doesn't follow mouse pointer anyways, so might as well scale it up
            sTwoFinger = 1.0;
        } else {
            sThreeFingerH = sThreeFingerV = 5 / 10000.0;;
            sTwoFinger = 0.5;
        }
        
//        NSLog(@"deltaX: %f", deltaX);

        if ([_drag.type isEqualToString:kMFModifiedDragDictTypeThreeFingerSwipe]) {
            
            if (_drag.usageAxis == kMFAxisHorizontal) {
                double delta = -deltaX * sThreeFingerH;
                [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:_drag.phase];
            } else if (_drag.usageAxis == kMFAxisVertical) {
                double delta = deltaY * sThreeFingerV;
                [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:_drag.phase];
            }
            _drag.phase = kIOHIDEventPhaseChanged;
        } else if ([_drag.type isEqualToString:kMFModifiedDragDictTypeTwoFingerSwipe]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, scrollDispatchDelay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                [GestureScrollSimulator postGestureScrollEventWithDeltaX:deltaX*sTwoFinger deltaY:deltaY*sTwoFinger phase:_drag.phase isGestureDelta:!inputIsPointerMovement];
            });
        }
        _drag.phase = kIOHIDEventPhaseChanged;
    }
}

+ (void)deactivate {
    
#if DEBUG
    NSLog(@"DEACTIVE MODIFIED DRAG");
#endif
    
    if (_drag.activationState == kMFModifiedInputActivationStateNone) return;
    
    if (_drag.activationState == kMFModifiedInputActivationStateInUse) {
        if ([_drag.type isEqualToString:kMFModifiedDragDictTypeThreeFingerSwipe]) {
            if (_drag.usageAxis == kMFAxisHorizontal) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeHorizontal phase:kIOHIDEventPhaseEnded];
            } else if (_drag.usageAxis == kMFAxisVertical) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeVertical phase:kIOHIDEventPhaseEnded];
            }
        } else if ([_drag.type isEqualToString:kMFModifiedDragDictTypeTwoFingerSwipe]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, scrollDispatchDelay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded isGestureDelta:!inputIsPointerMovement];
            });
        } else if ([_drag.type isEqualToString:kMFModifiedDragDictTypeFakeDrag]) {
            [Utility_Transformation postMouseButton:_drag.fakeDragButtonNumber down:NO];
        }
    }
    disableMouseTracking();
    _drag.activationState = kMFModifiedInputActivationStateNone;
    
//    CGAssociateMouseAndMouseCursorPosition(true); // Doesn't work
//    CGDisplayShowCursor(CGMainDisplayID());
    
    // TODO: CHECK if we need to add more stuff here
}

static void disableMouseTracking() {
    if (inputIsPointerMovement) {
        CGEventTapEnable(_drag.eventTap, false);
        [NSCursor.closedHandCursor pop];
    } else {
        [_drag.modifiedDevice receiveOnlyButtonInput];
    }
}


@end
