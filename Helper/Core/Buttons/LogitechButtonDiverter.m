// Derived from lcandy2's MMF PR #1995, commit a874b40130ba0ab9bbea9e3eab57b5fa5de12f34.
// IOHID transport and request queue adapted under the unchanged MMF License.
// See docs/MX-Master-3-Bluetooth.md for attribution, scope and safe testing.
#import "LogitechButtonDiverter.h"
#import <IOKit/hid/IOHIDLib.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>
#import "Constants.h"
#import "Config.h"
#import "Logging.h"
#import "LogitechHIDPPState.h"

#pragma mark - Constants

/// HID++ transport
#define kHIDPPReportShort               0x10
#define kHIDPPReportLong                0x11
#define kHIDPPLongLength                20      /// Report ID + 19 bytes (macOS hands us / expects the report ID byte in the buffer)
#define kHIDPPDeviceIndexDirect         0xFF    /// Direct Bluetooth device index.

#define kHIDPPErrorFeatureIndex         0xFF
#define kHIDPPResponseTimeout           0.6     /// Seconds. A Bluetooth round trip takes ~15-40 ms.

/// HID++ 2.0 features
#define kHIDPPFeatureWirelessStatus     0x1D4B
#define kHIDPPFeatureReprogControlsV4   0x1B04

/// 0x1B04 getCidInfo flags byte
#define kCIDInfoFlagDivertable          0x20
/// 0x1B04 setCidReporting / getCidReporting flags byte
#define kCIDReportingDivert             0x01
#define kCIDReportingDivertValid        0x02

#define kVerifyInterval                 30.0    /// Seconds between checks that the diversion is still active.

/// Which physical controls we divert and which Mac Mouse Fix button they become.
///     Button numbers use MMF's 1-based numbering (1 = left, 2 = right, 3 = middle, 4 = back, 5 = forward).
typedef struct {
    uint16_t cid;
    int button;
} MFLogiControlPolicy;

static const MFLogiControlPolicy kDefaultPolicy[] = {
    { 0x00C3, 6 },
    { 0x00D0, 6 },
    { 0x00C4, 7 },
};
static BOOL _modeShiftRequestedAtStartup;

static const MFLogiControlPolicy *policyForCID(uint16_t cid) {
    for (size_t i = 0; i < sizeof(kDefaultPolicy) / sizeof(kDefaultPolicy[0]); i++) {
        if (kDefaultPolicy[i].cid == cid) return &kDefaultPolicy[i];
    }
    return NULL;
}

#pragma mark - State objects

/// A directly connected Bluetooth MX Master 3 (device index 0xFF).
@interface MFLogiTarget : NSObject
@property (nonatomic) uint8_t deviceIndex;
@property (nonatomic) uint8_t reprogFeatureIndex;       /// Feature index of 0x1B04 on this device. 0 = not probed / unsupported.
@property (nonatomic) uint8_t wirelessFeatureIndex;     /// Feature index of 0x1D4B. 0 = none.
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *buttonForCID;   /// Diverted control ID -> MMF button number
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSData *> *originalReporting;
@property (nonatomic, strong) NSDictionary<NSNumber *, NSNumber *> *flagsForCID;
@property (nonatomic) uint8_t pressedMask; /// Thumb=1, mode shift=2
@property (nonatomic) uint64_t senderID;                                            /// Registry entry ID stamped onto the events we post
@end
@implementation MFLogiTarget
- (instancetype)init {
    self = [super init];
    if (self) {
        _buttonForCID = [NSMutableDictionary dictionary];
        _originalReporting = [NSMutableDictionary dictionary];

    }
    return self;
}
@end

/// The vendor collection of a directly connected Bluetooth mouse.
@interface MFLogiInterface : NSObject {
    @public uint8_t _reportBuffer[64];
}
@property (nonatomic) IOHIDDeviceRef device;
@property (nonatomic, strong) NSString *name;
@property (nonatomic) uint16_t productID;

@property (nonatomic) BOOL isOpen;
@property (nonatomic, strong) NSMutableArray<MFLogiTarget *> *targets;
/// Pending request
@property (nonatomic) BOOL waiting;
@property (nonatomic) BOOL gotResponse;
@property (nonatomic) uint8_t pendingDeviceIndex;
@property (nonatomic) uint8_t pendingFeatureIndex;
@property (nonatomic) uint8_t pendingFunction;
@property (nonatomic) uint8_t softwareID;
@property (nonatomic, strong) NSMutableData *response;
@property (nonatomic) size_t responseLength;
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
@property (nonatomic, strong) NSMutableArray<MFLogiInterface *> *interfaces;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *workQueue;
@property (nonatomic) BOOL isDraining;
@property (nonatomic) IOHIDManagerRef manager;
@property (nonatomic) BOOL stopped;
@property (atomic) BOOL shutdownRequested;
@property (nonatomic) BOOL restoring;
@property (nonatomic) BOOL modeShiftRequested;
@end

static LogitechButtonDiverter *_shared = nil;
static NSThread *_thread = nil;
static CFRunLoopRef _runLoop = NULL;
static NSCondition *_threadReady = nil;

@implementation LogitechButtonDiverter

#pragma mark Public

+ (void)scheduleStartOnRunLoop:(CFRunLoopRef)runLoop {
    CFRunLoopPerformBlock(runLoop, kCFRunLoopDefaultMode, ^{ [self load_Manual]; });
    CFRunLoopWakeUp(runLoop);
}

+ (void)load_Manual {
    @synchronized (self) {
        if (_shared != nil) return;
        // Config is read only at startup on MMF's owning event-tap run loop.
        // No protocol traffic or hardware changes until explicitly opted in.
        if (![(NSNumber *)config(@"General.logitechMXMaster3SpecialButtons") boolValue]) return;
        _shared = [[LogitechButtonDiverter alloc] init];
        _shared.modeShiftRequested = _modeShiftRequestedAtStartup;
        [_shared startThread];
        [_shared enqueue:^{ [_shared setUpManager]; }];
        [_shared observeSystemWake];
        DDLogInfo("LogitechButtonDiverter: started");
    }
}

// Inspect only button trigger keys and button modifier preconditions in the
// effective remap dictionary. Add mode supplies temporary mappings for all buttons.
+ (void)updateRemaps:(NSDictionary *)remaps {
    BOOL wanted = NO;
    for (NSDictionary *precondition in remaps) {
        NSDictionary *effects = remaps[precondition];
        if ([effects[@7] count] > 0) wanted = YES;
        for (NSDictionary *button in precondition[@"buttonModifiers"]) {
            if ([button[@"button"] isEqual:@7] && effects.count > 0) wanted = YES;
        }
    }
    @synchronized (self) {
        _modeShiftRequestedAtStartup = wanted;
        if (_shared == nil) return; // Config initializes before the HID worker.
        [_shared enqueue:^{
            if (_shared.stopped || _shared.shutdownRequested) return;
            _shared.modeShiftRequested = wanted;
            for (MFLogiInterface *iface in _shared.interfaces) {
                for (MFLogiTarget *target in iface.targets) [_shared reconcileTarget:target on:iface];
            }
        }];
    }
}

+ (void)restoreNativeBehavior {
    @synchronized (self) {
        if (_shared == nil) return;
        _shared.shutdownRequested = YES;
    }
    if (NSThread.currentThread == _thread) {
        _shared.stopped = YES;
        [_shared restoreAllOnWorker];
        return;
    }
    NSCondition *done = [[NSCondition alloc] init];
    __block BOOL finished = NO;
    [done lock];
    [_shared enqueue:^{
        _shared.stopped = YES;
        [_shared restoreAllOnWorker];
        [done lock]; finished = YES; [done signal]; [done unlock];
    }];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:4.0];
    while (!finished && [done waitUntilDate:deadline]) {}
    if (!finished) NSLog(@"Logitech cleanup timed out; power-cycle mouse before rollback");
    [done unlock];
}

#pragma mark Init

- (instancetype)init {
    self = [super init];
    if (self) {
        _interfaces = [NSMutableArray array];
        _workQueue = [NSMutableArray array];

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
        @{ @kIOHIDVendorIDKey: @0x046D, @kIOHIDProductIDKey: @0xB023,
           @kIOHIDDeviceUsagePageKey: @0xFF43, @kIOHIDDeviceUsageKey: @0x0202 },
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

    NSString *transport = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDTransportKey));
    if (_stopped || ![transport hasPrefix:@"Bluetooth"] || [self interfaceForDevice:device] != nil) return;

    MFLogiInterface *iface = [[MFLogiInterface alloc] init];
    iface.device = (IOHIDDeviceRef)CFRetain(device);
    iface.name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey)) ?: @"Logitech device";
    iface.productID = ((__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey))).unsignedShortValue;

    IOReturn r = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    if (r != kIOReturnSuccess) {
        DDLogError("LogitechButtonDiverter: Couldn't open HID++ interface of '%{public}@': 0x%x", iface.name, r);
        CFRelease(device);
        return;
    }
    iface.isOpen = YES;
    IOHIDDeviceRegisterInputReportCallback(device, iface->_reportBuffer, sizeof(iface->_reportBuffer), inputReportCallback, (__bridge void *)iface);
    IOHIDDeviceScheduleWithRunLoop(device, _runLoop, kCFRunLoopDefaultMode);

    [_interfaces addObject:iface];

    MFLogiTarget *t = [[MFLogiTarget alloc] init];
    t.deviceIndex = kHIDPPDeviceIndexDirect;
    t.name = iface.name;
    t.senderID = registryIDOfDevice(device);
    [iface.targets addObject:t];
    [self activateTarget:t on:iface quietly:NO];
}

- (void)handleInterfaceRemoved:(IOHIDDeviceRef)device {
    MFLogiInterface *iface = [self interfaceForDevice:device];
    if (iface == nil) return;
    for (MFLogiTarget *t in iface.targets) [self releaseAllPressedOn:t];
    [self closeInterface:iface];

    [_interfaces removeObject:iface];

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

#pragma mark HID++ requests

/// Sends one HID++ 2.0 request and waits for the answer.
///     Must run on the HID++ thread (from the work queue).
///     Returns 0 on success (answer in `iface.responseBytes`), 1 when the mouse answered with a HID++ error (code in byte 6), -1 on transport failure or timeout.
- (int)request:(MFLogiInterface *)iface deviceIndex:(uint8_t)deviceIndex feature:(uint8_t)feature function:(uint8_t)function params:(const uint8_t *)params length:(int)paramsLength {

    assert(NSThread.currentThread == _thread);
    if (!iface.isOpen || (_shutdownRequested && !_restoring)) return -1;

    uint8_t packet[kHIDPPLongLength] = {0};
    packet[0] = kHIDPPReportLong;
    packet[1] = deviceIndex;
    packet[2] = feature;
    iface.softwareID = iface.softwareID % 15 + 1;
    packet[3] = (uint8_t)((function << 4) | iface.softwareID);
    if (params != NULL && paramsLength > 0) memcpy(packet + 4, params, MIN(paramsLength, kHIDPPLongLength - 4));

    iface.gotResponse = NO;
    iface.responseLength = 0;
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
    while (!iface.gotResponse && CFAbsoluteTimeGetCurrent() < deadline && (!_shutdownRequested || _restoring)) {
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
    return _modeShiftRequested ? @[@0xD0, @0xC3, @0xC4] : @[@0xD0, @0xC3];
}

/// Probes the device behind `target` and diverts the wanted controls. `quietly` suppresses logging when nothing is there (empty receiver slots).
- (void)activateTarget:(MFLogiTarget *)target on:(MFLogiInterface *)iface quietly:(BOOL)quietly {

    if (_stopped || _shutdownRequested || !iface.isOpen) return;
    [self releaseAllPressedOn:target];
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
    DDLogDebug("Logitech HID++ probe: ReprogControlsV4 feature index=0x%02x", reprog);
    target.wirelessFeatureIndex = [self featureIndexOf:kHIDPPFeatureWirelessStatus on:iface deviceIndex:target.deviceIndex didRespond:NULL];

    /// Enumerate controls
    ///     getCount (fn 0) -> count. getCidInfo (fn 1, index) -> cid[2], tid[2], flags, pos, group, gmask, additionalFlags
    if ([self request:iface deviceIndex:target.deviceIndex feature:reprog function:0x00 params:NULL length:0] != 0) return;
    int count = iface.responseBytes[4];
    DDLogDebug("Logitech HID++ probe: advertised control count=%d", count);
    NSMutableDictionary<NSNumber *, NSNumber *> *flagsForCID = [NSMutableDictionary dictionary];
    for (int i = 0; i < count; i++) {
        if (_shutdownRequested) return;
        uint8_t p = (uint8_t)i;
        if ([self request:iface deviceIndex:target.deviceIndex feature:reprog function:0x01 params:&p length:1] != 0 || iface.responseLength < 9) continue;
        uint16_t cid = (uint16_t)((iface.responseBytes[4] << 8) | iface.responseBytes[5]);
        flagsForCID[@(cid)] = @(iface.responseBytes[8]);
        DDLogDebug("Logitech HID++ probe: control[%d] CID=0x%04x flags=0x%02x", i, cid, iface.responseBytes[8]);
    }

    target.flagsForCID = flagsForCID;
    [self reconcileTarget:target on:iface];
}

// Change only the temporary diversion bit. All other reporting modes/remapping
// remain untouched; the exact previous state is required for confirmed cleanup.
- (NSData *)reportingCID:(uint16_t)cid on:(MFLogiInterface *)iface target:(MFLogiTarget *)target {
    uint8_t p[2] = { cid >> 8, cid & 255 };
    int r = [self request:iface deviceIndex:target.deviceIndex feature:target.reprogFeatureIndex function:2 params:p length:2];
    if (r != 0 || iface.responseLength < 9 || iface.responseBytes[4] != p[0] || iface.responseBytes[5] != p[1]) return nil;
    DDLogDebug("Logitech HID++ reporting CID=0x%04x flags=0x%02x", cid, iface.responseBytes[6]);
    return [NSData dataWithBytes:iface.responseBytes + 6 length:3];
}

- (BOOL)restoreCID:(NSNumber *)cid on:(MFLogiInterface *)iface target:(MFLogiTarget *)target {
    NSData *before = target.originalReporting[cid];
    NSData *now = [self reportingCID:cid.unsignedShortValue on:iface target:target];
    if (!before || !now) return NO;
    uint8_t expected[3]; memcpy(expected, before.bytes, 3); expected[0] |= kCIDReportingDivert;
    if (![now isEqual:before] && memcmp(now.bytes, expected, 3) != 0) {
        DDLogInfo("Logitech HID++ CID=0x%04x changed by another client; relinquishing without writing", cid.unsignedShortValue);
    } else if (![now isEqual:before]) {
        if (![self setDivert:NO cid:cid.unsignedShortValue on:iface target:target] ||
            ![[self reportingCID:cid.unsignedShortValue on:iface target:target] isEqual:before]) return NO;
    }
    if (target.pressedMask & MFHIDPPButtonBit(cid.unsignedShortValue)) [self postCID:cid down:NO target:target];
    target.pressedMask &= ~MFHIDPPButtonBit(cid.unsignedShortValue);
    [target.buttonForCID removeObjectForKey:cid];
    [target.originalReporting removeObjectForKey:cid];
    DDLogInfo("Logitech HID++ released ownership of CID=0x%04x", cid.unsignedShortValue);
    return YES;
}

- (void)reconcileTarget:(MFLogiTarget *)target on:(MFLogiInterface *)iface {
    if (_stopped || _shutdownRequested || !iface.isOpen || !target.reprogFeatureIndex) return;
    NSArray *wanted = self.wantedCIDs;
    for (NSNumber *cid in target.buttonForCID.allKeys) {
        if (![wanted containsObject:cid]) [self restoreCID:cid on:iface target:target];
    }
    for (NSNumber *cid in wanted) {
        if (target.buttonForCID[cid]) continue;
        const MFLogiControlPolicy *policy = policyForCID(cid.unsignedShortValue);
        if (!(target.flagsForCID[cid].unsignedCharValue & kCIDInfoFlagDivertable) ||
            [target.buttonForCID.allValues containsObject:@(policy->button)]) continue;
        NSData *before = [self reportingCID:cid.unsignedShortValue on:iface target:target];
        if (!before || (((const uint8_t *)before.bytes)[0] & kCIDReportingDivert)) continue;
        // Own an ambiguous accepted write as well, so it can always be cleaned up.
        target.originalReporting[cid] = before;
        target.buttonForCID[cid] = @(policy->button);
        if ([self setDivert:YES cid:cid.unsignedShortValue on:iface target:target]) {
            DDLogInfo("Logitech HID++ acquired CID=0x%04x -> Button %d", cid.unsignedShortValue, policy->button);
        } else {
            [self restoreCID:cid on:iface target:target];
        }
    }
}

/// setCidReporting (fn 3): cid[2], flags, remap[2]. The mouse echoes the request on success.
- (BOOL)setDivert:(BOOL)divert cid:(uint16_t)cid on:(MFLogiInterface *)iface target:(MFLogiTarget *)target {
    uint8_t p[5] = { (uint8_t)(cid >> 8), (uint8_t)(cid & 0xFF), (uint8_t)(kCIDReportingDivertValid | (divert ? kCIDReportingDivert : 0)), 0, 0 };
    int result = [self request:iface deviceIndex:target.deviceIndex feature:target.reprogFeatureIndex function:0x03 params:p length:5];
    return result == 0 && iface.responseBytes[4] == p[0] && iface.responseBytes[5] == p[1] &&
           [self isDivertedCID:cid on:iface target:target] == (divert ? 1 : 0);
}

/// getCidReporting (fn 2): cid[2] -> cid[2], flags, remap[2]. Returns -1 if the mouse didn't answer, else the divert bit.
- (int)isDivertedCID:(uint16_t)cid on:(MFLogiInterface *)iface target:(MFLogiTarget *)target {
    NSData *state = [self reportingCID:cid on:iface target:target];
    return state ? ((((const uint8_t *)state.bytes)[0] & kCIDReportingDivert) ? 1 : 0) : -1;
}

/// Verify every owned CID and retry initially sleeping devices.
- (void)verifyAll:(BOOL)force {
    if (_stopped || _shutdownRequested) return;
    for (MFLogiInterface *iface in [_interfaces copy]) {
        if (!iface.isOpen) continue;
        for (MFLogiTarget *t in iface.targets) {
            if (force || t.reprogFeatureIndex == 0 || t.buttonForCID.count == 0) {
                [self activateTarget:t on:iface quietly:YES];
            }
            [self reconcileTarget:t on:iface];
            for (NSNumber *cid in t.buttonForCID.allKeys) {
                NSData *state = [self reportingCID:cid.unsignedShortValue on:iface target:t];
                if (!state) { [self releaseAllPressedOn:t]; continue; }
                NSData *before = t.originalReporting[cid];
                uint8_t expected[3]; memcpy(expected, before.bytes, 3); expected[0] |= kCIDReportingDivert;
                if ([state isEqual:before]) {
                    [self releaseAllPressedOn:t];
                    if ([[self wantedCIDs] containsObject:cid]) [self setDivert:YES cid:cid.unsignedShortValue on:iface target:t];
                } else if (memcmp(state.bytes, expected, 3) != 0) {
                    [self restoreCID:cid on:iface target:t]; // another client changed it; don't overwrite
                }
            }
        }
    }
}

- (void)restoreAllOnWorker {
    _restoring = YES;
    for (MFLogiInterface *iface in [_interfaces copy]) {
        if (!iface.isOpen) continue;
        for (MFLogiTarget *t in iface.targets) {
            [self releaseAllPressedOn:t];
            for (NSNumber *cid in t.buttonForCID.allKeys) {
                BOOL restored = [self restoreCID:cid on:iface target:t];
                if (!restored) NSLog(@"Logitech restoration unconfirmed for CID 0x%04x; power-cycle mouse", cid.unsignedShortValue);
            }
            [t.buttonForCID removeAllObjects];
        }
        [self closeInterface:iface];
    }
    if (_manager) {
        IOHIDManagerUnscheduleFromRunLoop(_manager, _runLoop, kCFRunLoopDefaultMode);
        IOHIDManagerClose(_manager, kIOHIDOptionsTypeNone);
    }
    _restoring = NO;
}

#pragma mark Input reports

static void inputReportCallback(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *report, CFIndex length) {

    if (result != kIOReturnSuccess || length < 4) return;
    if (reportID != kHIDPPReportLong && reportID != kHIDPPReportShort) return;      /// Mouse reports etc. share the Bluetooth interface

    MFLogiInterface *iface = (__bridge MFLogiInterface *)context;

    uint8_t r[kHIDPPLongLength] = {0};
    size_t n = MFHIDPPNormalize(reportID, report, (size_t)length, r);
    if (n == 0) return;

    uint8_t deviceIndex = r[1], featureIndex = r[2], function = r[3] >> 4, softwareID = r[3] & 0x0F;

    /// Response to our pending request?
    if (iface.waiting && deviceIndex == iface.pendingDeviceIndex) {
        if (MFHIDPPReply(r, n, iface.pendingDeviceIndex, iface.pendingFeatureIndex,
                         iface.pendingFunction, iface.softwareID)) {
            memcpy(iface.responseBytes, r, sizeof(r));
            iface.responseLength = n;
            iface.gotResponse = YES;
            return;
        }
    }

    /// HID++ 2.0 notifications carry software ID 0
    if (softwareID != 0 || _shared.stopped || !iface.isOpen) return;
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

- (void)handleDivertedButtons:(const uint8_t *)r length:(size_t)n target:(MFLogiTarget *)target {

    uint8_t mask;
    if (!MFHIDPPButtonSnapshot(r, (size_t)n, target.reprogFeatureIndex, &mask)) return;
    uint8_t owned = 0;
    for (NSNumber *cid in target.buttonForCID) owned |= MFHIDPPButtonBit(cid.unsignedShortValue);
    uint8_t held = target.pressedMask;
    MFHIDPPEdges edges = MFHIDPPTransition(&held, mask, owned);
    target.pressedMask = held;
    for (NSNumber *cid in target.buttonForCID) {
        if (edges.up & MFHIDPPButtonBit(cid.unsignedShortValue)) [self postCID:cid down:NO target:target];
    }
    for (NSNumber *cid in target.buttonForCID) {
        if (edges.down & MFHIDPPButtonBit(cid.unsignedShortValue)) [self postCID:cid down:YES target:target];
    }
}

- (void)releaseAllPressedOn:(MFLogiTarget *)target {
    uint8_t held = target.pressedMask;
    target.pressedMask = 0;
    for (NSNumber *cid in target.buttonForCID) {
        if (held & MFHIDPPButtonBit(cid.unsignedShortValue)) [self postCID:cid down:NO target:target];
    }
}

- (void)postCID:(NSNumber *)cid down:(BOOL)down target:(MFLogiTarget *)target {
    NSNumber *button = target.buttonForCID[cid];
    if (button == nil) return;   /// Diverted by someone else (e.g. Logi Options+) – not ours
    postButtonEvent(button.intValue, down, target.senderID);
}

/// Posts a regular button event at the HID level, so it takes the same path as a button event from the mouse itself.
static void postButtonEvent(int button, BOOL down, uint64_t senderID) {
    CGEventRef locationEvent = CGEventCreate(NULL);
    if (!locationEvent) return;
    CGPoint location = CGEventGetLocation(locationEvent);
    CFRelease(locationEvent);

    CGEventRef event = CGEventCreateMouseEvent(NULL, down ? kCGEventOtherMouseDown : kCGEventOtherMouseUp, location, (CGMouseButton)(button - 1));
    if (event == NULL) return;
    // Match ButtonInputReceiver's integer-field read (double setter reads back as 0 there).
    CGEventSetIntegerValueField(event, kCGMouseEventPressure, down ? 1 : 0);
    CGEventSetIntegerValueField(event, kCGMouseEventClickState, 1);
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
    [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceWillSleepNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self enqueue:^{
            for (MFLogiInterface *iface in self.interfaces) {
                for (MFLogiTarget *t in iface.targets) [self releaseAllPressedOn:t];
            }
        }];
    }];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceDidWakeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self enqueueAfterDelay:3.0 block:^{ [self verifyAll:YES]; }];
    }];
}

@end
