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
#import <AppKit/AppKit.h>
#import "SharedUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "DeviceManager.h"
#import "Device.h"

#define kLogitechVID    0x046D
#define kHIDPP_Long     0x11
#define kHIDPP_Device   0xFF
#define kFeat_ReprogV4  0x1B04

/// SetCidReporting flags — Solaar hidpp20.py "valid bit" pattern:
///   each flag bit has a corresponding valid bit = flag << 1
///   0x03 = divert=1 (bit0) + divert_valid=1 (bit1)
#define kDivertFlags    0x03
/// TIDs of controls that already report natively — must NOT be diverted.
/// The Back/Forward side buttons are the exception: on newer Logitech mice the
/// firmware can delay their native reports for horizontal scroll, so we divert
/// their CIDs and feed them into MMF as normal buttons 4/5.
///   0x0038=left, 0x0039=right, 0x003A=middle, 0x003C=back, 0x003E=forward
static const uint16_t kNativeTIDs[] = { 0x0038, 0x0039, 0x003A, 0x003C, 0x003E };
static const uint16_t kNativeSideButtonTIDs[] = { 0x003C, 0x003E };
static const uint16_t kNativeSideButtonCIDs[] = { 0x0053, 0x0056 };

/// CGEvent button numbers are 0-based. 5 = MMF "button 6" (first above L/R/M/Back/Fwd)
#define kFirstCGButton  6

typedef struct {
    IOHIDDeviceRef  device;
    IOHIDDeviceRef  writeDevice;
    uint8_t         reportBuf[64];
    uint16_t        cidMap[32];
    int             cidCount;
    uint16_t        pressedCIDs[32];
    int             pressedCount;
    uint8_t         deviceIndex;
    
    // Request/Response State (localized to each device)
    uint8_t         resp[20];
    BOOL            gotResp;
    uint8_t         waitingIndex;
    
    // Connection Monitor feature ID (0 if not supported/found)
    uint8_t         featConn;
} MFCIDDeviceState;

static BOOL sIsActivatingOrReactivating = NO;

static int activateDevice(MFCIDDeviceState *s);
static uint8_t lookupFeature(MFCIDDeviceState *s, uint16_t featId);

static BOOL isNativeTID(uint16_t tid) {
    for (int i = 0; i < 5; i++) if (kNativeTIDs[i] == tid) return YES;
    return NO;
}

static BOOL isNativeSideButton(uint16_t cid, uint16_t tid) {
    for (int i = 0; i < 2; i++) {
        if (kNativeSideButtonTIDs[i] == tid || kNativeSideButtonCIDs[i] == cid) return YES;
    }
    return NO;
}

static BOOL appendUniqueCID(uint16_t *cids, int *count, uint16_t cid, int maxCount) {
    if (cid == 0) return NO;
    for (int i = 0; i < *count; i++) if (cids[i] == cid) return NO;
    if (*count >= maxCount) return NO;
    cids[(*count)++] = cid;
    return YES;
}

static int buttonForCID(MFCIDDeviceState *s, uint16_t cid) {
    if (cid == 0x0053) return 4;
    if (cid == 0x0056) return 5;
    for (int i = 0; i < s->cidCount; i++)
        if (s->cidMap[i] == cid) return kFirstCGButton + i;
    if (s->cidCount < 32) { s->cidMap[s->cidCount++] = cid; return kFirstCGButton + s->cidCount - 1; }
    return kFirstCGButton;
}

static void injectButton(MFCIDDeviceState *s, uint16_t cid, BOOL down) {
    int btn = buttonForCID(s, cid);
    Device *device = [DeviceManager attachedDeviceWithIOHIDDevice: s->device];
    if (!device) device = [Device strangeDevice];
    CGEventRef event = CGEventCreate(NULL);
    [Buttons handleInputWithDevice: device button: @(btn) downNotUp: down event: event];
    CFRelease(event);
}

static void inputReportCallback(void *ctx, IOReturn result, void *sender,
                                IOHIDReportType type, uint32_t reportID,
                                uint8_t *report, CFIndex len) {
    if (len < 5 || report[0] != kHIDPP_Long) return;
    MFCIDDeviceState *s = (MFCIDDeviceState *)ctx;
    if (!s) return;
    
    // Allow receiver broadcast reports (deviceIndex 0xFF) to pass through for connection monitoring
    if (report[1] != s->deviceIndex && report[1] != 0xFF) return;
    
    if (report[3] != 0x00) {
        if (s->waitingIndex == report[1]) {
            memcpy(s->resp, report, len < 20 ? (size_t)len : 20);
            s->gotResp = YES;
        } else {
            // Handle unsolicited notifications (e.g. wireless device reconnects)
            BOOL reconnectDetected = NO;
            
            // 1. Unifying 1.0 connection notification:
            //    report[1] == 0xFF, report[2] == 0x00, report[3] == 0x41
            //    report[4] == deviceIndex, (report[5] & 0x40) != 0 -> connected
            if (report[1] == 0xFF && report[2] == 0x00 && report[3] == 0x41 && len >= 6) {
                uint8_t devIdx = report[4];
                uint8_t status = report[5];
                if (devIdx == s->deviceIndex && (status & 0x40)) {
                    DDLogInfo(@"LogitechCIDActivator: Unifying reconnection event detected for deviceIndex 0x%02X", devIdx);
                    reconnectDetected = YES;
                }
            }
            
            // 2. HID++ 2.0 Connection Monitor event:
            //    report[1] == 0xFF, report[2] == s->featConn (if set)
            //    report[3] == 0x00 (connection state changed event)
            //    report[4] == deviceIndex, (report[5] & 0x01) -> link established
            if (s->featConn != 0 && report[1] == 0xFF && report[2] == s->featConn && report[3] == 0x00 && len >= 6) {
                uint8_t devIdx = report[4];
                uint8_t status = report[5];
                if (devIdx == s->deviceIndex && (status & 0x01)) {
                    DDLogInfo(@"LogitechCIDActivator: HID++ 2.0 reconnection event detected for deviceIndex 0x%02X", devIdx);
                    reconnectDetected = YES;
                }
            }
            
            if (reconnectDetected) {
                DDLogInfo(@"LogitechCIDActivator: Device reconnected wirelessly. Scheduling activation in 1.0 second...");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    sIsActivatingOrReactivating = YES;
                    int activeCount = activateDevice(s);
                    sIsActivatingOrReactivating = NO;
                    DDLogInfo(@"LogitechCIDActivator: Async reactivation after wireless reconnect completed. CIDs configured: %d", activeCount);
                });
            } else {
                DDLogDebug(@"LogitechCIDActivator: Unsolicited report received: [%02x %02x %02x %02x %02x %02x]",
                           report[0], report[1], report[2], report[3], report[4], report[5]);
            }
        }
        return;
    }

    // Parse the divertedButtonsEvent (up to 4 CIDs)
    uint16_t currentPressed[4];
    int currentCount = 0;
    
    // Bytes 4-11 correspond to Parameters 0-7 (cid1 to cid4)
    if (len >= 6) {
        uint16_t cid1 = ((uint16_t)report[4] << 8) | report[5];
        if (cid1 != 0) currentPressed[currentCount++] = cid1;
    }
    if (len >= 8) {
        uint16_t cid2 = ((uint16_t)report[6] << 8) | report[7];
        if (cid2 != 0) currentPressed[currentCount++] = cid2;
    }
    if (len >= 10) {
        uint16_t cid3 = ((uint16_t)report[8] << 8) | report[9];
        if (cid3 != 0) currentPressed[currentCount++] = cid3;
    }
    if (len >= 12) {
        uint16_t cid4 = ((uint16_t)report[10] << 8) | report[11];
        if (cid4 != 0) currentPressed[currentCount++] = cid4;
    }

    // 1. Find released buttons: in s->pressedCIDs but not in currentPressed
    for (int i = 0; i < s->pressedCount; i++) {
        uint16_t oldCid = s->pressedCIDs[i];
        BOOL stillPressed = NO;
        for (int j = 0; j < currentCount; j++) {
            if (currentPressed[j] == oldCid) {
                stillPressed = YES;
                break;
            }
        }
        if (!stillPressed) {
            injectButton(s, oldCid, NO);
        }
    }

    // 2. Find newly pressed buttons: in currentPressed but not in s->pressedCIDs
    for (int i = 0; i < currentCount; i++) {
        uint16_t newCid = currentPressed[i];
        BOOL alreadyPressed = NO;
        for (int j = 0; j < s->pressedCount; j++) {
            if (s->pressedCIDs[j] == newCid) {
                alreadyPressed = YES;
                break;
            }
        }
        if (!alreadyPressed) {
            injectButton(s, newCid, YES);
        }
    }

    // 3. Update the state
    s->pressedCount = 0;
    for (int i = 0; i < currentCount; i++) {
        if (s->pressedCount < 32) {
            s->pressedCIDs[s->pressedCount++] = currentPressed[i];
        }
    }
}

static IOReturn sendAndWaitWithTimeout(MFCIDDeviceState *s, uint8_t *pkt, int maxLaps) {
    s->gotResp = NO;
    s->waitingIndex = pkt[1];
    IOReturn r = IOHIDDeviceSetReport(s->writeDevice, kIOHIDReportTypeOutput, pkt[0], pkt, 20);
    if (r != kIOReturnSuccess) {
        DDLogError(@"LogitechCIDActivator: IOHIDDeviceSetReport failed with error 0x%x", r);
        return r;
    }
    for (int i = 0; i < maxLaps && !s->gotResp; i++) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
    }
    if (!s->gotResp) {
        return kIOReturnTimeout;
    }
    if (s->resp[2] == 0xFF) {
        DDLogError(@"LogitechCIDActivator: sendAndWait received error packet: [%02x %02x %02x %02x %02x...]", s->resp[0], s->resp[1], s->resp[2], s->resp[3], s->resp[4]);
        return kIOReturnError;
    }
    return kIOReturnSuccess;
}

static IOReturn sendAndWait(MFCIDDeviceState *s, uint8_t *pkt) {
    return sendAndWaitWithTimeout(s, pkt, 100);
}

static int activateDevice(MFCIDDeviceState *s) {
    IOHIDDeviceRef dev = s->writeDevice;
    uint8_t pkt[20];
    NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(s->device, CFSTR(kIOHIDProductKey));

    /// Probe: Find active device index
    uint8_t indices[] = {0xFF, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06};
    uint8_t activeIndex = 0;
    uint8_t feat = 0;
    
    for (int idx = 0; idx < sizeof(indices)/sizeof(indices[0]); idx++) {
        uint8_t testIndex = indices[idx];
        s->deviceIndex = testIndex;
        
        memset(pkt, 0, 20);
        pkt[0]=kHIDPP_Long; pkt[1]=testIndex; pkt[2]=0x00; pkt[3]=0x0E;
        pkt[4]=(kFeat_ReprogV4>>8)&0xFF; pkt[5]=kFeat_ReprogV4&0xFF;
        
        if (sendAndWaitWithTimeout(s, pkt, 10) == kIOReturnSuccess && s->resp[4] != 0) {
            activeIndex = testIndex;
            feat = s->resp[4];
            DDLogInfo(@"LogitechCIDActivator: Found active device index 0x%02X for feature 0x1B04 on '%@'", activeIndex, name);
            break;
        }
    }
    
    if (activeIndex == 0 || feat == 0) {
        return 0;
    }
    
    s->deviceIndex = activeIndex;
    s->featConn = lookupFeature(s, 0x0001);
    if (s->featConn != 0) {
        DDLogInfo(@"LogitechCIDActivator: Found Connection Monitor Feature 0x%02X for deviceIndex 0x%02X on '%@'", s->featConn, activeIndex, name);
    }

    /// 2. GetCount
    memset(pkt, 0, 20);
    pkt[0]=kHIDPP_Long; pkt[1]=s->deviceIndex; pkt[2]=feat; pkt[3]=0x0E;
    if (sendAndWaitWithTimeout(s, pkt, 100) != kIOReturnSuccess) return 0;
    int count = s->resp[4];

    /// 3. GetCidInfo — collect divertable CIDs
    uint16_t todivert[32]; int ndiv = 0;
    for (int i = 0; i < count && ndiv < 32; i++) {
        memset(pkt, 0, 20);
        pkt[0]=kHIDPP_Long; pkt[1]=s->deviceIndex; pkt[2]=feat; pkt[3]=0x1E; pkt[4]=(uint8_t)i;
        if (sendAndWaitWithTimeout(s, pkt, 100) != kIOReturnSuccess) continue;
        uint16_t cid = ((uint16_t)s->resp[4]<<8)|s->resp[5];
        uint16_t tid = ((uint16_t)s->resp[6]<<8)|s->resp[7];
        uint8_t flags = s->resp[8];
        if (isNativeSideButton(cid, tid)) {
            appendUniqueCID(todivert, &ndiv, cid, 32);
            DDLogInfo(@"LogitechCIDActivator: side-button CID 0x%04X/TID 0x%04X will be diverted as Button %d on '%@'", cid, tid, buttonForCID(s, cid), name);
            continue;
        }
        if ((flags & (1<<5)) && !isNativeTID(tid)) {
            appendUniqueCID(todivert, &ndiv, cid, 32);
        }
    }

    /// 4. Pre-register button mapping for stable numbering
    for (int i = 0; i < ndiv; i++) buttonForCID(s, todivert[i]);

    /// 5. SetCidReporting — divert non-native controls and side buttons.
    /// Diverting side buttons disables the firmware's horizontal-scroll hold
    /// state and gives MMF an immediate down/up signal for hold-and-drag.
    int diverted = 0;
    for (int i = 0; i < ndiv; i++) {
        memset(pkt, 0, 20);
        pkt[0]=kHIDPP_Long; pkt[1]=s->deviceIndex; pkt[2]=feat; pkt[3]=0x3E;
        pkt[4]=(todivert[i]>>8)&0xFF; pkt[5]=todivert[i]&0xFF; pkt[6]=kDivertFlags;
        if (sendAndWaitWithTimeout(s, pkt, 100) == kIOReturnSuccess) {
            diverted++;
            if (isNativeSideButton(todivert[i], todivert[i])) {
                DDLogInfo(@"LogitechCIDActivator: diverted side-button CID 0x%04X as Button %d on '%@'", todivert[i], buttonForCID(s, todivert[i]), name);
            }
        } else {
            DDLogError(@"LogitechCIDActivator: Failed to divert CID 0x%04X on '%@'", todivert[i], name);
        }
    }
    return diverted;
}

static uint8_t lookupFeature(MFCIDDeviceState *s, uint16_t featId) {
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = 0x00; // Root feature
    pkt[3] = 0x0E; // GetFeature command (function 0, software ID 0x0E)
    pkt[4] = (featId >> 8) & 0xFF;
    pkt[5] = featId & 0xFF;
    if (sendAndWaitWithTimeout(s, pkt, 100) != kIOReturnSuccess) {
        return 0;
    }
    return s->resp[4];
}

@interface LogitechCIDActivator ()
@property (nonatomic) NSMutableArray *states;
@property (nonatomic) NSTimer *reactivateTimer;
@end

static MFCIDDeviceState *stateForDevice(IOHIDDeviceRef dev) {
    LogitechCIDActivator *activator = [LogitechCIDActivator shared];
    for (NSValue *v in activator.states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        if (s->device == dev || s->writeDevice == dev) {
            return s;
        }
    }
    return NULL;
}

static IOHIDDeviceRef findVendorInterface(IOHIDDeviceRef mouseDev) {
    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(mouseDev, CFSTR(kIOHIDVendorIDKey));
    NSNumber *pid = (__bridge NSNumber *)IOHIDDeviceGetProperty(mouseDev, CFSTR(kIOHIDProductIDKey));
    NSString *mName = (__bridge NSString *)IOHIDDeviceGetProperty(mouseDev, CFSTR(kIOHIDProductKey));
    DDLogInfo(@"LogitechCIDActivator: findVendorInterface starting for '%@' (VID: %@, PID: %@)", mName, vid, pid);
    if (!vid || !pid) {
        CFRetain(mouseDev);
        return mouseDev;
    }
    
    CFMutableDictionaryRef matchingDict = IOServiceMatching("IOHIDDevice");
    if (!matchingDict) {
        CFRetain(mouseDev);
        return mouseDev;
    }
    
    CFDictionarySetValue(matchingDict, CFSTR("VendorID"), (__bridge CFNumberRef)vid);
    CFDictionarySetValue(matchingDict, CFSTR("ProductID"), (__bridge CFNumberRef)pid);
    
    io_iterator_t iterator;
    mach_port_t port = kIOMainPortDefault;
#if __MAC_OS_X_VERSION_MIN_REQUIRED < 120000
    if (!@available(macOS 12.0, *)) {
        port = kIOMasterPortDefault;
    }
#endif
    
    kern_return_t kr = IOServiceGetMatchingServices(port, matchingDict, &iterator);
    if (kr != KERN_SUCCESS) {
        CFRetain(mouseDev);
        return mouseDev;
    }
    
    io_service_t service;
    IOHIDDeviceRef foundDev = NULL;
    
    while ((service = IOIteratorNext(iterator))) {
        IOHIDDeviceRef dev = IOHIDDeviceCreate(kCFAllocatorDefault, service);
        if (dev) {
            NSNumber *upage = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDPrimaryUsagePageKey));
            NSNumber *maxOut = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDMaxOutputReportSizeKey));
            
            if (upage && upage.intValue >= 0xFF00) {
                foundDev = dev;
                IOObjectRelease(service);
                break;
            } else if (maxOut && maxOut.intValue >= 20) {
                foundDev = dev;
                IOObjectRelease(service);
                break;
            }
            CFRelease(dev);
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
    
    if (foundDev) {
        IOReturn openRes = IOHIDDeviceOpen(foundDev, kIOHIDOptionsTypeNone);
        if (openRes == kIOReturnSuccess) {
            DDLogInfo(@"LogitechCIDActivator: findVendorInterface found and opened vendor interface successfully");
        } else {
            DDLogError(@"LogitechCIDActivator: findVendorInterface failed to open vendor interface: 0x%x", openRes);
            CFRelease(foundDev);
            foundDev = NULL;
        }
    }
    
    if (!foundDev) {
        DDLogWarn(@"LogitechCIDActivator: findVendorInterface failed to find any vendor interface, returning mouseDev");
        foundDev = mouseDev;
        CFRetain(mouseDev);
    }
    
    return foundDev;
}

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
        /// Re-activate on system wake — firmware clears divert state on sleep
        [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver: self
               selector: @selector(reactivateAll)
                   name: NSWorkspaceDidWakeNotification
                 object: nil];
        /// Periodic safety net — covers firmware timeout without sleep/wake cycle
        _reactivateTimer = [NSTimer scheduledTimerWithTimeInterval: 60 * 30
                                                            target: self
                                                          selector: @selector(reactivateAll)
                                                          userInfo: nil
                                                           repeats: YES];
    }
    return self;
}

- (void)reactivateAll {
    sIsActivatingOrReactivating = YES;
    for (NSValue *v in _states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        activateDevice(s);
    }
    sIsActivatingOrReactivating = NO;
    DDLogDebug(@"LogitechCIDActivator: re-activated %lu device(s)", (unsigned long)_states.count);
}

- (void)handleDeviceAttached: (IOHIDDeviceRef)device {
    sIsActivatingOrReactivating = YES;
    NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    DDLogInfo(@"LogitechCIDActivator: handleDeviceAttached for device '%@' (VID: %@)", name, vid);
    if (vid.integerValue != kLogitechVID) {
        sIsActivatingOrReactivating = NO;
        return;
    }
    
    // We already opened device in DeviceManager or Device.m, but let's make sure
    IOReturn openRes = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    if (openRes != kIOReturnSuccess && openRes != kIOReturnExclusiveAccess) {
        // Safe to ignore if already opened
    }

    IOHIDDeviceRef writeDevice = findVendorInterface(device);

    MFCIDDeviceState *s = calloc(1, sizeof(MFCIDDeviceState));
    s->device = device;
    s->writeDevice = writeDevice;
    
    IOHIDDeviceRegisterInputReportCallback(writeDevice, s->reportBuf, sizeof(s->reportBuf), inputReportCallback, s);
    IOHIDDeviceScheduleWithRunLoop(writeDevice, CFRunLoopGetMain(), kCFRunLoopDefaultMode);

    int configured = activateDevice(s);
    sIsActivatingOrReactivating = NO; // Reset flag before running post-config queries
    if (configured > 0) {
        DDLogInfo(@"LogitechCIDActivator: configured %d CID(s) on '%@'", configured, name);
        [_states addObject: [NSValue valueWithPointer: s]];
        Device *attachedDev = [DeviceManager attachedDeviceWithIOHIDDevice:device];
        if (attachedDev) {
            attachedDev.isLogitechDiverted = YES;
            [self queryBatteryAndDPIForDevice:attachedDev];
        }
    } else {
        DDLogWarn(@"LogitechCIDActivator: No CIDs configured on '%@', closing device", name);
        IOHIDDeviceUnscheduleFromRunLoop(writeDevice, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        IOHIDDeviceRegisterInputReportCallback(writeDevice, NULL, 0, NULL, NULL);
        if (writeDevice != device) {
            IOHIDDeviceClose(writeDevice, kIOHIDOptionsTypeNone);
        }
        CFRelease(writeDevice);
        free(s);
    }
}

- (void)handleDeviceRemoved: (IOHIDDeviceRef)device {
    NSValue *found = nil;
    for (NSValue *v in _states) {
        if (((MFCIDDeviceState *)v.pointerValue)->device == device) { found = v; break; }
    }
    if (!found) return;
    MFCIDDeviceState *s = (MFCIDDeviceState *)found.pointerValue;
    for (int i = 0; i < s->pressedCount; i++) injectButton(s, s->pressedCIDs[i], NO);
    
    IOHIDDeviceUnscheduleFromRunLoop(s->writeDevice, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDDeviceRegisterInputReportCallback(s->writeDevice, NULL, 0, NULL, NULL);
    if (s->writeDevice != s->device) {
        IOHIDDeviceClose(s->writeDevice, kIOHIDOptionsTypeNone);
    }
    CFRelease(s->writeDevice);
    free(s);
    [_states removeObject: found];
}

- (void)queryBatteryAndDPIForDevice:(Device *)device {
    if (sIsActivatingOrReactivating) {
        DDLogWarn(@"LogitechCIDActivator: Skipping battery/DPI query because device activation/reactivation is in progress.");
        return;
    }
    IOHIDDeviceRef dev = device.iohidDevice;
    if (!dev) return;
    
    MFCIDDeviceState *s = stateForDevice(dev);
    if (!s) {
        // Fallback: look if any other attached device with same Product name has a diverted state
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDProductKey));
        if (name != nil) {
            for (NSValue *v in _states) {
                MFCIDDeviceState *otherS = (MFCIDDeviceState *)v.pointerValue;
                NSString *otherName = (__bridge NSString *)IOHIDDeviceGetProperty(otherS->device, CFSTR(kIOHIDProductKey));
                if ([name isEqualToString:otherName]) {
                    s = otherS;
                    break;
                }
            }
        }
    }
    if (!s) return; // If we still don't have a state, we can't query battery/DPI safely
    
    // 1. Query battery
    uint8_t featBattery = lookupFeature(s, 0x1004);
    BOOL is1004 = YES;
    if (featBattery == 0) {
        featBattery = lookupFeature(s, 0x1000);
        is1004 = NO;
    }
    
    if (featBattery != 0) {
        uint8_t pkt[20];
        memset(pkt, 0, 20);
        pkt[0] = kHIDPP_Long;
        pkt[1] = s->deviceIndex;
        pkt[2] = featBattery;
        pkt[3] = is1004 ? 0x1E : 0x0E; // Function 1 for 0x1004, Function 0 for 0x1000 (with software ID 0x0E)
        if (sendAndWaitWithTimeout(s, pkt, 100) == kIOReturnSuccess) {
            device.logitechBatteryPercentage = s->resp[4];
            device.logitechBatteryStatus = s->resp[6];
            DDLogInfo(@"LogitechCIDActivator: Battery query successful. Percentage: %d%%, Status: %d", device.logitechBatteryPercentage, device.logitechBatteryStatus);
        }
    } else {
        DDLogWarn(@"LogitechCIDActivator: Unified Battery feature (0x1004/0x1000) not found on device");
    }
    
    // 2. Query DPI — try 0x2201 (AdjustableDPI) first, then 0x2202 (ExtendedAdjustableDPI)
    uint8_t featDPI = lookupFeature(s, 0x2201);
    BOOL isExtendedDPI = NO;
    if (featDPI == 0) {
        featDPI = lookupFeature(s, 0x2202);
        isExtendedDPI = YES;
    }
    if (featDPI != 0) {
        uint8_t pkt[20];
        memset(pkt, 0, 20);
        pkt[0] = kHIDPP_Long;
        pkt[1] = s->deviceIndex;
        pkt[2] = featDPI;
        // 0x2201: Function 2 (GetSensorDpi) = 0x2E, 0x2202: Function 5 (GetSensorDpiParameters) = 0x5E
        pkt[3] = isExtendedDPI ? 0x5E : 0x2E;
        pkt[4] = 0; // Sensor index 0
        if (sendAndWaitWithTimeout(s, pkt, 100) == kIOReturnSuccess) {
            DDLogInfo(@"LogitechCIDActivator: DPI raw response: [%02x %02x %02x %02x %02x %02x %02x %02x %02x %02x]",
                      s->resp[0], s->resp[1], s->resp[2], s->resp[3], s->resp[4], s->resp[5], s->resp[6], s->resp[7], s->resp[8], s->resp[9]);
            int dpi = (s->resp[5] << 8) | s->resp[6];
            if (dpi == 0 && !isExtendedDPI) {
                dpi = (s->resp[7] << 8) | s->resp[8];
            }
            device.logitechDPI = dpi;
            DDLogInfo(@"LogitechCIDActivator: DPI query successful (feat 0x%04X). DPI: %d", isExtendedDPI ? 0x2202 : 0x2201, device.logitechDPI);
        }
    } else {
        DDLogWarn(@"LogitechCIDActivator: Adjustable DPI feature (0x2201/0x2202) not found on device");
    }
}

@end
