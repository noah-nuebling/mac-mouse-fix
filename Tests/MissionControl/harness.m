// Isolated pointer-workaround harness: never starts MMF or its Helper.
#import <AppKit/AppKit.h>
#import "MissionControlPreviews.h"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        MissionControlPreviews *previews = [MissionControlPreviews new];
        if (argc >= 3) CGWarpMouseCursorPosition(CGPointMake(atof(argv[1]), atof(argv[2])));
        CGEventRef initial = CGEventCreate(NULL);
        CGPoint start = CGEventGetLocation(initial);
        CFRelease(initial);
        printf("start: %.0f %.0f, moved count: %u\n", start.x, start.y, CGEventSourceCounterForEventType(kCGEventSourceStateHIDSystemState, kCGEventMouseMoved));
        fflush(stdout);
        uint32_t displayCount = 0;
        CGGetActiveDisplayList(0, NULL, &displayCount);
        printf("active displays: %u\n", displayCount);
        CGDirectDisplayID displays[16];
        uint32_t count = 0;
        CGGetActiveDisplayList(16, displays, &count);
        for (uint32_t i = 0; i < count; i++) {
            CGRect b = CGDisplayBounds(displays[i]);
            printf("display %u: %.0f %.0f %.0f %.0f\n", displays[i], b.origin.x, b.origin.y, b.size.width, b.size.height);
        }
        if (argc == 2 && strcmp(argv[1], "--info") == 0) return 0;
        void (^action)(void) = ^{
            NSTask *task = [NSTask new];
            task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
            task.arguments = @[@"-a", @"Mission Control"];
            NSError *error;
            if (![task launchAndReturnError:&error]) NSLog(@"%@", error);
        };
        [previews toggleWithAction:action];
        if (argc >= 4) {
            double repeatDelay = atof(argv[3]);
            [NSTimer scheduledTimerWithTimeInterval:repeatDelay repeats:NO block:^(NSTimer *timer) {
                [previews toggleWithAction:action];
            }];
        }
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.5]];
        CGEventRef event = CGEventCreate(NULL);
        CGPoint point = CGEventGetLocation(event);
        printf("pointer after: %.0f %.0f, moved count: %u\n", point.x, point.y, CGEventSourceCounterForEventType(kCGEventSourceStateHIDSystemState, kCGEventMouseMoved));
        CFRelease(event);
    }
}
