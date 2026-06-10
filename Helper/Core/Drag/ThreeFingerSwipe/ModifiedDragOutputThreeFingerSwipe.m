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
static BOOL _verticalSHKWasTriggered = NO;

static const double _thresholdHorizontal = 220.0; /// Pixels of drag per space-switch
static const double _thresholdVertical = 150.0;   /// Pixels of drag to trigger Mission Control / App Exposé

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
    _accumulatedDelta = 0;
    _verticalSHKWasTriggered = NO;

    /// Freeze pointer
    if (GeneralConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
    }
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {

    if (useSymbolicHotKeyFallback()) {
        /// The deltas are already inverted according to `naturalDirection` by ModifiedDrag before they reach this plugin.

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
            /// Mission Control and App Exposé are toggles, so only fire once per drag to prevent flickering
            if (!_verticalSHKWasTriggered) {
                _accumulatedDelta += deltaY;
                if (_accumulatedDelta <= -_thresholdVertical) {
                    [SymbolicHotKeys post:kCGSHotKeyExposeAllWindows]; /// Drag up -> Mission Control
                    _verticalSHKWasTriggered = YES;
                } else if (_accumulatedDelta >= _thresholdVertical) {
                    [SymbolicHotKeys post:kCGSHotKeyExposeApplicationWindows]; /// Drag down -> App Exposé
                    _verticalSHKWasTriggered = YES;
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
