//
// --------------------------------------------------------------------------
// ModifiedDragOutputTwoFingerSwipe.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputTwoFingerSwipe.h"
static ModifiedDragState *_drag;
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "Utility_Transformation.h"
#import "GestureScrollSimulator.h"
#import "CGSConnection.h"

@implementation ModifiedDragOutputTwoFingerSwipe

#pragma mark - Vars

static ModifiedDragState *_drag;

static int _cgsConnection; /// This is used by private APIs to talk to the window server and do fancy shit like hiding the cursor from a background application
static NSCursor *_puppetCursor;
static NSImageView *_puppetCursorView;
static /*PixelatedAnimator*/ BaseAnimator *_smoothingAnimator;
static BOOL _smoothingAnimatorShouldStartMomentumScroll = NO;
static dispatch_group_t _momentumScrollWaitGroup;
static CGDirectDisplayID _display;

#pragma mark - Init

+ (void)load_Manual {
    
    /// Setup smoothingAnimator
    ///     When using a twoFingerModifedDrag and performance drops, the timeBetweenEvents can sometimes be erratic, and this sometimes leads apps like Xcode to start their custom momentumScroll algorithms with way too high speeds (At least I think that's whats going on) So we're using an animator to smooth things out and hopefully achieve more consistent behaviour
    _smoothingAnimator = [[BaseAnimator alloc] init];
    
    /// Setup cgs stuff
    _cgsConnection = CGSMainConnectionID();
    
    /// Setup puppet cursor
    _puppetCursorView = [[NSImageView alloc] init];
    
    /// Setup smoothingGroup
    ///     It allows us to wait until the _smoothingAnimator is done.
    
    _momentumScrollWaitGroup = dispatch_group_create();
}

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
}

+ (void)handleBecameInUse {
    
    /// Get display under mouse pointer
    CVReturn rt = [Utility_Helper display:&_display atPoint:_drag->usageOrigin];
    if (rt != kCVReturnSuccess) DDLogWarn(@"Couldn't get display under mouse pointer in modifiedDrag");
    
    /// Draw puppet cursor before hiding
    drawPuppetCursor(YES, YES);
    
    /// Decrease delay after warping
    ///     But only as much so that it doesn't break `CGWarpMouseCursorPosition(()` ability to stop cursor by calling repeatedly
    ///     This changes the timeout globally for many events, so we need to reset this after the drag is deactivated!
    setSuppressionInterval(kMFEventSuppressionIntervalForStoppingCursor);
    
    /// Hide cursor
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.02), _drag->queue, ^{
        /// The puppetCursor will only be drawn after a delay, while hiding the mouse pointer is really fast.
        ///     This leads to a little flicker when the puppetCursor is not yet drawn, but the real cursor is already hidden.
        ///     Not sure why this happens. But adding a delay of 0.02 before hiding makes it look seamless.
        
        [Utility_Transformation hideMousePointer:YES];
    });
    
    // [GestureScrollSimulator postGestureScrollEventWithGestureDeltaX:0.0 deltaY:0.0 phase:kIOHIDEventPhaseMayBegin];
    /// ^ Always sending this at the start breaks swiping between pages on some websites (Google search results)
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /**
     scrollSwipe scaling
     A scale of 1.0 will make the pixel based animations (normal scrolling) follow the mouse pointer.
     Gesture based animations (swiping between pages in Safari etc.) seem to be scaled separately such that swiping 3/4 (or so) of the way across the Trackpad equals one whole page. No matter how wide the page is.
     So to scale the gesture deltas such that the page-change-animations follow the mouse pointer exactly, we'd somehow have to get the width of the underlying scrollview. This might be possible using the _systemWideAXUIElement we created in ScrollControl, but it'll probably be really slow.
     */
    double twoFingerScale = 1.0;
    
    /// Warp pointer to origin to prevent cursor movement
    ///     This only works when the suppressionInterval is a certain size, and that will cause a slight stutter / delay until the mouse starts moving againg when we deactivate. So this isn't optimal
    CGWarpMouseCursorPosition(_drag->usageOrigin);
    //        CGWarpMouseCursorPosition(_drag->origin);
    /// ^ Move pointer to origin instead of usageOrigin to make scroll events dispatch there - would be nice but that moves the pointer, which creates events which will feed back into our eventTap and mess everything up (even though `CGWarpMouseCursorPosition` docs say that it doesn't create events??)
    ///     I gues we'll just have to make the usageThreshold small instead
    
    /// Disassociate pointer to prevent cursor movements
    ///     This makes the inputDeltas weird I feel. Better to freeze pointer through calling CGWarpMouseCursorPosition repeatedly.
    //        CGAssociateMouseAndMouseCursorPosition(NO);
    
    /// Draw puppet cursor
    drawPuppetCursor(YES, NO);
    
    /// Post event
    ///     Using animator for smoothing
    
    /// Smoothing group allows us to us to wait until the smoothingAnimator is finished and momentumScroll has started
    if (!_smoothingAnimator.isRunning) {
        DDLogDebug(@"\nEntering dispatch group from ModifiedDrag");
        dispatch_group_enter(_momentumScrollWaitGroup);
        [_smoothingAnimator onStopWithCallback:^{
            printf("\nLeaving dispatch group from animator stop callback\n");
            dispatch_group_leave(_momentumScrollWaitGroup);
        }];
    }
    
    /// Declare static vars for animator
    static IOHIDEventPhaseBits eventPhase = kIOHIDEventPhaseUndefined;
    static Vector combinedDirection = { .x = 0, .y = 0 };
    
    /// Values that block should copy instead of reference
    IOHIDEventPhaseBits dragPhase = _drag->phase;
    
    /// Start animator
    ///     We made this a BaseAnimator instead of a PixelatedAnimator for debugging
    [_smoothingAnimator startWithParams:^NSDictionary<NSString *,id> * _Nonnull(double valueLeft, BOOL isRunning, id<AnimationCurve> _Nullable curve) {
        
        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        
        Vector lastDirection = combinedDirection;
        
        Vector currentVec = { .x = deltaX*twoFingerScale, .y = deltaY*twoFingerScale };
        double magnitudeLeft = valueLeft;
        
        Vector vectorLeft = scaledVector(lastDirection, magnitudeLeft);
        Vector combinedVec = addedVectors(currentVec, vectorLeft);
        
        double combinedMagnitude = magnitudeOfVector(combinedVec);
        combinedDirection = unitVector(combinedVec);
        
        if (dragPhase == kIOHIDEventPhaseBegan) eventPhase = kIOHIDEventPhaseBegan;
        
        /// Debug
        
        DDLogDebug(@"Starting BaseAnimator - deltaLeft: %f, inputVec: (%f, %f), oldDirection: (%f, %f), combinedDelta: %f", valueLeft, currentVec.x, currentVec.y, lastDirection.x, lastDirection.y, combinedMagnitude);
        
        static double lastTs = 0;
        double ts = CACurrentMediaTime();
        double tsDiff = ts - lastTs;
        lastTs = ts;
        
        DDLogDebug(@"Time since last baseAnimator start: %f", tsDiff * 1000);
        
        /// Return
        
        if (combinedMagnitude == 0.0) {
            DDLogDebug(@"Not starting baseAnimator since combinedMagnitude is 0.0");
            p[@"doStart"] = @NO;
        } else {
            p[@"value"] = @(combinedMagnitude);
            p[@"duration"] = @(3.0/60); // @(0.00001); // @(0.04);
            p[@"curve"] = ScrollConfig.linearCurve;
        }
        
        return p;
        
    } callback:^(double valueDeltaD, double timeDelta, MFAnimationPhase phase) {
        
        NSInteger valueDelta = ceil(valueDeltaD);
        
        if (_smoothingAnimatorShouldStartMomentumScroll
            && (phase == kMFAnimationPhaseEnd || phase == kMFAnimationPhaseStartAndEnd)) {
            /// Sorry for this confusing code. Heres the idea:
            /// Due to the nature of PixelatedAnimator, the last delta is almost always much smaller. This will make apps like Xcode start momentumScroll at a too low speed. Also apps like Xcode will have a litte stuttery jump when the time between the kIOHIDEventPhaseEnded event and the previous event is very small
            ///     Our solution to these two problems is to set the _smoothingAnimatorShouldStartMomentumScroll flag when the user releases the button, and if this flag is set, we transform the last delta callback from the animator into the kIOHIDEventPhaseEnded GestureScroll event. The deltas from this last callback are lost like this, but no one will notice.
            
            /// Debug
            DDLogDebug(@"Shifting dispatch group exit from smoothingAnimator stop to momentumScroll start");
            
            /// Shift dispatch group leaving to gestureScroll
            [_smoothingAnimator onStop_SynchronouslyFromAnimationQueueWithCallback: ^{}];
            [GestureScrollSimulator afterStartingMomentumScroll:^{
                DDLogDebug(@"\nLeaving dispatch group from momentum start callback\n");
                dispatch_group_leave(_momentumScrollWaitGroup);
            }];
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
            _smoothingAnimatorShouldStartMomentumScroll = NO;
        } else {
            //            IOHIDEventPhaseBits eventPhase = phase == kMFAnimationPhaseStart || phase == kMFAnimationPhaseStartAndEnd ? kIOHIDEventPhaseBegan : kIOHIDEventPhaseChanged;
            Vector deltaVec = scaledVector(combinedDirection, valueDelta);
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:deltaVec.x deltaY:deltaVec.y phase:eventPhase];
            if (eventPhase == kIOHIDEventPhaseBegan) eventPhase = kIOHIDEventPhaseChanged;
        }
        
    }];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancelation {
    
    //        /// Draw puppet cursor
    //        drawPuppetCursorWithFresh(YES, YES);
    //
    //        /// Hide real cursor
    //        [Utility_Transformation hideMousePointer:YES];
    //_
    //        /// Set suppression interval
    //        setSuppressionInterval(kMFEventSuppressionIntervalForStartingMomentumScroll);
    //
    //        /// Set _drag to origin to start momentum scroll there
    //        CGWarpMouseCursorPosition(_drag->origin);
    
    /// Send final scroll event
    ///     This will set off momentum scroll
    //        [_smoothingAnimator onStopWithCallback:^{ /// Do this after the smoothingAnimator is done animating
    //            [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
    //        }];
    
    /// Send final scroll event (or wait until final scroll event has been sent)
    ///     (Final scroll events starts momentumScroll)
    
    if (_smoothingAnimator.isRunning) {
        
        _smoothingAnimatorShouldStartMomentumScroll = YES; /// _smoothingAnimator callback also manipulates this which is a race cond
        
    } else {
        DDLogDebug(@"Entering dispatch group from deactivate()");
        dispatch_group_enter(_momentumScrollWaitGroup);
        [GestureScrollSimulator afterStartingMomentumScroll:^{
            DDLogDebug(@"Leaving dispatch group from momentumScroll callback (Scheduled by deactivate())");
            dispatch_group_leave(_momentumScrollWaitGroup);
        }];
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
    }
    
    /// Wait until momentumScroll has been started
    ///     We want to wait for momentumScroll so it is started before the warp. That way momentumScrol will still kick in and work, even if we moved the pointer outside the scrollView that we started scrolling in.
    ///     Waiting here will also block all other items on _twoFingerDragQueue
    
    ///     This whole _momentumScrollWaitGroup thing is pretty risky, because if there is any race condition and we don't leave the group properly, then we need to crash the whole app (I think?).
    ///     It's really hard to avoid race conditions here though the different  eventTap threads that control ModifiedDrag and all the different nested dispatch queues of ModifiedDrag and its smoothingAnimator and the GestureScrollSimulator queue and it's momentumAnimator's queue and then all those animators have displayLinks with their own queues.... All of these queues call each other in a mix of synchronous and asynchronous, and it all needs to work perfectly without race conditions or deadlocks... Really hard to keep track of.
    ///     If our code is perfect, then it's a good solution though!
    
    intptr_t rt = dispatch_group_wait(_momentumScrollWaitGroup, dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC));
    if (rt != 0) {
        DDLogWarn(@"Waiting for dispatch group _momentumScrollWaitGroup timed out. _momentumScrollWaitGroup info: %@. Crashing.", _momentumScrollWaitGroup.debugDescription);
        assert(false);
    }
    
    /// Get puppet Cursor position
    CGPoint puppetPos = puppetCursorPosition();
    
    /// Set suppression interval for warping
    setSuppressionInterval(kMFEventSuppressionIntervalForWarping);
    
    /// Warp actual cursor to position of puppet cursor
    CGWarpMouseCursorPosition(puppetPos);
    
    /// Show mouse pointer again
    [Utility_Transformation hideMousePointer:NO];
    
    /// Undraw puppet cursor
    drawPuppetCursor(NO, NO);
    
    /// Reset suppression interval to default
    setSuppressionInterval(kMFEventSuppressionIntervalDefault);
}

#pragma mark - Helper functions

/// Event suppression

typedef enum {
    kMFEventSuppressionIntervalForWarping,
    kMFEventSuppressionIntervalForStoppingCursor,
    kMFEventSuppressionIntervalForStartingMomentumScroll,
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
        interval = 0.07; /// 0.05; /// Can't be 0 or else repeatedly calling CGWarpMouseCursorPosition() won't work for stopping the cursor
    } else if (mfInterval == kMFEventSuppressionIntervalForStartingMomentumScroll) {
        assert(false); /// Not using this anymore
        interval = 0.01;
    } else if (mfInterval == kMFEventSuppressionIntervalDefault) {
        interval = _defaultSuppressionInterval;
    } else if (mfInterval == kMFEventSuppressionIntervalForWarping) {
        interval = 0.000;
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

void drawPuppetCursor(BOOL draw, BOOL fresh) {
    
    /// Define workload block
    ///     (Graphics code always needs to be executed on main)
    
    void (^workload)(void) = ^{
        
        if (!draw) {
            _puppetCursorView.alphaValue = 0; /// Make the puppetCursor invisible
            return;
        }
        
        if (_puppetCursor == nil) {
            /// Init puppetCursot
            ///     Might be better to do this during ModifidDrags + initialize function
            _puppetCursor = NSCursor.arrowCursor;
        }
        
        if (fresh) {
            /// Use the currently displaying cursor, instead of the default arrow cursor
            //            _puppetCursor = NSCursor.currentSystemCursor;
            
            /// Store cursor image into puppet view
            _puppetCursorView.image = _puppetCursor.image;
        }
        
        /// Get puppet pointer location
        CGPoint loc = puppetCursorPosition();
        
        /// Subtract hotspot to get puppet image loc
        CGPoint hotspot = _puppetCursor.hotSpot;
        CGPoint imageLoc = CGPointMake(loc.x - hotspot.x, loc.y - hotspot.y);
        
        /// Unflip coordinates to be compatible with Cocoa
        NSRect puppetImageFrame = NSMakeRect(imageLoc.x, imageLoc.y, _puppetCursorView.image.size.width, _puppetCursorView.image.size.height);
        NSRect puppetImageFrameUnflipped = [SharedUtility quartzToCocoaScreenSpace:puppetImageFrame];
        
        
        if (fresh) {
            /// Draw puppetCursor
            [ScreenDrawer.shared drawWithView:_puppetCursorView atFrame:puppetImageFrameUnflipped onScreen:NSScreen.mainScreen];
        } else {
            /// Reposition  puppet cursor!
            [ScreenDrawer.shared moveWithView:_puppetCursorView toOrigin:puppetImageFrameUnflipped.origin];
        }
        
        /// Unhide puppet cursot
        _puppetCursorView.alphaValue = 1;
    };
    
    /// Make sure workload is executed on main thread
    
    if (NSThread.isMainThread) {
        workload();
    } else {
        dispatch_sync(dispatch_get_main_queue(), workload);
    }
}

CGPoint puppetCursorPosition(void) {
    
    /// Get base pos
    CGPoint pos = CGPointMake(_drag->origin.x + _drag->originOffset.x, _drag->origin.y + _drag->originOffset.y);
    
    /// Clip to screen bounds
    CGRect screenSize = CGDisplayBounds(_display);
    pos.x = CLIP(pos.x, CGRectGetMinX(screenSize), CGRectGetMaxX(screenSize));
    pos.y = CLIP(pos.y, CGRectGetMinY(screenSize), CGRectGetMaxY(screenSize));
    
    /// Clip originOffsets to screen bounds
    ///     Not sure if good idea. Origin offset is also used for other important stuff
    
    /// return
    return pos;
}


@end
