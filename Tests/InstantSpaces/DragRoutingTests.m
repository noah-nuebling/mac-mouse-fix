#import "ModifiedDragOutputThreeFingerSwipe.h"
#import "InstantSpaceSwitcher/include/ISS.h"
#include <assert.h>

static int switches, gestureEvents, freezes, unfreezes;
static ISSDirection switchedDirection;
static MFDockSwipeType postedType;
static IOHIDEventPhaseBits postedPhase;
static double postedDelta;
static BOOL freezeEnabled = YES;
static bool switchSucceeds = true;
bool iss_switch(ISSDirection direction) {
    switches++;
    switchedDirection = direction;
    return switchSucceeds;
}
@implementation TestScreen
+ (TestScreen *)mainScreen { return [TestScreen new]; }
- (NSRect)frame { return NSMakeRect(0, 0, 1920, 1080); }
- (NSString *)mf_UUIDString { return @"test-display"; }
@end
@implementation GeneralConfig
+ (BOOL)freezePointerDuringModifiedDrag { return freezeEnabled; }
@end
@implementation PointerFreeze
+ (void)freezePointerAtPosition:(CGPoint)position { (void)position; freezes++; }
+ (void)unfreeze { unfreezes++; }
@end
@implementation TouchSimulator
+ (void)postDockSwipeEventWithDelta:(double)delta type:(MFDockSwipeType)type
                             phase:(IOHIDEventPhaseBits)phase invertedFromDevice:(BOOL)inverted {
    assert(isfinite(delta)); (void)inverted;
    gestureEvents++; postedType = type; postedPhase = phase; postedDelta = delta;
}
@end
int CGSMainConnectionID(void) { return 1; }
CFArrayRef CGSCopyManagedDisplaySpaces(int connection) {
    (void)connection;
    return CFBridgingRetain(@[@{@"Display Identifier": @"test-display", @"Spaces": @[@1, @2, @3]}]);
}
static void reset(void) { switches = gestureEvents = freezes = unfreezes = 0; }
static ModifiedDragState drag(NSString *type, MFAxis axis, BOOL natural, double x) {
    return (ModifiedDragState){ .type = type, .usageAxis = axis, .naturalDirection = natural,
        .originOffset = CGPointMake(x, -20), .usageOrigin = CGPointMake(100, 100), .firstCallback = YES };
}
static void begin(ModifiedDragState *state) {
    [ModifiedDragOutputThreeFingerSwipe initializeWithDragState:state];
    [ModifiedDragOutputThreeFingerSwipe handleBecameInUse];
}
static void moveWithY(double y) {
    [ModifiedDragOutputThreeFingerSwipe handleMouseInputWhileInUseWithDeltaX:10 deltaY:y];
}
static void move(void) { moveWithY(-10); }
static void end(BOOL cancel) {
    [ModifiedDragOutputThreeFingerSwipe handleDeactivationWhileInUseWithCancel:cancel];
}
int main(void) {
    @autoreleasepool {
        // Horizontal activation consumes the threshold-crossing movement once.
        for (int natural = 0; natural < 2; natural++) {
            for (int left = 0; left < 2; left++) {
                reset();
                ModifiedDragState state = drag(kMFModifiedDragTypeThreeFingerSwipeInstant,
                    kMFAxisHorizontal, natural, left ? -20 : 20);
                begin(&state);
                ISSDirection expected = natural == left ? ISSDirectionRight : ISSDirectionLeft;
                assert(switches == 1 && switchedDirection == expected);
                for (int i = 0; i < 20; i++) move();
                end(NO);
                assert(switches == 1 && gestureEvents == 0);
                assert(freezes == 1 && unfreezes == 1);
            }
        }
        // Release/cancellation must not reopen or terminate an instant gesture.
        reset(); switchSucceeds = false;
        ModifiedDragState state = drag(kMFModifiedDragTypeThreeFingerSwipeInstant, kMFAxisHorizontal, YES, 20);
        begin(&state); move(); end(YES);
        assert(switches == 1 && gestureEvents == 0 && unfreezes == 1);
        switchSucceeds = true;

        // The new option keeps BOTH vertical directions and phase lifecycle.
        for (int y = -10; y <= 10; y += 20) for (int cancel = 0; cancel < 2; cancel++) {
            reset();
            state = drag(kMFModifiedDragTypeThreeFingerSwipeInstant, kMFAxisVertical, YES, 0);
            begin(&state); moveWithY(y);
            assert(postedDelta * y > 0);
            assert(switches == 0 && gestureEvents == 1);
            assert(postedType == kMFDockSwipeTypeVertical && postedPhase == kIOHIDEventPhaseBegan);
            state.firstCallback = NO; moveWithY(y);
            assert(postedPhase == kIOHIDEventPhaseChanged);
            end(cancel);
            assert(gestureEvents == 3 && postedType == kMFDockSwipeTypeVertical);
            assert(postedPhase == (cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded));
            assert(freezes == 1 && unfreezes == 1);
        }
        // Existing mappings retain their continuous horizontal gesture.
        reset();
        state = drag(kMFModifiedDragTypeThreeFingerSwipe, kMFAxisHorizontal, YES, 20);
        begin(&state); move(); end(NO);
        assert(switches == 0 && gestureEvents == 2);
        assert(postedType == kMFDockSwipeTypeHorizontal && postedPhase == kIOHIDEventPhaseEnded);

        // A later instant drag re-arms after a legacy or vertical drag.
        reset(); freezeEnabled = NO;
        state = drag(kMFModifiedDragTypeThreeFingerSwipeInstant, kMFAxisHorizontal, YES, -20);
        begin(&state); move(); end(NO);
        assert(switches == 1 && gestureEvents == 0 && freezes == 0 && unfreezes == 0);
        puts("Drag routing tests passed");
    }
}
