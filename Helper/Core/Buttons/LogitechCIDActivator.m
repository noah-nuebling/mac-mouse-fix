//
// --------------------------------------------------------------------------
// LogitechCIDActivator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Miguel Angelo in 2026
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------

#import "LogitechCIDActivator.h"
#import <IOKit/hid/IOHIDLib.h>
#import <CoreGraphics/CoreGraphics.h>
#import "SharedUtility.h"

#define kLogitechVID    0x046D
#define kHIDPP_Long     0x11
#define kHIDPP_Short    0x10
#define kHIDPP_DevBLE   0xFF
#define kFeat_ReprogV4  0x1B04
#define kDivertFlags    0x03

static const uint16_t kNativeTIDs[] = { 0x0038, 0x0039, 0x003A, 0x003C, 0x003E };
static const int kNativeTIDCount = 5;

/// Known Unifying/Bolt receiver PIDs
static const uint16_t kReceiverPIDs[] = { 0xC52B, 0xC534, 0xC548, 0xC547 };
static const int kReceiverPIDCount = 4;

#define kFirstCGButton  5
#define kMaxCIDs        32
#define kMaxSlots       6

typedef struct {
    IOHIDDeviceRef  device;
    uint8_t         reportBuf[64];
    uint8_t         deviceIndex;    // 0xFF for BT, 1-6 for receiver slots
    BOOL            isReceiver;
    uint16_t        pressedCIDs[kMaxCIDs];
    int             pressedCount;
} MFCIDDeviceState;

static uint8_t sResp[20];
static BOOL    sGotResp = NO;
static uint8_t sProbingDevIdx = 0;

/// Global CID→button map shared across all devices/transports for consistent numbering
static uint16_t sGlobalCIDMap[kMaxCIDs];
static int      sGlobalCIDCount = 0;

static BOOL isNativeTID(uint16_t tid) {
    for (int i = 0; i < kNativeTIDCount; i++) if (kNativeTIDs[i] == tid) return YES;
    return NO;
}

static BOOL isReceiverPID(uint16_t pid) {
    for (int i = 0; i < kReceiverPIDCount; i++) if (kReceiverPIDs[i] == pid) return YES;
    return NO;
}

/// Returns a stable button number for a CID, consistent across BT and USB transports
static int buttonForCID(MFCIDDeviceState *s, uint16_t cid) {
    // Check global map first
    for (int i = 0; i < sGlobalCIDCount; i++)
        if (sGlobalCIDMap[i] == cid) return kFirstCGButton + i;
    // Register new CID globally
    if (sGlobalCIDCount < kMaxCIDs) {
        sGlobalCIDMap[sGlobalCIDCount++] = cid;
        return kFirstCGButton + sGlobalCIDCount - 1;
    }
    return kFirstCGButton;
}

static void injectButton(MFCIDDeviceState *s, uint16_t cid, BOOL down) {
    int btn = buttonForCID(s, cid);
    CGEventRef pos = CGEventCreate(NULL);
    CGPoint pt = CGEventGetLocation(pos); CFRelease(pos);
    CGEventRef ev = CGEventCreateMouseEvent(NULL, down ? kCGEventOtherMouseDown : kCGEventOtherMouseUp, pt, kCGMouseButtonCenter);
    if (!ev) return;
    CGEventSetIntegerValueField(ev, kCGMouseEventButtonNumber, btn);
    CGEventPost(kCGHIDEventTap, ev);
    CFRelease(ev);
}

static void inputReportCallback(void *ctx, IOReturn result, void *sender,
                                IOHIDReportType type, uint32_t reportID,
                                uint8_t *report, CFIndex len) {
    if (len < 5) return;
    if (report[0] != kHIDPP_Long && report[0] != kHIDPP_Short) return;

    uint8_t reportDevIdx = report[1];

    // Command response — route to sendAndWait
    if (report[3] != 0x00) {
        if (reportDevIdx == sProbingDevIdx) {
            memcpy(sResp, report, len < 20 ? (size_t)len : 20);
            sGotResp = YES;
        }
        return;
    }

    // CID button event — find matching state by device index
    MFCIDDeviceState *s = (MFCIDDeviceState *)ctx;
    if (s->deviceIndex != reportDevIdx) return;

    uint16_t cid = ((uint16_t)report[4] << 8) | report[5];
    if (cid == 0) {
        for (int i = 0; i < s->pressedCount; i++) injectButton(s, s->pressedCIDs[i], NO);
        s->pressedCount = 0;
    } else {
        for (int i = 0; i < s->pressedCount; i++) if (s->pressedCIDs[i] == cid) return;
        injectButton(s, cid, YES);
        if (s->pressedCount < kMaxCIDs) s->pressedCIDs[s->pressedCount++] = cid;
    }
}

static IOReturn sendAndWait(IOHIDDeviceRef dev, uint8_t *pkt) {
    sGotResp = NO;
    IOReturn r = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, pkt[0], pkt, 20);
    if (r != kIOReturnSuccess) return r;
    for (int i = 0; i < 30 && !sGotResp; i++)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.002, false);
    if (!sGotResp) return kIOReturnTimeout;
    if (sResp[2] == 0xFF) return kIOReturnError;
    return kIOReturnSuccess;
}

static int activateDevice(IOHIDDeviceRef dev, MFCIDDeviceState *s) {
    uint8_t devIdx = s->deviceIndex;
    uint8_t pkt[20];

    // 1. GetFeature(0x1B04)
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long; pkt[1] = devIdx; pkt[2] = 0x00; pkt[3] = 0x0E;
    pkt[4] = (kFeat_ReprogV4 >> 8) & 0xFF; pkt[5] = kFeat_ReprogV4 & 0xFF;
    sProbingDevIdx = devIdx;
    if (sendAndWait(dev, pkt) != kIOReturnSuccess || sResp[4] == 0) return 0;
    uint8_t feat = sResp[4];

    // 2. GetCount
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long; pkt[1] = devIdx; pkt[2] = feat; pkt[3] = 0x0E;
    if (sendAndWait(dev, pkt) != kIOReturnSuccess) return 0;
    int count = sResp[4];

    // 3. GetCidInfo — collect divertable CIDs
    uint16_t todivert[kMaxCIDs]; int ndiv = 0;
    for (int i = 0; i < count && ndiv < kMaxCIDs; i++) {
        memset(pkt, 0, 20);
        pkt[0] = kHIDPP_Long; pkt[1] = devIdx; pkt[2] = feat; pkt[3] = 0x1E; pkt[4] = (uint8_t)i;
        if (sendAndWait(dev, pkt) != kIOReturnSuccess) continue;
        uint16_t cid = ((uint16_t)sResp[4] << 8) | sResp[5];
        uint16_t tid = ((uint16_t)sResp[6] << 8) | sResp[7];
        uint8_t flags = sResp[8];
        if ((flags & (1 << 4)) && !isNativeTID(tid)) todivert[ndiv++] = cid;
    }

    // 4. Pre-register button mapping
    for (int i = 0; i < ndiv; i++) buttonForCID(s, todivert[i]);

    // 5. SetCidReporting — divert
    int diverted = 0;
    for (int i = 0; i < ndiv; i++) {
        memset(pkt, 0, 20);
        pkt[0] = kHIDPP_Long; pkt[1] = devIdx; pkt[2] = feat; pkt[3] = 0x3E;
        pkt[4] = (todivert[i] >> 8) & 0xFF; pkt[5] = todivert[i] & 0xFF; pkt[6] = kDivertFlags;
        if (sendAndWait(dev, pkt) == kIOReturnSuccess) diverted++;
    }
    return diverted;
}

// MARK: - Objective-C class

@interface LogitechCIDActivator ()
@property (nonatomic) NSMutableArray *states;
@property (nonatomic) NSMutableSet *openReceivers;
@property (nonatomic) NSTimer *keepAliveTimer;
@end

@implementation LogitechCIDActivator

+ (instancetype)shared {
    static LogitechCIDActivator *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [self new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _states = [NSMutableArray array];
        _openReceivers = [NSMutableSet set];
        
        /// NSWorkspaceDidWakeNotification — fires when system wakes from sleep
        [NSWorkspace.sharedWorkspace.notificationCenter
            addObserverForName:NSWorkspaceDidWakeNotification
            object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *note) {
                NSLog(@"LogitechCIDActivator: NSWorkspaceDidWakeNotification");
                [self handleSystemWake];
            }];
        
        /// NSWorkspaceScreensDidWakeNotification — fires when display wakes (more reliable for display sleep)
        [NSWorkspace.sharedWorkspace.notificationCenter
            addObserverForName:NSWorkspaceScreensDidWakeNotification
            object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *note) {
                NSLog(@"LogitechCIDActivator: NSWorkspaceScreensDidWakeNotification");
                [self handleSystemWake];
            }];
        
        /// Periodic keep-alive: Logitech firmware can reset CID diversion after ~30-60s
        /// of inactivity or on firmware events. Re-divert every 25s to stay ahead of it.
        _keepAliveTimer = [NSTimer scheduledTimerWithTimeInterval:25.0
                                                          target:self
                                                        selector:@selector(keepAliveTicket)
                                                        userInfo:nil
                                                         repeats:YES];
    }
    return self;
}

- (void)keepAliveTicket {
    if (_states.count == 0 && _openReceivers.count == 0) return;
    
    DDLogDebug(@"LogitechCIDActivator: keep-alive re-divert (%lu active states)", (unsigned long)_states.count);
    
    /// Re-divert all active states — re-sends SetCidReporting for each diverted CID
    /// This is fast (just HID++ commands, no full reprobe) and keeps diversion alive.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        for (NSValue *v in self->_states) {
            MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
            activateDevice(s->device, s);
        }
        
        /// Also re-probe receiver slots in case a device rejoined without triggering attach
        for (NSValue *rv in self->_openReceivers) {
            IOHIDDeviceRef rcv = (IOHIDDeviceRef)rv.pointerValue;
            [self probeReceiverSlots:rcv];
        }
    });
}

- (void)handleSystemWake {
    NSLog(@"LogitechCIDActivator: handleSystemWake called — %lu states, %lu receivers",
          (unsigned long)_states.count, (unsigned long)_openReceivers.count);
    DDLogInfo(@"LogitechCIDActivator: system woke — re-probing all devices");
    
    /// Clear all existing states (devices need to be re-diverted after sleep)
    for (NSValue *v in _states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        /// Release any held buttons
        for (int i = 0; i < s->pressedCount; i++) injectButton(s, s->pressedCIDs[i], NO);
        free(s);
    }
    [_states removeAllObjects];
    
    /// Re-probe all open receivers after a short delay to let USB/BT settle after wake
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (NSValue *rv in self->_openReceivers) {
            IOHIDDeviceRef rcv = (IOHIDDeviceRef)rv.pointerValue;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
                [self probeReceiverSlots:rcv];
            });
        }
    });
    
    /// Note: direct BT devices will re-trigger handleDeviceAttached naturally via IOHIDManager
    /// as the system re-enumerates them after wake. No need to re-probe those manually.
}

- (void)handleDeviceAttached:(IOHIDDeviceRef)device {
    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    if (vid.integerValue != kLogitechVID) return;

    NSNumber *pidNum = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    uint16_t pid = pidNum.unsignedShortValue;

    if (isReceiverPID(pid)) {
        [self handleReceiverAttached:device];
    } else {
        [self handleDirectDeviceAttached:device];
    }
}

- (void)handleDirectDeviceAttached:(IOHIDDeviceRef)device {
    if (IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone) != kIOReturnSuccess) return;

    MFCIDDeviceState *s = calloc(1, sizeof(MFCIDDeviceState));
    s->device = device;
    s->deviceIndex = kHIDPP_DevBLE;
    s->isReceiver = NO;

    IOHIDDeviceRegisterInputReportCallback(device, s->reportBuf, sizeof(s->reportBuf), inputReportCallback, s);
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    sProbingDevIdx = kHIDPP_DevBLE;
    int diverted = activateDevice(device, s);
    if (diverted > 0) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        DDLogInfo(@"LogitechCIDActivator: diverted %d CIDs on '%@' [BT]", diverted, name);
        // Ensure scheduled on main for events
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        [_states addObject:[NSValue valueWithPointer:s]];
    } else {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
        free(s);
    }
}

- (void)handleReceiverAttached:(IOHIDDeviceRef)device {
    // Only use the HID++ interface (vendor page 0xFF00 or generic desktop usage 6)
    NSNumber *usagePage = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDPrimaryUsagePageKey));
    NSNumber *usage = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDPrimaryUsageKey));
    BOOL isHIDPP = (usagePage.intValue == 0xFF00) || (usagePage.intValue == 0x0001 && usage.intValue == 0x0006);
    if (!isHIDPP) return;

    if ([_openReceivers containsObject:[NSValue valueWithPointer:device]]) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            [self probeReceiverSlots:device];
        });
        return;
    }

    if (IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone) != kIOReturnSuccess) return;
    [_openReceivers addObject:[NSValue valueWithPointer:device]];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        [self probeReceiverSlots:device];
    });
}

- (void)probeReceiverSlots:(IOHIDDeviceRef)device {
    // Get current thread's run loop for HID++ response reception during probing
    CFRunLoopRef probeRL = CFRunLoopGetCurrent();
    IOHIDDeviceScheduleWithRunLoop(device, probeRL, kCFRunLoopDefaultMode);
    
    for (uint8_t devIdx = 1; devIdx <= kMaxSlots; devIdx++) {
        // Skip if already have an active state for this device+slot
        BOOL alreadyActive = NO;
        for (NSValue *v in _states) {
            MFCIDDeviceState *existing = (MFCIDDeviceState *)v.pointerValue;
            if (existing->device == device && existing->deviceIndex == devIdx) {
                alreadyActive = YES; break;
            }
        }
        if (alreadyActive) continue;

        MFCIDDeviceState *s = calloc(1, sizeof(MFCIDDeviceState));
        s->device = device;
        s->deviceIndex = devIdx;
        s->isReceiver = YES;

        IOHIDDeviceRegisterInputReportCallback(device, s->reportBuf, sizeof(s->reportBuf), inputReportCallback, s);

        // Quick ping to check if slot has a device before full probe
        sProbingDevIdx = devIdx;
        int diverted = activateDevice(device, s);
        if (diverted > 0) {
            NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
            DDLogInfo(@"LogitechCIDActivator: diverted %d CIDs via receiver slot %d on '%@'", diverted, devIdx, name);
            // Move to main run loop for event delivery
            dispatch_async(dispatch_get_main_queue(), ^{
                IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
                [self->_states addObject:[NSValue valueWithPointer:s]];
            });
        } else {
            free(s);
        }
    }
    
    // Unschedule from probe run loop
    IOHIDDeviceUnscheduleFromRunLoop(device, probeRL, kCFRunLoopDefaultMode);
}

- (void)handleDeviceRemoved:(IOHIDDeviceRef)device {
    // Release buttons and remove states for this device
    NSMutableArray *toRemove = [NSMutableArray array];
    BOOL hadDirectDevice = NO;
    for (NSValue *v in _states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        if (s->device == device) {
            for (int i = 0; i < s->pressedCount; i++) injectButton(s, s->pressedCIDs[i], NO);
            if (!s->isReceiver) hadDirectDevice = YES;
            [toRemove addObject:v];
            free(s);
        }
    }
    [_states removeObjectsInArray:toRemove];

    // Clean up receiver tracking
    NSValue *devVal = [NSValue valueWithPointer:device];
    if ([_openReceivers containsObject:devVal]) {
        [_openReceivers removeObject:devVal];
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
    }

    // If a BT device was removed, mouse likely switched to USB — re-probe receivers after delay
    if (hadDirectDevice) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (NSValue *rv in self->_openReceivers) {
                IOHIDDeviceRef rcv = (IOHIDDeviceRef)rv.pointerValue;
                [self probeReceiverSlots:rcv];
            }
        });
    }
}

@end
