//
// --------------------------------------------------------------------------
// ModifiedDragOutputNotificationCenter.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputNotificationCenter.h"
#import "Constants.h"
#import "IOHIDEventTypes.h"
#import "PointerFreeze.h"
#import "WannabePrefixHeader.h"
#import "MFHIDEventImports.h"
#import "DragInertiaEngine.h"
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <dlfcn.h>

/// IOHIDEvent NavigationSwipe creation — dispatch at HID layer for smooth rendering
/// This bypasses CGEvent entirely and sends events the same way real trackpad hardware does.

typedef IOHIDEventRef (*IOHIDEventCreateNavigationSwipeEventFunc)(
    CFAllocatorRef allocator,
    uint64_t timeStamp,
    IOHIDSwipeMask swipeMask,
    IOHIDEventOptionBits options
);

typedef IOReturn (*IOHIDEventSystemClientDispatchEventFunc)(
    IOHIDEventSystemClientRef client,
    IOHIDEventRef event
);

typedef IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreateFunc)(
    CFAllocatorRef allocator
);

typedef void (*IOHIDEventSetFloatValueFunc)(
    IOHIDEventRef event,
    IOHIDEventField field,
    IOHIDFloat value
);

typedef void (*IOHIDEventSetIntegerValueFunc)(
    IOHIDEventRef event,
    IOHIDEventField field,
    CFIndex value
);

static IOHIDEventCreateNavigationSwipeEventFunc _IOHIDEventCreateNavigationSwipeEvent = NULL;
static IOHIDEventSystemClientDispatchEventFunc  _IOHIDEventSystemClientDispatchEvent  = NULL;
static IOHIDEventSystemClientCreateFunc         _IOHIDEventSystemClientCreate         = NULL;
static IOHIDEventSetFloatValueFunc              _IOHIDEventSetFloatValue              = NULL;
static IOHIDEventSetIntegerValueFunc            _IOHIDEventSetIntegerValue            = NULL;
static IOHIDEventSystemClientRef                _hidClient                            = NULL;

static void loadHIDSymbols(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (!handle) handle = RTLD_DEFAULT;
        _IOHIDEventCreateNavigationSwipeEvent = dlsym(handle, "IOHIDEventCreateNavigationSwipeEvent");
        _IOHIDEventSystemClientDispatchEvent  = dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
        _IOHIDEventSystemClientCreate         = dlsym(handle, "IOHIDEventSystemClientCreate");
        _IOHIDEventSetFloatValue              = dlsym(handle, "IOHIDEventSetFloatValue");
        _IOHIDEventSetIntegerValue            = dlsym(handle, "IOHIDEventSetIntegerValue");
        
        if (_IOHIDEventSystemClientCreate) {
            _hidClient = _IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        }
        
        DDLogInfo(@"NC Drag: HID symbols loaded. NavSwipe=%p Dispatch=%p Client=%p",
                  _IOHIDEventCreateNavigationSwipeEvent,
                  _IOHIDEventSystemClientDispatchEvent,
                  _hidClient);
    });
}

@implementation ModifiedDragOutputNotificationCenter

static ModifiedDragState *_drag;
static BOOL _gestureStarted;
static double _originOffset;
static double _lastDelta;
static double _velocityBuffer[5]; /// Last 5 deltas for velocity averaging
static int _velocityIndex;
static DragInertiaEngine *_ncInertia; /// Fling engine for momentum after release
static BOOL _ncIsOpen; /// Tracks whether NC was left open after last gesture
static NSInteger _ncGeneration; /// Incremented on each new drag to cancel stale dispatch_after callbacks

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    loadHIDSymbols();
    if (!_ncInertia) _ncInertia = [[DragInertiaEngine alloc] init];
    [_ncInertia cancel];
    _ncGeneration++; /// Invalidate any pending dispatch_after from previous session
}

+ (void)handleBecameInUse {
    _gestureStarted = NO;
    _lastDelta = 0.0;
    _velocityIndex = 0;
    memset(_velocityBuffer, 0, sizeof(_velocityBuffer));
    /// Note: _originOffset is intentionally NOT reset here — it persists from the
    /// previous gesture so the panel starts exactly where it was left.
    
    /// Debug log
    FILE *f = fopen("/Users/virgoh/Library/Application Support/com.virgoh.mac-mouse-fix/nc_drag.log", "a");
    if (f) { fprintf(f, "=== handleBecameInUse offset=%.3f ncIsOpen=%d ===\n", _originOffset, _ncIsOpen); fclose(f); }
    
    /// Warp cursor to right edge — NC gesture requires edge position
    CGEventRef locEvent = CGEventCreate(NULL);
    CGPoint cursorPos = CGEventGetLocation(locEvent);
    CFRelease(locEvent);
    
    NSPoint mouse = [NSEvent mouseLocation];
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(mouse, screen.frame)) {
            CGDirectDisplayID displayID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
            CGRect bounds = CGDisplayBounds(displayID);
            CGPoint edgePoint = CGPointMake(bounds.origin.x + bounds.size.width - 2, cursorPos.y);
            CGWarpMouseCursorPosition(edgePoint);
            break;
        }
    }
    
    CGDisplayHideCursor(kCGNullDirectDisplay);
    [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    CGSize screenSize = NSScreen.mainScreen.frame.size;
    double baseScale = 1.8 / screenSize.width;
    
    /// Skip initialization artifacts
    if (fabs(deltaX) > 80) return;
    
    /// Non-linear input curve — same principle as VolumeBrightness:
    /// slow = precise fine control, fast = covers full range quickly.
    /// Toned down vs VolumeBrightness since NC offset range (0-2) is sensitive.
    double absX = fabs(deltaX);
    double accelMultiplier = 1.0 + fmin(absX / 20.0, 1.5); /// 1x–2.5x (gentler than vol/bright)
    /// Precision floor for very slow movements
    double precisionScale = 1.0;
    if (absX < 3.0) {
        precisionScale = 0.2 + (absX / 3.0) * 0.8; /// 0.2 at 0px → 1.0 at 3px
    }
    double delta = deltaX * baseScale * precisionScale * accelMultiplier;
    
    if (!_gestureStarted) {
        _gestureStarted = YES;
        
        /// First event: use base scale only (no non-linear boost) to avoid jump on start
        double firstDelta = deltaX * baseScale;
        _originOffset += firstDelta;
        _originOffset = fmax(0.0, fmin(2.0, _originOffset));
        
        /// Track velocity even on first event (important for fling detection)
        double unused1, unused2;
        [_ncInertia trackDeltaX:deltaX deltaY:0 outDeltaX:&unused1 outDeltaY:&unused2];
        
        [self postNCSwipeWithOffset:_originOffset phase:kIOHIDEventPhaseBegan];
        return;
    }
    
    _originOffset += delta;
    _originOffset = fmax(-0.3, fmin(2.3, _originOffset)); /// Allow slight overscroll for rubberband
    _lastDelta = delta;
    _velocityBuffer[_velocityIndex % 5] = delta;
    _velocityIndex++;
    
    {
        FILE *f = fopen("/Users/virgoh/Library/Application Support/com.virgoh.mac-mouse-fix/nc_drag.log", "a");
        if (f) { fprintf(f, "input: deltaX=%.1f delta=%.4f offset=%.3f\n", deltaX, delta, _originOffset); fclose(f); }
    }
    
    /// Track velocity for fling
    double unused1, unused2;
    [_ncInertia trackDeltaX:deltaX deltaY:0 outDeltaX:&unused1 outDeltaY:&unused2];
    
    [self postNCSwipeWithOffset:_originOffset phase:kIOHIDEventPhaseChanged];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    
    if (!_gestureStarted) {
        CGDisplayShowCursor(kCGNullDirectDisplay);
        [PointerFreeze unfreeze];
        return;
    }
    
    if (cancel) {
        [_ncInertia cancel];
        _ncIsOpen = NO;
        [self postNCSwipeWithOffset:_originOffset phase:kIOHIDEventPhaseCancelled];
        _originOffset = 0.0; /// OS will spring to closed
        CGDisplayShowCursor(kCGNullDirectDisplay);
        [PointerFreeze unfreeze];
        return;
    }
    
    /// Both open and close: send the final event immediately and let the OS animate.
    /// Animating the offset ourselves breaks the continuous gesture stream,
    /// causing the OS to reset position to 0 on the next Began.
    
    BOOL isClosingFling = (_lastDelta < -0.008);  /// deliberate leftward fling
    BOOL isOpeningFling = (_lastDelta > 0.008);   /// deliberate rightward fling
    
    /// Guard: don't close if already closed, don't "open-fling" if already open
    if (isClosingFling && _originOffset <= 0.05) isClosingFling = NO;
    if (isOpeningFling && _originOffset >= 0.55) isOpeningFling = NO;
    
    IOHIDEventPhaseBits finalPhase;
    if (isClosingFling) {
        finalPhase = kIOHIDEventPhaseCancelled;
        _ncIsOpen = NO;
    } else if (isOpeningFling) {
        finalPhase = kIOHIDEventPhaseEnded;
        _ncIsOpen = YES;
    } else {
        /// Slow release — decide by position (NC fully open around offset 0.5+)
        finalPhase = (_originOffset >= 0.5) ? kIOHIDEventPhaseEnded : kIOHIDEventPhaseCancelled;
        _ncIsOpen = (finalPhase == kIOHIDEventPhaseEnded);
    }
    
    /// Clamp offset back to valid range before sending final event
    _originOffset = fmax(0.0, fmin(2.0, _originOffset));
    
    {
        FILE *f = fopen("/Users/virgoh/Library/Application Support/com.virgoh.mac-mouse-fix/nc_drag.log", "a");
        if (f) { fprintf(f, "RELEASE: offset=%.3f lastDelta=%.4f isClosing=%d isOpening=%d phase=%s ncIsOpen=%d\n---\n",
            _originOffset, _lastDelta, isClosingFling, isOpeningFling,
            (finalPhase == kIOHIDEventPhaseEnded ? "Ended" : "Cancelled"), _ncIsOpen); fclose(f); }
    }
    
    /// Boost exit speed so the OS animates decisively to open or closed
    double savedLastDelta = _lastDelta;
    _lastDelta = savedLastDelta * 12.0;
    [self postNCSwipeWithOffset:_originOffset phase:finalPhase];
    _lastDelta = savedLastDelta;
    
    /// Reset offset to match where the OS will actually settle after its animation.
    /// This prevents the next Began from snapping to a stale position.
    _originOffset = _ncIsOpen ? 1.4 : 0.0;
    
    CGDisplayShowCursor(kCGNullDirectDisplay);
    [PointerFreeze unfreeze];
}

+ (void)postNCSwipeWithOffset:(double)offset phase:(IOHIDEventPhaseBits)phase {
    
    /// CGEvent path — posts NavigationSwipe events (slightly choppy but functional)
    CGEventRef e29 = CGEventCreate(NULL);
    CGEventSetDoubleValueField(e29, 55, 29);
    CGEventSetIntegerValueField(e29, 45, 1);
    CGEventSetIntegerValueField(e29, 53, 3);
    CGEventSetIntegerValueField(e29, 101, 28);
    CGEventSetIntegerValueField(e29, 107, 848);
    
    CGEventRef e31 = CGEventCreate(NULL);
    CGEventSetDoubleValueField(e31, 55, 31);
    CGEventSetIntegerValueField(e31, 45, 1);
    CGEventSetIntegerValueField(e31, 53, 3);
    CGEventSetIntegerValueField(e31, 101, 28);
    CGEventSetIntegerValueField(e31, 107, 848);
    CGEventSetDoubleValueField(e31, 110, 27);
    CGEventSetDoubleValueField(e31, 119, 1.401298464324817e-45);
    CGEventSetDoubleValueField(e31, 123, 1);
    CGEventSetDoubleValueField(e31, 139, 1.401298464324817e-45);
    CGEventSetDoubleValueField(e31, 165, 1);
    CGEventSetIntegerValueField(e31, 138, 1);
    CGEventSetDoubleValueField(e31, 132, phase);
    CGEventSetDoubleValueField(e31, 134, phase);
    CGEventSetDoubleValueField(e31, 124, offset);
    Float32 ofsFloat32 = (Float32)offset;
    uint32_t ofsInt32;
    memcpy(&ofsInt32, &ofsFloat32, sizeof(ofsFloat32));
    CGEventSetIntegerValueField(e31, 135, (int64_t)ofsInt32);
    if (phase == kIOHIDEventPhaseEnded || phase == kIOHIDEventPhaseCancelled) {
        double exitSpeed = _lastDelta * 100.0;
        CGEventSetDoubleValueField(e31, 129, exitSpeed);
        CGEventSetDoubleValueField(e31, 130, exitSpeed);
    }
    CGEventPost(kCGSessionEventTap, e31);
    CGEventPost(kCGSessionEventTap, e29);
    CFRelease(e31);
    CFRelease(e29);
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
