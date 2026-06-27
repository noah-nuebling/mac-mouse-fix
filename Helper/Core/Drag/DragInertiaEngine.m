//
// DragInertiaEngine.m
// Created for Mac Mouse Fix
//
// Provides scroll-momentum-quality fling for drag modes (volume, brightness, rotate, zoom).
// Uses the same DragCurve + TouchAnimator physics as the scroll system.
//
// Precision scaling: slow mouse movements → reduced sensitivity for fine control.
//

#import "DragInertiaEngine.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"  // DragCurve, TouchAnimator, nsValueFromVector
#import "VectorUtility.h"
#import <QuartzCore/QuartzCore.h>

/// Max time between events for fling to trigger (~80ms, matching scroll system)
static const double kMouseMovingMaxInterval = 0.08;

// MARK: - Tuning

/// Precision scaling
static const double kPrecisionThreshold = 2.5;
static const double kPrecisionFactor    = 0.08;  /// floor for very slow movements (was 0.20)

/// Fling physics (same values as scroll momentum)
static const double kFlingDragCoefficient = 30.0;
static const double kFlingDragExponent    = 0.7;
static const double kFlingStopSpeed       = 1.5;
static const double kFlingMinExitSpeed    = 4.0;

/// Flywheel physics
static const double kFlywheelAcceleration = 0.025;  /// base mouse delta → velocity force
static const double kFlywheelDrag         = 0.96;   /// per-frame velocity decay
static const double kFlywheelMinSpeed     = 0.0003; /// stop threshold
static const double kFlywheelFrameRate    = 120.0;  /// Hz

@implementation DragInertiaEngine {
    double _vx;
    double _vy;
    CFTimeInterval _lastEventTime;
    TouchAnimator *_animator;
    
    /// Flywheel state
    double _fwVx;           /// flywheel velocity x
    double _fwVy;           /// flywheel velocity y
    dispatch_source_t _fwTimer;
    DragInertiaCallback _fwCallback;
}

// MARK: - Init

- (instancetype)init {
    self = [super init];
    if (self) {
        _vx = 0; _vy = 0;
        _lastEventTime = 0;
        _animator = [[TouchAnimator alloc] init];
        _fwVx = 0; _fwVy = 0;
        _fwTimer = nil;
        _fwCallback = nil;
    }
    return self;
}

// MARK: - Velocity tracking + precision scaling

- (void)trackDeltaX:(double)dx deltaY:(double)dy
          outDeltaX:(double *)outDx outDeltaY:(double *)outDy {
    
    /// Update velocity estimate (EMA of per-event deltas converted to px/s)
    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval dt = (_lastEventTime > 0) ? (now - _lastEventTime) : 0.008;
    if (dt < 0.001) dt = 0.001;
    _lastEventTime = now;
    
    /// Per-second velocity estimate
    double ivx = dx / dt;
    double ivy = dy / dt;
    
    double alpha = 0.3; // EMA weight for newest sample
    _vx = _vx * (1.0 - alpha) + ivx * alpha;
    _vy = _vy * (1.0 - alpha) + ivy * alpha;
    
    /// Precision scaling: ramp from kPrecisionFactor → 1.0 as speed crosses threshold
    double speed = sqrt(dx*dx + dy*dy);
    double scale = 1.0;
    if (speed > 0.01 && speed < kPrecisionThreshold) {
        double t = speed / kPrecisionThreshold; // 0..1
        scale = kPrecisionFactor + t * (1.0 - kPrecisionFactor);
    }
    
    *outDx = dx * scale;
    *outDy = dy * scale;
}

// MARK: - Flywheel

- (void)startFlywheelWithCallback:(DragInertiaCallback)callback {
    [self stopFlywheelTimer];
    _fwVx = 0; _fwVy = 0;
    _fwCallback = callback;
    
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    _fwTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    uint64_t interval = (uint64_t)(NSEC_PER_SEC / kFlywheelFrameRate);
    dispatch_source_set_timer(_fwTimer, dispatch_time(DISPATCH_TIME_NOW, interval), interval, interval / 10);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_fwTimer, ^{
        typeof(self) s = weakSelf;
        if (!s) return;
        
        /// Apply drag decay
        s->_fwVx *= kFlywheelDrag;
        s->_fwVy *= kFlywheelDrag;
        
        double speed = sqrt(s->_fwVx * s->_fwVx + s->_fwVy * s->_fwVy);
        if (speed < kFlywheelMinSpeed) {
            s->_fwVx = 0; s->_fwVy = 0;
            /// Keep timer running — flywheel is just coasting at zero, waiting for more input
            return;
        }
        
        double dx = s->_fwVx;
        double dy = s->_fwVy;
        DragInertiaCallback cb = s->_fwCallback;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (cb) cb(dx, dy);
        });
    });
    
    dispatch_resume(_fwTimer);
}

- (void)pedalDeltaX:(double)dx deltaY:(double)dy {
    /// Add force to flywheel velocity with non-linear (power curve) acceleration.
    ///
    /// The precision scaling in trackDeltaX already compresses slow movements.
    /// On top of that, the accel multiplier further stretches the response curve:
    ///   - Very slow (speed ≈ 0):  ~0.08x precision + ~1.0x accel = ultra-fine control
    ///   - Medium (speed ≈ 8):     ~1.0x precision + ~2.0x accel = normal feel
    ///   - Fast fling (speed ≥ 24): ~1.0x precision + ~4.0x accel = full-range sweep
    ///
    /// This lets the user go from mute→full or full→mute with a single hard fling.
    double scaledDx, scaledDy;
    [self trackDeltaX:dx deltaY:dy outDeltaX:&scaledDx outDeltaY:&scaledDy];
    
    double speed = sqrt(scaledDx*scaledDx + scaledDy*scaledDy);
    double accelMultiplier = 1.0 + fmin(speed / 8.0, 3.0); /// 1x–4x, saturates at speed=24
    double accel = kFlywheelAcceleration * accelMultiplier;
    
    _fwVx += scaledDx * accel;
    _fwVy += scaledDy * accel;
}

- (void)stopFlywheelTimer {
    if (_fwTimer) {
        dispatch_source_cancel(_fwTimer);
        _fwTimer = nil;
    }
}

// MARK: - Fling (scroll-momentum physics)

- (void)startFlingWithVelocityScale:(double)velocityScale
                           callback:(DragInertiaCallback)callback {
    
    [_animator cancel_forAutoMomentumScroll:YES];
    
    CFTimeInterval timeSinceLastInput = (_lastEventTime > 0)
        ? (CACurrentMediaTime() - _lastEventTime)
        : DBL_MAX;
    
    double exitSpeed = sqrt(_vx*_vx + _vy*_vy);
    
    /// Reset velocity for next drag
    double vx = _vx, vy = _vy;
    _vx = 0; _vy = 0;
    _lastEventTime = 0;
    
    /// Don't fling if stopped or moving too slowly
    if (exitSpeed < kFlingMinExitSpeed) return;
    if (timeSinceLastInput > kMouseMovingMaxInterval
        || timeSinceLastInput == DBL_MAX) return;
    
    /// Apply velocity scale and build exit velocity vector
    Vector exitVelocity = (Vector){ .x = vx * velocityScale, .y = vy * velocityScale };
    
    [_animator resetSubPixelator];
    [_animator linkToMainScreen];
    
    [_animator startWithParams:^NSDictionary<NSString *,id> * _Nonnull(Vector valueLeft, BOOL isRunning, Curve * _Nullable curve, Vector currentSpeed) {
        
        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        
        double initialSpeed = magnitudeOfVector(exitVelocity);
        if (initialSpeed <= kFlingStopSpeed) {
            p[@"doStart"] = @(NO);
            return p;
        }
        
        DragCurve *animationCurve = [[DragCurve alloc]
                                      initWithCoefficient:kFlingDragCoefficient
                                      exponent:kFlingDragExponent
                                      initialSpeed:initialSpeed
                                      stopSpeed:kFlingStopSpeed];
        
        double duration = animationCurve.timeInterval.length;
        double distance = animationCurve.distanceInterval.length;
        
        /// Build a distance vector in the direction of exit velocity
        Vector unit = unitVector(exitVelocity);
        Vector distanceVec = scaledVector(unit, distance);
        
        p[@"vector"]   = nsValueFromVector(distanceVec);
        p[@"duration"] = @(duration);
        p[@"curve"]    = animationCurve;
        
        return p;
        
    } integerCallback:^(Vector deltaVec, MFAnimationCallbackPhase animationPhase, MFMomentumHint hint) {
        
        if (animationPhase == kMFAnimationCallbackPhaseEnd) return;
        
        callback(deltaVec.x, deltaVec.y);
    }];
}

// MARK: - Cancel

- (void)cancel {
    [_animator cancel_forAutoMomentumScroll:YES];
    [self stopFlywheelTimer];
    _vx = 0; _vy = 0;
    _lastEventTime = 0;
    _fwVx = 0; _fwVy = 0;
}

@end
