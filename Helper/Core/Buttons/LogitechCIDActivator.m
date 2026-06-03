//
// --------------------------------------------------------------------------
// LogitechCIDActivator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Miguel Angelo in 2026
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------

#import "LogitechCIDActivator.h"
#import <IOKit/hid/IOHIDLib.h>
#import <UserNotifications/UserNotifications.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>
#import "SharedUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "DeviceManager.h"
#import "Device.h"
#import "Config.h"
#import "Constants.h"
#import "PointerSpeed.h"

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
    uint8_t         featWirelessStatus;
    uint8_t         featReprogV4;
    uint8_t         featSmartShift;
    uint8_t         featAdjustableDpi;  // 0x2201
    uint8_t         featExtendedDpi;    // 0x2202
    uint8_t         lastErrorCode;
    int             lastNotifiedBatteryLevel;
    NSTimeInterval  lastBatteryQueryTime;
} MFCIDDeviceState;

static BOOL sIsActivatingOrReactivating = NO;

static int activateDevice(MFCIDDeviceState *s);
static uint8_t lookupFeature(MFCIDDeviceState *s, uint16_t featId);

static BOOL isNativeTID(uint16_t tid) {
    for (int i = 0; i < 5; i++) if (kNativeTIDs[i] == tid) return YES;
    return NO;
}

static BOOL isButtonRemapped(int buttonNumber) {
    NSArray *remapsTable = (NSArray *)config(kMFConfigKeyRemaps);
    if (!remapsTable) return NO;
    for (NSDictionary *tableEntry in remapsTable) {
        id trigger = tableEntry[kMFRemapsKeyTrigger];
        if ([trigger isKindOfClass:NSDictionary.class]) {
            NSDictionary *triggerDict = (NSDictionary *)trigger;
            NSNumber *buttonNum = triggerDict[kMFButtonTriggerKeyButtonNumber];
            if (buttonNum != nil && buttonNum.intValue == buttonNumber) {
                return YES;
            }
        }
    }
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
    if (cid == 0x00C4) return 6; // 中键下方最常用的智能轮换/功能键 -> 固定为 Button 6
    if (cid == 0x00D7) return 7; // Mode Shift 键 -> 固定为 Button 7
    
    for (int i = 0; i < s->cidCount; i++)
        if (s->cidMap[i] == cid) return 8 + i;
    if (s->cidCount < 24) {
        s->cidMap[s->cidCount++] = cid;
        return 8 + s->cidCount - 1;
    }
    return 8;
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
    if (len < 4) return;
    if (report[0] != 0x10 && report[0] != 0x11) return;
    
    MFCIDDeviceState *s = (MFCIDDeviceState *)ctx;
    if (!s) return;
    
    // Print all received HID++ reports for wireless reconnect diagnostics
    NSMutableString *hexStr = [NSMutableString string];
    for (CFIndex i = 0; i < len && i < 20; i++) {
        [hexStr appendFormat:@"%02x ", report[i]];
    }
    DDLogInfo(@"LogitechCIDActivator: Input report [ID:%02X, len:%ld]: %@", report[0], (long)len, hexStr);
    
    // Allow receiver broadcast reports (deviceIndex 0xFF) or target device reports to pass through
    if (report[1] != s->deviceIndex && report[1] != 0xFF) return;
    
    // 1. Handle synchronous response we are waiting for
    if (report[3] != 0x00 && s->waitingIndex == report[1]) {
        memcpy(s->resp, report, len < 20 ? (size_t)len : 20);
        s->gotResp = YES;
        return;
    }
    
    // 2. Handle unsolicited notifications (e.g. wireless device reconnects)
    BOOL reconnectDetected = NO;
    
    // 2.1. Unifying 1.0 connection notification:
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
    
    // 2.2. Logitech HID++ 2.0 Wireless Status Notification:
    //    report[0] == 0x11, report[1] == s->deviceIndex, report[3] == 0x00 (StatusBroadcast)
    //    report[4] == 0x01 (proto_activation) or 0x02 (connection status change) -> connected/active
    if (!reconnectDetected &&
        report[0] == 0x11 && (report[1] == s->deviceIndex || report[1] == 0xFF) &&
        report[3] == 0x00 && len >= 5) {
        
        if (s->featWirelessStatus != 0 && report[2] == s->featWirelessStatus) {
            uint8_t status = report[4];
            if (status == 0x01 || status == 0x02) {
                DDLogInfo(@"LogitechCIDActivator: Wireless reconnection event (StatusBroadcast via feature 0x1D4B) detected for deviceIndex 0x%02X", s->deviceIndex);
                reconnectDetected = YES;
            }
        } else if (report[2] != 0 && report[2] < 0x10) {
            uint8_t status = report[4];
            if (status == 0x01 || status == 0x02) {
                DDLogInfo(@"LogitechCIDActivator: Generic wireless status event detected for deviceIndex 0x%02X", s->deviceIndex);
                reconnectDetected = YES;
            }
        }
    }
    
    if (reconnectDetected) {
        DDLogInfo(@"LogitechCIDActivator: Device reconnected wirelessly. Scheduling activation in 0.35 seconds...");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            sIsActivatingOrReactivating = YES;
            int activeCount = activateDevice(s);
            sIsActivatingOrReactivating = NO;
            DDLogInfo(@"LogitechCIDActivator: Async reactivation after wireless reconnect completed. CIDs configured: %d", activeCount);
            if (activeCount >= 0) {
                Device *attachedDev = [DeviceManager attachedDeviceWithIOHIDDevice:s->device];
                if (attachedDev) {
                    if (s->featReprogV4 != 0) {
                        attachedDev.isLogitechDiverted = YES;
                    } else {
                        attachedDev.isLogitechDiverted = NO;
                    }
                    [[LogitechCIDActivator shared] queryBatteryAndDPIForDevice:attachedDev];
                }
            }
        });
        return;
    }
    
    // 3. Handle diverted button notifications from ReprogControlsV4
    //    Only parse if report[3] == 0x00 (unsolicited event) and report[2] matches our ReprogControlsV4 feature index
    if (report[3] != 0x00 || report[2] != s->featReprogV4) {
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
    
    // 3.1. Find released buttons: in s->pressedCIDs but not in currentPressed
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
    
    // 3.2. Find newly pressed buttons: in currentPressed but not in s->pressedCIDs
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
    
    // 3.3. Update the state
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
    s->lastErrorCode = 0;
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
        s->lastErrorCode = s->resp[5];
        DDLogError(@"LogitechCIDActivator: sendAndWait received error packet: [%02x %02x %02x %02x %02x...], errorCode: 0x%02X",
                   s->resp[0], s->resp[1], s->resp[2], s->resp[3], s->resp[4], s->lastErrorCode);
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

    /// Probe: Find active device index using feature 0x0001 (Feature Set) which is universally supported by HID++ 2.0
    uint8_t indices[] = {0xFF, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06};
    uint8_t activeIndex = 0;
    
    for (int idx = 0; idx < sizeof(indices)/sizeof(indices[0]); idx++) {
        uint8_t testIndex = indices[idx];
        s->deviceIndex = testIndex;
        
        memset(pkt, 0, 20);
        pkt[0]=kHIDPP_Long; pkt[1]=testIndex; pkt[2]=0x00; pkt[3]=0x0E;
        pkt[4]=0x00; pkt[5]=0x01; // Feature 0x0001 (Feature Set)
        
        if (sendAndWaitWithTimeout(s, pkt, 100) == kIOReturnSuccess && s->resp[2] == 0x00) {
            activeIndex = testIndex;
            DDLogInfo(@"LogitechCIDActivator: Found active device index 0x%02X on '%@'", activeIndex, name);
            break;
        }
    }
    
    if (activeIndex == 0) {
        return -1;
    }
    
    s->deviceIndex = activeIndex;
    s->featReprogV4 = lookupFeature(s, kFeat_ReprogV4);
    
    s->featWirelessStatus = lookupFeature(s, 0x1D4B);
    if (s->featWirelessStatus != 0) {
        DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator: Found wireless status feature 0x1D4B index 0x%02X on index 0x%02X", s->featWirelessStatus, activeIndex);
    } else {
        DDLogWarn(@"[SMARTSHIFT] LogitechCIDActivator: Wireless status feature 0x1D4B not found on index 0x%02X", activeIndex);
    }

    s->featSmartShift = lookupFeature(s, 0x2111);
    if (s->featSmartShift == 0) {
        s->featSmartShift = lookupFeature(s, 0x2110);
    }
    if (s->featSmartShift != 0) {
        DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator: Found SmartShift feature index 0x%02X on index 0x%02X", s->featSmartShift, activeIndex);
    } else {
        DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator: SmartShift feature not supported on index 0x%02X", activeIndex);
    }

    s->featAdjustableDpi = lookupFeature(s, 0x2201);
    s->featExtendedDpi = lookupFeature(s, 0x2202);
    if (s->featAdjustableDpi != 0) {
        DDLogInfo(@"LogitechCIDActivator: Found Adjustable DPI feature index 0x%02X (Extended DPI support: %d) on index 0x%02X",
                  s->featAdjustableDpi, (s->featExtendedDpi != 0), activeIndex);
    } else {
        DDLogInfo(@"LogitechCIDActivator: Adjustable DPI feature not supported on index 0x%02X", activeIndex);
    }

    int diverted = 0;
    if (s->featReprogV4 != 0) {
        /// 2. GetCount
        memset(pkt, 0, 20);
        pkt[0]=kHIDPP_Long; pkt[1]=s->deviceIndex; pkt[2]=s->featReprogV4; pkt[3]=0x0E;
        if (sendAndWaitWithTimeout(s, pkt, 100) == kIOReturnSuccess) {
            int count = s->resp[4];

            /// 3. GetCidInfo — collect divertable CIDs
            uint16_t todivert[32]; int ndiv = 0;
            for (int i = 0; i < count && ndiv < 32; i++) {
                memset(pkt, 0, 20);
                pkt[0]=kHIDPP_Long; pkt[1]=s->deviceIndex; pkt[2]=s->featReprogV4; pkt[3]=0x1E; pkt[4]=(uint8_t)i;
                if (sendAndWaitWithTimeout(s, pkt, 100) != kIOReturnSuccess) continue;
                uint16_t cid = ((uint16_t)s->resp[4]<<8)|s->resp[5];
                uint16_t tid = ((uint16_t)s->resp[6]<<8)|s->resp[7];
                uint8_t flags = s->resp[8];
                int btn = buttonForCID(s, cid);
                // If the button is a Mode-Shift / Gesture button (btn >= 6) and NOT remapped by the user,
                // we DO NOT divert it! This keeps the original Mode-Shift physical function working perfectly on the mouse.
                if (btn >= 6 && !isButtonRemapped(btn)) {
                    DDLogInfo(@"LogitechCIDActivator: CID 0x%04X maps to Button %d which is not remapped. Skipping divert to keep native wheel mode switching.", cid, btn);
                    continue;
                }

                if (isNativeSideButton(cid, tid)) {
                    appendUniqueCID(todivert, &ndiv, cid, 32);
                    DDLogInfo(@"LogitechCIDActivator: side-button CID 0x%04X/TID 0x%04X will be diverted as Button %d on '%@'", cid, tid, btn, name);
                    continue;
                }
                if ((flags & (1<<5)) && !isNativeTID(tid)) {
                    appendUniqueCID(todivert, &ndiv, cid, 32);
                }
            }

            /// 4. Pre-register button mapping for stable numbering
            for (int i = 0; i < ndiv; i++) buttonForCID(s, todivert[i]);

            /// 5. SetCidReporting — divert non-native controls and side buttons.
            for (int i = 0; i < ndiv; i++) {
                memset(pkt, 0, 20);
                pkt[0]=kHIDPP_Long; pkt[1]=s->deviceIndex; pkt[2]=s->featReprogV4; pkt[3]=0x3E;
                pkt[4]=(todivert[i]>>8)&0xFF; pkt[5]=todivert[i]&0xFF; pkt[6]=kDivertFlags;
                
                IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
                if (ret == kIOReturnError && s->lastErrorCode == 0x04) {
                    DDLogInfo(@"LogitechCIDActivator: CID 0x%04X set reporting failed with busy error 0x04. Retrying in 200ms...", todivert[i]);
                    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.20, false);
                    ret = sendAndWaitWithTimeout(s, pkt, 100);
                }
                
                if (ret == kIOReturnSuccess) {
                    diverted++;
                    if (isNativeSideButton(todivert[i], todivert[i])) {
                        DDLogInfo(@"LogitechCIDActivator: diverted side-button CID 0x%04X as Button %d on '%@'", todivert[i], buttonForCID(s, todivert[i]), name);
                    }
                } else {
                    DDLogError(@"LogitechCIDActivator: Failed to divert CID 0x%04X on '%@', error 0x%x, lastError: 0x%02X", todivert[i], name, ret, s->lastErrorCode);
                }
            }
        }
    }
    
    // Apply persisted settings to the hardware when device is configured
    if (s->featAdjustableDpi != 0) {
        NSNumber *savedDpi = (NSNumber *)config(@"Pointer.logitechDPI");
        if (savedDpi != nil) {
            uint16_t dpi = [savedDpi unsignedShortValue];
            DDLogInfo(@"LogitechCIDActivator: activateDevice applying saved DPI setting: %d", dpi);
            [[LogitechCIDActivator shared] setDpi:dpi forDevice:s->device];
        }
    }
    
    if (s->featSmartShift != 0) {
        NSNumber *savedWheelMode = (NSNumber *)config(@"Pointer.logitechWheelMode");
        NSNumber *savedAutoShift = (NSNumber *)config(@"Pointer.logitechAutoShift");
        NSNumber *savedThreshold = (NSNumber *)config(@"Pointer.logitechSmartShiftThreshold");
        NSNumber *savedTorque = (NSNumber *)config(@"Pointer.logitechTorque");
        if (savedWheelMode != nil || savedAutoShift != nil || savedThreshold != nil || savedTorque != nil) {
            LogitechSmartShiftState state = {0};
            state.wheelMode = savedWheelMode ? [savedWheelMode unsignedCharValue] : 1;
            state.autoShift = savedAutoShift ? [savedAutoShift unsignedCharValue] : 0;
            state.threshold = savedThreshold ? [savedThreshold unsignedCharValue] : 20;
            state.torque = savedTorque ? [savedTorque unsignedCharValue] : 0;
            DDLogInfo(@"LogitechCIDActivator: activateDevice applying saved SmartShift settings (wheelMode: %d, autoShift: %d, threshold: %d, torque: %d)",
                      state.wheelMode, state.autoShift, state.threshold, state.torque);
            [[LogitechCIDActivator shared] setSmartShiftState:state forDevice:s->device];
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
    // Fallback: match VID and PID
    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDVendorIDKey));
    NSNumber *pid = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDProductIDKey));
    if (vid != nil && pid != nil) {
        for (NSValue *v in activator.states) {
            MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
            NSNumber *sVid = (__bridge NSNumber *)IOHIDDeviceGetProperty(s->device, CFSTR(kIOHIDVendorIDKey));
            NSNumber *sPid = (__bridge NSNumber *)IOHIDDeviceGetProperty(s->device, CFSTR(kIOHIDProductIDKey));
            if ([vid isEqualToNumber:sVid] && [pid isEqualToNumber:sPid]) {
                return s;
            }
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
               selector: @selector(handleSystemWake:)
                   name: NSWorkspaceDidWakeNotification
                 object: nil];
        /// Periodic safety net — 5 seconds polling to detect reconnection without sleep/wake cycle
        _reactivateTimer = [NSTimer scheduledTimerWithTimeInterval: 5.0
                                                            target: self
                                                          selector: @selector(periodicCheck)
                                                          userInfo: nil
                                                           repeats: YES];
    }
    return self;
}

- (void)handleSystemWake:(NSNotification *)notification {
    DDLogInfo(@"LogitechCIDActivator: System woke up. Scheduling reactivation in 0.8 seconds...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self reactivateAll];
    });
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
    if (vid == nil || vid.intValue != 0x046d) {
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
    
    [_states addObject: [NSValue valueWithPointer: s]];
    
    if (configured >= 0) {
        DDLogInfo(@"LogitechCIDActivator: configured %d CID(s) on '%@'", configured, name);
        Device *attachedDev = [DeviceManager attachedDeviceWithIOHIDDevice:device];
        if (attachedDev) {
            if (s->featReprogV4 != 0) {
                attachedDev.isLogitechDiverted = YES;
            } else {
                attachedDev.isLogitechDiverted = NO;
            }
            [self queryBatteryAndDPIForDevice:attachedDev];
        }
    } else {
        DDLogError(@"LogitechCIDActivator: Failed to configure device '%@'.", name);
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
            
            int percentage = s->resp[4];
            int status = s->resp[6];
            BOOL isDischarging = (status == 0x00);
            
            int threshold = 0;
            if (percentage <= 10) {
                threshold = 10;
            } else if (percentage <= 20) {
                threshold = 20;
            } else if (percentage <= 50) {
                threshold = 50;
            }
            
            if (s->lastNotifiedBatteryLevel == 0) {
                // Initialize on first run to prevent notifying immediately on start if already low
                if (percentage > 50) {
                    s->lastNotifiedBatteryLevel = 100;
                } else if (percentage > 20) {
                    s->lastNotifiedBatteryLevel = 50;
                } else if (percentage > 10) {
                    s->lastNotifiedBatteryLevel = 20;
                } else {
                    s->lastNotifiedBatteryLevel = 10;
                }
            } else {
                if (threshold > 0) {
                    if (s->lastNotifiedBatteryLevel > threshold) {
                        s->lastNotifiedBatteryLevel = threshold;
                        if (isDischarging) {
                            [self postLowBatteryNotificationForDevice:device percentage:percentage threshold:threshold];
                        }
                    }
                } else {
                    if (percentage > 50) {
                        s->lastNotifiedBatteryLevel = 100; // Reset threshold
                    }
                }
            }
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
        device.supportsLogitechDPI = YES;
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
            dispatch_async(dispatch_get_main_queue(), ^{
                [PointerSpeed setForAllDevices];
            });
        }
    } else {
        DDLogWarn(@"LogitechCIDActivator: Adjustable DPI feature (0x2201/0x2202) not found on device");
    }
}

- (void)periodicCheck {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    for (NSValue *v in _states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        Device *attachedDev = [DeviceManager attachedDeviceWithIOHIDDevice:s->device];
        if (attachedDev != nil) {
            // Periodic background battery level monitoring (every 30 minutes)
            if (s->lastBatteryQueryTime == 0 || (now - s->lastBatteryQueryTime >= 1800.0)) {
                s->lastBatteryQueryTime = now;
                DDLogInfo(@"LogitechCIDActivator: Background querying battery level for device '%@'", attachedDev.name);
                [self queryBatteryAndDPIForDevice:attachedDev];
            }
            
            // Re-activation check
            if (s->featReprogV4 != 0 && !attachedDev.isLogitechDiverted) {
                DDLogInfo(@"LogitechCIDActivator: Periodic check detected device '%@' is not diverted. Reactivating...", attachedDev.name);
                sIsActivatingOrReactivating = YES;
                int activeCount = activateDevice(s);
                sIsActivatingOrReactivating = NO;
                if (activeCount > 0) {
                    attachedDev.isLogitechDiverted = YES;
                    [self queryBatteryAndDPIForDevice:attachedDev];
                }
            }
        }
    }
}

- (void)reactivateDeviceWithIOHIDDevice:(IOHIDDeviceRef)device {
    if (!device) return;
    sIsActivatingOrReactivating = YES;
    MFCIDDeviceState *s = stateForDevice(device);
    if (s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        DDLogInfo(@"LogitechCIDActivator: Manually triggering activation for device '%@'", name);
        int activeCount = activateDevice(s);
        sIsActivatingOrReactivating = NO; // MUST reset before querying!
        if (activeCount >= 0) {
            Device *attachedDev = [DeviceManager attachedDeviceWithIOHIDDevice:device];
            if (attachedDev) {
                if (s->featReprogV4 != 0) {
                    attachedDev.isLogitechDiverted = YES;
                } else {
                    attachedDev.isLogitechDiverted = NO;
                }
                [self queryBatteryAndDPIForDevice:attachedDev];
            }
        }
    } else {
        sIsActivatingOrReactivating = NO; // Reset before handleDeviceAttached
        DDLogWarn(@"LogitechCIDActivator: Cannot reactivate device, no state found for this IOHIDDeviceRef. Trying to handle as attached.");
        [self handleDeviceAttached:device];
    }
}

- (BOOL)anyAttachedDeviceSupportsSmartShift {
    for (NSValue *v in _states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        if (s->featSmartShift != 0) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)toggleSmartShiftForDevice:(IOHIDDeviceRef)device {
    DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice entered for device %p", device);
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: state not found directly for '%@'. Searching siblings...", name);
        if (name != nil) {
            for (NSValue *v in _states) {
                MFCIDDeviceState *otherS = (MFCIDDeviceState *)v.pointerValue;
                NSString *otherName = (__bridge NSString *)IOHIDDeviceGetProperty(otherS->device, CFSTR(kIOHIDProductKey));
                if ([name isEqualToString:otherName]) {
                    s = otherS;
                    DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: found matching sibling state: '%@'", otherName);
                    break;
                }
            }
        }
    }
    if (!s) {
        DDLogWarn(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice failed: Device state not found!");
        return NO;
    }
    DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: featSmartShift = 0x%02X, deviceIndex = 0x%02X", s->featSmartShift, s->deviceIndex);
    if (s->featSmartShift == 0) {
        DDLogWarn(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: SmartShift feature not supported (featSmartShift is 0)");
        return NO;
    }
    
    // 1. Get current mode
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featSmartShift;
    pkt[3] = 0x1E; // Function 1 (getStatus), software ID 0xE -> 0x1E
    
    DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: Sending getStatus command...");
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret != kIOReturnSuccess) {
        DDLogError(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice failed to get current mode, error: 0x%x, lastError: 0x%02X", ret, s->lastErrorCode);
        return NO;
    }
    
    uint8_t currentMode = s->resp[4]; // 2 = SmartShift, 1 = Freespin, 0 = Ratchet
    uint8_t newMode;
    if (currentMode == 1) {
        newMode = 2; // 优先切回 SmartShift (自动切换)
    } else {
        newMode = 1; // 切到 Free-spin (固定无阻尼)
    }
    DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: Current mode is %d. Toggling to %d...", currentMode, newMode);
    
    // 2. Set new mode
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featSmartShift;
    pkt[3] = 0x2E; // Function 2 (setStatus), software ID 0xE -> 0x2E
    pkt[4] = newMode;
    
    ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret != kIOReturnSuccess) {
        DDLogWarn(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: Set mode to %d failed with error: 0x%x, lastError: 0x%02X", newMode, ret, s->lastErrorCode);
        
        // 如果之前尝试切回 SmartShift (2) 失败，可能是设备不支持自动切换，我们降级切回 Ratchet (0)
        if (newMode == 2) {
            newMode = 0;
            pkt[4] = newMode;
            DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: Falling back to set mode to %d (Ratchet)...", newMode);
            ret = sendAndWaitWithTimeout(s, pkt, 100);
            if (ret != kIOReturnSuccess) {
                DDLogError(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice failed on fallback to %d, error: 0x%x, lastError: 0x%02X", newMode, ret, s->lastErrorCode);
                return NO;
            }
        } else {
            return NO;
        }
    }
    
    DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - SmartShift mode toggled successfully from %d to %d", currentMode, newMode);
    return YES;
}

- (BOOL)getSmartShiftState:(LogitechSmartShiftState *)outState forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
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
    if (!s || s->featSmartShift == 0) return NO;
    
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featSmartShift;
    pkt[3] = 0x0E; // Function 0
    
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret != kIOReturnSuccess) {
        pkt[3] = 0x1E; // Try fallback to Function 1
        ret = sendAndWaitWithTimeout(s, pkt, 100);
        if (ret != kIOReturnSuccess) {
            return NO;
        }
    }
    
    BOOL is2111 = (s->featSmartShift == lookupFeature(s, 0x2111));
    outState->supportsTunableTorque = is2111;
    
    if (pkt[3] == 0x1E) {
        uint8_t currentMode = s->resp[4];
        if (currentMode == 2) {
            outState->autoShift = 1;
            outState->wheelMode = 1;
        } else if (currentMode == 1) {
            outState->autoShift = 0;
            outState->wheelMode = 0;
        } else {
            outState->autoShift = 0;
            outState->wheelMode = 1;
        }
        outState->threshold = 20;
        outState->torque = 0;
    } else {
        outState->wheelMode = s->resp[4];
        outState->autoShift = s->resp[5];
        outState->threshold = s->resp[6];
        if (is2111) {
            outState->torque = s->resp[7];
        } else {
            outState->torque = 0;
        }
    }
    return YES;
}

- (BOOL)setSmartShiftState:(LogitechSmartShiftState)state forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
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
    if (!s || s->featSmartShift == 0) return NO;
    
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featSmartShift;
    pkt[3] = 0x1E; // Function 1
    pkt[4] = state.wheelMode;
    pkt[5] = state.autoShift;
    pkt[6] = state.threshold;
    
    BOOL is2111 = (s->featSmartShift == lookupFeature(s, 0x2111));
    if (is2111) {
        pkt[7] = state.torque;
    } else {
        pkt[7] = 0;
    }
    
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret != kIOReturnSuccess) {
        memset(pkt, 0, 20);
        pkt[0] = kHIDPP_Long;
        pkt[1] = s->deviceIndex;
        pkt[2] = s->featSmartShift;
        pkt[3] = 0x2E; // Function 2
        
        uint8_t mode = 0;
        if (state.autoShift == 1) {
            mode = 2;
        } else if (state.wheelMode == 0) {
            mode = 1;
        } else {
            mode = 0;
        }
        pkt[4] = mode;
        ret = sendAndWaitWithTimeout(s, pkt, 100);
        if (ret != kIOReturnSuccess && mode == 2) {
            pkt[4] = 0;
            ret = sendAndWaitWithTimeout(s, pkt, 100);
        }
    }
    return (ret == kIOReturnSuccess);
}

- (BOOL)getDPICapabilities:(LogitechDPICapabilities *)outCaps forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
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
    if (!s) return NO;
    uint8_t feat = s->featExtendedDpi != 0 ? s->featExtendedDpi : s->featAdjustableDpi;
    if (feat == 0) return NO;
    
    NSMutableData *dpiData = [NSMutableData data];
    uint8_t pkt[20];
    BOOL isExtended = (s->featExtendedDpi != 0);
    uint8_t function = isExtended ? 0x2E : 0x1E; // Function 2 for 0x2202, Function 1 for 0x2201 (both + swId 0x0E)
    int ignoreCount = isExtended ? 3 : 1;
    
    for (int page = 0; page < 8; page++) {
        memset(pkt, 0, 20);
        pkt[0] = kHIDPP_Long;
        pkt[1] = s->deviceIndex;
        pkt[2] = feat;
        pkt[3] = function;
        pkt[4] = 0;    // Sensor Index 0
        pkt[5] = 0;    // Direction 0 (X axis)
        pkt[6] = page; // Page index
        
        IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
        if (ret != kIOReturnSuccess) {
            break;
        }
        
        int dataOffset = 4 + ignoreCount;
        int dataLen = 16 - ignoreCount;
        if (dataOffset < 20 && dataLen > 0) {
            [dpiData appendBytes:&s->resp[dataOffset] length:dataLen];
        }
        
        if (dpiData.length >= 2) {
            const uint8_t *bytes = (const uint8_t *)dpiData.bytes;
            if (bytes[dpiData.length - 1] == 0x00 && bytes[dpiData.length - 2] == 0x00) {
                break;
            }
        }
    }
    
    NSMutableArray<NSNumber *> *dpiList = [NSMutableArray array];
    const uint8_t *bytes = (const uint8_t *)dpiData.bytes;
    NSUInteger len = dpiData.length;
    NSUInteger idx = 0;
    
    while (idx + 1 < len) {
        uint16_t val = (bytes[idx] << 8) | bytes[idx + 1];
        if (val == 0) {
            break;
        }
        if ((val >> 13) == 0x07) { // 0b111
            uint16_t step = val & 0x1FFF;
            if (idx + 3 >= len) {
                break;
            }
            uint16_t last = (bytes[idx + 2] << 8) | bytes[idx + 3];
            if (dpiList.count > 0 && step > 0 && last >= [dpiList.lastObject unsignedShortValue]) {
                uint16_t start = [dpiList.lastObject unsignedShortValue] + step;
                for (uint32_t d = start; d <= last; d += step) {
                    [dpiList addObject:@(d)];
                }
            }
            idx += 4;
        } else {
            [dpiList addObject:@(val)];
            idx += 2;
        }
    }
    
    uint16_t minDpi = 200;
    uint16_t maxDpi = 4000;
    uint16_t step = 50;
    
    if (dpiList.count >= 2) {
        minDpi = [dpiList.firstObject unsignedShortValue];
        maxDpi = [dpiList.lastObject unsignedShortValue];
        step = [dpiList[1] unsignedShortValue] - minDpi;
    } else if (dpiList.count == 1) {
        minDpi = [dpiList.firstObject unsignedShortValue];
        maxDpi = minDpi;
        step = 50;
    }
    
    outCaps->minDpi = minDpi;
    outCaps->maxDpi = maxDpi;
    outCaps->step = step;
    
    if (s->featExtendedDpi != 0 && outCaps->maxDpi < 8000) {
        outCaps->maxDpi = 8000;
    }
    
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    if (s->featExtendedDpi != 0) {
        pkt[2] = s->featExtendedDpi;
        pkt[3] = 0x5E; // Function 5 (GetSensorDpi) for 0x2202
    } else {
        pkt[2] = s->featAdjustableDpi;
        pkt[3] = 0x2E; // Function 2 (GetSensorDpi) for 0x2201
    }
    pkt[4] = 0;    // Sensor Index 0
    
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret == kIOReturnSuccess) {
        int dpi = (s->resp[5] << 8) | s->resp[6];
        if (dpi == 0 && s->featExtendedDpi == 0) {
            dpi = (s->resp[7] << 8) | s->resp[8];
        }
        outCaps->currentDpi = dpi;
        outCaps->defaultDpi = dpi;
    } else {
        outCaps->currentDpi = 1000;
        outCaps->defaultDpi = 1000;
    }
    
    return YES;
}

- (BOOL)setDpi:(uint16_t)dpi forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
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
    if (!s) return NO;
    
    uint8_t feat = s->featExtendedDpi != 0 ? s->featExtendedDpi : s->featAdjustableDpi;
    if (feat == 0) return NO;
    
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = feat;
    
    if (s->featExtendedDpi != 0) {
        pkt[3] = 0x6E; // Function 6 (SetSensorDpi) for 0x2202
        pkt[4] = 0;    // Sensor Index 0
        pkt[5] = (dpi >> 8) & 0xFF;
        pkt[6] = dpi & 0xFF;
        pkt[7] = (dpi >> 8) & 0xFF; // Y axis DPI same
        pkt[8] = dpi & 0xFF;
        pkt[9] = 0;    // LOD (Default/High)
    } else {
        pkt[3] = 0x3E; // Function 3 (SetSensorDpi) for 0x2201
        pkt[4] = 0;    // Sensor Index 0
        pkt[5] = (dpi >> 8) & 0xFF;
        pkt[6] = dpi & 0xFF;
    }
    
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret == kIOReturnSuccess) {
        Device *attachedDev = [DeviceManager attachedDeviceWithIOHIDDevice:device];
        if (attachedDev) {
            attachedDev.logitechDPI = dpi;
        }
    }
    return (ret == kIOReturnSuccess);
}

- (void)postLowBatteryNotificationForDevice:(Device *)device percentage:(int)percentage threshold:(int)threshold {
    if (@available(macOS 10.14, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted) {
                UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
                
                NSString *title = @"Mouse Battery Low";
                NSString *bodyFormat = @"%@ battery is low: %d%%";
                NSString *prefLanguage = [[NSLocale preferredLanguages] firstObject];
                if ([prefLanguage hasPrefix:@"zh"]) {
                    title = @"鼠标电量低";
                    bodyFormat = @"%@ 电量低: %d%%";
                }
                
                content.title = title;
                NSString *deviceName = device.name ?: @"Mouse";
                content.body = [NSString stringWithFormat:bodyFormat, deviceName, percentage];
                content.sound = [UNNotificationSound defaultSound];
                
                NSString *identifier = [NSString stringWithFormat:@"mmf-battery-%@-%d", [device uniqueID], threshold];
                
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:nil];
                [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable err) {
                    if (err) {
                        DDLogError(@"LogitechCIDActivator: Failed to post notification: %@", err);
                    } else {
                        DDLogInfo(@"LogitechCIDActivator: Posted low battery notification for %@ (%d%%)", deviceName, percentage);
                    }
                }];
            } else {
                DDLogWarn(@"LogitechCIDActivator: Notification permission denied: %@", error);
            }
        }];
    }
}

@end
