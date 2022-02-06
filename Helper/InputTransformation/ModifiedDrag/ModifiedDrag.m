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
#import "GestureScrollSimulator.h"
#import "ModifierManager.h"

#import "SubPixelator.h"
#import <Cocoa/Cocoa.h>

#import "Utility_Transformation.h"
#import "SharedMessagePort.h"
#import "TransformationManager.h"
#import "SharedUtility.h"

#import "Utility_Helper.h"

#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "SharedUtility.h"

#import "ModifiedDragOutputThreeFingerSwipe.h"
#import "ModifiedDragOutputTwoFingerSwipe.h"
#import "ModifiedDragOutputFakeDrag.h"
#import "ModifiedDragOutputAddMode.h"

@implementation ModifiedDrag

/// Vars

static ModifiedDragState _drag;

/// Derived props

+ (CGPoint)pseudoPointerPosition {
    
    return CGPointMake(_drag.origin.x + _drag.originOffset.x, _drag.origin.y + _drag.originOffset.y);
}

/// Debug

+ (NSString *)modifiedDragStateDescription:(ModifiedDragState)drag {
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
        phase: %hu\n",
                  drag.eventTap, drag.usageThreshold, drag.type, drag.activationState, drag.modifiedDevice, drag.origin.x, drag.origin.y, drag.originOffset.x, drag.originOffset.y, drag.usageAxis, drag.phase
                  ];
    } @catch (NSException *exception) {
        DDLogInfo(@"Exception while generating string description of ModifiedDragState: %@", exception);
    }
    return output;
}

/// There are two different modes for how we receive mouse input, toggle to switch between the two for testing
/// Set to no, if you want input to be raw mouse input, set to yes if you want input to be mouse pointer delta
/// Raw input has better performance (?) and allows for blocking mouse pointer movement. Mouse pointer input makes all the animation follow the pointer, but it has some issues with the pointer jumping when the framerate is low which I'm not quite sure how to fix.
///      When the pointer jumps that sometimes leads to scrolling in random directions and stuff.
/// Edit: We can block pointer movement while using pointer delta as input now! Also the jumping in random directions when driving gestureScrolling is gone. So using pointerMovement as input is fine.

+ (void)load_Manual {
    
    /// Init plugins
    [ModifiedDragOutputTwoFingerSwipe load_Manual];
    
    /// Setup dispatch queue
    ///     This allows us to process events in the right order
    ///     When the eventTap and the deactivate function are driven by different threads or whatever then the deactivation can happen before we've processed all the events. This allows us to avoid that issue
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
    _drag.queue = dispatch_queue_create("com.nuebling.mac-mouse-fix.helper.drag", attr);
    
    /// Set usage threshold
    _drag.usageThreshold = 7; // 20, 5
    
    /// Create mouse pointer moved input callback
    if (_drag.eventTap == nil) {
        
        CGEventTapLocation location = kCGHIDEventTap;
        CGEventTapPlacement placement = kCGHeadInsertEventTap;
        CGEventTapOptions option = kCGEventTapOptionListenOnly; /// kCGEventTapOptionDefault
        /// ^ Using `Default` causes weird cursor jumping issues when clicking-dragging-and-holding during addMode. Not sure why that happens. This didn't happen in v2 while using `Default`. Not sure if `ListenOnly` has any disadvantages.
        CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDragged) | CGEventMaskBit(kCGEventMouseMoved); /// kCGEventMouseMoved is only necessary for keyboard-only drag-modification (which we've disable because it had other problems), and maybe for AddMode to work.
        mask = mask | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged); /// This is necessary for modified drag to work during a left/right click and drag. Concretely I added this to make drag and drop work. For that we only need the kCGEventLeftMouseDragged. Adding kCGEventRightMouseDragged is probably completely unnecessary. Not sure if there are other concrete applications outside of drag and drop.
        
        CFMachPortRef eventTap = [Utility_Transformation createEventTapWithLocation:location mask:mask option:option placement:placement callback:eventTapCallBack];
        
        _drag.eventTap = eventTap;
    }
}

/// Interface - start

+ (NSDictionary *)dict { // TODO: What is this good for? Why didn't we need it in 2.0?
    
    if (_drag.activationState == kMFModifiedInputActivationStateNone) {
        return nil;
    } else if (_drag.activationState == kMFModifiedInputActivationStateInitialized || _drag.activationState == kMFModifiedInputActivationStateInUse) {
        return _drag.dict;
    } else {
        assert(false);
    }
}

+ (void)initializeDragWithModifiedDragDict:(NSDictionary *)dict onDevice:(Device *)dev largeUsageThreshold:(BOOL)largeUsageThreshold {
    
    dispatch_async(_drag.queue, ^{
        
        /// Debug
        
        DDLogDebug(@"INITIALIZING MODIFIEDDRAG WITH previous type %@ activationState %d, dict: %@", _drag.type, _drag.activationState, dict);
        
        /// Make cursor settable
        
        [Utility_Transformation makeCursorSettable]; /// I think we only need to do this once
        
        /// Get values from dict
        MFStringConstant type = dict[kMFModifiedDragDictKeyType];
        
        /// Init _drag struct
        
        /// Init static
        _drag.modifiedDevice = dev;
        _drag.type = type;
        _drag.dict = dict;
        
        /// Get output plugin
        if ([type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
            _drag.outputPlugin = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputThreeFingerSwipe.class;
        } else if ([type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
            _drag.outputPlugin = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputTwoFingerSwipe.class;
        } else if ([type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
            _drag.outputPlugin = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputFakeDrag.class;
        } else if ([type isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
            _drag.outputPlugin = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputAddMode.class;
        } else {
            assert(false);
        }
        
        /// Init output plugin
        [_drag.outputPlugin initializeWithDragState:&_drag];
        
        /// Init dynamic
        initDragState();
        
        /// Stop momentum scroll if we're initing a twoFingerDrag
        if ([_drag.type isEqual:kMFModifiedDragTypeTwoFingerSwipe]) {
            [GestureScrollSimulator stopMomentumScroll];
        }
        
    });
}

void initDragState(void) {
    
    _drag.origin = getRoundedPointerLocation();
    _drag.originOffset = (Vector){0};
    _drag.activationState = kMFModifiedInputActivationStateInitialized;
    
    CGEventTapEnable(_drag.eventTap, true);
    DDLogDebug(@"\nEnabled drag eventTap");
}

static CGEventRef __nullable eventTapCallBack(CGEventTapProxy proxy, CGEventType type, CGEventRef  event, void * __nullable userInfo) {
    
    /// Catch special events
    if (type == kCGEventTapDisabledByTimeout) {
        /// Re-enable on timeout (Not sure if this ever times out)
        DDLogInfo(@"ModifiedDrag eventTap timed out. Re-enabling.");
        CGEventTapEnable(_drag.eventTap, true);
        return event;
    } else if (type == kCGEventTapDisabledByUserInput) {
        DDLogInfo(@"ModifiedDrag eventTap disabled by user input.");
        return event;
    }
    
    /// Get deltas
    
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
    
    /// ^ These are truly integer values, I'm not rounding anything / losing any info here
    /// However, the deltas seem to be pre-subpixelated, and often, both dx and dy are 0.
    
    /// Debug
    
//    DDLogDebug(@"modifiedDrag input: %lld %lld", dx, dy);
    
    /// Ignore event if both deltas are zero
    ///     We do this so the phases for the gesture scroll simulation (aka twoFingerSwipe) make sense. The gesture scroll event with phase kIOHIDEventPhaseBegan should always have a non-zero delta. If we let through zero deltas here it messes those phases up.
    ///     I think for all other types of modified drag (aside from gesture scroll simulation) this shouldn't break anything, either.
    if (dx == 0 && dy == 0) return NULL;
    
    /// Process delta
    [ModifiedDrag handleMouseInputWithDeltaX:dx deltaY:dy event:event];
        
    /// Return
    ///     Sending `event` or NULL here doesn't seem to make a difference. If you alter the event and send that it does have an effect though?
    
    return NULL;
}

+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY event:(CGEventRef)event {
    
    CGEventRef eventCopy = CGEventCreateCopy(event);
    
    dispatch_async(_drag.queue, ^{
        
        _drag.originOffset.x += deltaX;
        _drag.originOffset.y += deltaY;
        /// ^ We get the originOffset outside the _drag.queue, so that we still record changes in originOffset while deactivate() is blocking the _drag.queue
        
        MFModifiedInputActivationState st = _drag.activationState;
        
    //        DDLogDebug(@"Handling mouse input. dx: %lld, dy: %lld, activationState: %@", deltaX, deltaY, @(st));
        
        if (st == kMFModifiedInputActivationStateNone) {
            /// Disabling the callback triggers this function one more time apparently, aside form that case, this should never happen I think
        } else if (st == kMFModifiedInputActivationStateInitialized) {
            handleMouseInputWhileInitialized(deltaX, deltaY, eventCopy);
        } else if (st == kMFModifiedInputActivationStateInUse) {
            handleMouseInputWhileInUse(deltaX, deltaY, eventCopy); /// This shouldn't mutate any shared state, so we don't need to schedule it on _twoFingerDragQueue
        }

    });
}
static void handleMouseInputWhileInitialized(int64_t deltaX, int64_t deltaY, CGEventRef event) {
    
    Vector ofs = _drag.originOffset;
    
    /// Activate the modified drag if the mouse has been moved far enough from the point where the drag started
    if (MAX(fabs(ofs.x), fabs(ofs.y)) > _drag.usageThreshold) {
        
        /// Get usageOrigin
        
//        _drag.usageOrigin = CGPointMake(_drag.origin.x + ofs.x, _drag.origin.y + ofs.y);
        /// ^ This is just the current pointer location, but obtained without a CGEvent. However this didn't quite work because ofs.x and ofs.y are integers while origin.x and origin.y are floats. I tried to roud the values myself to counterbalance this, but it didn't work, so I'm just passing in a CGEvent and getting the location from that. See below v
        _drag.usageOrigin = getRoundedPointerLocationWithEvent(event);
        
        /// Do weird stuff
        Device *dev = _drag.modifiedDevice;
//        [NSCursor.closedHandCursor push]; // Doesn't work for some reason

        /// Set activationState
        _drag.activationState = kMFModifiedInputActivationStateInUse; /// Activate modified drag input!
        
        /// Send modifier feedback
        [ModifierManager handleModifiersHaveHadEffectWithDevice:dev.uniqueID];
        
        /// Get usage axis
        if (fabs(ofs.x) < fabs(ofs.y)) {
            _drag.usageAxis = kMFAxisVertical;
        } else {
            _drag.usageAxis = kMFAxisHorizontal;
        }
        
        /// Debug
        DDLogDebug(@"SETTING DRAG PHASE TO BEGAN");
        
        /// Set phase
        _drag.phase = kIOHIDEventPhaseBegan;
        
        /// Do type-specific stuff
        
        [_drag.outputPlugin handleBecameInUse];
    }
}
/// Only passing in event to obtain event location to get slightly better behaviour for fakeDrag
void handleMouseInputWhileInUse(int64_t deltaX, int64_t deltaY, CGEventRef event) {
    
    [_drag.outputPlugin handleMouseInputWhileInUseWithDeltaX:deltaX deltaY:deltaY event:event];
    
    _drag.phase = kIOHIDEventPhaseChanged;
}

+ (void)deactivate {
    
//    DDLogDebug(@"Deactivated modifiedDrag. Caller: %@", [SharedUtility callerInfo]);
    
    [self deactivateWithCancel:false];
}
+ (void)deactivateWithCancel:(BOOL)cancel {
    
    dispatch_async(_drag.queue, ^{
        /// Do everything on the dragQueue to ensure correct order of operations with the processing of the events from the eventTap.
        
        DDLogDebug(@"modifiedDrag deactivate with state: %@", [self modifiedDragStateDescription:_drag]);
        
        if (_drag.activationState == kMFModifiedInputActivationStateNone) return;
        
        if (_drag.activationState == kMFModifiedInputActivationStateInUse) {
            [_drag.outputPlugin handleDeactivationWhileInUseWithCancel:cancel];
        }
        _drag.activationState = kMFModifiedInputActivationStateNone;
        
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.1), _drag.queue, ^{
            /// Delay so we don't "cut off" the mouseDragged events that are still pent up in the eventTap. Better solution might be to have one single event tap that drives both button input and mouseDragged events.
            ///     Edit: Not even sure that this does anything. I feel like the feeling of events being "cut off" might be due to to CGWarpMouseCursorPosittion causing the pointer to freeze for a short time.
            ///         This seems to make issue worse where the mouse pointer jumps when re-initializing the twoFingerModifiedDrag right after deactivating
            disableMouseTracking();
//        });
    });
}
+ (void)modifiedScrollHasBeenUsed {
    /// It's easy to accidentally drag while trying to click and scroll. And some modifiedDrag effects can interfere with modifiedScroll effects. We built this cool ModifiedDrag `suspend()` method which effectively restarts modifiedDrag. This is cool and feels nice and has a few usability benefits, but also leads to a bunch of bugs and race conditions in its current form, so were just using `deactivate()`
    if (_drag.activationState == kMFModifiedInputActivationStateInUse) { /// This check should probably also be performed on the _drag.queue
        [self deactivateWithCancel:YES];
    }
}
    
//+ (void)suspend {
//    /// Deactivate and re-initialize
//    ///     Cool but not used cause it caused some weird bugs
//
//    if (_drag.activationState == kMFModifiedInputActivationStateNone) return;
//
//    [self deactivateWithCancel:true];
//    initDragState();
//}

#pragma mark - Helper functions

/// Disable mouse tracking
///     I forgot what this does. Is it necessary?

static void disableMouseTracking() {

    CGEventTapEnable(_drag.eventTap, false);
    DDLogDebug(@"\nmodifiedDrag disabled drag eventTap. Caller info: %@", [SharedUtility callerInfo]);
        
    [NSCursor.closedHandCursor pop];
}

/// Get rounded pointer location

static CGPoint getRoundedPointerLocation() {
    /// Convenience wrapper for getRoundedPointerLocationWithEvent()
    
    CGEventRef event = CGEventCreate(NULL);
    CGPoint location = getRoundedPointerLocationWithEvent(event);
    CFRelease(event);
    return location;
}
static CGPoint getRoundedPointerLocationWithEvent(CGEventRef event) {
    /// I thought it was necessary to use this on _drag.origin to calculate the _drag.usageOrigin properly.
    /// To get the _drag.usageOrigin, I used to take the _drag.origin (which is float) and add the kCGMouseEventDeltaX and DeltaY (which are ints)
    ///     But even with rounding it didn't work properly so we went over to getting usageOrigin directly from a CGEvent. I think with this new setup there might not be a  reason to use the getRoundedPointerLocation functions anymore. But I'll just leave them in because they don't break anything.
    
    CGPoint pointerLocation = CGEventGetLocation(event);
    CGPoint pointerLocationRounded = (CGPoint){ .x = floor(pointerLocation.x), .y = floor(pointerLocation.y) };
    return pointerLocationRounded;
}


@end
