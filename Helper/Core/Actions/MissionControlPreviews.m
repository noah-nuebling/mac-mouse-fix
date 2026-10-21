// Licensed under the MMF License. See License.
#import "MissionControlPreviews.h"

@implementation MissionControlPreviews {
    CGPoint (^_position)(void);
    CGRect (^_bounds)(CGPoint);
    CGError (^_warp)(CGPoint);
    void (^_schedule)(NSTimeInterval, void (^)(void));
    CGPoint _origin, _target;
    NSUInteger _generation;
    BOOL _pending;
}

- (instancetype)init {
    return [self initWithPosition:^{
        CGEventRef event = CGEventCreate(NULL);
        CGPoint result = event ? CGEventGetLocation(event) : CGPointMake(NAN, NAN);
        if (event) CFRelease(event);
        return result;
    } bounds:^CGRect(CGPoint point) {
        if (!isfinite(point.x) || !isfinite(point.y)) return CGRectNull;
        CGDirectDisplayID display;
        uint32_t count = 0;
        if (CGGetDisplaysWithPoint(point, 1, &display, &count) != kCGErrorSuccess || count == 0)
            return CGRectNull;
        return CGDisplayBounds(display);
    } warp:^CGError(CGPoint point) {
        return CGWarpMouseCursorPosition(point);
    } schedule:^(NSTimeInterval delay, void (^block)(void)) {
        NSTimer *timer = [NSTimer timerWithTimeInterval:delay repeats:NO block:^(NSTimer *timer) { block(); }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    }];
}

- (instancetype)initWithPosition:(CGPoint (^)(void))position bounds:(CGRect (^)(CGPoint))bounds
                           warp:(CGError (^)(CGPoint))warp schedule:(void (^)(NSTimeInterval, void (^)(void)))schedule {
    if ((self = [super init])) {
        _position = [position copy];
        _bounds = [bounds copy];
        _warp = [warp copy];
        _schedule = [schedule copy];
    }
    return self;
}

- (void)restorePointer {
    if (!_pending) return;
    _pending = NO;
    /// Never pull the pointer back after the user has moved it. Don't warp into a removed display.
    if (CGPointEqualToPoint(_position(), _target) && CGRectContainsPoint(_bounds(_origin), _origin))
        _warp(_origin);
}

- (void)toggleWithAction:(void (^)(void))action {
    NSAssert(NSThread.isMainThread, @"Mission Control pointer state belongs to the main thread");
    /// A second invocation invalidates the previous completion; it still toggles Mission Control normally.
    [self restorePointer];
    NSUInteger generation = ++_generation;
    _origin = _position();
    CGRect bounds = _bounds(_origin);
    if (CGRectIsNull(bounds) || CGRectIsEmpty(bounds) || !CGRectContainsPoint(bounds, _origin)) {
        action();
        return;
    }
    /// Pre-position before opening: warping alone does not generate a hover event.
    /// Use the display under the pointer, including displays above/left of the main display.
    _target = CGPointMake(CGRectGetMidX(bounds), CGRectGetMinY(bounds) + 1);
    if (_warp(_target) != kCGErrorSuccess) {
        action();
        return;
    }
    _pending = YES;
    action();
    /// Best effort animation allowance, not a public Dock readiness contract. See docs.
    _schedule(0.5, ^{
        if (generation == self->_generation) [self restorePointer];
    });
}
@end
