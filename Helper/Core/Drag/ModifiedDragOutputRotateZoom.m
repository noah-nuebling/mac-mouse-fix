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

@implementation ModifiedDragOutputRotateZoom

#pragma mark - Vars

static ModifiedDragState *_drag;
static BOOL _isFirstCallback;

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    _isFirstCallback = YES;
}

+ (void)handleBecameInUse {
    _isFirstCallback = YES;
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    IOHIDEventPhaseBits phase = _isFirstCallback ? kIOHIDEventPhaseBegan : kIOHIDEventPhaseChanged;
    _isFirstCallback = NO;
    
    BOOL isRotate = [_drag->type isEqualToString:kMFModifiedDragTypeRotate];
    
    if (isRotate) {
        /// Horizontal mouse movement → rotation
        /// Scale: ~400px = full 360° rotation (but in practice small movements are used)
        double rotation = deltaX / 8.0;
        [TouchSimulator postRotationEventWithRotation:rotation phase:phase];
    } else {
        /// Vertical mouse movement → zoom (pinch)
        /// Moving up (negative deltaY) = zoom in, moving down = zoom out
        double magnification = -deltaY / 400.0;
        [TouchSimulator postMagnificationEventWithMagnification:magnification phase:phase];
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    
    IOHIDEventPhaseBits endPhase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
    
    BOOL isRotate = [_drag->type isEqualToString:kMFModifiedDragTypeRotate];
    
    if (isRotate) {
        [TouchSimulator postRotationEventWithRotation:0 phase:endPhase];
    } else {
        [TouchSimulator postMagnificationEventWithMagnification:0 phase:endPhase];
    }
    
    _isFirstCallback = YES;
}

+ (void)suspend {
}

+ (void)unsuspend {
}

@end
