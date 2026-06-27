//
// --------------------------------------------------------------------------
// ModifiedDragOutputRotateZoom.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputRotateZoom.h"
#import "TouchSimulator.h"
#import "Constants.h"
#import "IOHIDEventTypes.h"
#import "PointerFreeze.h"
#import "DragInertiaEngine.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation ModifiedDragOutputRotateZoom

#pragma mark - Vars

static ModifiedDragState *_drag;
static BOOL _rotateStarted;
static BOOL _zoomStarted;
static double _rotationAccumulator; /// Accumulated rotation for snap mode
static double _gestureRotationAccumulator; /// Tracks rotation within current gesture to restart at 80°
static DragInertiaEngine *_rzInertia; /// Fling + precision engine

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    _rotateStarted = NO;
    _zoomStarted = NO;
    _rotationAccumulator = 0.0;
    if (!_rzInertia) _rzInertia = [[DragInertiaEngine alloc] init];
    [_rzInertia cancel];
}

+ (void)handleBecameInUse {
    _rotateStarted = NO;
    _zoomStarted = NO;
    _rotationAccumulator = 0.0;
    _gestureRotationAccumulator = 0.0;
    
    /// Freeze pointer — PointerFreeze warps cursor back to origin on each event,
    /// so it never reaches screen edges and deltas never stop.
    [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /// Apply precision scaling only — no non-linear acceleration.
    /// Rotate/zoom sends continuous gesture deltas directly to apps which render
    /// frame-by-frame; non-linear multipliers cause visible jerkiness.
    double scaledDx, scaledDy;
    [_rzInertia trackDeltaX:deltaX deltaY:deltaY outDeltaX:&scaledDx outDeltaY:&scaledDy];
    
    [self applyDeltaX:scaledDx deltaY:scaledDy event:event];
}

+ (void)applyDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef _Nullable)event {
    
    /// Check if Shift is held (for 90° snap mode)
    CGEventFlags flags = event ? CGEventGetFlags(event) : 0;
    BOOL shiftHeld = (flags & kCGEventFlagMaskShift) != 0;
    
    /// Axis selection with hysteresis — once an axis is active, require 2x the other
    /// axis magnitude to switch. Prevents jitter on diagonal movements.
    static BOOL _lastWasRotate = NO;
    
    BOOL horizontalDominant;
    if (_rotateStarted && !_zoomStarted) {
        /// Currently rotating — need 2x vertical to switch to zoom
        horizontalDominant = fabs(deltaX) > fabs(deltaY) * 0.5;
    } else if (_zoomStarted && !_rotateStarted) {
        /// Currently zooming — need 2x horizontal to switch to rotate
        horizontalDominant = fabs(deltaX) * 0.5 > fabs(deltaY);
    } else {
        horizontalDominant = fabs(deltaX) > fabs(deltaY);
    }
    
    if (horizontalDominant && fabs(deltaX) > 0.5) {
        /// --- Rotate: horizontal movement (left/right) ---
        
        double rotation = deltaX / 8.0; /// Increased sensitivity from /20
        
        if (shiftHeld) {
            _rotationAccumulator += rotation;
            double snapStep = 90.0;
            
            if (fabs(_rotationAccumulator) >= snapStep) {
                double snappedRotation = ((_rotationAccumulator > 0) ? snapStep : -snapStep);
                _rotationAccumulator = fmod(_rotationAccumulator, snapStep);
                
                [TouchSimulator postRotationEventWithRotation:snappedRotation phase:kIOHIDEventPhaseBegan];
                [TouchSimulator postRotationEventWithRotation:0 phase:kIOHIDEventPhaseEnded];
                DDLogDebug(@"RotateZoom: SNAP rotation=%.1f", snappedRotation);
            }
        } else {
            _rotationAccumulator = 0.0;
            
            /// Continuous gesture — let the app handle its own limits
            IOHIDEventPhaseBits phase = _rotateStarted ? kIOHIDEventPhaseChanged : kIOHIDEventPhaseBegan;
            _rotateStarted = YES;
            [TouchSimulator postRotationEventWithRotation:rotation phase:phase];
            DDLogDebug(@"RotateZoom: rotation=%.2f phase=%d", rotation, phase);
        }
        
    } else if (!horizontalDominant && fabs(deltaY) > 0.5) {
        /// --- Zoom: vertical movement (up = zoom in, down = zoom out) ---
        IOHIDEventPhaseBits zoomPhase = _zoomStarted ? kIOHIDEventPhaseChanged : kIOHIDEventPhaseBegan;
        _zoomStarted = YES;
        double magnification = -deltaY / 400.0;
        [TouchSimulator postMagnificationEventWithMagnification:magnification phase:zoomPhase];
        DDLogDebug(@"RotateZoom: zoom=%.4f phase=%d", magnification, zoomPhase);
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    
    IOHIDEventPhaseBits endPhase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
    
    if (_zoomStarted) {
        [TouchSimulator postMagnificationEventWithMagnification:0 phase:endPhase];
    }
    if (_rotateStarted) {
        [TouchSimulator postRotationEventWithRotation:0 phase:endPhase];
    }
    
    _rotateStarted = NO;
    _zoomStarted = NO;
    _rotationAccumulator = 0.0;
    
    /// Unfreeze pointer
    [PointerFreeze unfreeze];
    _gestureRotationAccumulator = 0.0;
    
    if (cancel) {
        [_rzInertia cancel];
    } else {
        /// Fling — full velocity for rotate/zoom (natural scroll-like feel)
        __weak id weakSelf = self;
        [_rzInertia startFlingWithVelocityScale:1.0 callback:^(double dx, double dy) {
            [weakSelf applyDeltaX:dx deltaY:dy event:nil];
        }];
    }
}

+ (void)suspend {
}

+ (void)unsuspend {
}

@end
