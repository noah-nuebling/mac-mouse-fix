#!/usr/bin/env python3
"""Compile TouchSimulator.m with recording substitutes; never post system input.

Run on macOS 27+ with Xcode command-line tools:
    python3 Tests/DockSwipeExitVelocityRegression.py
An optional source path allows checking the same regression against an older file.
Licensed under the MMF License (see License).
"""

from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "Helper/Core/Touch/TouchSimulator.m"
# Keep the production implementation intact, replacing only its imports and
# environment (logging, event posting, timers and the private HID overlay).
implementation = "\n".join(line for line in source.read_text().splitlines()
                           if not line.lstrip().startswith("#import"))

environment = r'''
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "TouchSimulator.h"

static NSMutableDictionary *payloads;
static NSMutableArray *posts, *timers;
static unsigned sequences, terminalPayloads, failures;

@interface RecordingHIDEvent : NSObject
@property uint32_t type, options;
@property NSMutableDictionary *fields;
@property NSMutableArray *children;
- (instancetype)initWithType:(uint32_t)type timestamp:(uint64_t)timestamp senderID:(uint64_t)sender;
- (void)setIntegerValue:(NSInteger)value forField:(uint32_t)field;
- (void)setDoubleValue:(double)value forField:(uint32_t)field;
- (void)appendEvent:(RecordingHIDEvent *)event;
@end
@implementation RecordingHIDEvent
- (instancetype)initWithType:(uint32_t)type timestamp:(uint64_t)timestamp senderID:(uint64_t)sender {
    if ((self = [super init])) { _type = type; _fields = [NSMutableDictionary new]; _children = [NSMutableArray new]; }
    return self;
}
- (void)setIntegerValue:(NSInteger)value forField:(uint32_t)field { _fields[@(field)] = @(value); }
- (void)setDoubleValue:(double)value forField:(uint32_t)field { _fields[@(field)] = @(value); }
- (void)appendEvent:(RecordingHIDEvent *)event { [_children addObject:event]; }
@end

@interface RecordingTimer : NSObject
@property id userInfo, target;
@property SEL selector;
@property BOOL valid;
@property NSTimeInterval interval;
+ (instancetype)scheduledTimerWithTimeInterval:(NSTimeInterval)interval target:(id)target
    selector:(SEL)selector userInfo:(id)info repeats:(BOOL)repeats;
- (void)invalidate;
- (void)fire;
@end
@implementation RecordingTimer
+ (instancetype)scheduledTimerWithTimeInterval:(NSTimeInterval)interval target:(id)target
    selector:(SEL)selector userInfo:(id)info repeats:(BOOL)repeats {
    RecordingTimer *timer = [self new];
    timer.interval = interval; timer.target = target; timer.selector = selector;
    timer.userInfo = info; timer.valid = YES; [timers addObject:timer]; return timer;
}
- (void)invalidate { _valid = NO; }
- (void)fire {
    if (_valid) ((void (*)(id, SEL, id))[_target methodForSelector:_selector])(_target, _selector, self);
}
@end

static void recordHID(CGEventRef event, RecordingHIDEvent *hid) { payloads[@((uintptr_t)event)] = hid; }
static void recordPost(CGEventTapLocation location, CGEventRef event) {
    RecordingHIDEvent *hid = payloads[@((uintptr_t)event)];
    RecordingHIDEvent *velocity = hid.children.firstObject;
    [posts addObject:@{ @"type":@(hid.type), @"motion":hid.fields[@(kIOHIDEventFieldDockSwipeMotion)],
        @"phase":@(hid.options >> kIOHIDEventEventOptionPhaseShift),
        @"progress":hid.fields[@(kIOHIDEventFieldDockSwipeProgress)], @"children":@(hid.children.count),
        @"vx":velocity.fields[@(kIOHIDEventFieldVelocityX)] ?: @0,
        @"vy":velocity.fields[@(kIOHIDEventFieldVelocityY)] ?: @0,
        @"vz":velocity.fields[@(kIOHIDEventFieldVelocityZ)] ?: @0 }];
}
static bool runningPreRelease(void) { return false; }
#define HIDEvent RecordingHIDEvent
#define NSTimer RecordingTimer
#define CGEventSetHIDEvent recordHID
#define CGEventPost recordPost
#define assertRunLoop(...) ((void)0)
#define DDLogDebug(...) ((void)0)
#define mfsign(value) (((value) > 0) - ((value) < 0))
'''

checks = r'''
static void check(BOOL condition, const char *message) {
    if (!condition) { if (failures < 6) fprintf(stderr, "FAIL: %s\n", message); failures++; }
}
static BOOL near(double a, double b) { return fabs(a - b) < 1e-9; }
static void sequence(MFDockSwipeType type, BOOL inverted, int phase, double start, double movement, BOOL reverse) {
    NSArray *previousTimers = [timers copy];
    [posts removeAllObjects]; [payloads removeAllObjects]; [timers removeAllObjects];
    [TouchSimulator postDockSwipeEventWithDelta:start type:type phase:kIOHIDEventPhaseBegan invertedFromDevice:inverted];
    for (RecordingTimer *timer in previousTimers) check(!timer.valid, "new gesture cancels old resends");
    [TouchSimulator postDockSwipeEventWithDelta:movement type:type phase:kIOHIDEventPhaseChanged invertedFromDevice:inverted];
    double progress = start + movement, lastMovement = movement == 0 ? start : movement;
    if (reverse) {
        lastMovement = -movement / 2; progress += lastMovement;
        [TouchSimulator postDockSwipeEventWithDelta:lastMovement type:type phase:kIOHIDEventPhaseChanged invertedFromDevice:inverted];
    }
    for (NSDictionary *post in posts) check([post[@"children"] intValue] == 0, "no velocity child before termination");
    [TouchSimulator postDockSwipeEventWithDelta:0 type:type phase:phase invertedFromDevice:inverted];
    NSDictionary *terminal = posts.lastObject;
    double expectedProgress = inverted ? -progress : progress;
    double expectedVelocity = (inverted ? -1 : 1) * lastMovement * 100;
    check([terminal[@"type"] intValue] == kIOHIDEventTypeDockSwipe, "DockSwipe event type preserved");
    check([terminal[@"motion"] intValue] == type, "motion preserved");
    check([terminal[@"children"] intValue] == 1, "one terminal velocity child");
    check([terminal[@"phase"] intValue] == (reverse ? kIOHIDEventPhaseCancelled : phase), "termination phase preserved");
    check(near([terminal[@"progress"] doubleValue], expectedProgress), "progress direction preserved");
    check(near([terminal[@"vx"] doubleValue], expectedVelocity), "X velocity follows latest movement in HID coordinates");
    check(near([terminal[@"vy"] doubleValue], expectedVelocity), "Y velocity follows latest movement in HID coordinates");
    check([terminal[@"vz"] doubleValue] == 0, "Z velocity stays zero");
    check(timers.count == 2, "both terminal resend timers preserved");
    check(near([timers[0] interval], 0.2) && near([timers[1] interval], 0.5), "resend intervals preserved");
    for (RecordingTimer *timer in timers) {
        [timer fire]; check([posts.lastObject isEqual:terminal], "resend retains the corrected terminal payload");
    }
    sequences++; terminalPayloads += 3;
}
int main(void) {
    @autoreleasepool {
        if (@available(macOS 27.0, *)) {} else { fputs("SKIP: requires macOS 27 native HID path\n", stderr); return 77; }
        payloads = [NSMutableDictionary new]; posts = [NSMutableArray new]; timers = [NSMutableArray new];
        for (int type = 1; type <= 3; type++) for (int inverted = 0; inverted <= 1; inverted++) {
            for (int phase = 4; phase <= 8; phase += 4) {
                for (int direction = -1; direction <= 1; direction += 2) {
                    double amplitudes[] = {0.00002, 0.0433333};
                    for (unsigned i = 0; i < 2; i++) {
                        double amplitude = amplitudes[i];
                        sequence(type, inverted, phase, direction * amplitude, direction * amplitude, NO);
                    }
                }
                sequence(type, inverted, phase, 0, 0, NO);
            }
            for (int direction = -1; direction <= 1; direction += 2)
                sequence(type, inverted, kIOHIDEventPhaseEnded, direction * 0.25, direction * 0.25, YES);
        }
        printf("%s: %u gesture sequences, %u terminal payloads, %u failures; no system input posted\n",
            failures ? "FAIL" : "PASS", sequences, terminalPayloads, failures);
        return failures ? 1 : 0;
    }
}
'''

with tempfile.TemporaryDirectory(prefix="mmf-dock-swipe-regression-") as directory:
    directory = Path(directory)
    instrumented = directory / "TouchSimulatorRegression.m"
    instrumented.write_text(environment + implementation + checks)
    binary = directory / "regression"
    command = ["xcrun", "clang", "-fobjc-arc", "-fmodules", "-Wno-unused-variable",
               "-I" + str(root / "Helper/Core/Touch"), "-I" + str(root / "Shared/IOKit"),
               "-I" + str(root / "Shared/IOKit/External"), "-framework", "Cocoa",
               "-framework", "QuartzCore", str(instrumented), "-o", str(binary)]
    subprocess.run(command, check=True)
    sys.exit(subprocess.run([str(binary)]).returncode)
