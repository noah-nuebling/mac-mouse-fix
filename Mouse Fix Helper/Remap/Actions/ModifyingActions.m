//
// --------------------------------------------------------------------------
// ModifyingActions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ModifyingActions.h"
#import "ScrollModifiers.h"
#import "ButtonInputParser.h"
#import "TouchSimulator.h"
#import "GestureScrollSimulator.h"

@implementation ModifyingActions

struct ModifiedDragState {
//    CFMachPortRef eventTap;
    int64_t usageThreshold;
    
    NSString * type;

    MFModifiedInputActivationState activationState;
    MFActivationCondition activationCondition;
    
    CGPoint origin;
    MFVector originOffset;
    MFAxis usageAxis;
    IOHIDEventPhaseBits phase;
};

static struct ModifiedDragState _modifiedDrag;

+ (void)load {
//    modifyingState = @{
//        @(4): @{
//                @"modyfyingDrag": @(kMFModifierStateInitialized),
//                @"modifyingScroll": @(kMFModifierStateInUse),
//        }
//    };
    
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
    _modifiedDrag.usageThreshold = 32;
}

+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY {
    
//    NSLog(@"handle mouse input. dx: %d, dy: %d", deltaX, deltaY);
    
    switch (_modifiedDrag.activationState) {
            
        case kMFModifiedInputActivationStateNone:
        {
            // Disabling the callback triggers this function one more time apparently, aside form that case, this should never be be executed
            break;
        }
        case kMFModifiedInputActivationStateInitialized:
        {
            _modifiedDrag.originOffset.x += deltaX;
            _modifiedDrag.originOffset.y += deltaY;
            
            MFVector ofs = _modifiedDrag.originOffset;
            
            // Activate the modified drag if the mouse has been moved far enough from the point where the drag started
            if (MAX(fabs(ofs.x), fabs(ofs.y)) > _modifiedDrag.usageThreshold) {
                
                MFDevice *dev = _modifiedDrag.activationCondition.activatingDevice;
                [dev receiveButtonAndAxisInputWithSeize:YES];
                
                if (fabs(ofs.x) < fabs(ofs.y)) {
                    _modifiedDrag.usageAxis = kMFAxisVertical;
                } else {
                    _modifiedDrag.usageAxis = kMFAxisHorizontal;
                }
                _modifiedDrag.activationState = kMFModifiedInputActivationStateInUse; // Activate modified drag input!
                [ButtonInputParser reset]; // Reset input parser to prevent hold timer from firing
//                [ModifyingActions deactivateModifiedScroll]; // Deactivate other potentially initalized modified input.
                
                if ([_modifiedDrag.type isEqualToString:@"threeFingerSwipe"]) {
                    _modifiedDrag.phase = kIOHIDEventPhaseBegan;
                } else if ([_modifiedDrag.type isEqualToString:@"twoFingerSwipe"]) {
                    [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0.0 deltaY:0.0 phase:kIOHIDEventPhaseMayBegin];
                    _modifiedDrag.phase = kIOHIDEventPhaseBegan;
                }
                
            }
//            else {
//                return event;
//            }
            
            break;
        }
        case kMFModifiedInputActivationStateInUse:
        {
            

//
//            if ([_modifiedDrag.type isEqualToString:@"threeFingerSwipe"]) {
//
//                if (_modifiedDrag.usageAxis == axis) {
//                    double delta = IOHIDValueGetIntegerValue(inputValue) / 1000.0;
//                    if (axis == kMFAxisHorizontal) {
//                        [TouchSimulator postDockSwipeEventWithDelta:-delta type:kMFDockSwipeTypeHorizontal phase:_modifiedDrag.phase];
//                    } else if (axis == kMFAxisVertical) {
//                        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:_modifiedDrag.phase];
//                    }
//                    _modifiedDrag.phase = kIOHIDEventPhaseChanged;
//                }
//            } else if ([_modifiedDrag.type isEqualToString:@"twoFingerSwipe"]) {
//
//                int64_t deltaX = 0;
//                int64_t deltaY = 0;
//
//                if (axis == kMFAxisHorizontal) {
//                    deltaX = IOHIDValueGetIntegerValue(inputValue);
//                }
//                if (axis == kMFAxisVertical) {
//                    deltaY = IOHIDValueGetIntegerValue(inputValue);
//                }
//                [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:deltaX deltaY:deltaY phase:_modifiedDrag.phase];
//                _modifiedDrag.phase = kIOHIDEventPhaseChanged;
//            }

            if ([_modifiedDrag.type isEqualToString:@"threeFingerSwipe"]) {
                if (_modifiedDrag.usageAxis == kMFAxisHorizontal) {
                    double delta = -deltaX/1000.0;
//                    delta *= 1;
                    [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:_modifiedDrag.phase];
                } else if (_modifiedDrag.usageAxis == kMFAxisVertical) {
                    double delta = deltaY/1000.0;
//                    delta *= 2; // It's a bit harder to make large vertical movements on a mouse
                    [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:_modifiedDrag.phase];
                }
                _modifiedDrag.phase = kIOHIDEventPhaseChanged;
            } else if ([_modifiedDrag.type isEqualToString:@"twoFingerSwipe"]) {
                
                double scale = 1.0;
                
                [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:deltaX * scale deltaY:deltaY * scale phase:_modifiedDrag.phase];
                _modifiedDrag.phase = kIOHIDEventPhaseChanged;
            }
            
        }
        default:
        {
            break;
        }
    }
    
    
//    return event;
}

+ (void)initializeModifiedInputsWithActionArray:(NSArray *)actionArray withActivationCondition:(MFActivationCondition *)activationCondition {
    for (NSDictionary *actionDict in actionArray) {
        NSString *type = actionDict[@"type"];
        NSString *subtype = actionDict[@"value"];
        
        if ([type isEqualToString:@"modifiedDrag"]) {
            
            _modifiedDrag.activationState = kMFModifiedInputActivationStateInitialized;
            _modifiedDrag.type = subtype;
            _modifiedDrag.activationCondition = *activationCondition;
            _modifiedDrag.origin = CGEventGetLocation(CGEventCreate(NULL));
            _modifiedDrag.originOffset = (MFVector){};
            
            
//            CGEventTapEnable(_modifiedDrag.eventTap, true);
            MFDevice *dev = _modifiedDrag.activationCondition.activatingDevice;
            
            [dev receiveButtonAndAxisInputWithSeize:NO];
            
            
            
            
        } else if ([type isEqualToString:@"modifiedScroll"]) {
            
        } else if ([type isEqualToString:@"fakeDrag"]) {
            
        }
    }
}

+ (void)deactivateAllInputModificationWithActivationCondition:(MFActivationCondition *)falsifiedCondition {
    if (_modifiedDrag.activationCondition.type == kMFActivationConditionTypeMouseButtonPressed
        && _modifiedDrag.activationCondition.value == falsifiedCondition->value
        && _modifiedDrag.activationCondition.activatingDevice == falsifiedCondition->activatingDevice)
    {
        [self deactivateModifiedDrag];
    }
//    if (_modifiedScroll.activationCondition.type == kMFActivationConditionTypeMouseButtonPressed
//        && _modifiedScroll.activationCondition.type.activationCondition.value == button) {
//        [self deactivateModifiedScroll];
//    }
//    if (_fakeDrag.activationCondition.type == kMFActivationConditionTypeMouseButtonPressed
//        && _fakeDrag.activationCondition.type.activationCondition.value == button) {
//        [self deactivateFakeDrag];
//    }
}
+ (void)deactivateModifiedDrag {
    
    if (_modifiedDrag.activationState == kMFModifiedInputActivationStateInUse) {
        if ([_modifiedDrag.type isEqualToString:@"threeFingerSwipe"]) {
            if (_modifiedDrag.usageAxis == kMFAxisHorizontal) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeHorizontal phase:kIOHIDEventPhaseEnded];
            } else if (_modifiedDrag.usageAxis == kMFAxisVertical) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeVertical phase:kIOHIDEventPhaseEnded];
            }
        } else if ([_modifiedDrag.type isEqualToString:@"twoFingerSwipe"]) {
            [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
        }
    }
//    CGEventTapEnable(_modifiedDrag.eventTap, false);
    MFDevice *dev = _modifiedDrag.activationCondition.activatingDevice;
    [dev receiveOnlyButtonInput];
    _modifiedDrag.activationState = kMFModifiedInputActivationStateNone;
    
//    CGAssociateMouseAndMouseCursorPosition(true); // Doesn't work
//    CGDisplayShowCursor(CGMainDisplayID());
    
    // TODO: CHECK if we need to add more stuff here
}

+ (BOOL)anyModifiedInputIsInUseForButton:(int64_t)button {
    
    if (_modifiedDrag.activationState == kMFModifiedInputActivationStateInUse
        && _modifiedDrag.activationCondition.type == kMFActivationConditionTypeMouseButtonPressed
        && _modifiedDrag.activationCondition.value == button) {
        return YES;
    }
    
    // TODO: v Update this function for all modified input types
    
//    if (_fakeDrag.activationState == kMFModifiedInputActivationStateInUse
//        && _fakeDrag.activationCondition.type == kMFActivationConditionTypeMouseButtonPressed
//        && _fakeDrag.activationCondition.value == button) {
//        return YES;
//    }
//
//    if (_modifiedScroll.activationState == kMFModifiedInputActivationStateInUse
//        && _modifiedScroll.activationCondition.type == kMFActivationConditionTypeMouseButtonPressed
//        && _modifiedScroll.activationCondition.value == button) {
//        return YES;
//    }
    
    return NO;
    
}


@end
