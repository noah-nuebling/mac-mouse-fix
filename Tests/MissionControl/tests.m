// Regression tests for pointer ownership and overlapping invocations. No desktop interaction.
#import <Foundation/Foundation.h>
#import "MissionControlPreviews.h"

static CGPoint pointer;
static CGRect display;
static BOOL warpFails;
static int warps, actions;
static NSMutableArray *completions;
static MissionControlPreviews *make(void) {
    pointer = CGPointMake(600, 500);
    display = CGRectMake(0, 0, 1440, 900);
    warpFails = NO; warps = 0; actions = 0;
    completions = [NSMutableArray new];
    return [[MissionControlPreviews alloc] initWithPosition:^{ return pointer; }
        bounds:^CGRect(CGPoint point) { return display; }
        warp:^CGError(CGPoint point) {
            warps++;
            if (warpFails) return kCGErrorFailure;
            pointer = point;
            return kCGErrorSuccess;
        }
        schedule:^(NSTimeInterval delay, void (^completion)(void)) {
            assert(delay > 0 && delay <= 1);
            [completions addObject:[completion copy]];
        }];
}
static void fire(NSUInteger index) { ((void (^)(void))completions[index])(); }
static void toggle(MissionControlPreviews *p) { [p toggleWithAction:^{ actions++; }]; }
int main(void) {
    @autoreleasepool {
        MissionControlPreviews *p = make();
        toggle(p);
        assert(actions == 1 && CGPointEqualToPoint(pointer, CGPointMake(720, 1)));
        fire(0);
        assert(warps == 2 && CGPointEqualToPoint(pointer, CGPointMake(600, 500)));
        fire(0); assert(warps == 2); // Completion is idempotent.

        p = make(); toggle(p);
        pointer = CGPointMake(800, 100); // User movement wins over restoring.
        fire(0); assert(warps == 1 && pointer.x == 800);

        p = make(); toggle(p); toggle(p);
        assert(actions == 2 && warps == 3);
        fire(0); assert(warps == 3); // Stale completion cannot restore the new invocation.
        fire(1); assert(warps == 4 && pointer.y == 500);

        p = make(); toggle(p); pointer = CGPointMake(850, 300); toggle(p);
        fire(0); fire(1);
        assert(pointer.x == 850 && pointer.y == 300); // New user position becomes the new origin.

        p = make(); display = CGRectMake(-1920, -1080, 1920, 1080); pointer = CGPointMake(-500, -400);
        toggle(p); assert(pointer.x == -960 && pointer.y == -1079);
        fire(0); assert(pointer.x == -500 && pointer.y == -400);

        p = make(); toggle(p); display = CGRectNull; fire(0);
        assert(warps == 1); // Unplugged display: never restore offscreen.

        p = make(); display = CGRectNull; toggle(p);
        assert(actions == 1 && warps == 0 && completions.count == 0);

        p = make(); warpFails = YES; toggle(p);
        assert(actions == 1 && completions.count == 0 && pointer.y == 500);

        p = make(); toggle(p);
        // Escape/Cancel requires no callback into this object: timer only restores, never opens MC again.
        fire(0); assert(actions == 1 && pointer.y == 500);
        puts("PASS: 9 Mission Control pointer lifecycle scenarios");
    }
}
