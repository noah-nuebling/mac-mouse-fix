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

@implementation ModifiedDrag

struct ModifiedDragState {
//    CFMachPortRef eventTap;
    int64_t usageThreshold;
    
    MFStringConstant type;

    MFModifiedInputActivationState activationState;
    MFDevice *modifiedDevice;
    
    CGPoint origin;
    MFVector originOffset;
    MFAxis usageAxis;
    IOHIDEventPhaseBits phase;
};

static struct ModifiedDragState _drag;

+ (void)load {
    
    // Create mouse moved input callback
//    if (_modifiedDrag.eventTap == nil) {
//        CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDragged); // TODO: Check which of the two is necessary
//        _modifiedDrag.eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, otherMouseDraggedCallback, NULL);
//        NSLog(@"_eventTap: %@", _modifiedDrag.eventTap);
//        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _modifiedDrag.eventTap, 0);
//        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
//        CFRelease(runLoopSource);
//        CGEventTapEnable(_modifiedDrag.eventTap, false);
//    }
    
    _drag.usageThreshold = 50;
}

+ (void)initializeithType:(MFStringConstant)type onDevice:(MFDevice *)dev {
            
    _drag.modifiedDevice = dev;
    _drag.activationState = kMFModifiedInputActivationStateInitialized;
    _drag.type = type;
    _drag.origin = CGEventGetLocation(CGEventCreate(NULL));
    _drag.originOffset = (MFVector){0};
    
    [dev receiveAxisInputAndDoSeizeDevice:NO];
}

+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY {
    
//    NSLog(@"handle mouse input. dx: %d, dy: %d", deltaX, deltaY);
    
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
            [dev receiveAxisInputAndDoSeizeDevice:YES];
            _drag.activationState = kMFModifiedInputActivationStateInUse; // Activate modified drag input!
            [ModifierManager handleModifiersHaveHadEffect:dev.uniqueID];
            
            if (fabs(ofs.x) < fabs(ofs.y)) {
                _drag.usageAxis = kMFAxisVertical;
            } else {
                _drag.usageAxis = kMFAxisHorizontal;
            }
            
            if ([_drag.type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
                _drag.phase = kIOHIDEventPhaseBegan;
            } else if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
                [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0.0 deltaY:0.0 phase:kIOHIDEventPhaseMayBegin];
                _drag.phase = kIOHIDEventPhaseBegan;
            }
        }
        
    } else if (st == kMFModifiedInputActivationStateInUse) {

        if ([_drag.type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
            if (_drag.usageAxis == kMFAxisHorizontal) {
                double delta = -deltaX/1000.0;
                [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:_drag.phase];
            } else if (_drag.usageAxis == kMFAxisVertical) {
                double delta = deltaY/1000.0;
                [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:_drag.phase];
            }
            _drag.phase = kIOHIDEventPhaseChanged;
        } else if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
            double scale = 1.0;
            [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:deltaX * scale deltaY:deltaY * scale phase:_drag.phase];
        }
        _drag.phase = kIOHIDEventPhaseChanged;
    }
}

+ (void)deactivate {
    
    if (_drag.activationState == kMFModifiedInputActivationStateNone) return;
    
    if (_drag.activationState == kMFModifiedInputActivationStateInUse) {
        if ([_drag.type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
            if (_drag.usageAxis == kMFAxisHorizontal) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeHorizontal phase:kIOHIDEventPhaseEnded];
            } else if (_drag.usageAxis == kMFAxisVertical) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeVertical phase:kIOHIDEventPhaseEnded];
            }
        } else if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
            [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
        }
    }
//    CGEventTapEnable(_modifiedDrag.eventTap, false);
    [_drag.modifiedDevice receiveOnlyButtonInput];
    _drag.activationState = kMFModifiedInputActivationStateNone;
    
//    CGAssociateMouseAndMouseCursorPosition(true); // Doesn't work
//    CGDisplayShowCursor(CGMainDisplayID());
    
    // TODO: CHECK if we need to add more stuff here
}


@end
