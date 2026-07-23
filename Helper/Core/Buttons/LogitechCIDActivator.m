//
// --------------------------------------------------------------------------
// LogitechCIDActivator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------

#import "LogitechCIDActivator.h"
#import <IOKit/hid/IOHIDLib.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>
#import "SharedUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "DeviceManager.h"

#define kLogitechVID             0x046D
#define kBoltReceiverPID         0xC548
#define kUnifyingReceiverPID1    0xC52B
#define kUnifyingReceiverPID2    0xC532
#define kHIDPP_Long              0x11
#define kHIDPP_DirectDevice      0xFF
#define kFeat_ReprogV4           0x1B04
#define kDivertFlags             0x03
#define kFirstMMFButton          6
#define kResponseTimeout         0.30
#define kMaxReceiverSlots        6

/// Logitech's HID++ vendor collections. The ordinary GenericDesktop/Mouse
/// collection cannot carry HID++ 0x10/0x11 output reports.
#define kHIDPPUSBUsagePage       0xFF00
#define kHIDPPUSBUsage           0x0001
#define kHIDPPBLEUsagePage       0xFF43
#define kHIDPPBLEUsage           0x0202

/// Known DPI / ModeShift control IDs from Logitech's 0x1B04 control table.
static const uint16_t kDPICIDs[] = { 0x00C4, 0x00ED, 0x00FD };

typedef struct {
    IOHIDDeviceRef hidppDevice;
    IOHIDDeviceRef mouseDevice;
    uint8_t reportBuf[64];

    BOOL waitingForResponse;
    BOOL gotResponse;
    uint8_t pendingDeviceIndex;
    uint8_t pendingFeatureIndex;
    uint8_t pendingFunction;
    uint8_t response[64];
    CFIndex responseLength;

    uint8_t deviceIndex;
    uint8_t reprogFeatureIndex;
    uint16_t cidMap[8];
    int cidCount;
    uint16_t pressedCIDs[8];
    int pressedCount;
} MFCIDDeviceState;

@interface LogitechCIDActivator ()
@property (nonatomic) NSMutableArray<NSValue *> *states;
@property (nonatomic) NSTimer *reactivateTimer;
@property (nonatomic) IOHIDManagerRef hidppManager;
@property (nonatomic) IOHIDDeviceRef fallbackMouseDevice;
- (void)handleHIDPPDeviceAttached:(IOHIDDeviceRef)device;
- (void)handleHIDPPDeviceRemoved:(IOHIDDeviceRef)device;
@end

static BOOL isReceiverPID(NSInteger pid) {
    return pid == kBoltReceiverPID || pid == kUnifyingReceiverPID1 || pid == kUnifyingReceiverPID2;
}

static BOOL isDPICID(uint16_t cid) {
    for (NSUInteger i = 0; i < sizeof(kDPICIDs) / sizeof(kDPICIDs[0]); i++) {
        if (kDPICIDs[i] == cid) return YES;
    }
    return NO;
}

static int buttonForCID(MFCIDDeviceState *state, uint16_t cid) {
    for (int i = 0; i < state->cidCount; i++) {
        if (state->cidMap[i] == cid) return kFirstMMFButton + i;
    }
    if (state->cidCount < 8) {
        int index = state->cidCount++;
        state->cidMap[index] = cid;
        return kFirstMMFButton + index;
    }
    return kFirstMMFButton;
}

static void injectButton(MFCIDDeviceState *state, uint16_t cid, BOOL down) {
    Device *device = state->mouseDevice == NULL
        ? nil
        : [DeviceManager attachedDeviceWithIOHIDDevice:state->mouseDevice];
    if (!device) device = [Device strangeDevice];

    CGEventRef event = CGEventCreate(NULL);
    (void)[Buttons handleInputWithDevice:device
                                   button:@(buttonForCID(state, cid))
                                downNotUp:down
                                    event:event];
    if (event) CFRelease(event);
}

static BOOL containsCID(const uint16_t *cids, int count, uint16_t cid) {
    for (int i = 0; i < count; i++) if (cids[i] == cid) return YES;
    return NO;
}

static void handleDivertedButtonsEvent(MFCIDDeviceState *state, const uint8_t *report, CFIndex len) {
    uint16_t nextPressed[8] = {0};
    int nextCount = 0;

    /// divertedButtonsEvent carries up to four currently-held CIDs.
    for (CFIndex offset = 4; offset + 1 < len && offset <= 10; offset += 2) {
        uint16_t cid = ((uint16_t)report[offset] << 8) | report[offset + 1];
        if (cid != 0 && isDPICID(cid) && nextCount < 8) nextPressed[nextCount++] = cid;
    }

    for (int i = 0; i < state->pressedCount; i++) {
        uint16_t cid = state->pressedCIDs[i];
        if (!containsCID(nextPressed, nextCount, cid)) injectButton(state, cid, NO);
    }
    for (int i = 0; i < nextCount; i++) {
        uint16_t cid = nextPressed[i];
        if (!containsCID(state->pressedCIDs, state->pressedCount, cid)) injectButton(state, cid, YES);
    }

    memcpy(state->pressedCIDs, nextPressed, sizeof(nextPressed));
    state->pressedCount = nextCount;
}

static void inputReportCallback(void *context, IOReturn result, void *sender,
                                IOHIDReportType type, uint32_t reportID,
                                uint8_t *report, CFIndex len) {
    MFCIDDeviceState *state = context;
    if (result != kIOReturnSuccess || len < 6 || report[0] != kHIDPP_Long) return;

    uint8_t function = report[3] >> 4;
    BOOL isExpectedResponse = state->waitingForResponse
        && report[1] == state->pendingDeviceIndex
        && report[2] == state->pendingFeatureIndex
        && function == state->pendingFunction;
    BOOL isExpectedError = state->waitingForResponse
        && report[1] == state->pendingDeviceIndex
        && report[2] == 0xFF
        && report[4] == state->pendingFeatureIndex
        && (report[5] >> 4) == state->pendingFunction;

    if (isExpectedResponse || isExpectedError) {
        state->responseLength = MIN(len, (CFIndex)sizeof(state->response));
        memcpy(state->response, report, (size_t)state->responseLength);
        state->gotResponse = YES;
        return;
    }

    if (state->reprogFeatureIndex != 0
        && report[1] == state->deviceIndex
        && report[2] == state->reprogFeatureIndex
        && function == 0x00) {
        handleDivertedButtonsEvent(state, report, len);
    }
}

static IOReturn sendAndWait(MFCIDDeviceState *state, uint8_t packet[20]) {
    state->gotResponse = NO;
    state->waitingForResponse = YES;
    state->pendingDeviceIndex = packet[1];
    state->pendingFeatureIndex = packet[2];
    state->pendingFunction = packet[3] >> 4;
    state->responseLength = 0;
    memset(state->response, 0, sizeof(state->response));

    IOReturn result = IOHIDDeviceSetReport(state->hidppDevice,
                                           kIOHIDReportTypeOutput,
                                           packet[0], packet, 20);
    if (result != kIOReturnSuccess) {
        state->waitingForResponse = NO;
        return result;
    }

    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + kResponseTimeout;
    while (!state->gotResponse && CFAbsoluteTimeGetCurrent() < deadline) {
        (void)CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
    }
    state->waitingForResponse = NO;

    if (!state->gotResponse) return kIOReturnTimeout;
    if (state->response[2] == 0xFF) return kIOReturnError;
    return kIOReturnSuccess;
}

static int activateDeviceIndex(MFCIDDeviceState *state, uint8_t deviceIndex) {
    uint8_t packet[20] = {0};

    /// Resolve ReprogControlsV4 (0x1B04) on this receiver slot/direct device.
    packet[0] = kHIDPP_Long;
    packet[1] = deviceIndex;
    packet[2] = 0x00;
    packet[3] = 0x0E;
    packet[4] = (kFeat_ReprogV4 >> 8) & 0xFF;
    packet[5] = kFeat_ReprogV4 & 0xFF;
    if (sendAndWait(state, packet) != kIOReturnSuccess || state->response[4] == 0) return 0;
    uint8_t featureIndex = state->response[4];

    /// Enumerate the control table.
    memset(packet, 0, sizeof(packet));
    packet[0] = kHIDPP_Long;
    packet[1] = deviceIndex;
    packet[2] = featureIndex;
    packet[3] = 0x0E;
    if (sendAndWait(state, packet) != kIOReturnSuccess) return 0;
    int count = state->response[4];

    uint16_t dpiCIDs[8] = {0};
    int dpiCount = 0;
    for (int i = 0; i < count && dpiCount < 8; i++) {
        memset(packet, 0, sizeof(packet));
        packet[0] = kHIDPP_Long;
        packet[1] = deviceIndex;
        packet[2] = featureIndex;
        packet[3] = 0x1E;
        packet[4] = (uint8_t)i;
        if (sendAndWait(state, packet) != kIOReturnSuccess) continue;

        uint16_t cid = ((uint16_t)state->response[4] << 8) | state->response[5];
        uint8_t flags = state->response[8];
        if (isDPICID(cid) && (flags & (1 << 4))) dpiCIDs[dpiCount++] = cid;
    }

    /// Divert only known DPI / ModeShift controls.
    int diverted = 0;
    for (int i = 0; i < dpiCount; i++) {
        uint16_t cid = dpiCIDs[i];
        memset(packet, 0, sizeof(packet));
        packet[0] = kHIDPP_Long;
        packet[1] = deviceIndex;
        packet[2] = featureIndex;
        packet[3] = 0x3E;
        packet[4] = (cid >> 8) & 0xFF;
        packet[5] = cid & 0xFF;
        packet[6] = kDivertFlags;
        if (sendAndWait(state, packet) == kIOReturnSuccess) {
            buttonForCID(state, cid);
            diverted++;
        }
    }

    if (diverted > 0) {
        state->deviceIndex = deviceIndex;
        state->reprogFeatureIndex = featureIndex;
    }
    return diverted;
}

static int activateState(MFCIDDeviceState *state) {
    NSNumber *pid = (__bridge NSNumber *)IOHIDDeviceGetProperty(state->hidppDevice,
                                                                 CFSTR(kIOHIDProductIDKey));
    if (isReceiverPID(pid.integerValue)) {
        for (uint8_t slot = 1; slot <= kMaxReceiverSlots; slot++) {
            int diverted = activateDeviceIndex(state, slot);
            if (diverted > 0) return diverted;
        }
        return 0;
    }
    return activateDeviceIndex(state, kHIDPP_DirectDevice);
}

static void vendorDeviceMatched(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    LogitechCIDActivator *activator = (__bridge LogitechCIDActivator *)context;
    [activator handleHIDPPDeviceAttached:device];
}

static void vendorDeviceRemoved(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    LogitechCIDActivator *activator = (__bridge LogitechCIDActivator *)context;
    [activator handleHIDPPDeviceRemoved:device];
}

@implementation LogitechCIDActivator

+ (instancetype)shared {
    static LogitechCIDActivator *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [self new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _states = [NSMutableArray array];
        [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
               selector:@selector(reactivateAll)
                   name:NSWorkspaceDidWakeNotification
                 object:nil];
        _reactivateTimer = [NSTimer scheduledTimerWithTimeInterval:60 * 30
                                                            target:self
                                                          selector:@selector(reactivateAll)
                                                          userInfo:nil
                                                           repeats:YES];
    }
    return self;
}

- (void)start {
    [self startHIDPPManagerIfNeeded];
}

- (void)startHIDPPManagerIfNeeded {
    if (_hidppManager) return;

    _hidppManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
    NSArray *matches = @[
        /// On macOS the combined Bolt receiver IOHIDDevice has short-report
        /// usage 1 as its primary usage, while still carrying long report 0x11.
        @{ @kIOHIDVendorIDKey: @(kLogitechVID),
           @kIOHIDDeviceUsagePageKey: @(kHIDPPUSBUsagePage),
           @kIOHIDDeviceUsageKey: @(kHIDPPUSBUsage) },
        @{ @kIOHIDVendorIDKey: @(kLogitechVID),
           @kIOHIDDeviceUsagePageKey: @(kHIDPPBLEUsagePage),
           @kIOHIDDeviceUsageKey: @(kHIDPPBLEUsage) },
    ];
    DDLogInfo("LogitechCIDActivator: starting HID++ vendor manager");
    IOHIDManagerSetDeviceMatchingMultiple(_hidppManager, (__bridge CFArrayRef)matches);
    IOHIDManagerRegisterDeviceMatchingCallback(_hidppManager, vendorDeviceMatched, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_hidppManager, vendorDeviceRemoved, (__bridge void *)self);
    IOHIDManagerScheduleWithRunLoop(_hidppManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOReturn result = IOHIDManagerOpen(_hidppManager, kIOHIDOptionsTypeNone);
    if (result != kIOReturnSuccess) {
        DDLogInfo("LogitechCIDActivator: failed to open HID++ manager: 0x%x", result);
    }
}

- (void)handleDeviceAttached:(IOHIDDeviceRef)device {
    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    if (vid.integerValue != kLogitechVID) return;

    _fallbackMouseDevice = device;
    for (NSValue *value in _states) {
        MFCIDDeviceState *state = value.pointerValue;
        if (!state->mouseDevice) state->mouseDevice = device;
    }
    [self startHIDPPManagerIfNeeded];
}

- (void)handleDeviceRemoved:(IOHIDDeviceRef)device {
    if (_fallbackMouseDevice == device) _fallbackMouseDevice = NULL;
    for (NSValue *value in _states) {
        MFCIDDeviceState *state = value.pointerValue;
        if (state->mouseDevice == device) state->mouseDevice = NULL;
    }
}

- (void)handleHIDPPDeviceAttached:(IOHIDDeviceRef)device {
    NSString *matchedName = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    NSNumber *matchedPID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    DDLogInfo("LogitechCIDActivator: matched HID++ node '%@' pid=0x%lx", matchedName, (long)matchedPID.integerValue);
    for (NSValue *value in _states) {
        if (((MFCIDDeviceState *)value.pointerValue)->hidppDevice == device) return;
    }

    if (IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone) != kIOReturnSuccess) return;

    MFCIDDeviceState *state = calloc(1, sizeof(MFCIDDeviceState));
    state->hidppDevice = device;
    state->mouseDevice = _fallbackMouseDevice;
    IOHIDDeviceRegisterInputReportCallback(device, state->reportBuf, sizeof(state->reportBuf),
                                           inputReportCallback, state);
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);

    int diverted = activateState(state);
    /// The first probe can wake a sleeping receiver device without getting a
    /// complete feature-table response. Retry briefly before giving up.
    for (int attempt = 0; diverted == 0 && attempt < 2; attempt++) {
        (void)CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.35, false);
        diverted = activateState(state);
    }
    NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    if (diverted > 0) {
        DDLogInfo("LogitechCIDActivator: diverted %d DPI control(s) on '%@' at index %u",
                  diverted, name, state->deviceIndex);
        [_states addObject:[NSValue valueWithPointer:state]];
    } else {
        DDLogInfo("LogitechCIDActivator: no divertible DPI controls found on '%@'", name);
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
        free(state);
    }
}

- (void)handleHIDPPDeviceRemoved:(IOHIDDeviceRef)device {
    NSValue *found;
    for (NSValue *value in _states) {
        if (((MFCIDDeviceState *)value.pointerValue)->hidppDevice == device) {
            found = value;
            break;
        }
    }
    if (!found) return;

    MFCIDDeviceState *state = found.pointerValue;
    for (int i = 0; i < state->pressedCount; i++) injectButton(state, state->pressedCIDs[i], NO);
    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
    free(state);
    [_states removeObject:found];
}

- (void)reactivateAll {
    for (NSValue *value in _states) {
        MFCIDDeviceState *state = value.pointerValue;
        state->cidCount = 0;
        state->reprogFeatureIndex = 0;
        (void)activateState(state);
    }
}

@end
