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
#import "MessagePort_HelperApp.h"
#import "TransformationManager.h"
#import "SharedUtility.h"

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
    
    MFMouseButtonNumber fakeDragButtonNumber; // Button number. Only used with modified drag of type kMFModifiedDragTypeFakeDrag.
    NSDictionary *addModePayload; // Payload to send to the mainApp. Only used with modified drag of type kMFModifiedDragTypeAddModeFeedback.
};

+ (NSString *)modifiedDragStateDescription:(struct ModifiedDragState)drag {
    NSString *output = @"";
    @try {
        output = [NSString stringWithFormat:
@"\n\
eventTap: %@\n\
usageThreshold: %lld\n\
type: %@\n\
activationState: %u\n\
modifiedDevice: \n%@\n\
origin: (%f, %f)\n\
originOffset: (%f, %f)\n\
usageAxis: %u\n\
phase: %hu\n\
subPixelatorX: %@\n\
subPixelatorY: %@\n\
fakeDragButtonNumber: %u\n\
addModePayload: %@\n",
                  drag.eventTap, drag.usageThreshold, drag.type, drag.activationState, drag.modifiedDevice, drag.origin.x, drag.origin.y, drag.originOffset.x, drag.originOffset.y, drag.usageAxis, drag.phase, drag.subPixelatorX, drag.subPixelatorY, drag.fakeDragButtonNumber, drag.addModePayload
                  ];
    } @catch (NSException *exception) {
        NSLog(@"Exception while generating string description of ModifiedDragState: %@", exception);
    }
    return output;
}

static struct ModifiedDragState _drag;

dispatch_queue_t _fakeInputQueue;

#define scrollDispatchDelay 0 // In ms // Thought this would help when using pointer movement as input, but it doesn't
#define navigationDispatchDelay 0 // In ms // This seems to help against navigation-swipe-modified-drags getting stuck. But maybe it's the threading/using queues we used to facilitate this.
#define inputIsPointerMovement YES
// There are two different modes for how we receive mouse input, toggle to switch between the two for testing
// Set to no, if you want input to be raw mouse input, set to yes if you want input to be mouse pointer delta
// Raw input has better performance (?) and allows for blocking mouse pointer movement. Mouse pointer input makes all the animation follow the pointer, but it has some issues with the pointer jumping when the framerate is low which I'm not quite sure how to fix.
//      When the pointer jumps that sometimes leads to scrolling in random directions and stuff.

+ (void)load {
    
    // Setup fakeInputQueue
    // Create custom dispatch queue so we have control over execution order and stuff
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
    _fakeInputQueue = dispatch_queue_create("mf.fake.input.queue", attr);
    
    // Setup input callback and related
    if (inputIsPointerMovement) {
        // Create mouse pointer moved input callback
        if (_drag.eventTap == nil) {
            CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDragged) | CGEventMaskBit(kCGEventMouseMoved); // kCGEventMouseMoved is only necessary for keyboard only drag modification, and maybe for AddMode to work.
            _drag.eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, mouseMovedOrDraggedCallback, NULL);
            // ^ Make sure to use the same EventTapLocation and EventTapPlacement here as you do in ButtonInputReceiver, otherwise there'll be timing and ordering issues!
            //      This fixed the stuck-bug! (I think) (The bug where fake navigation swipes would sometimes get stuck mid animation after releasing the modifying button)
            //      As well as the problem, where mouse movement capturing would still be active after releasing the button leading to weird UX.
            //      -> Nopee it didn't fix the stuck-bug. It seems to have fixed it on horizontal navigation swipes, but on vertical ones it's worse than ever.
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

+ (void)initializeWithModifiedDragDict:(NSDictionary *)dict onDevice:(MFDevice *)dev {
    
    // Get values from dict
    MFStringConstant type = dict[kMFModifiedDragDictKeyType];
    MFMouseButtonNumber fakeDragButtonNumber = -1;
    if ([type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
        fakeDragButtonNumber = ((NSNumber *)dict[kMFModifiedDragDictKeyFakeDragVariantButtonNumber]).intValue;
    }
    // Prepare payload to send to mainApp during addMode. See TransformationManager -> AddMode for context
    NSMutableDictionary *payload = nil;
    if ([type isEqualToString:kMFModifiedDragDictKeyType]){
        payload = dict.mutableCopy;
        [payload removeObjectForKey:kMFModifiedDragDictKeyType];
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
    _drag.addModePayload = payload;
    
    if (inputIsPointerMovement) {
        CGEventTapEnable(_drag.eventTap, true);
    } else {
        [dev receiveAxisInputAndDoSeizeDevice:NO];
    }
}

static CGEventRef __nullable mouseMovedOrDraggedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef  event, void * __nullable userInfo) {
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
    [ModifiedDrag handleMouseInputWithDeltaX:dx deltaY:dy];
    return event;
}

+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY {
#if DEBUG
    NSLog(@"Handling mouse input. dx: %lld, dy: %lld", deltaX, deltaY);
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
                [NSCursor.closedHandCursor push]; // Doesn't work for some reason
            } else {
                if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) { // Only seize when drag scrolling // TODO: Would be cleaner to call this further down where we check for kMFModifiedDragVariantTwoFingerSwipe anyways. Does that work too?
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
            
            if ([_drag.type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
                _drag.phase = kIOHIDEventPhaseBegan;
            } else if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
//                [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0.0 deltaY:0.0 phase:kIOHIDEventPhaseMayBegin];
                    // ^ Always sending this at the start breaks swiping between pages on some websites (Google search results)
                _drag.phase = kIOHIDEventPhaseBegan;
            } else if ([_drag.type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
                [Utility_Transformation postMouseButton:_drag.fakeDragButtonNumber down:YES];
                disableMouseTracking();
            } else if ([_drag.type isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
                [MessagePort_HelperApp sendMessageToMainApp:@"addModeFeedback" withPayload:_drag.addModePayload];
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

        if ([_drag.type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
            // When we dispatch this to another queue, nothing works at all.
            //      -> I think it's because we didn't understand how block capture variables. See https://stackoverflow.com/questions/15117992/why-does-this-block-not-capture-variable-value-at-time-of-creation
            //      We figured the block stuff out, but its slower than just doing everything sequentially I think, and the bug with fake 3fingerswipes getting stuck still occurs
            
            // Create local copies of variables, so that block captures the values at the current time (at declaration time, not at time of execution)
            struct ModifiedDragState localDrag = _drag;
            double localSThreeFingerH = sThreeFingerH;
            double localSThreeFingerV = sThreeFingerV;
            double localDeltaX = deltaX;
            double localDeltaY = deltaY;
            
            dispatch_async(_fakeInputQueue, ^{
                if (localDrag.usageAxis == kMFAxisHorizontal) {
                    double delta = -localDeltaX * localSThreeFingerH;
                    [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:localDrag.phase];
                } else if (localDrag.usageAxis == kMFAxisVertical) {
                    double delta = localDeltaY * localSThreeFingerV;
                    [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:localDrag.phase];
                }
                if (!(localDrag.activationState == kMFModifiedInputActivationStateInUse)) {
                    NSLog(@"Modified drag not found in 'in-use' state right after sending mid-swipe event");
                    // ^ This hints at some race condition which might be causing stuck-bug
                    //      It just occured and this wasn't triggered
                }
                _drag.phase = kIOHIDEventPhaseChanged;
            });
        } else if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, scrollDispatchDelay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                [GestureScrollSimulator postGestureScrollEventWithDeltaX:deltaX*sTwoFinger deltaY:deltaY*sTwoFinger phase:_drag.phase isGestureDelta:!inputIsPointerMovement];
            });
        }
        _drag.phase = kIOHIDEventPhaseChanged;
    }
}

+ (void)deactivate {
    
#if DEBUG
    NSLog(@"Deactivating modified drag with state: %@", [self modifiedDragStateDescription:_drag]);
#endif
    
    if (_drag.activationState == kMFModifiedInputActivationStateNone) return;

    // TODO: Investigate - Moving this code up here causes stuck bug every time
//    _drag.activationState = kMFModifiedInputActivationStateNone;
//    disableMouseTracking();
    
    if (_drag.activationState == kMFModifiedInputActivationStateInUse) {
        if ([_drag.type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
//            NSLog(@"BEFORE DISPATCH (swipeDeactivated) queue %@, thread: %@", [SharedUtility currentDispatchQueueDescription], NSThread.currentThread);
            struct ModifiedDragState localDrag = _drag;
            dispatch_async(_fakeInputQueue, ^{
                if (localDrag.usageAxis == kMFAxisHorizontal) {
                    [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeHorizontal phase:kIOHIDEventPhaseEnded];
                } else if (localDrag.usageAxis == kMFAxisVertical) {
                    [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeVertical phase:kIOHIDEventPhaseEnded];
                }
            });
        } else if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, scrollDispatchDelay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded isGestureDelta:!inputIsPointerMovement];
            });
        } else if ([_drag.type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
            [Utility_Transformation postMouseButton:_drag.fakeDragButtonNumber down:NO];
        } else if ([_drag.type isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
            [TransformationManager disableAddMode];
        }
    }
    
    _drag.activationState = kMFModifiedInputActivationStateNone;
    disableMouseTracking();
    
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
