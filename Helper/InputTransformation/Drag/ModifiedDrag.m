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
#import "SharedMessagePort.h"
#import "TransformationManager.h"
#import "SharedUtility.h"

#import <Cocoa/Cocoa.h>
#import "VectorUtility.h"
#import "Utility_Helper.h"

#import "CGSCursor.h"
#import "CGSConnection.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "SharedUtility.h"

@implementation ModifiedDrag

/// Vars - drag state

struct ModifiedDragState {
    CFMachPortRef eventTap;
    int64_t usageThreshold;
    
    MFStringConstant type;

    MFModifiedInputActivationState activationState;
    Device *modifiedDevice;
    
    CGPoint origin;
    Vector originOffset;
    CGPoint usageOrigin; // Point at which the modified drag changed its activationState to inUse
    MFAxis usageAxis;
    IOHIDEventPhaseBits phase;
    
    CGDirectDisplayID display;
    
    SubPixelator *subPixelatorX;
    SubPixelator *subPixelatorY;
    
    MFMouseButtonNumber fakeDragButtonNumber; // Button number. Only used with modified drag of type kMFModifiedDragTypeFakeDrag.
    NSDictionary *addModePayload; // Payload to send to the mainApp. Only used with modified drag of type kMFModifiedDragTypeAddModeFeedback.
};
static struct ModifiedDragState _drag;

/// Debug

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
        DDLogInfo(@"Exception while generating string description of ModifiedDragState: %@", exception);
    }
    return output;
}

/// More vars /defs

#define inputIsPointerMovement YES
static int _cgsConnection; /// This is used by private APIs to talk to the window server and do fancy shit like hiding the cursor from a background application
static NSImageView *_puppetCursorView;

/// There are two different modes for how we receive mouse input, toggle to switch between the two for testing
/// Set to no, if you want input to be raw mouse input, set to yes if you want input to be mouse pointer delta
/// Raw input has better performance (?) and allows for blocking mouse pointer movement. Mouse pointer input makes all the animation follow the pointer, but it has some issues with the pointer jumping when the framerate is low which I'm not quite sure how to fix.
///      When the pointer jumps that sometimes leads to scrolling in random directions and stuff.
/// Edit: We can block pointer movement while using pointer delta as input now! Also the jumping in random directions when driving gestureScrolling is gone. So using pointerMovement as input is fine.

+ (void)load_Manual {
    
    /// Setup cgs stuff
    _cgsConnection = CGSMainConnectionID();
    
    /// Setup puppet cursor
    
    _puppetCursorView = [[NSImageView alloc] init];
    
    /// Setup input callback and related
    if (inputIsPointerMovement) {
        // Create mouse pointer moved input callback
        if (_drag.eventTap == nil) {
            
            CGEventTapLocation location = kCGHIDEventTap;
            CGEventTapPlacement placement = kCGHeadInsertEventTap;
            CGEventTapOptions option = kCGEventTapOptionDefault;
            CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDragged) | CGEventMaskBit(kCGEventMouseMoved); // kCGEventMouseMoved is only necessary for keyboard-only drag-modification (which we've disable because it had other problems), and maybe for AddMode to work.
            mask = mask | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged); // This is necessary for modified drag to work during a left/right click and drag. Concretely I added this to make drag and drop work. For that we only need the kCGEventLeftMouseDragged. Adding kCGEventRightMouseDragged is probably completely unnecessary. Not sure if there are other concrete applications outside of drag and drop.
            
            CFMachPortRef eventTap = [Utility_Transformation createEventTapWithLocation:location mask:mask option:option placement:placement callback:eventTapCallBack];
            
            _drag.eventTap = eventTap;
        }
    }
}

+ (void)initializeDragWithModifiedDragDict:(NSDictionary *)dict onDevice:(Device *)dev largeUsageThreshold:(BOOL)largeUsageThreshold {
    
    /// Make cursor settable
    
    [Utility_Transformation makeCursorSettable];
    
    /// Get values from dict
    MFStringConstant type = dict[kMFModifiedDragDictKeyType];
    MFMouseButtonNumber fakeDragButtonNumber = -1;
    if ([type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
        fakeDragButtonNumber = ((NSNumber *)dict[kMFModifiedDragDictKeyFakeDragVariantButtonNumber]).intValue;
    }
    /// Prepare payload to send to mainApp during AddMode. See TransformationManager -> AddMode for context
    NSMutableDictionary *payload = nil;
    if ([type isEqualToString:kMFModifiedDragTypeAddModeFeedback]){
        payload = dict.mutableCopy;
        [payload removeObjectForKey:kMFModifiedDragDictKeyType];
    }
    
//    DDLogDebug(@"INITIALIZING MODIFIED DRAG WITH TYPE %@ ON DEVICE %@", type, dev);
    
    /// Init _drag struct
    
    /// Init static
    _drag.modifiedDevice = dev;
    _drag.type = type;
    _drag.fakeDragButtonNumber = fakeDragButtonNumber;
    _drag.addModePayload = payload;
    if (inputIsPointerMovement) {
        _drag.usageThreshold = largeUsageThreshold ? 20 : 5;
    } else {
        _drag.usageThreshold = largeUsageThreshold ? 50 : 12;
    }
    
    /// Init dynamic
    initDragState();
}

void initDragState(void) {
    _drag.originOffset = (Vector){0};
    _drag.subPixelatorX = [SubPixelator roundPixelator];
    _drag.subPixelatorY = [SubPixelator roundPixelator];
    
    _drag.origin = getRoundedPointerLocation();
    _drag.activationState = kMFModifiedInputActivationStateInitialized;
    
    if (inputIsPointerMovement) {
        CGEventTapEnable(_drag.eventTap, true);
    } else {
        [_drag.modifiedDevice receiveAxisInputAndDoSeizeDevice:NO];
    }
}

static CGEventRef __nullable eventTapCallBack(CGEventTapProxy proxy, CGEventType type, CGEventRef  event, void * __nullable userInfo) {
    
    /// Re-enable on timeout (Not sure if this ever times out)
    if (type == kCGEventTapDisabledByTimeout) {
        DDLogInfo(@"ButtonInputReceiver eventTap timed out. Re-enabling.");
        CGEventTapEnable(_drag.eventTap, true);
    }
    
    /// Get deltas
    
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
    
    /// ^ These are truly integer values, I'm not rounding anything / losing any info here
    /// However, the deltas seem to be pre-subpixelated, and often, both dx and dy are 0.
    
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
    
    _drag.originOffset.x += deltaX;
    _drag.originOffset.y += deltaY;
    
    MFModifiedInputActivationState st = _drag.activationState;
    
//    DDLogDebug(@"Handling mouse input. dx: %lld, dy: %lld, activationState: %@", deltaX, deltaY, @(st));
            
    if (st == kMFModifiedInputActivationStateNone) {
        // Disabling the callback triggers this function one more time apparently, aside form that case, this should never happen I think
    } else if (st == kMFModifiedInputActivationStateInitialized) {
        handleMouseInputWhileInitialized(deltaX, deltaY, event);
    } else if (st == kMFModifiedInputActivationStateInUse) {
        handleMouseInputWhileInUse(deltaX, deltaY, event);
    }
}
static void handleMouseInputWhileInitialized(int64_t deltaX, int64_t deltaY, CGEventRef event) {
    
    Vector ofs = _drag.originOffset;
    
    // Activate the modified drag if the mouse has been moved far enough from the point where the drag started
    if (MAX(fabs(ofs.x), fabs(ofs.y)) > _drag.usageThreshold) {
        
        /// Get usageOrigin
        
//        _drag.usageOrigin = CGPointMake(_drag.origin.x + ofs.x, _drag.origin.y + ofs.y);
        /// ^ This is just the current pointer location, but obtained without a CGEvent. However this didn't quite work because ofs.x and ofs.y are integers while origin.x and origin.y are floats. I tried to roud the values myself to counterbalance this, but it didn't work, so I'm just passing in a CGEvent and getting the location from that. See below v
        _drag.usageOrigin = getRoundedPointerLocationWithEvent(event);
        
        /// Get display under mouse pointer
        CVReturn rt = [Utility_Helper display:&_drag.display atPoint:_drag.usageOrigin];
        if (rt != kCVReturnSuccess) DDLogWarn(@"Couldn't get display under mouse pointer in modifiedDrag");
        
        /// Do weird stuff
        Device *dev = _drag.modifiedDevice;
        if (inputIsPointerMovement) {
//            [NSCursor.closedHandCursor push]; // Doesn't work for some reason
        } else {
            if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) { // Only seize when drag scrolling // TODO: Would be cleaner to call this further down where we check for kMFModifiedDragVariantTwoFingerSwipe anyways. Does that work too?
                [dev receiveAxisInputAndDoSeizeDevice:YES];
            }
        }
        /// Set activationState
        _drag.activationState = kMFModifiedInputActivationStateInUse; // Activate modified drag input!
        
        /// Setnd modifier feednack
        [ModifierManager handleModifiersHaveHadEffectWithDevice:dev.uniqueID];
        
        //// Get usage axis
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
        
        if ([_drag.type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
            
//            if (inputIsPointerMovement) [NSCursor.closedHandCursor push];
            
        } else if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
            
            /// Draw puppet cursor before hiding
            drawPuppetCursor(YES);
            
            /// Decrease delay after warping
            ///     But only as much so that it doesn't break `CGWarpMouseCursorPosition(()` ability to stop cursor by calling repeatedly
            ///     This changes the timeout globally for many events, so we need to reset this after the drag is deactivated!
            setSuppressionInterval(kMFEventSuppressionIntervalForStoppingCursor);
            
            /// Hide cursor
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.02), dispatch_get_main_queue(), ^{
                /// The puppetCursor will only be drawn after a delay, while hiding the mouse pointer is really fast.
                ///     This leads to a little flicker when the puppetCursor is not yet drawn, but the real cursor is already hidden.
                ///     Not sure why this happens. But adding a delay of 0.02 before hiding makes it look seamless.
                
                [Utility_Transformation hideMousePointer:YES];
            });
            
            // [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0.0 deltaY:0.0 phase:kIOHIDEventPhaseMayBegin];
            // ^ Always sending this at the start breaks swiping between pages on some websites (Google search results)
            
        } else if ([_drag.type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
            
            [Utility_Transformation postMouseButton:_drag.fakeDragButtonNumber down:YES];
            
        } else if ([_drag.type isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
            
            if (_drag.addModePayload != nil) {
                if ([TransformationManager addModePayloadIsValid:_drag.addModePayload]) {
                    [SharedMessagePort sendMessage:@"addModeFeedback" withPayload:_drag.addModePayload expectingReply:NO];
                    disableMouseTracking(); // Not sure if should be here
                }
            } else {
                @throw [NSException exceptionWithName:@"InvalidAddModeFeedbackPayload" reason:@"_drag.addModePayload is nil. Something went wrong!" userInfo:nil]; // Throw exception to cause crash
            }
        }
        
    }
}
// Only passing in event to obtain event location to get slightly better behaviour for fakeDrag
void handleMouseInputWhileInUse(int64_t deltaX, int64_t deltaY, CGEventRef event) {
    
    double twoFingerScale;
    double threeFingerScaleH;
    double threeFingerScaleV;
    
    /*
     Horizontal dockSwipe scaling
        This makes horizontal dockSwipes (switch between spaces) follow the pointer exactly. (If everything works)
        I arrived at these value through testing documented in the NotePlan note "MMF - Scraps - Testing DockSwipe scaling"
        TODO: Test this on a vertical screen
     */
    
    double originOffsetForOneSpace = 2.0;  // I've seen this be: 1.25, 1.5, 2.0. Not sure why. Restarting, attaching displays, or changing UI scaling don't seem to change it from my testing. It just randomly changes after a few weeks.
    CGFloat screenWidth = NSScreen.mainScreen.frame.size.width;
    double spaceSeparatorWidth = 63;
    threeFingerScaleH = threeFingerScaleV = originOffsetForOneSpace / (screenWidth + spaceSeparatorWidth);
    
    // Vertical dockSwipe scaling
    // We should maybe use screenHeight to scale vertical dockSwipes (Mission Control and App Windows), but since they don't follow the mouse pointer anyways, this is fine;
    threeFingerScaleV *= 1.0;
    
    /*
     scrollSwipe scaling
        A scale of 1.0 will make the pixel based animations (normal scrolling) follow the mouse pointer.
        Gesture based animations (swiping between pages in Safari etc.) seem to be scaled separately such that swiping 3/4 (or so) of the way across the Trackpad equals one whole page. No matter how wide the page is.
        So to scale the gesture deltas such that the page-change-animations follow the mouse pointer exactly, we'd somehow have to get the width of the underlying scrollview. This might be possible using the _systemWideAXUIElement we created in ScrollControl, but it'll probably be really slow.
    */
    twoFingerScale = 1.0;
    
    if ([_drag.type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
        
        if (_drag.usageAxis == kMFAxisHorizontal) {
            double delta = -deltaX * threeFingerScaleH;
            [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:_drag.phase];
        } else if (_drag.usageAxis == kMFAxisVertical) {
            double delta = deltaY * threeFingerScaleV;
            [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:_drag.phase];
        }
//        _drag.phase = kIOHIDEventPhaseChanged;
    } else if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
        
        /// Warp pointer to origin to prevent cursor movement
        ///     This only works when the suppressionInterval is a certain size, and that will cause a slight stutter / delay until the mouse starts moving againg when we deactivate. So this isn't optimal
        CGWarpMouseCursorPosition(_drag.usageOrigin);
        /// Disassociate pointer to prevent cursor movements
        CGAssociateMouseAndMouseCursorPosition(NO);
        
        /// Draw puppet cursor
        drawPuppetCursor(NO);
        
        /// Post event
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:deltaX*twoFingerScale deltaY:deltaY*twoFingerScale phase:_drag.phase];
        
    } else if ([_drag.type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
        CGPoint location;
        if (event) {
            location = CGEventGetLocation(event); // I feel using `event` passed in from eventTap here makes things slighly more responsive that using `getPointerLocation()`
        } else {
            location = getPointerLocation();
        }
        CGMouseButton button = [SharedUtility CGMouseButtonFromMFMouseButtonNumber:_drag.fakeDragButtonNumber];
        CGEventRef draggedEvent = CGEventCreateMouseEvent(NULL, kCGEventOtherMouseDragged, location, button);
        CGEventPost(kCGSessionEventTap, draggedEvent);
        CFRelease(draggedEvent);
    }
    _drag.phase = kIOHIDEventPhaseChanged;
}

+ (void)deactivate {
    [self deactivateCancel:false];
}

+ (void)suspend {
    /// Deactivate and re-initialize
    
    [self deactivateCancel:true];
    initDragState();
}

+ (void)deactivateCancel:(BOOL)cancel {
    
//    DDLogDebug(@"Deactivating modified drag with state: %@", [self modifiedDragStateDescription:_drag]);
    
    if (_drag.activationState == kMFModifiedInputActivationStateNone) return;
    
    disableMouseTracking(); // Moved this up here instead of at the end of the function to minimize mouseMovedOrDraggedCallback() being called when we don't need that anymore. Not sure if it makes a difference.
    
    if (_drag.activationState == kMFModifiedInputActivationStateInUse) {
        handleDeactivationWhileInUse(cancel);
    }
    _drag.activationState = kMFModifiedInputActivationStateNone;
}

static void handleDeactivationWhileInUse(BOOL cancelation) {
    if ([_drag.type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) {
        
        MFDockSwipeType type;
        IOHIDEventPhaseBits phase;
        
        struct ModifiedDragState localDrag = _drag;
        if (localDrag.usageAxis == kMFAxisHorizontal) {
            type = kMFDockSwipeTypeHorizontal;
        } else if (localDrag.usageAxis == kMFAxisVertical) {
            type = kMFDockSwipeTypeVertical;
        } else assert(false);
        
        phase = cancelation ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
        
        [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:phase];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:phase];
        });
        // ^ The inital dockSwipe event we post will be ignored by the system when it is under load (I called this the "stuck bug" in other places). Sending the event again with a delay of 200ms (0.2s) gets it unstuck almost always. Sending the event twice gives us the best of both responsiveness and reliability.
        
        /// Revert cursor back to normal
//        if (inputIsPointerMovement) [NSCursor.closedHandCursor pop];
        
    } else if ([_drag.type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe]) {
        
        /// Send final scroll event
        ///     This will set off momentum scroll
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.05 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            /// ^ Execute this on a delay so that momentumScroll is started before the warp. That way momentumScrol will still kick in and work, even if we moved the ponter outside the scrollView that we started scrolling in.
            
            /// Set suppression interval to zero to avoid delay after
            setSuppressionInterval(kMFEventSuppressionIntervalZero);
            
            /// Set actual cursor to position of puppet cursor
            CGWarpMouseCursorPosition(puppetCursorPosition());
//            CGWarpMouseCursorPosition(_drag.origin);
            
            /// Reset suppression interval to default
            setSuppressionInterval(kMFEventSuppressionIntervalDefault);
            
            /// Show mouse pointer again
            [Utility_Transformation hideMousePointer:NO];
            
            /// Undraw puppet cursor
            [ScreenDrawer.shared undrawWithView:_puppetCursorView];
        });
        
    } else if ([_drag.type isEqualToString:kMFModifiedDragTypeFakeDrag]) {
        
        [Utility_Transformation postMouseButton:_drag.fakeDragButtonNumber down:NO];
        
    } else if ([_drag.type isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
        
        if ([TransformationManager addModePayloadIsValid:_drag.addModePayload]) { // If it's valid, then we sent the payload off to the MainApp
            [TransformationManager disableAddMode]; // Why disable it here and not when sending the payload?
        }
    }
}

#pragma mark - Helper functions

/// Event suppression

typedef enum {
    kMFEventSuppressionIntervalZero,
    kMFEventSuppressionIntervalForStoppingCursor,
    kMFEventSuppressionIntervalDefault,
} MFEventSuppressionInterval;

static MFEventSuppressionInterval _previousMFSuppressionInterval = kMFEventSuppressionIntervalDefault;
static CFTimeInterval _defaultSuppressionInterval = 0.25;
void setSuppressionInterval(MFEventSuppressionInterval mfInterval) {
    /// We use CGWarpMousePointer to keep the pointer from moving during simulated touchScroll.
    ///     However, after that, the cursor will freeze for like half a second which is annoying.
    ///     To avoid this we need to set the CGEventSuppressionInterval to 0
    ///         (I also looked into permitting all (mouse) events during suppression using `CGEventSourceSetLocalEventsFilterDuringSuppressionState()`. However, it doesn't remove the delay after warping unfortunately. Only `CGEventSourceGetLocalEventsSuppressionInterval()` works.)
    ///     Butttt I just found that whe you set the suppressionInterval to zero then CGWarpMouseCursorPosition doesn't work at all anymore..., so maybe a small value like 0.1? ... 0.05 seems to be the smallest value that fully stops pointer from moving when repeatedly calling CGWarpMouseCursorPosition()
    ///         I thought about using CGAssociateMouseAndMouseCursorPosition(), but in the end we'll still have to use the warp when deactivating to get the real pointer position to where the puppetPointerPosition is. And that's where the delay comes from. Also when using CGAssociateMouseAndMouseCursorPosition() the deltas become really inaccurate and irratic, overdriving the momentumScroll. So there's no benefit to using CGAssociateMouseAndMouseCursorPosition().
    /// Src: https://stackoverflow.com/questions/8215413/why-is-cgwarpmousecursorposition-causing-a-delay-if-it-is-not-what-is
    
    /// Get source
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    
    /// Store default
    if (_previousMFSuppressionInterval == kMFEventSuppressionIntervalDefault) {
        _defaultSuppressionInterval = CGEventSourceGetLocalEventsSuppressionInterval(src);
    }
    
    /// Get interval
    double interval;
    if (mfInterval == kMFEventSuppressionIntervalForStoppingCursor) {
        interval = 0.05; /// Can't be 0 or else repeatedly calling CGWarpMouseCursorPosition() won't work for stopping the cursor
    } else if (mfInterval == kMFEventSuppressionIntervalDefault) {
        interval = _defaultSuppressionInterval;
    } else if (mfInterval == kMFEventSuppressionIntervalZero) {
        interval = 0.0;
    } else {
        assert(false);
    }
    
    /// Set new suppressionInterval
    CGEventSourceSetLocalEventsSuppressionInterval(src, interval);
    
    /// Analyze suppresionInterval
    CFTimeInterval intervalResult = CGEventSourceGetLocalEventsSuppressionInterval(src);
    DDLogDebug(@"Event suppression interval: %f", intervalResult);
    
    /// Store previous mfInterval
    _previousMFSuppressionInterval = mfInterval;
}

void setSuppressionIntervalWithTimeInterval(CFTimeInterval interval) {
    
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    /// Set new suppressionInterval
    CGEventSourceSetLocalEventsSuppressionInterval(src, interval);
}

/// Puppet cursor

void drawPuppetCursor(BOOL fresh) {
    
    /// Get cursor
    NSCursor *cursor = NSCursor.currentCursor;
    
    /// Store cursor image into puppet view
    NSImage *puppetImage = cursor.image;
    _puppetCursorView.image = puppetImage;
    
    /// Get puppet pointer location
    CGPoint loc = puppetCursorPosition();
    
    /// Subtract hotspot to get puppet image loc
    CGPoint hotspot = cursor.hotSpot;
    CGPoint imageLoc = CGPointMake(loc.x - hotspot.x, loc.y - hotspot.y);
    
    /// Unflip coordinates to be compatible with Cocoa
    NSRect puppetImageFrame = NSMakeRect(imageLoc.x, imageLoc.y, puppetImage.size.width, puppetImage.size.height);
    NSRect puppetImageFrameUnflipped = [SharedUtility quartzToCocoaScreenSpace:puppetImageFrame];
    
    /// Draw!
    if (fresh) {
        [ScreenDrawer.shared drawWithView:_puppetCursorView atFrame:puppetImageFrameUnflipped onScreen:NSScreen.mainScreen];
    } else {
        [ScreenDrawer.shared moveWithView:_puppetCursorView toFrame:puppetImageFrameUnflipped];
    }
}

CGPoint puppetCursorPosition(void) {
    
    /// Get base pos
    CGPoint pos = CGPointMake(_drag.origin.x + _drag.originOffset.x, _drag.origin.y + _drag.originOffset.y);
    
    /// Clip to screen bounds
    CGRect screenSize = CGDisplayBounds(_drag.display);
    pos.x = CLIP(pos.x, CGRectGetMinX(screenSize), CGRectGetMaxX(screenSize));
    pos.y = CLIP(pos.y, CGRectGetMinY(screenSize), CGRectGetMaxY(screenSize));
    
    /// Normalize originOffsets
    ///     Not sure if good idea. Origin offset is also used for other important stuff
    
    /// return
    return pos;
}

/// Disable mouse tracking
///     I forgot what this does. Is it necessary?

static void disableMouseTracking() {
    if (inputIsPointerMovement) {
        CGEventTapEnable(_drag.eventTap, false);
        [NSCursor.closedHandCursor pop];
    } else {
        [_drag.modifiedDevice receiveOnlyButtonInput];
    }
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
