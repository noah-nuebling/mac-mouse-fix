//
// --------------------------------------------------------------------------
// ModifiedDragOutputThreeFingerDrag.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputThreeFingerSwipe.h"
#import "CGSSpace.h"
#import "TouchSimulator.h"
@import Cocoa;
@import QuartzCore;
#import "PointerFreeze.h"
#import "SymbolicHotKeys.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation ModifiedDragOutputThreeFingerSwipe

/// Vars

static ModifiedDragState *_drag;

static int16_t _nOfSpaces = 1;

/// On macOS 26 (Tahoe) and later, the WindowServer drops synthetic dockSwipe gesture events (`CGXSenderCanSynthesizeEvents()` compares the sender PID against the WindowServer's – not bypassable through code signing or TCC grants). So instead of the smooth dockSwipe gesture we accumulate the drag and trigger the corresponding SymbolicHotKeys at fixed thresholds. Trade-off: discrete jumps instead of following the pointer.
static BOOL useSymbolicHotKeyFallback(void) {
    if (@available(macOS 26.0, *)) return YES;
    return NO;
}

static double _accumulatedDelta = 0;
static double _smoothedVelocity = 0;       /// Exponential moving average of drag speed along the usage axis (px/s)
static CFTimeInterval _lastInputTime = 0;
static int _verticalState = 0;             /// 0: nothing open, -1: Mission Control opened by this gesture, +1: App Exposé opened

static const double _thresholdHorizontal = 220.0; /// Pixels of drag per space-switch
static const double _thresholdVertical = 150.0;   /// Pixels of drag to trigger Mission Control / App Exposé
static const double _flickMinDistance = 50.0;     /// Minimum drag distance for a flick to count on release
static const double _flickMinVelocity = 600.0;    /// px/s – release faster than this fires even below the distance threshold

/// Interface funcs

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
}

+ (void)handleBecameInUse {
    /// Get number of spaces
    ///     for use in `handleMouseInputWhileInUse()`. Getting it here for performance reasons. Not sure if significant.
    CFArrayRef spaces = CGSCopySpaces(CGSMainConnectionID(), CGSSpaceIncludesUser | CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent);
    if (spaces != NULL) {
        /// Full screen spaces appear twice for some reason so we need to filter duplicates
        NSSet *uniqueSpaces = [NSSet setWithArray:(__bridge NSArray *)spaces];
        _nOfSpaces = MAX((int16_t)1, (int16_t)uniqueSpaces.count);
        CFRelease(spaces);
    } else {
        _nOfSpaces = 1;
    }

    /// Reset state for the symbolic-hotkey fallback
    ///     Note: `_verticalState` is deliberately NOT reset – if a previous drag opened Mission Control, the next drag (down) should close it again, like the real gesture.
    _accumulatedDelta = 0;
    _smoothedVelocity = 0;
    _lastInputTime = CACurrentMediaTime();

    /// Freeze pointer
    if (GeneralConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
    }
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {

    if (useSymbolicHotKeyFallback()) {
        /// The deltas are already inverted according to `naturalDirection` by ModifiedDrag before they reach this plugin.

        /// Track drag velocity (EMA), for flick detection on release
        CFTimeInterval now = CACurrentMediaTime();
        CFTimeInterval dt = now - _lastInputTime;
        _lastInputTime = now;
        double axisDelta = (_drag->usageAxis == kMFAxisHorizontal) ? deltaX : deltaY;
        if (dt > 0 && dt < 0.5) {
            _smoothedVelocity = 0.7 * _smoothedVelocity + 0.3 * (axisDelta / dt);
        }

        if (_drag->usageAxis == kMFAxisHorizontal) {
            _accumulatedDelta += deltaX;
            while (_accumulatedDelta >= _thresholdHorizontal) {
                [SymbolicHotKeys post:kCGSHotKeySpaceLeft]; /// Drag right -> previous space (matches the natural-direction dockSwipe)
                _accumulatedDelta -= _thresholdHorizontal;
            }
            while (_accumulatedDelta <= -_thresholdHorizontal) {
                [SymbolicHotKeys post:kCGSHotKeySpaceRight];
                _accumulatedDelta += _thresholdHorizontal;
            }
        } else if (_drag->usageAxis == kMFAxisVertical) {
            _accumulatedDelta += deltaY;
            if (_verticalState == 0) {
                if (_accumulatedDelta <= -_thresholdVertical) {
                    [SymbolicHotKeys post:kCGSHotKeyExposeAllWindows]; /// Drag up -> Mission Control
                    _verticalState = -1;
                    _accumulatedDelta = 0;
                } else if (_accumulatedDelta >= _thresholdVertical) {
                    [SymbolicHotKeys post:kCGSHotKeyExposeApplicationWindows]; /// Drag down -> App Exposé
                    _verticalState = +1;
                    _accumulatedDelta = 0;
                }
            } else if (_verticalState == -1) {
                /// Mission Control is open – dragging back down closes it (the SHK toggles), like the real gesture
                if (_accumulatedDelta < 0) _accumulatedDelta = 0; /// Only track progress in the closing direction
                if (_accumulatedDelta >= _thresholdVertical) {
                    [SymbolicHotKeys post:kCGSHotKeyExposeAllWindows];
                    _verticalState = 0;
                    _accumulatedDelta = 0;
                }
            } else { /// _verticalState == +1
                /// App Exposé is open – dragging back up closes it
                if (_accumulatedDelta > 0) _accumulatedDelta = 0;
                if (_accumulatedDelta <= -_thresholdVertical) {
                    [SymbolicHotKeys post:kCGSHotKeyExposeApplicationWindows];
                    _verticalState = 0;
                    _accumulatedDelta = 0;
                }
            }
        }
        return;
    }

    /**
     Horizontal dockSwipe scaling
     This makes horizontal dockSwipes (switch between spaces) follow the pointer exactly
     I arrived at these value through testing documented in the NotePlan note "MMF - Scraps - Testing DockSwipe scaling"
     TODO: Test this on a vertical screen
     */
    CGSize screenSize = NSScreen.mainScreen.frame.size;
    double originOffsetForOneSpace = _nOfSpaces == 1 ? 2.0 : 1.0 + (1.0 / (_nOfSpaces-1));
    double spaceSeparatorWidth = 63;
    double threeFingerScaleH = originOffsetForOneSpace / (screenSize.width + spaceSeparatorWidth);
    
    /// Vertical dockSwipe scaling
    ///     Not sure if it makes sense to scale this with screen height
    double threeFingerScaleV = 1.0 / screenSize.height;
    
    /// Get phase
    
    IOHIDEventPhaseBits eventPhase = _drag->firstCallback ? kIOHIDEventPhaseBegan : kIOHIDEventPhaseChanged;
    
    /// Send events
    
    if (_drag->usageAxis == kMFAxisHorizontal) {
        double delta = -deltaX * threeFingerScaleH;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:eventPhase invertedFromDevice:_drag->naturalDirection];
    } else if (_drag->usageAxis == kMFAxisVertical) {
        double delta = deltaY * threeFingerScaleV;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:eventPhase invertedFromDevice:_drag->naturalDirection];
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {

    if (useSymbolicHotKeyFallback()) {

        /// Flick detection: a fast release below the distance threshold still fires, like the real gesture's momentum
        if (!cancel
            && fabs(_accumulatedDelta) >= _flickMinDistance
            && fabs(_smoothedVelocity) >= _flickMinVelocity
            && (_smoothedVelocity > 0) == (_accumulatedDelta > 0)) { /// Only if still moving in the accumulated direction

            if (_drag->usageAxis == kMFAxisHorizontal) {
                [SymbolicHotKeys post:(_accumulatedDelta > 0 ? kCGSHotKeySpaceLeft : kCGSHotKeySpaceRight)];
            } else if (_drag->usageAxis == kMFAxisVertical) {
                if (_verticalState == 0) {
                    [SymbolicHotKeys post:(_accumulatedDelta < 0 ? kCGSHotKeyExposeAllWindows : kCGSHotKeyExposeApplicationWindows)];
                    _verticalState = (_accumulatedDelta < 0) ? -1 : +1;
                } else if (_verticalState == -1 && _accumulatedDelta > 0) {
                    [SymbolicHotKeys post:kCGSHotKeyExposeAllWindows]; /// Flick down closes Mission Control
                    _verticalState = 0;
                } else if (_verticalState == +1 && _accumulatedDelta < 0) {
                    [SymbolicHotKeys post:kCGSHotKeyExposeApplicationWindows]; /// Flick up closes App Exposé
                    _verticalState = 0;
                }
            }
        }
        _accumulatedDelta = 0;

        /// No gesture-end event to send – just unfreeze the pointer
        if (GeneralConfig.freezePointerDuringModifiedDrag) {
            [PointerFreeze unfreeze];
        }
        return;
    }

    MFDockSwipeType type;
    IOHIDEventPhaseBits phase;
    
    if (_drag->usageAxis == kMFAxisHorizontal) {
        type = kMFDockSwipeTypeHorizontal;
    } else if (_drag->usageAxis == kMFAxisVertical) {
        type = kMFDockSwipeTypeVertical;
    } else {
        assert(false);
    }
    
    phase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
    
    [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:phase invertedFromDevice:_drag->naturalDirection];
    
    /// Unfreeze pointer
    if (GeneralConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze unfreeze];
    }
    
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
