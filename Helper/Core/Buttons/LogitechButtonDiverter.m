//
// --------------------------------------------------------------------------
// LogitechButtonDiverter.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//
/// Problem
///     Newer Logitech mice (MX Anywhere 3/3S, MX Master 3/3S, M650, Lift, ...) don't report their side buttons like normal
///     mouse buttons. Without Logi Options+ the firmware only sends a click (or nothing at all) and never a "held down"
///     state, so Click and Drag / Click and Scroll can't work on those buttons.
///     See GitHub issues #1841, #1769, #1665, #1563, #1559, #1154, #812, #555.
///
/// Solution
///     These mice speak HID++ 2.0 over a vendor-defined HID collection (usage page 0xFF43 on Bluetooth, 0xFF00 on USB and
///     on Bolt / Unifying receivers). Feature 0x1B04 `ReprogControlsV4` can *divert* a physical control: the firmware then
///     stops acting on the button itself and reports press *and* release through a HID++ notification instead.
///     We divert the problematic controls, translate the notifications into ordinary button events, and post those into the
///     event system tagged with the mouse's sender ID – so the rest of Mac Mouse Fix sees them exactly like button events
///     from any other mouse (they go through ButtonInputReceiver's event tap like everything else).
///
/// Behaviour
///     - Diversion is temporary. It lives in the mouse's RAM only, resets when the mouse reconnects, and we undo it in
///       `restoreNativeBehavior` when the Helper exits, so a mouse never gets stuck in a diverted state.
///     - The mouse tells us when it reconnected (feature 0x1D4B). We also re-check after system wake and every 30 s, since
///       some firmware silently forgets the diversion after a while.
///     - Which controls get diverted is decided by `kDefaultPolicy` below. Users can override it with the config key
///       `General.logitechDivertedControls` (an array of control IDs, see `kDefaultPolicy` for the IDs).
///     - All HID++ traffic runs on its own thread with its own run loop, so a slow or sleeping mouse can never block the
///       main thread, where MMF's event taps live.
///
/// References
///     - Logitech HID++ 2.0 feature 0x1B04: https://lekensteyn.nl/files/logitech/x1b04_specialkeysmsebuttons.html
///     - Solaar (https://github.com/pwr-Solaar/Solaar): `hidpp20.py`, `special_keys.py` (control IDs, flags, events)
///     - Earlier attempts in MMF pull requests #1710 (PradyumnaKrishna), #1848/#1856/#1904 (miguelAngelo1999), #1938 (nikuscs)
///

#import "LogitechButtonDiverter.h"
#import <IOKit/hid/IOHIDLib.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>
#import <mach/mach_time.h>
#import "Constants.h"
#import "Config.h"
#import "Logging.h"
#import "DeviceManager.h"
#import "Device.h"

#pragma mark - Constants

#define kLogiVendorID                   0x046D

/// HID++ transport
#define kHIDPPReportShort               0x10
#define kHIDPPReportLong                0x11
#define kHIDPPLongLength                20      /// Report ID + 19 bytes (macOS hands us / expects the report ID byte in the buffer)
#define kHIDPPDeviceIndexDirect         0xFF    /// Device index for mice connected directly via Bluetooth or USB. Receivers use slots 1-6.
#define kHIDPPMaxReceiverSlots          6
#define kHIDPPSoftwareID                0x0C    /// 4-bit tag that the mouse echoes in every response. Lets us ignore traffic of other software.
#define kHIDPPErrorFeatureIndex         0xFF
#define kHIDPPResponseTimeout           0.6     /// Seconds. A Bluetooth round trip takes ~15-40 ms.

/// HID++ 2.0 features
#define kHIDPPFeatureRoot               0x0000
#define kHIDPPFeatureWirelessStatus     0x1D4B
#define kHIDPPFeatureReprogControlsV4   0x1B04

/// HID++ 1.0 receiver notification: device connection / disconnection
#define kHIDPP1NotificationDeviceConnection 0x41

/// 0x1B04 getCidInfo flags byte
#define kCIDInfoFlagDivertable          0x20
/// 0x1B04 setCidReporting / getCidReporting flags byte
#define kCIDReportingDivert             0x01
#define kCIDReportingDivertValid        0x02

#define kVerifyInterval                 30.0    /// Seconds between checks that the diversion is still active.

/// Which physical controls we divert and which Mac Mouse Fix button they become.
///     Button numbers use MMF's 1-based numbering (1 = left, 2 = right, 3 = middle, 4 = back, 5 = forward).
///     `defaultOn == NO` entries are only diverted when listed in the `General.logitechDivertedControls` config key.
typedef struct {
    uint16_t cid;
    int button;
    BOOL defaultOn;
    const char *name;
} MFLogiControlPolicy;

static const MFLogiControlPolicy kDefaultPolicy[] = {
    { 0x0053, 4, YES, "Back" },
    { 0x0056, 5, YES, "Forward" },
    { 0x00C3, 6, YES, "Gesture button" },       /// Thumb button on MX Master (older firmware)
    { 0x00D0, 6, YES, "Gesture button" },       /// Thumb button on MX Master (newer firmware)
    { 0x00C4, 7, NO,  "Mode shift button" },    /// "Smart Shift" button behind the wheel on MX Anywhere / MX Master. Off by default because diverting it disables the ratchet / free-spin toggle in the firmware.
    { 0x00ED, 8, NO,  "DPI button" },           /// Logi Lift, gaming mice
    { 0x00FD, 8, NO,  "DPI button" },
    { 0x0052, 3, NO,  "Middle button" },        /// Works natively, listed for completeness
    { 0x005B, 9, NO,  "Tilt left" },            /// Diverting the tilt wheel turns it into buttons and disables horizontal scrolling on it
    { 0x005D, 10, NO, "Tilt right" },
};

static BOOL isReceiverPID(uint16_t pid) {
    /// Unifying: C52B, C532, C534. Bolt: C548, C547.
    return pid == 0xC52B || pid == 0xC532 || pid == 0xC534 || pid == 0xC548 || pid == 0xC547;
}

static const MFLogiControlPolicy *policyForCID(uint16_t cid) {
    for (size_t i = 0; i < sizeof(kDefaultPolicy) / sizeof(kDefaultPolicy[0]); i++) {
        if (kDefaultPolicy[i].cid == cid) return &kDefaultPolicy[i];
    }
    return NULL;
}

#pragma mark - State objects

/// One HID++ device: a mouse connected directly (index 0xFF), or one slot of a receiver.
@interface MFLogiTarget : NSObject
@property (nonatomic) uint8_t deviceIndex;
@property (nonatomic) uint8_t reprogFeatureIndex;       /// Feature index of 0x1B04 on this device. 0 = not probed / unsupported.
@property (nonatomic) uint8_t wirelessFeatureIndex;     /// Feature index of 0x1D4B. 0 = none.
@property (nonatomic) NSString *name;
@property (nonatomic) NSMutableDictionary<NSNumber *, NSNumber *> *buttonForCID;   /// Diverted control ID -> MMF button number
@property (nonatomic) NSMutableArray<NSNumber *> *pressedCIDs;                     /// Control IDs the mouse currently reports as held
@property (nonatomic) uint64_t senderID;                                            /// Registry entry ID stamped onto the events we post
@end
@implementation MFLogiTarget
- (instancetype)init {
    self = [super init];
    if (self) {
        _buttonForCID = [NSMutableDictionary dictionary];
        _pressedCIDs = [NSMutableArray array];
    }
    return self;
}
@end

/// One HID++ capable IOHIDDevice (the vendor collection of a mouse, or of a receiver).
@interface MFLogiInterface : NSObject {
    @public uint8_t _reportBuffer[64];
}
@property (nonatomic) IOHIDDeviceRef device;
@property (nonatomic) NSString *name;
@property (nonatomic) uint16_t productID;
@property (nonatomic) BOOL isReceiver;
@property (nonatomic) BOOL isOpen;
@property (nonatomic) NSMutableArray<MFLogiTarget *> *targets;
/// Pending request
@property (nonatomic) BOOL waiting;
@property (nonatomic) BOOL gotResponse;
@property (nonatomic) uint8_t pendingDeviceIndex;
@property (nonatomic) uint8_t pendingFeatureIndex;
@property (nonatomic) uint8_t pendingFunction;
@property (nonatomic) NSMutableData *response;
@end
@implementation MFLogiInterface
- (instancetype)init {
    self = [super init];
    if (self) {
        _targets = [NSMutableArray array];
        _response = [NSMutableData dataWithLength:kHIDPPLongLength];
    }
    return self;
}
- (MFLogiTarget *)targetForDeviceIndex:(uint8_t)index {
    for (MFLogiTarget *t in _targets) if (t.deviceIndex == index) return t;
    return nil;
}
- (uint8_t *)responseBytes { return (uint8_t *)_response.mutableBytes; }
@end

#pragma mark - Diverter

@interface LogitechButtonDiverter ()
@property (nonatomic) NSMutableArray<MFLogiInterface *> *interfaces;
@property (nonatomic) NSMutableArray<dispatch_block_t> *workQueue;
@property (nonatomic) BOOL isDraining;
@property (nonatomic) IOHIDManagerRef manager;
@property (nonatomic) NSLock *interfacesLock;
@end

static LogitechButtonDiverter *_shared = nil;
static NSThread *_thread = nil;
static CFRunLoopRef _runLoop = NULL;
static NSCondition *_threadReady = nil;

@implementation LogitechButtonDiverter

#pragma mark Public

+ (void)load_Manual {
    if (_shared != nil) return;
    _shared = [[LogitechButtonDiverter alloc] init];
    [_shared startThread];
    [_shared enqueue:^{ [_shared setUpManager]; }];
    [_shared observeSystemWake];
    DDLogInfo("LogitechButtonDiverter: started");
}

+ (void)restoreNativeBehavior {
    if (_shared == nil) return;
    [_shared restoreAllWithoutWaiting];
}

#pragma mark Init

- (instancetype)init {
    self = [super init];
    if (self) {
        _interfaces = [NSMutableArray array];
        _workQueue = [NSMutableArray array];
        _interfacesLock = [[NSLock alloc] init];
    }
    return self;
}

#pragma mark Thread & work queue

- (void)startThread {
    _threadReady = [[NSCondition alloc] init];
    [_threadReady lock];
    _thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadMain) object:nil];
    _thread.name = @"com.nuebling.mac-mouse-fix.logitech-hidpp";
    _thread.qualityOfService = NSQualityOfServiceUserInteractive;
    [_thread start];
    while (_runLoop == NULL) {
        [_threadReady waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    [_threadReady unlock];
}

- (void)threadMain {
    @autoreleasepool {
        /// Keep the run loop alive even when nothing is scheduled yet
        CFRunLoopSourceContext ctx = {0};
        CFRunLoopSourceRef emptySource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &ctx);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), emptySource, kCFRunLoopCommonModes);

        /// Periodic verification
        CFRunLoopTimerRef timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + kVerifyInterval, kVerifyInterval, 0, 0, ^(CFRunLoopTimerRef t) {
            [self enqueue:^{ [self verifyAll:NO]; }];
        });
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopCommonModes);

        [_threadReady lock];
        _runLoop = CFRunLoopGetCurrent();
        [_threadReady signal];
        [_threadReady unlock];
    }
    while (true) {
        @autoreleasepool { CFRunLoopRun(); }
    }
}

/// Everything that talks HID++ runs through this queue, one job at a time, on the HID++ thread.
///     Requests spin the run loop while waiting for the mouse to answer. Callbacks that fire during that wait only *enqueue*
///     work, so two request sequences can never interleave.
- (void)enqueue:(dispatch_block_t)block {
    @synchronized (_workQueue) { [_workQueue addObject:[block copy]]; }
    CFRunLoopPerformBlock(_runLoop, kCFRunLoopCommonModes, ^{ [self drain]; });
    CFRunLoopWakeUp(_runLoop);
}

- (void)drain {
    if (_isDraining) return;    /// We're inside a request's wait loop. The outer drain will pick the new job up.
    _isDraining = YES;
    while (true) {
        dispatch_block_t job = nil;
        @synchronized (_workQueue) {
            if (_workQueue.count > 0) { job = _workQueue.firstObject; [_workQueue removeObjectAtIndex:0]; }
        }
        if (job == nil) break;
        @autoreleasepool { job(); }
    }
    _isDraining = NO;
}

- (void)enqueueAfterDelay:(NSTimeInterval)delay block:(dispatch_block_t)block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self enqueue:block];
    });
}

#pragma mark IOHIDManager

static void interfaceMatched(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    LogitechButtonDiverter *self = (__bridge LogitechButtonDiverter *)context;
    CFRetain(device);
    [self enqueue:^{ [self handleInterfaceMatched:device]; CFRelease(device); }];
}

static void interfaceRemoved(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    LogitechButtonDiverter *self = (__bridge LogitechButtonDiverter *)context;
    CFRetain(device);
    [self enqueue:^{ [self handleInterfaceRemoved:device]; CFRelease(device); }];
}

- (void)setUpManager {
    _manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
    NSArray *matching = @[
        /// Bluetooth (LE): the mouse itself carries a HID++ collection next to its mouse collection
        @{ @kIOHIDVendorIDKey: @(kLogiVendorID), @kIOHIDDeviceUsagePageKey: @0xFF43, @kIOHIDDeviceUsageKey: @0x0202 },
        /// USB cable, Bolt and Unifying receivers: HID++ lives on a separate vendor interface
        @{ @kIOHIDVendorIDKey: @(kLogiVendorID), @kIOHIDDeviceUsagePageKey: @0xFF00, @kIOHIDDeviceUsageKey: @0x0001 },
        @{ @kIOHIDVendorIDKey: @(kLogiVendorID), @kIOHIDDeviceUsagePageKey: @0xFF00, @kIOHIDDeviceUsageKey: @0x0002 },
    ];
    IOHIDManagerSetDeviceMatchingMultiple(_manager, (__bridge CFArrayRef)matching);
    IOHIDManagerRegisterDeviceMatchingCallback(_manager, interfaceMatched, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_manager, interfaceRemoved, (__bridge void *)self);
    IOHIDManagerScheduleWithRunLoop(_manager, _runLoop, kCFRunLoopDefaultMode);
    IOReturn r = IOHIDManagerOpen(_manager, kIOHIDOptionsTypeNone);
    if (r != kIOReturnSuccess) {
        DDLogError("LogitechButtonDiverter: IOHIDManagerOpen failed: 0x%x", r);
    }
}

- (MFLogiInterface *)interfaceForDevice:(IOHIDDeviceRef)device {
    NSNumber *uid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDUniqueIDKey));
    for (MFLogiInterface *iface in _interfaces) {
        if (iface.device == device) return iface;
        NSNumber *otherUID = (__bridge NSNumber *)IOHIDDeviceGetProperty(iface.device, CFSTR(kIOHIDUniqueIDKey));
        if (uid != nil && [uid isEqual:otherUID]) return iface;
    }
    return nil;
}

static void inputReportCallback(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *report, CFIndex length);

- (void)handleInterfaceMatched:(IOHIDDeviceRef)device {

    if ([self interfaceForDevice:device] != nil) return;

    MFLogiInterface *iface = [[MFLogiInterface alloc] init];
    iface.device = (IOHIDDeviceRef)CFRetain(device);
    iface.name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey)) ?: @"Logitech device";
    iface.productID = ((__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey))).unsignedShortValue;
    iface.isReceiver = isReceiverPID(iface.productID);

    IOReturn r = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    if (r != kIOReturnSuccess) {
        DDLogError("LogitechButtonDiverter: Couldn't open HID++ interface of '%{public}@': 0x%x", iface.name, r);
        CFRelease(device);
        return;
    }
    iface.isOpen = YES;
    IOHIDDeviceRegisterInputReportCallback(device, iface->_reportBuffer, sizeof(iface->_reportBuffer), inputReportCallback, (__bridge void *)iface);
    IOHIDDeviceScheduleWithRunLoop(device, _runLoop, kCFRunLoopDefaultMode);

    [_interfacesLock lock];
    [_interfaces addObject:iface];
    [_interfacesLock unlock];

    DDLogInfo("LogitechButtonDiverter: Found HID++ interface '%{public}@' (pid 0x%04x, %{public}@)", iface.name, iface.productID, iface.isReceiver ? @"receiver" : @"direct");

    if (iface.isReceiver) {
        for (uint8_t slot = 1; slot <= kHIDPPMaxReceiverSlots; slot++) {
            MFLogiTarget *t = [[MFLogiTarget alloc] init];
            t.deviceIndex = slot;
            t.name = [NSString stringWithFormat:@"%@ slot %d", iface.name, slot];
            t.senderID = [self senderIDForReceiverInterface:iface];
            [iface.targets addObject:t];
            [self activateTarget:t on:iface quietly:YES];
        }
    } else {
        MFLogiTarget *t = [[MFLogiTarget alloc] init];
        t.deviceIndex = kHIDPPDeviceIndexDirect;
        t.name = iface.name;
        t.senderID = registryIDOfDevice(device);
        [iface.targets addObject:t];
        [self activateTarget:t on:iface quietly:NO];
    }
}

- (void)handleInterfaceRemoved:(IOHIDDeviceRef)device {
    MFLogiInterface *iface = [self interfaceForDevice:device];
    if (iface == nil) return;
    for (MFLogiTarget *t in iface.targets) [self releaseAllPressedOn:t];
    [self closeInterface:iface];
    [_interfacesLock lock];
    [_interfaces removeObject:iface];
    [_interfacesLock unlock];
    CFRelease(iface.device);
    iface.device = NULL;
    DDLogInfo("LogitechButtonDiverter: HID++ interface '%{public}@' went away", iface.name);
}

- (void)closeInterface:(MFLogiInterface *)iface {
    if (!iface.isOpen) return;
    IOHIDDeviceRegisterInputReportCallback(iface.device, iface->_reportBuffer, sizeof(iface->_reportBuffer), NULL, NULL);
    IOHIDDeviceUnscheduleFromRunLoop(iface.device, _runLoop, kCFRunLoopDefaultMode);
    IOHIDDeviceClose(iface.device, kIOHIDOptionsTypeNone);
    iface.isOpen = NO;
}

#pragma mark Sender ID

/// MMF identifies the mouse behind a CGEvent through the IORegistry entry ID stored in the event (see `CGEventGetSendingDevice()`).
/// We stamp the same ID onto the events we post, so they're attributed to the real mouse instead of to a "strange device".
static uint64_t registryIDOfDevice(IOHIDDeviceRef device) {
    io_service_t service = IOHIDDeviceGetService(device);
    if (service == MACH_PORT_NULL) return 0;
    uint64_t entryID = 0;
    if (IORegistryEntryGetRegistryEntryID(service, &entryID) != KERN_SUCCESS) return 0;
    return entryID;
}

- (uint64_t)senderIDForReceiverInterface:(MFLogiInterface *)iface {
    /// A receiver's mouse events come from its mouse interface, which DeviceManager knows about. Pick the attached device with the same product ID.
    ///     DeviceManager's list is mutated on the main thread, so read it there.
    __block uint64_t result = 0;
    dispatch_sync(dispatch_get_main_queue(), ^{
        for (Device *d in DeviceManager.attachedDevices) {
            IOHIDDeviceRef mouse = d.iohidDevice;
            if (mouse == NULL) continue;
            NSNumber *pid = (__bridge NSNumber *)IOHIDDeviceGetProperty(mouse, CFSTR(kIOHIDProductIDKey));
            if (pid.unsignedShortValue == iface.productID) { result = registryIDOfDevice(mouse); break; }
        }
    });
    return result;
}

#pragma mark HID++ requests

/// Sends one HID++ 2.0 request and waits for the answer.
///     Must run on the HID++ thread (from the work queue).
///     Returns 0 on success (answer in `iface.responseBytes`), 1 when the mouse answered with a HID++ error (code in byte 6), -1 on transport failure or timeout.
- (int)request:(MFLogiInterface *)iface deviceIndex:(uint8_t)deviceIndex feature:(uint8_t)feature function:(uint8_t)function params:(const uint8_t *)params length:(int)paramsLength {

    assert(NSThread.currentThread == _thread);
    if (!iface.isOpen) return -1;

    uint8_t packet[kHIDPPLongLength] = {0};
    packet[0] = kHIDPPReportLong;
    packet[1] = deviceIndex;
    packet[2] = feature;
    packet[3] = (uint8_t)((function << 4) | kHIDPPSoftwareID);
    if (params != NULL && paramsLength > 0) memcpy(packet + 4, params, MIN(paramsLength, kHIDPPLongLength - 4));

    iface.gotResponse = NO;
    iface.waiting = YES;
    iface.pendingDeviceIndex = deviceIndex;
    iface.pendingFeatureIndex = feature;
    iface.pendingFunction = function;

    IOReturn r = IOHIDDeviceSetReport(iface.device, kIOHIDReportTypeOutput, kHIDPPReportLong, packet, sizeof(packet));
    if (r != kIOReturnSuccess) {
        iface.waiting = NO;
        DDLogDebug("LogitechButtonDiverter: SetReport to '%{public}@' failed: 0x%x", iface.name, r);
        return -1;
    }

    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + kHIDPPResponseTimeout;
    while (!iface.gotResponse && CFAbsoluteTimeGetCurrent() < deadline) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.005, true);
    }
    iface.waiting = NO;

    if (!iface.gotResponse) return -1;
    if (iface.responseBytes[2] == kHIDPPErrorFeatureIndex) return 1;
    return 0;
}

/// Convenience: Root.getFeature(featureID) -> feature index, or 0 if the device doesn't have it / didn't answer.
- (uint8_t)featureIndexOf:(uint16_t)featureID on:(MFLogiInterface *)iface deviceIndex:(uint8_t)deviceIndex didRespond:(BOOL *)didRespond {
    uint8_t p[2] = { (uint8_t)(featureID >> 8), (uint8_t)(featureID & 0xFF) };
    int r = [self request:iface deviceIndex:deviceIndex feature:0x00 function:0x00 params:p length:2];
    if (didRespond) *didRespond = (r != -1);
    if (r != 0) return 0;
    return iface.responseBytes[4];
}

#pragma mark Diverting

/// The control IDs we want to divert, in priority order, together with their button numbers.
- (NSArray<NSNumber *> *)wantedCIDs {
    __block NSObject *override = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{ override = config(@"General.logitechDivertedControls"); });
    if ([override isKindOfClass:NSArray.class]) {
        NSMutableArray *result = [NSMutableArray array];
        for (NSObject *o in (NSArray *)override) if ([o isKindOfClass:NSNumber.class]) [result addObject:o];
        return result;
    }
    NSMutableArray *result = [NSMutableArray array];
    for (size_t i = 0; i < sizeof(kDefaultPolicy) / sizeof(kDefaultPolicy[0]); i++) {
        if (kDefaultPolicy[i].defaultOn) [result addObject:@(kDefaultPolicy[i].cid)];
    }
    return result;
}

- (int)buttonForCID:(uint16_t)cid alreadyAssigned:(NSDictionary<NSNumber *, NSNumber *> *)assigned {
    const MFLogiControlPolicy *p = policyForCID(cid);
    if (p != NULL) return p->button;
    /// Unknown control from the config override: hand out the next free number from 8 upwards
    int candidate = 8;
    while ([assigned.allValues containsObject:@(candidate)] && candidate < kMFMaxButtonNumber) candidate++;
    return candidate;
}

/// Probes the device behind `target` and diverts the wanted controls. `quietly` suppresses logging when nothing is there (empty receiver slots).
- (void)activateTarget:(MFLogiTarget *)target on:(MFLogiInterface *)iface quietly:(BOOL)quietly {

    /// Reset
    [self releaseAllPressedOn:target];
    [target.buttonForCID removeAllObjects];
    target.reprogFeatureIndex = 0;
    target.wirelessFeatureIndex = 0;

    /// Find features
    BOOL responded = NO;
    uint8_t reprog = [self featureIndexOf:kHIDPPFeatureReprogControlsV4 on:iface deviceIndex:target.deviceIndex didRespond:&responded];
    if (!responded) {
        if (!quietly) DDLogInfo("LogitechButtonDiverter: '%{public}@' didn't answer the HID++ probe", target.name);
        return;
    }
    if (reprog == 0) {
        if (!quietly) DDLogInfo("LogitechButtonDiverter: '%{public}@' has no ReprogControlsV4 (0x1B04) feature – nothing to do", target.name);
        return;
    }
    target.reprogFeatureIndex = reprog;
    target.wirelessFeatureIndex = [self featureIndexOf:kHIDPPFeatureWirelessStatus on:iface deviceIndex:target.deviceIndex didRespond:NULL];

    /// Enumerate controls
    ///     getCount (fn 0) -> count. getCidInfo (fn 1, index) -> cid[2], tid[2], flags, pos, group, gmask, additionalFlags
    if ([self request:iface deviceIndex:target.deviceIndex feature:reprog function:0x00 params:NULL length:0] != 0) return;
    int count = iface.responseBytes[4];
    NSMutableDictionary<NSNumber *, NSNumber *> *flagsForCID = [NSMutableDictionary dictionary];
    for (int i = 0; i < count; i++) {
        uint8_t p = (uint8_t)i;
        if ([self request:iface deviceIndex:target.deviceIndex feature:reprog function:0x01 params:&p length:1] != 0) continue;
        uint16_t cid = (uint16_t)((iface.responseBytes[4] << 8) | iface.responseBytes[5]);
        flagsForCID[@(cid)] = @(iface.responseBytes[8]);
    }

    /// Divert
    NSMutableArray<NSString *> *diverted = [NSMutableArray array];
    NSMutableArray<NSString *> *skipped = [NSMutableArray array];
    for (NSNumber *cidNum in [self wantedCIDs]) {
        uint16_t cid = cidNum.unsignedShortValue;
        NSNumber *flags = flagsForCID[cidNum];
        if (flags == nil) continue;    /// This mouse doesn't have the control
        const MFLogiControlPolicy *policy = policyForCID(cid);
        NSString *cidName = policy ? @(policy->name) : [NSString stringWithFormat:@"control 0x%04X", cid];
        if (!(flags.unsignedCharValue & kCIDInfoFlagDivertable)) {
            [skipped addObject:[NSString stringWithFormat:@"%@ (not divertable)", cidName]];
            continue;
        }
        if ([self setDivert:YES cid:cid on:iface target:target]) {
            int button = [self buttonForCID:cid alreadyAssigned:target.buttonForCID];
            target.buttonForCID[cidNum] = @(button);
            [diverted addObject:[NSString stringWithFormat:@"%@ (0x%04X) -> Button %d", cidName, cid, button]];
        } else {
            [skipped addObject:[NSString stringWithFormat:@"%@ (mouse refused)", cidName]];
        }
    }

    DDLogInfo("LogitechButtonDiverter: '%{public}@': diverted %{public}@%{public}@", target.name,
              diverted.count ? [diverted componentsJoinedByString:@", "] : @"nothing",
              skipped.count ? [NSString stringWithFormat:@". Skipped: %@", [skipped componentsJoinedByString:@", "]] : @"");
}

/// setCidReporting (fn 3): cid[2], flags, remap[2]. The mouse echoes the request on success.
- (BOOL)setDivert:(BOOL)divert cid:(uint16_t)cid on:(MFLogiInterface *)iface target:(MFLogiTarget *)target {
    uint8_t p[5] = { (uint8_t)(cid >> 8), (uint8_t)(cid & 0xFF), (uint8_t)(kCIDReportingDivertValid | (divert ? kCIDReportingDivert : 0)), 0, 0 };
    return [self request:iface deviceIndex:target.deviceIndex feature:target.reprogFeatureIndex function:0x03 params:p length:5] == 0;
}

/// getCidReporting (fn 2): cid[2] -> cid[2], flags, remap[2]. Returns -1 if the mouse didn't answer, else the divert bit.
- (int)isDivertedCID:(uint16_t)cid on:(MFLogiInterface *)iface target:(MFLogiTarget *)target {
    uint8_t p[2] = { (uint8_t)(cid >> 8), (uint8_t)(cid & 0xFF) };
    int r = [self request:iface deviceIndex:target.deviceIndex feature:target.reprogFeatureIndex function:0x02 params:p length:2];
    if (r != 0) return -1;
    return (iface.responseBytes[6] & kCIDReportingDivert) ? 1 : 0;
}

/// Re-check every diverted target. Cheap: one query per mouse. Only re-diverts when the mouse forgot.
- (void)verifyAll:(BOOL)force {
    for (MFLogiInterface *iface in [_interfaces copy]) {
        for (MFLogiTarget *t in iface.targets) {
            if (t.reprogFeatureIndex == 0) {
                /// Never worked or wasn't there (e.g. empty receiver slot / mouse was asleep during the probe). Try again on receivers and after wake.
                if (force || iface.isReceiver) [self activateTarget:t on:iface quietly:YES];
                continue;
            }
            if (t.buttonForCID.count == 0) continue;
            uint16_t firstCID = t.buttonForCID.allKeys.firstObject.unsignedShortValue;
            int state = force ? 0 : [self isDivertedCID:firstCID on:iface target:t];
            if (state == 1) continue;                     /// Still diverted
            if (state == -1 && !force) continue;          /// Mouse asleep / unreachable. It'll tell us when it's back (0x1D4B), or we'll catch it next time.
            DDLogInfo("LogitechButtonDiverter: '%{public}@' lost its diversion – re-diverting", t.name);
            [self activateTarget:t on:iface quietly:NO];
        }
    }
}

- (void)restoreAllWithoutWaiting {
    /// Fire-and-forget setCidReporting(divert = 0) for everything we diverted. Used on exit, where we can't wait for answers.
    [_interfacesLock lock];
    NSArray *interfaces = [_interfaces copy];
    [_interfacesLock unlock];
    for (MFLogiInterface *iface in interfaces) {
        if (!iface.isOpen) continue;
        for (MFLogiTarget *t in iface.targets) {
            if (t.reprogFeatureIndex == 0) continue;
            for (NSNumber *cidNum in t.buttonForCID.allKeys) {
                uint16_t cid = cidNum.unsignedShortValue;
                uint8_t packet[kHIDPPLongLength] = {0};
                packet[0] = kHIDPPReportLong;
                packet[1] = t.deviceIndex;
                packet[2] = t.reprogFeatureIndex;
                packet[3] = (uint8_t)((0x03 << 4) | kHIDPPSoftwareID);
                packet[4] = (uint8_t)(cid >> 8);
                packet[5] = (uint8_t)(cid & 0xFF);
                packet[6] = kCIDReportingDivertValid;   /// divert = 0
                IOHIDDeviceSetReport(iface.device, kIOHIDReportTypeOutput, kHIDPPReportLong, packet, sizeof(packet));
            }
            [t.buttonForCID removeAllObjects];
        }
    }
    NSLog(@"LogitechButtonDiverter: restored native button behaviour on %lu interface(s)", (unsigned long)interfaces.count);
}

#pragma mark Input reports

static void inputReportCallback(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *report, CFIndex length) {

    if (result != kIOReturnSuccess || length < 4) return;
    if (reportID != kHIDPPReportLong && reportID != kHIDPPReportShort) return;      /// Mouse reports etc. share the Bluetooth interface

    MFLogiInterface *iface = (__bridge MFLogiInterface *)context;

    /// macOS puts the report ID into the first byte. Be defensive in case that ever changes.
    uint8_t r[kHIDPPLongLength] = {0};
    CFIndex n;
    if (report[0] == reportID) { n = MIN(length, (CFIndex)sizeof(r)); memcpy(r, report, n); }
    else { r[0] = (uint8_t)reportID; n = MIN(length + 1, (CFIndex)sizeof(r)); memcpy(r + 1, report, n - 1); }
    if (n < 5) return;

    uint8_t deviceIndex = r[1], featureIndex = r[2], function = r[3] >> 4, softwareID = r[3] & 0x0F;

    /// Response to our pending request?
    if (iface.waiting && deviceIndex == iface.pendingDeviceIndex) {
        BOOL isReply = (featureIndex == iface.pendingFeatureIndex && function == iface.pendingFunction && softwareID == kHIDPPSoftwareID);
        BOOL isError = (featureIndex == kHIDPPErrorFeatureIndex && r[4] == iface.pendingFeatureIndex && (r[5] >> 4) == iface.pendingFunction && (r[5] & 0x0F) == kHIDPPSoftwareID);
        if (isReply || isError) {
            memcpy(iface.responseBytes, r, sizeof(r));
            iface.gotResponse = YES;
            return;
        }
    }

    /// HID++ 1.0 receiver notification: a device (re)connected to a slot
    if (iface.isReceiver && featureIndex == kHIDPP1NotificationDeviceConnection) {
        BOOL linkEstablished = !(r[4] & 0x40);
        MFLogiTarget *t = [iface targetForDeviceIndex:deviceIndex];
        if (linkEstablished && t != nil) {
            [_shared enqueueAfterDelay:0.5 block:^{ [_shared activateTarget:t on:iface quietly:YES]; }];
        }
        return;
    }

    /// HID++ 2.0 notifications carry software ID 0
    if (softwareID != 0) return;
    MFLogiTarget *t = [iface targetForDeviceIndex:deviceIndex];
    if (t == nil || t.reprogFeatureIndex == 0) return;

    if (featureIndex == t.reprogFeatureIndex && function == 0x00) {
        /// divertedButtonsEvent: up to four control IDs that are currently held
        [_shared handleDivertedButtons:r length:n target:t];
    } else if (t.wirelessFeatureIndex != 0 && featureIndex == t.wirelessFeatureIndex && function == 0x00) {
        /// WirelessDeviceStatus: the mouse (re)connected and forgot its temporary settings
        DDLogInfo("LogitechButtonDiverter: '%{public}@' reconnected – re-diverting", t.name);
        [_shared enqueueAfterDelay:0.3 block:^{ [_shared activateTarget:t on:iface quietly:NO]; }];
    }
}

- (void)handleDivertedButtons:(const uint8_t *)r length:(CFIndex)n target:(MFLogiTarget *)target {

    NSMutableArray<NSNumber *> *nowPressed = [NSMutableArray array];
    for (CFIndex offset = 4; offset + 1 < n && offset < 12; offset += 2) {
        uint16_t cid = (uint16_t)((r[offset] << 8) | r[offset + 1]);
        if (cid != 0) [nowPressed addObject:@(cid)];
    }

    /// Releases first, then presses
    for (NSNumber *cid in target.pressedCIDs) {
        if (![nowPressed containsObject:cid]) [self postCID:cid down:NO target:target];
    }
    for (NSNumber *cid in nowPressed) {
        if (![target.pressedCIDs containsObject:cid]) [self postCID:cid down:YES target:target];
    }
    target.pressedCIDs = nowPressed;
}

- (void)releaseAllPressedOn:(MFLogiTarget *)target {
    for (NSNumber *cid in target.pressedCIDs) [self postCID:cid down:NO target:target];
    [target.pressedCIDs removeAllObjects];
}

- (void)postCID:(NSNumber *)cid down:(BOOL)down target:(MFLogiTarget *)target {
    NSNumber *button = target.buttonForCID[cid];
    if (button == nil) return;   /// Diverted by someone else (e.g. Logi Options+) – not ours
    postButtonEvent(button.intValue, down, target.senderID);
}

/// Posts a regular button event at the HID level, so it takes the same path as a button event from the mouse itself.
static void postButtonEvent(int button, BOOL down, uint64_t senderID) {
    CGEventRef locationEvent = CGEventCreate(NULL);
    CGPoint location = CGEventGetLocation(locationEvent);
    CFRelease(locationEvent);

    CGEventRef event = CGEventCreateMouseEvent(NULL, down ? kCGEventOtherMouseDown : kCGEventOtherMouseUp, location, (CGMouseButton)(button - 1));
    if (event == NULL) return;
    CGEventSetTimestamp(event, mach_absolute_time());
    if (senderID != 0) {
        int64_t field;
        memcpy(&field, &senderID, sizeof(field));
        CGEventSetIntegerValueField(event, (CGEventField)kMFCGEventFieldSenderID, field);
    }
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

#pragma mark System wake

- (void)observeSystemWake {
    [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceDidWakeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self enqueueAfterDelay:3.0 block:^{ [self verifyAll:YES]; }];
    }];
}

@end
