/**
    This script was written entirely by Opus 5.5 [Oct 2026]
    It's useful to see patterns in the timing of real Trackpad events and MMF simulated events.

    Observations:
        To see the 'true' phase of the trackpad events make sure system is not strained, otherwise delay in the phases. [Oct 2026]
*/

/// vvv Opus 5.5 stuff starts below here vvv

//
// vblphase.m
//
// Logs scroll (t22) and DockSwipe (t30) CGEvents with their phase offset relative to the display's VSync grid.
// Works for events from a real trackpad and from Mac Mouse Fix.
//
// Build:
//   clang -fobjc-arc -framework Foundation -framework CoreGraphics -framework IOKit \
//         -F/System/Library/PrivateFrameworks -framework SkyLight vblphase.m -o vblphase
// Run:
//   ./vblphase          (needs Accessibility / Input Monitoring permission for the terminal)
//
// Columns:
//   phase   (ts - lastVBL) / vblDelta, where `ts` is the CGEvent's timestamp. (Like the phaseShift debug-log in DisplayLink.m, but anchored at the event timestamp instead of `now`)
//   dt      CGEvent-timestamp delta to the previous logged event of the same source & kind
//   frame+N how many VSync frames lie between this event and the previous one
//   lat     receipt time - CGEvent timestamp
//   vbl     current VSync period of the display that was under the event's location at the start of the gesture
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ApplicationServices/ApplicationServices.h>
#import <mach/mach_time.h>
#import <libproc.h>

#pragma mark - Private APIs

extern uint64_t SLSDisplayGetPriorVBLTime(CGDirectDisplayID displayID);
extern uint64_t SLSDisplayGetCurrentVBLDelta(CGDirectDisplayID displayID);

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef uint32_t IOHIDEventField;
extern IOHIDEventRef CGEventCopyIOHIDEvent(CGEventRef event);
extern uint32_t      IOHIDEventGetType(IOHIDEventRef event);
extern uint32_t      IOHIDEventGetPhase(IOHIDEventRef event);
extern double        IOHIDEventGetFloatValue(IOHIDEventRef event, IOHIDEventField field);
extern long          IOHIDEventGetIntegerValue(IOHIDEventRef event, IOHIDEventField field);

#define kIOHIDEventTypeDockSwipe            23
#define kIOHIDEventFieldDockSwipeMotion     ((kIOHIDEventTypeDockSwipe << 16) | 1)
#define kIOHIDEventFieldDockSwipeProgress   ((kIOHIDEventTypeDockSwipe << 16) | 2)

#define kMFCGEventFieldSenderID 87  /// See Constants.h

#pragma mark - Time helpers

static mach_timebase_info_data_t _tb;
static double machToMs(int64_t t) { return (double)t * _tb.numer / _tb.denom / 1e6; }

static int64_t floorDivision(int64_t n, int64_t d) { return (n / d) - (n < 0 && n % d); }

static uint64_t lastVBLBefore(CGDirectDisplayID display, uint64_t anchor, uint64_t *outDelta) {
    /// Same as `CGDisplay_NearestVBLTime(display, "before", anchor, 0.0)` in DisplayLink.m
    uint64_t lastVBLTime  = SLSDisplayGetPriorVBLTime(display);
    uint64_t lastVBLDelta = SLSDisplayGetCurrentVBLDelta(display);
    *outDelta = lastVBLDelta;
    if (!lastVBLTime || !lastVBLDelta) return 0;
    int64_t x = (int64_t)anchor - 1;
    int64_t unit = floorDivision(x - (int64_t)lastVBLTime, (int64_t)lastVBLDelta);
    return (uint64_t)(unit * (int64_t)lastVBLDelta + (int64_t)lastVBLTime);
}

#pragma mark - Names

static const char *hidPhaseName(int64_t p) {
    switch (p) {
        case 0:   return "None";
        case 1:   return "Began";
        case 2:   return "Changed";
        case 4:   return "Ended";
        case 8:   return "Cancelled";
        case 128: return "MayBegin";
        default:  return "???";
    }
}
static const char *momentumPhaseName(int64_t p) {
    switch (p) {
        case 1:  return "Begin";
        case 2:  return "Continue";
        case 3:  return "End";
        default: return "???";
    }
}
static const char *dockSwipeMotionName(long m) {
    switch (m) {
        case 1:  return "dockSwipe horiz";
        case 2:  return "dockSwipe vert";
        case 3:  return "dockSwipe pinch";
        default: return "dockSwipe ?";
    }
}

static NSString *sourceLabel(CGEventRef e, pid_t pid) {
    if (CGEventGetIntegerValueField(e, (CGEventField)kMFCGEventFieldSenderID) != 0) return @"TP"; /// Has an IORegistry sender -> Came from a real device
    if (!pid) return @"???";
    char name[PROC_PIDPATHINFO_MAXSIZE] = {0};
    proc_name(pid, name, sizeof(name));
    NSString *n = @(name);
    if ([n.lowercaseString containsString: @"mouse fix"]) return @"MMF";
    return n.length ? n : [NSString stringWithFormat: @"pid%d", pid];
}

#pragma mark - Tap

static CFMachPortRef _tap;
static NSMutableDictionary<NSString *, NSArray<NSNumber *> *> *_prev; /// key: source+kind, value: @[ts, lastVBL, display]

static CGEventRef tapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *info) {

    uint64_t now = mach_absolute_time();

    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        CGEventTapEnable(_tap, true);
        return event;
    }

    /// Parse event
    char kind[64];
    const char *phaseStr;
    double dx = 0, dy = 0;
    bool isDockSwipe = false;
    bool isGestureStart = false; /// Display is only determined at gesture start

    if (type == kCGEventScrollWheel) {
        int64_t phase    = CGEventGetIntegerValueField(event, kCGScrollWheelEventScrollPhase);
        int64_t momentum = CGEventGetIntegerValueField(event, kCGScrollWheelEventMomentumPhase);
        if      (momentum) { snprintf(kind, sizeof(kind), "t22 momentum"); phaseStr = momentumPhaseName(momentum); }
        else if (phase)    { snprintf(kind, sizeof(kind), "t22 scroll");   phaseStr = hidPhaseName(phase); }
        else               { snprintf(kind, sizeof(kind), "t22 wheel");    phaseStr = ""; }
        isGestureStart = (phase == 128 /*MayBegin*/ || phase == 1 /*Began*/ || (!phase && !momentum));
        dx = (double)CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
        dy = (double)CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    }
    else if (type == 30) {
        /// macOS 27: DockSwipe data lives in the attached IOHIDEvent (See TouchSimulator.m). Older macOS: In the CGEventFields.
        IOHIDEventRef hid = CGEventCopyIOHIDEvent(event);
        if (hid && IOHIDEventGetType(hid) == kIOHIDEventTypeDockSwipe) {
            snprintf(kind, sizeof(kind), "t30 %s", dockSwipeMotionName(IOHIDEventGetIntegerValue(hid, kIOHIDEventFieldDockSwipeMotion)));
            phaseStr = hidPhaseName(IOHIDEventGetPhase(hid));
            isGestureStart = (IOHIDEventGetPhase(hid) == 1 /*Began*/);
            dx = IOHIDEventGetFloatValue(hid, kIOHIDEventFieldDockSwipeProgress);
            isDockSwipe = true;
        } else if (CGEventGetIntegerValueField(event, 110) == kIOHIDEventTypeDockSwipe) {
            snprintf(kind, sizeof(kind), "t30 %s", dockSwipeMotionName((long)CGEventGetDoubleValueField(event, 123)));
            phaseStr = hidPhaseName((int64_t)CGEventGetDoubleValueField(event, 132));
            isGestureStart = ((int64_t)CGEventGetDoubleValueField(event, 132) == 1 /*Began*/);
            dx = CGEventGetDoubleValueField(event, 124);
            isDockSwipe = true;
        }
        if (hid) CFRelease(hid);
        if (!isDockSwipe) return event; /// Some other t30 event (e.g. magnify)
    }
    else return event;

    /// Source
    pid_t pid = (pid_t)CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
    NSString *src = sourceLabel(event, pid);

    /// Timestamp
    ///     CGEvent timestamps are usually mach time, but MMF sets them via `CACurrentMediaTime() * NSEC_PER_SEC` (nanoseconds). (See GestureScrollSimulator.m and CGEventGetTimestampInSeconds())
    ///     -> If the timestamp lies in the future when read as mach time, treat it as nanoseconds and convert to mach time.
    uint64_t ts = CGEventGetTimestamp(event);
    if      (ts == 0)  ts = now; /// Shouldn't happen
    else if (ts > now) ts = (uint64_t)((double)ts * _tb.denom / _tb.numer);

    /// Previous event of the same source & kind
    NSString *key = [NSString stringWithFormat: @"%@ %s", src, isDockSwipe ? "dock" : "t22"];
    NSArray<NSNumber *> *prev = _prev[key];

    /// Display
    ///     Determined once at the start of the gesture (Momentum scrolls inherit the display of the preceding scroll gesture since they share the `key`)
    CGDirectDisplayID display;
    if (isGestureStart || !prev) {
        uint32_t n = 0;
        CGGetDisplaysWithPoint(CGEventGetLocation(event), 1, &display, &n);
        if (!n) display = CGMainDisplayID();
    } else {
        display = prev[2].unsignedIntValue;
    }

    /// VSync phase
    uint64_t vblDelta = 0;
    uint64_t lastVBL = lastVBLBefore(display, ts, &vblDelta);
    double phase = (lastVBL && vblDelta) ? (double)(ts - lastVBL) / vblDelta : NAN;

    char bar[21];
    memset(bar, '.', 20); bar[20] = 0;
    if (!isnan(phase)) bar[MIN(19, MAX(0, (int)floor(phase * 20)))] = '#';

    /// dt / frame+N (relative to previous event of the same source & kind)
    char dtStr[32] = "      -  ", frameStr[16] = "     ";
    if (prev) {
        snprintf(dtStr, sizeof(dtStr), "%7.2fms", machToMs((int64_t)ts - prev[0].longLongValue));
        if (vblDelta && lastVBL && prev[1].unsignedLongLongValue)
            snprintf(frameStr, sizeof(frameStr), "+%-3lld", llround((double)((int64_t)lastVBL - prev[1].longLongValue) / vblDelta));
    }
    _prev[key] = @[@(ts), @(lastVBL), @(display)];

    /// Latency
    double latMs = machToMs((int64_t)now - (int64_t)ts);

    /// Print
    char srcStr[16]; snprintf(srcStr, sizeof(srcStr), "[%s]", src.UTF8String);
    char dStr[64];
    if (isDockSwipe) snprintf(dStr, sizeof(dStr), "progress %.3f", dx);
    else             snprintf(dStr, sizeof(dStr), "d(%.1f, %.1f)", dx, dy);

    printf("%-5s %-19s %-9s phase %5.3f |%s| dt %s frame%s lat %5.2fms  vbl %.2fms  pid %-6d %s\n",
           srcStr, kind, phaseStr, phase, bar, dtStr, frameStr, latMs, machToMs((int64_t)vblDelta), pid, dStr);
    fflush(stdout);

    return event;
}

int vblphase_Start() {
    @autoreleasepool {
        mach_timebase_info(&_tb);
        _prev = [NSMutableDictionary dictionary];

        CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel) | CGEventMaskBit(30);

        /// Session tap sees both hardware events and events MMF posts to kCGSessionEventTap
        _tap = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionListenOnly, mask, tapCallback, NULL);
        if (!_tap) {
            fprintf(stderr, "Failed to create event tap. Grant Accessibility / Input Monitoring permission to your terminal.\n");
            return 1;
        }
        CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _tap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, kCFRunLoopCommonModes);
        CGEventTapEnable(_tap, true);

        printf("Listening for t22 scroll and t30 dockSwipe events... (ctrl-c to quit)\n");
        CFRunLoopRun();
    }

    return 0;
}
