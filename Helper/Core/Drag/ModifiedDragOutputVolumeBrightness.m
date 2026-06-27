//
// --------------------------------------------------------------------------
// ModifiedDragOutputVolumeBrightness.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created for volume and brightness drag control
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputVolumeBrightness.h"
#import "ScrollOutputUtility.h"
#import "PointerFreeze.h"
#import "Constants.h"
#import "WannabePrefixHeader.h"
#import "DragInertiaEngine.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation ModifiedDragOutputVolumeBrightness

#pragma mark - Vars

static ModifiedDragState *_drag;
static CGDirectDisplayID _targetDisplayID; /// Captured at drag start for brightness
static DragInertiaEngine *_inertia;        /// Fling + precision engine

/// Combined mode axis-lock state
static BOOL _combinedAxisLocked;       /// Whether we've committed to an axis
static BOOL _combinedIsVertical;       /// Which axis is active (once locked)
static double _combinedAccumX;         /// Accumulated horizontal movement during decision phase
static double _combinedAccumY;         /// Accumulated vertical movement during decision phase
static CFAbsoluteTime _combinedLastActiveTime; /// Last time the active axis received significant input
static const double kAxisDecisionThreshold = 6.0;  /// Pixels of travel before committing to an axis
static const double kAxisSwitchPause = 0.20;       /// Seconds of inactivity before allowing axis switch
static const double kAxisSwitchRatio = 3.0;        /// Other axis must be Nx dominant to switch

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    if (!_inertia) _inertia = [[DragInertiaEngine alloc] init];
    [_inertia cancel];
}

+ (void)handleBecameInUse {
    /// Determine target display from the drag origin point
    CGPoint origin = _drag->usageOrigin;
    uint32_t count = 0;
    CGDirectDisplayID displayID = kCGNullDirectDisplay;
    CGGetDisplaysWithPoint(origin, 1, &displayID, &count);
    _targetDisplayID = (count > 0) ? displayID : CGMainDisplayID();
    
    DDLogInfo(@"VolBright: drag started on display %u at (%.0f, %.0f)", _targetDisplayID, origin.x, origin.y);
    
    [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
    _combinedAxisLocked = NO;
    _combinedIsVertical = NO;
    _combinedAccumX = 0.0;
    _combinedAccumY = 0.0;
    _combinedLastActiveTime = CFAbsoluteTimeGetCurrent();
    
    /// Start flywheel — continuous timer that applies velocity to value
    __weak id weakSelf = self;
    [_inertia startFlywheelWithCallback:^(double dx, double dy) {
        [weakSelf applyDeltaX:dx deltaY:dy];
    }];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    /// Feed input into the flywheel — mouse movement = pedaling force
    [_inertia pedalDeltaX:deltaX deltaY:deltaY];
}

+ (void)applyDeltaX:(double)deltaX deltaY:(double)deltaY {
    
    /// Scale: ~250px of mouse movement = full range (0.0 to 1.0)
    /// Vertical: up (negative deltaY) = increase, down = decrease
    /// Horizontal: right (positive deltaX) = increase, left = decrease
    
    BOOL isCombined = [_drag->type isEqualToString:kMFModifiedDragTypeVolumeBrightness]
                   || [_drag->type isEqualToString:kMFModifiedDragTypeBrightnessVolume];
    
    if (isCombined) {
        /// Smart axis selection:
        /// 1. Decision phase: accumulate movement until threshold, then lock to dominant axis
        /// 2. Locked phase: stay on axis. Allow switch only after a pause + clear dominance.
        
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        
        if (!_combinedAxisLocked) {
            /// Decision phase — accumulate and wait for enough travel
            _combinedAccumX += fabs(deltaX);
            _combinedAccumY += fabs(deltaY);
            
            double totalTravel = _combinedAccumX + _combinedAccumY;
            if (totalTravel >= kAxisDecisionThreshold) {
                /// Commit to whichever axis accumulated more
                _combinedIsVertical = (_combinedAccumY > _combinedAccumX);
                _combinedAxisLocked = YES;
                _combinedLastActiveTime = now;
            } else {
                /// Not enough travel yet — don't apply anything
                return;
            }
        } else {
            /// Locked phase — check if we should switch axes
            double timeSinceActive = now - _combinedLastActiveTime;
            
            /// Update last-active time if current axis is getting input
            BOOL currentAxisActive = _combinedIsVertical ? (fabs(deltaY) > 0.5) : (fabs(deltaX) > 0.5);
            if (currentAxisActive) {
                _combinedLastActiveTime = now;
            }
            
            /// Allow switch only after a pause and clear dominance from the other axis
            if (timeSinceActive >= kAxisSwitchPause) {
                BOOL otherAxisDominant;
                if (_combinedIsVertical) {
                    otherAxisDominant = (fabs(deltaX) > fabs(deltaY) * kAxisSwitchRatio) && (fabs(deltaX) > 1.0);
                } else {
                    otherAxisDominant = (fabs(deltaY) > fabs(deltaX) * kAxisSwitchRatio) && (fabs(deltaY) > 1.0);
                }
                if (otherAxisDominant) {
                    _combinedIsVertical = !_combinedIsVertical;
                    _combinedLastActiveTime = now;
                }
            }
        }
        
        /// Apply the active axis
        BOOL volumeOnHorizontal = [_drag->type isEqualToString:kMFModifiedDragTypeBrightnessVolume];
        
        if (_combinedIsVertical) {
            double vertDelta = -deltaY / 500.0;
            if (fabs(vertDelta) < 0.0001) return;
            if (volumeOnHorizontal) {
                [ScrollOutputUtility adjustBrightnessByDelta:(float)vertDelta forDisplayID:_targetDisplayID];
            } else {
                float newVolume = [ScrollOutputUtility getSystemVolume] + (float)vertDelta;
                [ScrollOutputUtility setSystemVolume:newVolume];
            }
        } else {
            double horizDelta = deltaX / 500.0;
            if (fabs(horizDelta) < 0.0001) return;
            if (volumeOnHorizontal) {
                float newVolume = [ScrollOutputUtility getSystemVolume] + (float)horizDelta;
                [ScrollOutputUtility setSystemVolume:newVolume];
            } else {
                [ScrollOutputUtility adjustBrightnessByDelta:(float)horizDelta forDisplayID:_targetDisplayID];
            }
        }
        return;
    }
    
    BOOL isHorizontal = [_drag->type isEqualToString:kMFModifiedDragTypeVolumeHorizontal]
                     || [_drag->type isEqualToString:kMFModifiedDragTypeBrightnessHorizontal];
    
    double delta = isHorizontal ? (deltaX / 500.0) : (-deltaY / 500.0);
    
    BOOL isVolume = [_drag->type isEqualToString:kMFModifiedDragTypeVolume]
                 || [_drag->type isEqualToString:kMFModifiedDragTypeVolumeHorizontal];
    
    if (isVolume) {
        float newVolume = [ScrollOutputUtility getSystemVolume] + (float)delta;
        [ScrollOutputUtility setSystemVolume:newVolume];
    } else {
        [ScrollOutputUtility adjustBrightnessByDelta:(float)delta forDisplayID:_targetDisplayID];
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    [PointerFreeze unfreeze];
    
    if (cancel) {
        /// Hard stop — cancel kills flywheel immediately
        [_inertia cancel];
    }
    /// Normal release: flywheel keeps coasting via its timer until velocity decays to zero.
    /// No fling needed — the flywheel IS the momentum.
}

+ (void)suspend {
}

+ (void)unsuspend {
}

@end
