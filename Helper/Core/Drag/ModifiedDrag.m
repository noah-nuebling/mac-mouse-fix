//
// --------------------------------------------------------------------------
// ModifyingActions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Constants.h"

#import "ModifiedDrag.h"
#import "ScrollModifiers.h"
#import "GestureScrollSimulator.h"
#import "Modifiers.h"

#import "SubPixelator.h"
#import <Cocoa/Cocoa.h>

#import "ModificationUtility.h"
#import "MFMessagePort.h"
#import "Remap.h"
#import "SharedUtility.h"

#import "HelperUtility.h"

#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "SharedUtility.h"

#import "ModifiedDragOutputThreeFingerSwipe.h"
#import "ModifiedDragOutputTwoFingerSwipe.h"
#import "ModifiedDragOutputFakeDrag.h"
#import "ModifiedDragOutputAddMode.h"

#import "GlobalEventTapThread.h"

@implementation ModifiedDrag

/// TODO: Rename this to just `Drag`

/// Vars

static ModifiedDragState _drag;

//static CGEventTapProxy _tapProxy;

//+ (CGEventTapProxy)tapProxy {
//    return _tapProxy;
//}


/// Derived props

//+ (CGPoint)pseudoPointerPosition {
//
//    return CGPointMake(_drag.origin.x + _drag.originOffset.x, _drag.origin.y + _drag.originOffset.y);
//}

/// Debug

+ (void)activationStateWithCallback:(void (^)(MFModifiedInputActivationState))callback {
    
    /// We wanted to expose `_drag` to other modules for debugging, but `_drag` can't be exposed to Swift. Maybe because it contains an ObjC pointer`id`. Right now this is fine though because we only need the activationState for debugging anyways.
    /// We need to retrieve this on the `_drag.queue` to avoid race conditions. But using `dispatch_sync` leads to loads of concurrency issues, so we're using a callback instead.
    
    dispatch_async(_drag.queue, ^{
        callback(_drag.activationState);
    });
}

+ (NSString *)modifiedDragStateDescription:(ModifiedDragState)drag {
    NSString *output = @"";
    @try {
        output = [NSString stringWithFormat:
        @"\n\
        eventTap: %@\n\
        usageThreshold: %lld\n\
        type: %@\n\
        activationState: %u\n\
        origin: (%f, %f)\n\
        originOffset: (%f, %f)\n\
        usageAxis: %u\n\
        phase: %d\n",
                  drag.eventTap, drag.usageThreshold, drag.type, drag.activationState, drag.origin.x, drag.origin.y, drag.originOffset.x, drag.originOffset.y, drag.usageAxis, drag.firstCallback
                  ];
    } @catch (NSException *exception) {
        DDLogInfo(@"Exception while generating string description of ModifiedDragState: %@", exception);
    }
    return output;
}

+ (void)load_Manual {
    
    /// Init plugins
    [ModifiedDragOutputTwoFingerSwipe load_Manual];
    
    /// Setup dispatch queue
    ///     This allows us to process events in the right order
    ///     When the eventTap and the deactivate function are driven by different threads or whatever then the deactivation can happen before we've processed all the events. This allows us to avoid that issue
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
    _drag.queue = dispatch_queue_create("com.nuebling.mac-mouse-fix.helper.modified-drag", attr);
    
    /// Set usage threshold
    _drag.usageThreshold = 7; // 20, 5
    
    /// Create mouse moved callback
    if (_drag.eventTap == nil) {
        
        CGEventTapLocation location = kCGHIDEventTap;
        CGEventTapPlacement placement = kCGHeadInsertEventTap;
        CGEventTapOptions option = /*kCGEventTapOptionListenOnly*/ kCGEventTapOptionDefault;
        /// ^ Using `Default` causes weird cursor jumping issues when clicking-dragging-and-holding during addMode. Not sure why that happens. This didn't happen in v2 while using `Default`. Not sure if `ListenOnly` has any disadvantages. Edit: In other places, I've had issues using listenOnly because it messes up the timestamps (I'm on macOS 12.4. right now). -> Trying default again.
        CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDragged) | CGEventMaskBit(kCGEventMouseMoved); /// kCGEventMouseMoved is only necessary for keyboard-only drag-modification (which we've disable because it had other problems), and maybe for AddMode to work.
        mask = mask | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged); /// This is necessary for modified drag to work during a left/right click and drag. Concretely I added this to make drag and drop work. For that we only need the kCGEventLeftMouseDragged. Adding kCGEventRightMouseDragged is probably completely unnecessary. Not sure if there are other concrete applications outside of drag and drop.
        
        CFMachPortRef eventTap = [ModificationUtility createEventTapWithLocation:location mask:mask option:option placement:placement callback:eventTapCallBack runLoop:GlobalEventTapThread.runLoop];
        
        _drag.eventTap = eventTap;
    }
}

/// Interface - start

//+ (NSDictionary *)initialModifiers {
//
//    if (_drag.activationState == kMFModifiedInputActivationStateNone) {
//        return nil;
//    } else if (_drag.activationState == kMFModifiedInputActivationStateInitialized || _drag.activationState == kMFModifiedInputActivationStateInUse) {
//        return _drag.initialModifiers;
//    } else {
//        assert(false);
//    }
//}

+ (void)initializeDragWithDict:(NSDictionary *)effectDict {
    
    dispatch_async(_drag.queue, ^{
        
        /// Debug
        DDLogDebug(@"INITIALIZING MODIFIEDDRAG WITH previous type %@ activationState %d, newEffectDict: %@", _drag.type, _drag.activationState, effectDict);
        
        /// Guard state == inUse
        ///  I think if state == initialized we don't need to do anything special
        if (_drag.activationState == kMFModifiedInputActivationStateInUse) {
            BOOL isSame = [effectDict isEqualToDictionary:_drag.effectDict];
            BOOL isAddMode = [_drag.effectDict[kMFModifiedDragDictKeyType] isEqual:kMFModifiedDragTypeAddModeFeedback];
            if (!isSame && !isAddMode) {
//                deactivate_Unsafe(YES);
                return;
            } else {
                return;
            }
        }
        
        /// Get type
        MFStringConstant type = effectDict[kMFModifiedDragDictKeyType];
        
        /// Init static parts of `_drag`
        _drag.type = type;
        _drag.effectDict = effectDict;
//        _drag.initialModifiers = modifiers;
        _drag.initTime = CACurrentMediaTime();
        
        id<ModifiedDragOutputPlugin> p;
        if ([type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
            p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputThreeFingerSwipe.class;
        } else if ([type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
            p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputTwoFingerSwipe.class;
        } else if ([type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
            p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputFakeDrag.class;
        } else if ([type isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
            p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputAddMode.class;
        } else {
            assert(false);
        }
        
        /// Link with plugin
//        [p initializeWithDragState:&_drag];
        _drag.outputPlugin = p;
        
        /// Init dynamic parts of _drag
        initDragState_Unsafe();
    });
}
void initDragState_Unsafe(void) {
    
    _drag.origin = getRoundedPointerLocation();
    _drag.originOffset = (Vector){0};
    _drag.activationState = kMFModifiedInputActivationStateInitialized;
    _drag.isSuspended = NO;
    
    [_drag.outputPlugin initializeWithDragState:&_drag]; /// We just want to reset the plugin state here. The plugin will already hold ref to `_drag`. So this is not super pretty/semantic
    
    CGEventTapEnable(_drag.eventTap, true);
    DDLogDebug(@"\nEnabled drag eventTap");
}

static CGEventRef __nullable eventTapCallBack(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void * __nullable userInfo) {
    
    /// Store proxy
//    _tapProxy = proxy;
    
    /// Catch special events
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        
        DDLogDebug(@"ModifiedDrag eventTap was disabled by %@", type == kCGEventTapDisabledByTimeout ? @"timeout. Re-enabling." : @"user input.");
        
        if (type == kCGEventTapDisabledByTimeout) {
//            assert(false); /// Not sure this ever times out
            CGEventTapEnable(_drag.eventTap, true);
        }
        
        return event;
    }
    
    /// Get deltas
    /// These are truly integer values, I'm not rounding anything / losing any info here
    /// However, the deltas seem to be pre-subpixelated, and often, both dx and dy are 0.
    
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
    
    /// Debug
    
//    DDLogDebug(@"modifiedDrag input: %lld %lld", dx, dy);
    
    /// Ignore event if both deltas are zero
    /// - We do this so the phases for the gesture scroll simulation (aka twoFingerSwipe) make sense. The gesture scroll event with phase kIOHIDEventPhaseBegan should always have a non-zero delta. If we let through zero deltas here it messes those phases up. Now that we're dispatching throuch a TouchAnimator this shouldn't really matter but it doesn't hurt.
    /// - I think for all other types of modified drag (aside from the gesture scroll simulation discussed above) this shouldn't break anything, either.
    
    if (dx != 0 || dy != 0) {
        
        /// Make copy of event for _drag.queue
        
        CGEventRef eventCopy = CGEventCreateCopy(event);
        
        /// Do main processing on _drag.queue
        
        dispatch_async(_drag.queue, ^{
            
            /// Interrupt
            ///     This handles race condition where _drag.eventTap is disabled right after eventTapCallBack() is called
            ///     We implemented the same idea in PointerFreeze.
            ///     Actually, the check for kMFModifiedInputActivationStateNone below has the same effect, but I think but this makes it clearer?
            
            if (!CGEventTapIsEnabled(_drag.eventTap)) {
                return;
            }
            
            /// Update originOffset
            
            _drag.originOffset.x += dx;
            _drag.originOffset.y += dy;
            
            /// Suspension
            if (_drag.isSuspended) return;
            
            /// Debug
            DDLogDebug(@"ModifiedDrag handling mouseMoved");
            
            /// Call further handler functions depending on current state
            
            MFModifiedInputActivationState st = _drag.activationState;
            
            if (st == kMFModifiedInputActivationStateNone) {
                
                /// Disabling the callback triggers this function one more time apparently
                ///     That's the only case I know where I expect this. Maybe we should log this to see what's going on.
                
            } else if (st == kMFModifiedInputActivationStateInitialized) {
                
                handleMouseInputWhileInitialized(dx, dy, eventCopy);
                
            } else if (st == kMFModifiedInputActivationStateInUse) {
                
                handleMouseInputWhileInUse(dx, dy, eventCopy);
            }
            
        });
    }
        
    /// Return mouseMoved event
    /// Notes:
    /// - Sending NULL here almost works perfectly, but in screenRecordings it will make the cursor jump. That's especially annoying for DisplayLink users
    /// - The cursor jumping also goes away when you set the eventTap location to kCGAnnotatedSessionEventTap. The other two locations don't work.
    /// - Sending mouseMoved here would interfere with fakeDrag output. How will we solve that?
    /// - Just changing the type on the original event is a little hacky but it should work
    /// - Sending these mouseMoved events doesn't interfere with freezing the pointer. Not sure why.
    
    CGEventSetType(event, kCGEventMouseMoved);
    return event;
}

static void handleMouseInputWhileInitialized(int64_t deltaX, int64_t deltaY, CGEventRef event) {
    
    /// Activate the modified drag if the mouse has been moved far enough from the point where the drag started
    
    Vector ofs = _drag.originOffset;
    if (MAX(fabs(ofs.x), fabs(ofs.y)) > _drag.usageThreshold) {
        
        /// Debug
        DDLogDebug(@"Modified Drag entered 'in use' state");
        
        /// Store state
        _drag.usageOrigin = getRoundedPointerLocationWithEvent(event);
        
        if (fabs(ofs.x) < fabs(ofs.y)) {
            _drag.usageAxis = kMFAxisVertical;
        } else {
            _drag.usageAxis = kMFAxisHorizontal;
        }
        
        /// Update state
        _drag.activationState = kMFModifiedInputActivationStateInUse;
        _drag.firstCallback = true;
        
        /// Do deferred init
        /// Could also do this in normal init `initializeDragWithDict`, but here is more effiicient (`initializeDragWithDict` is called on every mouse click if it's set up for that button)
        /// -> Don't use `naturalDirection` before state switches to `kMFModifiedInputActivationStateInUse`!
        /// TODO: Build UI for this
        /// Edit:
        ///   Lot's of people complained about this in 3.0.0 Beta 6. See https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue+is%3Aopen+label%3A%223.0.0+Beta+6+Click+and+Drag+Direction%22
        ///   It think reading the userdefaults didn't work properly for many users. So we're disabling this now until we build the UI for it.
        /// Edit2: The problem was that the it fell back to naturalDirection = false when the userDefaults didn't contain a value for `com.apple.swipescrolldirection`, which is the case if the user has never edited the `natural scroll direction` system setting. But if `com.apple.swipescrolldirection` doesn't exist, then the scroll direction is actually natural on Apple Trackpad and Magic Mouse. So if we fall back to natural scroll direction, it should match Trackpad/Magic mouse behaviour and users should be happy.
    
        NSNumber *systemScrollDirection = [NSUserDefaults.standardUserDefaults objectForKey:@"com.apple.swipescrolldirection"];
        _drag.naturalDirection = systemScrollDirection == nil ? true : systemScrollDirection.boolValue;
        
        /// Notify output plugin
        [_drag.outputPlugin handleBecameInUse];
        
        /// Notify TrialCounter.swift
        [TrialCounter.shared handleUse];
        
        /// Notify other modules
        [Modifiers handleModificationHasBeenUsed];
//        (void)[OutputCoordinator suspendTouchDriversFromDriver:kTouchDriverModifiedDrag];
    }
}
/// Only passing in event to obtain event location to get slightly better behaviour for fakeDrag
void handleMouseInputWhileInUse(int64_t deltaX, int64_t deltaY, CGEventRef event) {
    
    /// Invert direction
    if (!_drag.naturalDirection) {
        deltaX = -deltaX;
        deltaY = -deltaY;
    }
    
    /// Notifiy plugin
    [_drag.outputPlugin handleMouseInputWhileInUseWithDeltaX:deltaX deltaY:deltaY event:event];
    
    /// Update phase
    ///
    /// - firstCallback is used in `handleMouseInputWhileInUseWithDeltaX:...` (called above)
    /// - The first time we call `handleMouseInputWhileInUseWithDeltaX:...` during a drag, the `firstCallback` will be true. On subsequent calls, the `firstCallback` will be false.
    ///     - Indirectly communicating with the plugin through _drag is a little confusing, we might want to consider removing _drag from the plugins and sending the relevant data as arguments instead.
    
    _drag.firstCallback = false;
}

+ (void (^ _Nullable)(void))suspend {
    
    /// This was used for OutputCoordinator stuff which is unused now. Can probably remove this
    /// Also this creates a dangling pointer according to Xcode analyzer
    
    void (^ __block unsuspend)(void);
    unsuspend = nil;
    ModifiedDragState *drag = &_drag; /// So the block references the gobal value instead of copying
    
    dispatch_sync(_drag.queue, ^{
        if ((*drag).activationState != kMFModifiedInputActivationStateInUse) return;
        DDLogDebug(@"Suspending ModifiedDrag");
        deactivate_Unsafe(YES);
        (*drag).isSuspended = YES;
        [(*drag).outputPlugin suspend];
        CFTimeInterval ogTime = (*drag).initTime;
        unsuspend = ^{
            dispatch_async((*drag).queue, ^{
                if (ogTime == (*drag).initTime && (*drag).isSuspended) { /// So we don't unsuspend a different drag than the one we suspended
                    DDLogDebug(@"UNSuspending ModifiedDrag");
                    (*drag).isSuspended = NO;
                    initDragState_Unsafe();
                    [(*drag).outputPlugin unsuspend];
                }
            });
        };
    });
    
    return unsuspend;
}

+ (void)deactivate {
    
//    DDLogDebug(@"Deactivated modifiedDrag. Caller: %@", [SharedUtility callerInfo]);
    [self deactivateWithCancel:false];
}

+ (void)deactivateWithCancel:(BOOL)cancel {
    
    dispatch_async(_drag.queue, ^{
        /// ^ Do everything on the dragQueue to ensure correct order of operations with the processing of the events from the eventTap.
        deactivate_Unsafe(cancel);
    });
}

void deactivate_Unsafe(BOOL cancel) {
    
    /// Debug
    DDLogDebug(@"modifiedDrag deactivate with state: %@", [ModifiedDrag modifiedDragStateDescription:_drag]);
    
    /// Disable supension
    _drag.isSuspended = NO;
    
    /// Handle state == none
    ///     Return immediately
    if (_drag.activationState == kMFModifiedInputActivationStateNone) return;
    
    /// Handle state == In use
    ///     Notify plugin
    if (_drag.activationState == kMFModifiedInputActivationStateInUse) {
        [_drag.outputPlugin handleDeactivationWhileInUseWithCancel:cancel];
    }
    
    /// Set state == none
    _drag.activationState = kMFModifiedInputActivationStateNone;
    
    /// Disable eventTap
    CGEventTapEnable(_drag.eventTap, false);
    
    /// Debug
    DDLogDebug(@"\nmodifiedDrag disabled drag eventTap. Caller info: %@", [SharedUtility callerInfo]);
}
                   
/// Handle interference with ModifiedScroll
///     I'm not confident this is an adequate solution.
                   
//+ (void)modifiedScrollHasBeenUsed {
//    /// It's easy to accidentally drag while trying to click and scroll. And some modifiedDrag effects can interfere with modifiedScroll effects. We built this cool ModifiedDrag `suspend()` method which effectively restarts modifiedDrag. This is cool and feels nice and has a few usability benefits, but also leads to a bunch of bugs and race conditions in its current form, so were just using `deactivate()`
//    if (_drag.activationState == kMFModifiedInputActivationStateInUse) { /// This check should probably also be performed on the _drag.queue
//        [self deactivateWithCancel:YES];
//    }
//}
    
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

/// Get rounded pointer location

CGPoint getRoundedPointerLocation(void) {
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
