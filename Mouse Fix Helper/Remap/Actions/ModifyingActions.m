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

CFMachPortRef _modfiedDragTap;
int64_t _modfiedDragThreshold;

CGPoint _modfiedDragOrigin;
MFModifiedInputState _modifiedDragState;
MFModifiedDragActivationAxis _modfiedDragActivationAxis;
NSString * _modifiedDragType;

IOHIDEventPhaseBits _modifiedDragDockSwipePhase;
IOHIDEventPhaseBits _modifiedDragGestureScrollPhase;

+ (void)load {
//    modifyingState = @{
//        @(4): @{
//                @"modyfyingDrag": @(kMFModifierStateInitialized),
//                @"modifyingScroll": @(kMFModifierStateInUse),
//        }
//    };
    
    // Create mouse moved input callback
    if (_modfiedDragTap == nil) {
        CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDragged); // TODO: Check which of the two is necessary
        _modfiedDragTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, otherMouseDraggedCallback, NULL);
        NSLog(@"_eventTap: %@", _modfiedDragTap);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _modfiedDragTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CGEventTapEnable(_modfiedDragTap, false);
    }
    _modfiedDragThreshold = 10;
}

CGEventRef otherMouseDraggedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    switch (_modifiedDragState) {
            
        case kMFModifiedInputStateNone:
        {
            // Disabling the callback triggers this function one more time apparently, aside form that case, this should never be be executed
            break;
        }
        case kMFModifiedInputStateInitialized:
        {
            CGPoint currMouseLoc = CGEventGetLocation(CGEventCreate(NULL));
            
            double xOfs = currMouseLoc.x - _modfiedDragOrigin.x;
            double yOfs = currMouseLoc.y - _modfiedDragOrigin.y;
            
            // Activate the modified drag if the mouse has been moved far enough from the point where the drag started
            if (MAX(fabs(xOfs), fabs(yOfs)) > _modfiedDragThreshold) {
                if (fabs(xOfs) < fabs(yOfs)) {
                    _modfiedDragActivationAxis = kMFModifiedDragActivationAxisVertical;
                } else {
                    _modfiedDragActivationAxis = kMFModifiedDragActivationAxisHorizontal;
                }
                _modifiedDragState = kMFModifiedInputStateActive; // Activate modified drag input!
                [ButtonInputParser resetInputParser]; // Reset input parser to prevent hold timer from firing
                [ModifyingActions deactivateModifiedScroll]; // Deactivate other potentially initalized modified input.
                
                if ([_modifiedDragType isEqualToString:@"threeFingerSwipe"]) {
                    _modifiedDragDockSwipePhase = kIOHIDEventPhaseBegan;
                } else if ([_modifiedDragType isEqualToString:@"twoFingerSwipe"]) {
                    [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0.0 deltaY:0.0 phase:kIOHIDEventPhaseMayBegin];
                    _modifiedDragGestureScrollPhase = kIOHIDEventPhaseBegan;
                }
                
            } else {
                return event;
            }
            
            break;
        }
        case kMFModifiedInputStateActive:
        {
            NSEvent *eNS = [NSEvent eventWithCGEvent:event];
            
            if ([_modifiedDragType isEqualToString:@"threeFingerSwipe"]) {
                if (_modfiedDragActivationAxis == kMFModifiedDragActivationAxisHorizontal) {
                    double delta = -[eNS deltaX]/1000;
                    [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:_modifiedDragDockSwipePhase];
                } else if (_modfiedDragActivationAxis == kMFModifiedDragActivationAxisVertical) {
                    double delta = [eNS deltaY]/1000;
                    [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:_modifiedDragDockSwipePhase];
                }
                _modifiedDragDockSwipePhase = kIOHIDEventPhaseChanged;
            } else if ([_modifiedDragType isEqualToString:@"twoFingerSwipe"]) {
                double deltaX = [eNS deltaX]*4;
                double deltaY = [eNS deltaY]*4;
                [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:deltaX deltaY:deltaY phase:_modifiedDragGestureScrollPhase];
                _modifiedDragGestureScrollPhase = kIOHIDEventPhaseChanged;
            }
            
        }
        default:
        {
            break;
        }
    }
    
    
    return event;
}

+ (void)initializeModifiedInputWithActionArray:(NSArray *)actionArray onButton:(int)button {

    for (NSDictionary *actionDict in actionArray) {
        NSString *type = actionDict[@"type"];
        NSString *subtype = actionDict[@"value"];
        if ([type isEqualToString:@"modifiedScroll"]) {
            
        } else if ([type isEqualToString:@"modifiedDrag"]) {
            _modfiedDragOrigin = CGEventGetLocation(CGEventCreate(NULL));
            _modifiedDragState = kMFModifiedInputStateInitialized;
            _modifiedDragType = subtype;
            CGEventTapEnable(_modfiedDragTap, true);
        }
//        modifiedState[@(button)][type] = @(kMFModifierStateInitialized);
    }
}
+ (void)deactivateAllInputModification {
    
    [self deactivateModifiedDrag];
    [self deactivateModifiedScroll];
}
+ (void)deactivateModifiedDrag {
    
    if (_modifiedDragState == kMFModifiedInputStateActive) {
        if ([_modifiedDragType isEqualToString:@"threeFingerSwipe"]) {
            if (_modfiedDragActivationAxis == kMFModifiedDragActivationAxisHorizontal) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeHorizontal phase:kIOHIDEventPhaseEnded];
            } else if (_modfiedDragActivationAxis == kMFModifiedDragActivationAxisVertical) {
                [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeVertical phase:kIOHIDEventPhaseEnded];
            }
        } else if ([_modifiedDragType isEqualToString:@"twoFingerSwipe"]) {
            [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
        }
    }
    CGEventTapEnable(_modfiedDragTap, false);
    _modifiedDragState = kMFModifiedInputStateNone;
    
    CGAssociateMouseAndMouseCursorPosition(true);
    CGDisplayShowCursor(CGMainDisplayID());
    
    // TODO: CHECK if we need to add more stuff here
}
+ (void)deactivateModifiedScroll {
    
}

+ (void)deactivateInputModificationForButton:(int)button {
    
}

@end
