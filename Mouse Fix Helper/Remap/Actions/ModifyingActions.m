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
    CFMachPortRef eventTap;
    int64_t usageThreshold;
    
    NSString * type;

    MFModifiedInputActivationState activationState;
    struct ActivationCondition activationCondition;
    
    CGPoint origin;
    MFModifiedDragUsageAxis usageAxis;
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
    if (_modifiedDrag.eventTap == nil) {
        CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDragged); // TODO: Check which of the two is necessary
        _modifiedDrag.eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, otherMouseDraggedCallback, NULL);
        NSLog(@"_eventTap: %@", _modifiedDrag.eventTap);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _modifiedDrag.eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CGEventTapEnable(_modifiedDrag.eventTap, false);
    }
    _modifiedDrag.usageThreshold = 15;
}

CGEventRef otherMouseDraggedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    switch (_modifiedDrag.activationState) {
            
        case kMFModifiedInputActivationStateNone:
        {
            // Disabling the callback triggers this function one more time apparently, aside form that case, this should never be be executed
            break;
        }
        case kMFModifiedInputActivationStateInitialized:
        {
            CGPoint currMouseLoc = CGEventGetLocation(CGEventCreate(NULL));
            
            double xOfs = currMouseLoc.x - _modifiedDrag.origin.x;
            double yOfs = currMouseLoc.y - _modifiedDrag.origin.y;
            
            // Activate the modified drag if the mouse has been moved far enough from the point where the drag started
            if (MAX(fabs(xOfs), fabs(yOfs)) > _modifiedDrag.usageThreshold) {
                if (fabs(xOfs) < fabs(yOfs)) {
                    _modifiedDrag.usageAxis = kMFModifiedDragUsageAxisVertical;
                } else {
                    _modifiedDrag.usageAxis = kMFModifiedDragUsageAxisHorizontal;
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
                
            } else {
                return event;
            }
            
            break;
        }
        case kMFModifiedInputActivationStateInUse:
        {
            NSEvent *eNS = [NSEvent eventWithCGEvent:event];
            
            if ([_modifiedDrag.type isEqualToString:@"threeFingerSwipe"]) {
                if (_modifiedDrag.usageAxis == kMFModifiedDragUsageAxisHorizontal) {
                    double delta = -[eNS deltaX]/1000;
//                    delta *= 1;
                    [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:_modifiedDrag.phase];
                } else if (_modifiedDrag.usageAxis == kMFModifiedDragUsageAxisVertical) {
                    double delta = [eNS deltaY]/1000;
//                    delta *= 2; // It's a bit harder to make large vertical movements on a mouse
                    [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:_modifiedDrag.phase];
                }
                _modifiedDrag.phase = kIOHIDEventPhaseChanged;
            } else if ([_modifiedDrag.type isEqualToString:@"twoFingerSwipe"]) {
                int deltaX = round([eNS deltaX]);
//                deltaX *= 1;
                int deltaY = round([eNS deltaY]);
//                deltaY *= 2;
                [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:deltaX deltaY:deltaY phase:_modifiedDrag.phase];
                _modifiedDrag.phase = kIOHIDEventPhaseChanged;
            }
            
        }
        default:
        {
            break;
        }
    }
    
    
    return event;
}

+ (void)initializeModifiedInputsWithActionArray:(NSArray *)actionArray withActivationCondtion:(struct ActivationCondition)activationCondition {
    for (NSDictionary *actionDict in actionArray) {
        NSString *type = actionDict[@"type"];
        NSString *subtype = actionDict[@"value"];
        
        if ([type isEqualToString:@"modifiedDrag"]) {
            _modifiedDrag.activationState = kMFModifiedInputActivationStateInitialized;
            _modifiedDrag.type = subtype;
            _modifiedDrag.activationCondition = activationCondition;
            _modifiedDrag.origin = CGEventGetLocation(CGEventCreate(NULL));
            CGEventTapEnable(_modifiedDrag.eventTap, true);
        } else if ([type isEqualToString:@"modifiedScroll"]) {
            
        } else if ([type isEqualToString:@"fakeDrag"]) {
            
        }
    }
}

+ (void)deactivateAllInputModificationConditionedOnButton:(int64_t)button {
    if (_modifiedDrag.activationCondition.type == kMFActivationConditionTypeMouseButtonPressed
        && _modifiedDrag.activationCondition.value == button) {
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
            if (_modifiedDrag.usageAxis == kMFModifiedDragUsageAxisHorizontal) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeHorizontal phase:kIOHIDEventPhaseEnded];
            } else if (_modifiedDrag.usageAxis == kMFModifiedDragUsageAxisVertical) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeVertical phase:kIOHIDEventPhaseEnded];
            }
        } else if ([_modifiedDrag.type isEqualToString:@"twoFingerSwipe"]) {
            [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
        }
    }
    CGEventTapEnable(_modifiedDrag.eventTap, false);
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
