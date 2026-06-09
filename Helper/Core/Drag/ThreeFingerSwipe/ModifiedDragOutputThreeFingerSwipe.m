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
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "SymbolicHotKeys.h"
#import "Constants.h"

@implementation ModifiedDragOutputThreeFingerSwipe

/// Vars

static ModifiedDragState *_drag;

static int16_t _nOfSpaces = 1;

/// Track the vertical direction determined when the gesture usage threshold is first crossed.
///   YES = moving UP  → Mission Control (animated dock swipe)
///   NO  = moving DOWN → App Exposé
static BOOL _verticalIsUpward;

/// Whether the one-shot App Exposé symbolic-hotkey fallback has already fired
/// for the current downward gesture.
static BOOL _appExposeSymbolicHotKeyFired;

/// Whether the one-shot Mission Control symbolic-hotkey fallback has already fired
/// for the current upward gesture.
static BOOL _missionControlSymbolicHotKeyFired;

/// Interface funcs

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
}

+ (void)handleBecameInUse {
    /// Get number of spaces
    ///     for use in `handleMouseInputWhileInUse()`. Getting it here for performance reasons. Not sure if significant.
    CFArrayRef spaces = CGSCopySpaces(CGSMainConnectionID(), CGSSpaceIncludesUser | CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent);
    /// Full screen spaces appear twice for some reason so we need to filter duplicates
    NSSet *uniqueSpaces = [NSSet setWithArray:(__bridge NSArray *)spaces];
    _nOfSpaces = uniqueSpaces.count;
    
    CFRelease(spaces);
    
    /// Determine the vertical direction from the accumulated originOffset
    ///   (ModifiedDrag.m sets usageAxis and accumulates originOffset before calling handleBecameInUse)
    ///   originOffset.y < 0 → mouse went UP  (screen-coords: Y grows downward)
    ///   originOffset.y > 0 → mouse went DOWN
    if (_drag->usageAxis == kMFAxisVertical) {
        _verticalIsUpward              = (_drag->originOffset.y < 0);
        _appExposeSymbolicHotKeyFired  = NO;
        _missionControlSymbolicHotKeyFired = NO;
    }
    
    /// Freeze pointer
    if (GeneralConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
    }
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
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
    double threeFingerScaleV = 1.0 / screenSize.height;
    
    /// Get phase
    IOHIDEventPhaseBits eventPhase = _drag->firstCallback ? kIOHIDEventPhaseBegan : kIOHIDEventPhaseChanged;
    
    /// Send events
    
    if (_drag->usageAxis == kMFAxisHorizontal) {
        
        /// Horizontal → switch Spaces (animated dock swipe)
        double delta = -deltaX * threeFingerScaleH;
        [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeHorizontal phase:eventPhase invertedFromDevice:_drag->naturalDirection];
        
    } else if (_drag->usageAxis == kMFAxisVertical) {
        
        if (_verticalIsUpward) {
            
            /// Swipe UP → Mission Control  (animated vertical dock swipe, negative delta)
            double delta = deltaY * threeFingerScaleV; /// deltaY is negative for upward mouse movement
            [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:eventPhase invertedFromDevice:_drag->naturalDirection];
            
            if (!_missionControlSymbolicHotKeyFired) {
                _missionControlSymbolicHotKeyFired = YES;
                [SymbolicHotKeys post:(CGSSymbolicHotKey)kMFSHMissionControl];
            }
        } else {
            
            /// Swipe DOWN → App Exposé
            ///
            /// Primary path: animated vertical dock swipe with positive delta.
            ///   The system maps a positive-delta kMFDockSwipeTypeVertical event to App Exposé –
            ///   exactly the same way a real trackpad sends it when you swipe three fingers down.
            ///   This gives the full interactive animation (the windows spread out as you drag).
            ///
            /// Fallback path (symbolic hotkey):
            ///   On some macOS versions or when the App Exposé trackpad gesture is disabled in
            ///   System Settings → Trackpad → More Gestures, the dock-swipe positive delta is
            ///   silently ignored.  In that case we fire the SymbolicHotKey on the first callback
            ///   so App Exposé still activates (without animation).
            
            double delta = deltaY * threeFingerScaleV; /// deltaY is positive for downward movement
            [TouchSimulator postDockSwipeEventWithDelta:delta type:kMFDockSwipeTypeVertical phase:eventPhase invertedFromDevice:_drag->naturalDirection];
            
            /// Symbolic-hotkey fallback – fire once on the first callback.
            ///   We fire it regardless of whether the dock swipe succeeded, so it acts as a
            ///   guaranteed trigger.  If the dock swipe already worked the SHK will just be a
            ///   no-op (the UI is already shown).
            if (!_appExposeSymbolicHotKeyFired) {
                _appExposeSymbolicHotKeyFired = YES;
                [SymbolicHotKeys post:(CGSSymbolicHotKey)kMFSHAppExpose];
            }
        }
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    
    IOHIDEventPhaseBits phase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
    
    if (_drag->usageAxis == kMFAxisHorizontal) {
        [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeHorizontal phase:phase invertedFromDevice:_drag->naturalDirection];
        
    } else if (_drag->usageAxis == kMFAxisVertical) {
        if (_verticalIsUpward) {
            /// Mission Control – close out the dock swipe stream
            [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeVertical phase:phase invertedFromDevice:_drag->naturalDirection];
        } else {
            /// App Exposé downward drag – we still send the end event so the dock swipe
            /// stream is properly closed even if the system ignored it.
            [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypeVertical phase:phase invertedFromDevice:_drag->naturalDirection];
        }
    }
    
    /// Unfreeze pointer
    if (GeneralConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze unfreeze];
    }
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
