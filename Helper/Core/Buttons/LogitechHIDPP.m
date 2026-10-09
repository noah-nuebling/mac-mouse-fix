//
// --------------------------------------------------------------------------
// LogitechHIDPP.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// HID++ 2.0 references:
///     - https://github.com/pwr-Solaar/Solaar/blob/master/lib/logitech_receiver/hidpp20.py
///     - https://github.com/cvuchener/hidpp
///     - Logitech's 'x1b04_specialkeysmsebuttons' spec (REPROG_CONTROLS_V4)
///
/// Message layout (long report, 20 bytes): [reportID 0x11, deviceIndex, featureIndex, function << 4 | softwareID, params[16]]
///     - deviceIndex is 0xFF for devices connected directly (Bluetooth, USB cable) and 1-6 for devices behind a Unifying/Bolt receiver.
///     - Replies echo our softwareID. Notifications from the device have softwareID 0.

#import "LogitechHIDPP.h"
#import <IOKit/hid/IOHIDKeys.h>
#import <sys/event.h>
#import "GlobalEventTapThread.h"
#import "SharedUtility.h"
#import "Threads.h"

#define kHIDPPVendorID          0x046D
#define kHIDPPReportShort       0x10
#define kHIDPPReportLong        0x11
#define kHIDPPLongLength        20
#define kHIDPPSoftwareID        0x0B
#define kHIDPPErrorFeature20    0xFF
#define kHIDPPErrorFeature10    0x8F
#define kHIDPPRequestTimeout    1.5

#define kFeatureRoot            0x0000
#define kFeatureReprogControls  0x1B04
#define kFeatureWirelessStatus  0x1D4B

#define kReportingDivert        0x01
#define kReportingDivertValid   0x02

#define kEventTag               ((int64_t)0x4C4F4749 << 32) /// 'LOGI'
#define kEventTagMask           ((int64_t)0xFFFFFFFF << 32)

static const struct { uint16_t cid; int button; } kCidToButton[] = {
    { 0x0053, 4 }, /// Back
    { 0x0056, 5 }, /// Forward
    { 0x00C3, 6 }, /// Gesture button (MX Master thumb button)
};

static int buttonForCid(uint16_t cid) {
    for (size_t i = 0; i < sizeof(kCidToButton) / sizeof(kCidToButton[0]); i++) {
        if (kCidToButton[i].cid == cid) return kCidToButton[i].button;
    }
    return 0;
}

typedef void (^MFHIDPPCompletion)(BOOL success, const uint8_t *_Nullable params);

@interface MFHIDPPRequest : NSObject
@property (nonatomic) uint8_t deviceIndex;
@property (nonatomic) uint8_t featureIndex;
@property (nonatomic) uint8_t function;
@property (nonatomic) NSData *params;
@property (nonatomic, copy) MFHIDPPCompletion completion;
@end
@implementation MFHIDPPRequest
@end

@class MFHIDPPInterface;

/// One HID++ 2.0 device. A receiver interface hosts up to 6 of these.
@interface MFHIDPPDevice : NSObject
@property (nonatomic, weak) MFHIDPPInterface *interface;
@property (nonatomic) uint8_t deviceIndex;
@property (nonatomic) uint8_t reprogIndex;
@property (nonatomic) uint8_t wirelessStatusIndex;
@property (nonatomic) NSMutableArray<NSNumber *> *divertedCids;
@property (nonatomic) NSUInteger generation;
@end

@interface MFHIDPPInterface : NSObject {
    @public
    uint8_t _inputBuffer[64];
    uint16_t _pressedCids[7][4]; /// Indexed by deviceIndex (0xFF maps to 0)
}
@property (nonatomic) IOHIDDeviceRef iohidDevice;
@property (nonatomic) NSString *name;
@property (nonatomic) uint32_t tag;
@property (nonatomic) NSMutableDictionary<NSNumber *, MFHIDPPDevice *> *devices;
@property (nonatomic) NSMutableArray<MFHIDPPRequest *> *requestQueue;
@property (nonatomic, nullable) MFHIDPPRequest *pendingRequest;
@property (nonatomic) NSUInteger requestCounter;
@property (nonatomic) BOOL removed;
@end

@implementation MFHIDPPDevice
@end
@implementation MFHIDPPInterface
@end

@implementation LogitechHIDPP

static IOHIDManagerRef _manager;
static NSMutableArray<MFHIDPPInterface *> *_interfaces;
static uint32_t _tagCounter;
static CFFileDescriptorRef _signalFD;

#pragma mark - Lifecycle

+ (void)load_Manual {

    assertRunLoop(GlobalEventTapThread.runLoop);

    _interfaces = [NSMutableArray array];

    _manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
    NSArray *matching = @[
        @{ @(kIOHIDVendorIDKey): @(kHIDPPVendorID), @(kIOHIDDeviceUsagePageKey): @(0xFF43), @(kIOHIDDeviceUsageKey): @(0x0202) }, /// Bluetooth LE
        @{ @(kIOHIDVendorIDKey): @(kHIDPPVendorID), @(kIOHIDDeviceUsagePageKey): @(0xFF00), @(kIOHIDDeviceUsageKey): @(0x0002) }, /// Receivers and USB cable
    ];
    IOHIDManagerSetDeviceMatchingMultiple(_manager, (__bridge CFArrayRef)matching);
    IOHIDManagerRegisterDeviceMatchingCallback(_manager, &handleDeviceMatching, NULL);
    IOHIDManagerRegisterDeviceRemovalCallback(_manager, &handleDeviceRemoval, NULL);
    IOHIDManagerScheduleWithRunLoop(_manager, GlobalEventTapThread.runLoop, kCFRunLoopCommonModes);
    IOReturn ret = IOHIDManagerOpen(_manager, kIOHIDOptionsTypeNone);
    if (ret != kIOReturnSuccess) {
        DDLogError("LogitechHIDPP - Failed to open HID manager: 0x%x", ret);
    }

    observeTerminationSignal();
}

+ (void)restoreDevices {

    assertRunLoop(GlobalEventTapThread.runLoop);

    for (MFHIDPPInterface *interface in _interfaces) {
        for (MFHIDPPDevice *device in interface.devices.allValues) {
            for (NSNumber *cid in device.divertedCids) {
                uint8_t params[5] = { cid.unsignedShortValue >> 8, cid.unsignedShortValue & 0xFF, kReportingDivertValid, 0, 0 };
                writeReport(interface, device.deviceIndex, device.reprogIndex, 3, params, sizeof(params));
            }
            DDLogInfo("LogitechHIDPP - Restored %lu buttons on %@ (index 0x%02x)", device.divertedCids.count, interface.name, device.deviceIndex);
            [device.divertedCids removeAllObjects];
            releasePressedButtons(interface, device.deviceIndex);
        }
    }
}

static void observeTerminationSignal(void) {

    /// launchd stops the helper with SIGTERM (e.g. when MMF is disabled), and `applicationWillTerminate:` isn't called in that case.
    /// We need to undivert before exiting, so we take over SIGTERM and exit ourselves.

    int kq = kqueue();
    if (kq < 0) return;
    struct kevent ev;
    EV_SET(&ev, SIGTERM, EVFILT_SIGNAL, EV_ADD, 0, 0, NULL);
    if (kevent(kq, &ev, 1, NULL, 0, NULL) < 0) { close(kq); return; }
    signal(SIGTERM, SIG_IGN);

    _signalFD = CFFileDescriptorCreate(kCFAllocatorDefault, kq, true, &handleTerminationSignal, NULL);
    CFFileDescriptorEnableCallBacks(_signalFD, kCFFileDescriptorReadCallBack);
    CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, _signalFD, 0);
    CFRunLoopAddSource(GlobalEventTapThread.runLoop, source, kCFRunLoopCommonModes);
    CFRelease(source);
}

static void handleTerminationSignal(CFFileDescriptorRef fd, CFOptionFlags callBackTypes, void *info) {
    DDLogInfo("LogitechHIDPP - Received SIGTERM");
    [LogitechHIDPP restoreDevices];
    exit(0);
}

#pragma mark - Synthetic events

+ (IOHIDDeviceRef _Nullable)sendingDeviceForEvent:(CGEventRef)event {

    assertRunLoop(GlobalEventTapThread.runLoop);

    int64_t userData = CGEventGetIntegerValueField(event, kCGEventSourceUserData);
    if ((userData & kEventTagMask) != kEventTag) return NULL;
    uint32_t tag = (uint32_t)(userData & 0xFFFFFFFF);
    for (MFHIDPPInterface *interface in _interfaces) {
        if (interface.tag == tag) return interface.iohidDevice;
    }
    return NULL;
}

static void postButton(MFHIDPPInterface *interface, int button, BOOL down) {

    CGEventRef locationEvent = CGEventCreate(NULL);
    CGPoint location = CGEventGetLocation(locationEvent);
    CFRelease(locationEvent);

    CGEventRef event = CGEventCreateMouseEvent(NULL, down ? kCGEventOtherMouseDown : kCGEventOtherMouseUp, location, (CGMouseButton)(button - 1));
    CGEventSetIntegerValueField(event, kCGMouseEventClickState, 1);
    CGEventSetDoubleValueField(event, kCGMouseEventPressure, down ? 1.0 : 0.0);
    CGEventSetIntegerValueField(event, kCGEventSourceUserData, kEventTag | interface.tag);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

static uint16_t *pressedCidsFor(MFHIDPPInterface *interface, uint8_t deviceIndex) {
    return interface->_pressedCids[deviceIndex == 0xFF ? 0 : MIN(deviceIndex, 6)];
}

static BOOL cidsContain(const uint16_t *cids, uint16_t cid) {
    for (int i = 0; i < 4; i++) if (cids[i] == cid) return YES;
    return NO;
}

static void releasePressedButtons(MFHIDPPInterface *interface, uint8_t deviceIndex) {
    uint16_t *pressed = pressedCidsFor(interface, deviceIndex);
    for (int i = 0; i < 4; i++) {
        int button = pressed[i] ? buttonForCid(pressed[i]) : 0;
        if (button) postButton(interface, button, NO);
        pressed[i] = 0;
    }
}

static void handleDivertedButtonsEvent(MFHIDPPInterface *interface, uint8_t deviceIndex, const uint8_t *params) {

    /// The device sends the full list of currently pressed diverted controls on every change.

    uint16_t now[4];
    for (int i = 0; i < 4; i++) now[i] = (params[2*i] << 8) | params[2*i + 1];
    uint16_t *before = pressedCidsFor(interface, deviceIndex);

    for (int i = 0; i < 4; i++) {
        if (before[i] == 0 || cidsContain(now, before[i])) continue;
        int button = buttonForCid(before[i]);
        DDLogDebug("LogitechHIDPP - Up cid 0x%04x -> button %d", before[i], button);
        if (button) postButton(interface, button, NO);
    }
    for (int i = 0; i < 4; i++) {
        if (now[i] == 0 || cidsContain(before, now[i])) continue;
        int button = buttonForCid(now[i]);
        DDLogDebug("LogitechHIDPP - Down cid 0x%04x -> button %d", now[i], button);
        if (button) postButton(interface, button, YES);
    }
    memcpy(before, now, sizeof(now));
}

#pragma mark - Device callbacks

static void handleDeviceMatching(void *context, IOReturn result, void *sender, IOHIDDeviceRef iohidDevice) {

    assertRunLoop(GlobalEventTapThread.runLoop);

    MFHIDPPInterface *interface = [[MFHIDPPInterface alloc] init];
    interface.iohidDevice = (IOHIDDeviceRef)CFRetain(iohidDevice);
    interface.name = (__bridge NSString *)IOHIDDeviceGetProperty(iohidDevice, CFSTR(kIOHIDProductKey)) ?: @"Logitech device";
    interface.tag = ++_tagCounter;
    interface.devices = [NSMutableDictionary dictionary];
    interface.requestQueue = [NSMutableArray array];
    [_interfaces addObject:interface];

    IOHIDDeviceRegisterInputReportCallback(iohidDevice, interface->_inputBuffer, sizeof(interface->_inputBuffer), &handleInputReport, (__bridge void *)interface);

    DDLogInfo("LogitechHIDPP - Attached %@", interface.name);

    /// Directly connected devices answer on index 0xFF. Receivers answer 0xFF with a HID++ 1.0 error, then we probe the paired slots.
    probeDevice(interface, 0xFF, ^(BOOL isHIDPP20) {
        if (isHIDPP20) return;
        for (uint8_t i = 1; i <= 6; i++) probeDevice(interface, i, nil);
    });
}

static void handleDeviceRemoval(void *context, IOReturn result, void *sender, IOHIDDeviceRef iohidDevice) {

    assertRunLoop(GlobalEventTapThread.runLoop);

    for (MFHIDPPInterface *interface in [_interfaces copy]) {
        if (interface.iohidDevice != iohidDevice) continue;
        DDLogInfo("LogitechHIDPP - Removed %@", interface.name);
        interface.removed = YES;
        for (NSNumber *index in interface.devices) releasePressedButtons(interface, index.unsignedCharValue);
        [interface.requestQueue removeAllObjects];
        interface.pendingRequest = nil;
        IOHIDDeviceRegisterInputReportCallback(iohidDevice, interface->_inputBuffer, sizeof(interface->_inputBuffer), NULL, NULL);
        CFRelease(interface.iohidDevice);
        [_interfaces removeObject:interface];
    }
}

static void handleInputReport(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *report, CFIndex length) {

    assertRunLoop(GlobalEventTapThread.runLoop);

    MFHIDPPInterface *interface = (__bridge MFHIDPPInterface *)context;
    if (interface.removed) return;
    if ((reportID != kHIDPPReportShort && reportID != kHIDPPReportLong) || length < 7) return;

    uint8_t deviceIndex = report[1];
    uint8_t featureIndex = report[2];
    uint8_t function = report[3] >> 4;
    uint8_t softwareID = report[3] & 0x0F;
    MFHIDPPRequest *pending = interface.pendingRequest;

    /// Error reply: [id, index, 0xFF or 0x8F, featureIndex, function|swid, errorCode]
    if (featureIndex == kHIDPPErrorFeature20 || featureIndex == kHIDPPErrorFeature10) {
        if (pending && pending.deviceIndex == deviceIndex && report[3] == pending.featureIndex && (report[4] >> 4) == pending.function) {
            DDLogDebug("LogitechHIDPP - Error 0x%02x for feature %d function %d on %@ (index 0x%02x)", report[5], pending.featureIndex, pending.function, interface.name, deviceIndex);
            finishPendingRequest(interface, NO, NULL);
        }
        return;
    }

    /// Reply
    if (softwareID == kHIDPPSoftwareID) {
        if (pending && pending.deviceIndex == deviceIndex && pending.featureIndex == featureIndex && pending.function == function) {
            uint8_t params[16] = {0};
            memcpy(params, report + 4, MIN(16, length - 4));
            finishPendingRequest(interface, YES, params);
        }
        return;
    }

    /// Notification
    MFHIDPPDevice *device = interface.devices[@(deviceIndex)];
    if (reportID == kHIDPPReportShort && featureIndex == 0x41) {
        /// Receiver says a paired device (re)connected. It forgets diversion when it powers off.
        DDLogInfo("LogitechHIDPP - Device connection notification on %@ (index 0x%02x)", interface.name, deviceIndex);
        if (device) releasePressedButtons(interface, deviceIndex);
        probeDevice(interface, deviceIndex, nil);
        return;
    }
    if (device == nil) return;
    if (device.reprogIndex && featureIndex == device.reprogIndex && function == 0) {
        handleDivertedButtonsEvent(interface, deviceIndex, report + 4);
    } else if (device.wirelessStatusIndex && featureIndex == device.wirelessStatusIndex && function == 0) {
        DDLogInfo("LogitechHIDPP - Reconnect notification from %@ (index 0x%02x)", interface.name, deviceIndex);
        releasePressedButtons(interface, deviceIndex);
        probeDevice(interface, deviceIndex, nil);
    }
}

#pragma mark - Setup

static void probeDevice(MFHIDPPInterface *interface, uint8_t deviceIndex, void (^_Nullable onProbed)(BOOL isHIDPP20)) {

    MFHIDPPDevice *device = interface.devices[@(deviceIndex)];
    if (device == nil) {
        device = [[MFHIDPPDevice alloc] init];
        device.interface = interface;
        device.deviceIndex = deviceIndex;
        device.divertedCids = [NSMutableArray array];
    }
    NSUInteger generation = ++device.generation;

    /// Root feature, function 1: getProtocolVersion(0, 0, pingData)
    uint8_t ping[3] = { 0, 0, 0x5A };
    sendRequest(interface, deviceIndex, 0, 1, ping, sizeof(ping), ^(BOOL success, const uint8_t *params) {
        BOOL isHIDPP20 = success && params[0] >= 2;
        if (onProbed) onProbed(isHIDPP20);
        if (!isHIDPP20 || device.generation != generation) return;
        interface.devices[@(deviceIndex)] = device;
        DDLogInfo("LogitechHIDPP - %@ (index 0x%02x) speaks HID++ %d.%d", interface.name, deviceIndex, params[0], params[1]);
        setUpDevice(interface, device, generation);
    });
}

static void getFeatureIndex(MFHIDPPInterface *interface, uint8_t deviceIndex, uint16_t featureID, void (^completion)(uint8_t index)) {
    uint8_t params[2] = { featureID >> 8, featureID & 0xFF };
    sendRequest(interface, deviceIndex, 0, 0, params, sizeof(params), ^(BOOL success, const uint8_t *reply) {
        completion(success ? reply[0] : 0);
    });
}

static void setUpDevice(MFHIDPPInterface *interface, MFHIDPPDevice *device, NSUInteger generation) {

    uint8_t deviceIndex = device.deviceIndex;
    [device.divertedCids removeAllObjects];

    getFeatureIndex(interface, deviceIndex, kFeatureWirelessStatus, ^(uint8_t index) {
        device.wirelessStatusIndex = index;
    });
    getFeatureIndex(interface, deviceIndex, kFeatureReprogControls, ^(uint8_t reprogIndex) {
        if (reprogIndex == 0 || device.generation != generation) return;
        device.reprogIndex = reprogIndex;

        /// Function 3: setCidReporting(cid, flags, remap). Not persistent, so the device forgets this when it powers off.
        ///     Controls the device doesn't have, or can't divert, get an error reply. That's cheaper than listing all controls with getCidInfo over Bluetooth.
        ///     Recorded before the reply arrives so `restoreDevices` also undoes in-flight diversions.
        for (size_t i = 0; i < sizeof(kCidToButton) / sizeof(kCidToButton[0]); i++) {
            uint16_t cid = kCidToButton[i].cid;
            int button = kCidToButton[i].button;
            if (![device.divertedCids containsObject:@(cid)]) [device.divertedCids addObject:@(cid)];
            uint8_t params[5] = { cid >> 8, cid & 0xFF, kReportingDivert | kReportingDivertValid, 0, 0 };
            sendRequest(interface, deviceIndex, reprogIndex, 3, params, sizeof(params), ^(BOOL success, const uint8_t *_) {
                if (device.generation != generation) return;
                if (!success) { [device.divertedCids removeObject:@(cid)]; return; }
                DDLogInfo("LogitechHIDPP - Diverted cid 0x%04x as button %d on %@ (index 0x%02x)", cid, button, interface.name, deviceIndex);
            });
        }
    });
}

#pragma mark - Request queue

static BOOL writeReport(MFHIDPPInterface *interface, uint8_t deviceIndex, uint8_t featureIndex, uint8_t function, const uint8_t *params, size_t paramsLength) {
    uint8_t report[kHIDPPLongLength] = { kHIDPPReportLong, deviceIndex, featureIndex, (uint8_t)((function << 4) | kHIDPPSoftwareID) };
    memcpy(report + 4, params, MIN(paramsLength, 16));
    IOReturn ret = IOHIDDeviceSetReport(interface.iohidDevice, kIOHIDReportTypeOutput, kHIDPPReportLong, report, kHIDPPLongLength);
    if (ret != kIOReturnSuccess) DDLogDebug("LogitechHIDPP - SetReport failed on %@: 0x%x", interface.name, ret);
    return ret == kIOReturnSuccess;
}

static void sendRequest(MFHIDPPInterface *interface, uint8_t deviceIndex, uint8_t featureIndex, uint8_t function, const uint8_t *_Nullable params, size_t paramsLength, MFHIDPPCompletion completion) {
    MFHIDPPRequest *request = [[MFHIDPPRequest alloc] init];
    request.deviceIndex = deviceIndex;
    request.featureIndex = featureIndex;
    request.function = function;
    request.params = params ? [NSData dataWithBytes:params length:paramsLength] : [NSData data];
    request.completion = completion;
    [interface.requestQueue addObject:request];
    sendNextRequest(interface);
}

static void sendNextRequest(MFHIDPPInterface *interface) {

    /// One request in flight per interface, so replies can't be confused with each other.

    while (!interface.removed && interface.pendingRequest == nil && interface.requestQueue.count > 0) {
        MFHIDPPRequest *request = interface.requestQueue.firstObject;
        [interface.requestQueue removeObjectAtIndex:0];
        interface.pendingRequest = request;
        NSUInteger requestNumber = ++interface.requestCounter;

        if (!writeReport(interface, request.deviceIndex, request.featureIndex, request.function, request.params.bytes, request.params.length)) {
            finishPendingRequest(interface, NO, NULL);
            continue;
        }
        MFCFRunLoopPerform_delay(GlobalEventTapThread.runLoop, nil, kHIDPPRequestTimeout, ^{
            if (interface.pendingRequest == request && interface.requestCounter == requestNumber) {
                DDLogDebug("LogitechHIDPP - Timeout for feature %d function %d on %@ (index 0x%02x)", request.featureIndex, request.function, interface.name, request.deviceIndex);
                finishPendingRequest(interface, NO, NULL);
            }
        });
    }
}

static void finishPendingRequest(MFHIDPPInterface *interface, BOOL success, const uint8_t *_Nullable params) {
    MFHIDPPRequest *request = interface.pendingRequest;
    interface.pendingRequest = nil;
    if (request.completion) request.completion(success, params);
    sendNextRequest(interface);
}

@end
