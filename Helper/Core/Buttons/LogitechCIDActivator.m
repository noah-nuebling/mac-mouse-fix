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
    uint8_t         waitingFeature;
    uint8_t         waitingFunction;
    uint8_t         featWirelessStatus;
    uint8_t         featReprogV4;
    uint8_t         featSmartShift;
    uint8_t         featAdjustableDpi;  // 0x2201
    uint8_t         featExtendedDpi;    // 0x2202
    uint8_t         featHiResWheel;     // 0x2121
    uint8_t         featReportRate;     // 0x8060
    uint8_t         featReportRateExt;  // 0x8061
    uint8_t         lastErrorCode;
    int             lastNotifiedBatteryLevel;
    NSTimeInterval  lastBatteryQueryTime;
    BOOL            isSmartShiftEnhanced;
    uint8_t         featBattery;
    BOOL            isBattery1004;
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
    //    Match by deviceIndex AND require long-report type (0x11) to avoid
    //    misinterpreting short unsolicited notifications as our response.
    BOOL isResponse = NO;
    if (s->waitingIndex == report[1] && report[0] == kHIDPP_Long) {
        if (report[2] == 0xFF) {
            // Error response: Software ID is in report[4]
            // report[3] is the feature index
            if (len >= 5 && report[3] == s->waitingFeature && (report[4] & 0x0F) == 0x0E && (report[4] & 0xF0) == (s->waitingFunction & 0xF0)) {
                isResponse = YES;
            }
        } else {
            // Normal response: Software ID is in report[3]
            // report[2] is the feature index
            if (report[2] == s->waitingFeature && (report[3] & 0x0F) == 0x0E && (report[3] & 0xF0) == (s->waitingFunction & 0xF0)) {
                isResponse = YES;
            }
        }
    }
    if (isResponse) {
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
    s->waitingFeature = pkt[2];
    s->waitingFunction = pkt[3];
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
    return sendAndWaitWithTimeout(s, pkt, 30);
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
        
        if (sendAndWaitWithTimeout(s, pkt, 10) == kIOReturnSuccess && s->resp[2] == 0x00) {
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
    if (s->featSmartShift != 0) {
        s->isSmartShiftEnhanced = YES;
    } else {
        s->featSmartShift = lookupFeature(s, 0x2110);
        s->isSmartShiftEnhanced = NO;
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

    // Probe HiRes Scroll Wheel (0x2121)
    s->featHiResWheel = lookupFeature(s, 0x2121);
    if (s->featHiResWheel != 0) {
        DDLogInfo(@"LogitechCIDActivator: Found HiRes Scroll Wheel feature index 0x%02X on index 0x%02X", s->featHiResWheel, activeIndex);
    } else {
        DDLogInfo(@"LogitechCIDActivator: HiRes Scroll Wheel feature not supported on index 0x%02X", activeIndex);
    }

    // Probe Report Rate (0x8060 / 0x8061)
    s->featReportRate = lookupFeature(s, 0x8060);
    s->featReportRateExt = lookupFeature(s, 0x8061);
    if (s->featReportRate != 0 || s->featReportRateExt != 0) {
        DDLogInfo(@"LogitechCIDActivator: Found Report Rate feature (0x8060 idx: 0x%02X, 0x8061 idx: 0x%02X) on index 0x%02X",
                  s->featReportRate, s->featReportRateExt, activeIndex);
    } else {
        DDLogInfo(@"LogitechCIDActivator: Report Rate feature not supported on index 0x%02X", activeIndex);
    }

    // Probe Battery Features (0x1004 / 0x1000)
    s->featBattery = lookupFeature(s, 0x1004);
    s->isBattery1004 = YES;
    if (s->featBattery == 0) {
        s->featBattery = lookupFeature(s, 0x1000);
        s->isBattery1004 = NO;
    }
    if (s->featBattery != 0) {
        DDLogInfo(@"LogitechCIDActivator: Found Battery feature index 0x%02X (is 0x1004 Unified Battery: %d) on index 0x%02X",
                  s->featBattery, s->isBattery1004, activeIndex);
    } else {
        DDLogWarn(@"LogitechCIDActivator: Battery features (0x1004/0x1000) not supported on index 0x%02X", activeIndex);
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
    
    // Apply persisted settings to the hardware when device is configured.
    // Check BOTH featAdjustableDpi (0x2201) and featExtendedDpi (0x2202) —
    // newer mice (e.g. MX Anywhere 3S) only support 0x2202.
    if (s->featAdjustableDpi != 0 || s->featExtendedDpi != 0) {
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

    // Restore saved HiRes Scroll Wheel setting + firmware scroll direction
    if (s->featHiResWheel != 0) {
        NSNumber *savedHiRes = (NSNumber *)config(@"Pointer.logitechHiResWheel");
        if (savedHiRes != nil) {
            BOOL hiResEnabled = [savedHiRes boolValue];
            DDLogInfo(@"LogitechCIDActivator: activateDevice applying saved HiRes Scroll setting: %d", hiResEnabled);
            [[LogitechCIDActivator shared] setHiResWheelMode:hiResEnabled forDevice:s->device];
        } else {
            // Device supports 0x2121 but user hasn't toggled HiRes yet.
            // Write default config so Scroll.m can use its existence as a reliable
            // indicator that firmware handles scroll direction inversion.
            setConfig(@"Pointer.logitechHiResWheel", @NO);
            commitConfig();
            BOOL shouldInvert = [(NSNumber *)config(@"Scroll.reverseDirection") boolValue];
            [[LogitechCIDActivator shared] setFirmwareScrollDirection:shouldInvert forDevice:s->device];
        }
    }

    // Restore saved Report Rate setting
    if (s->featReportRate != 0) {
        NSNumber *savedRate = (NSNumber *)config(@"Pointer.logitechReportRate");
        if (savedRate != nil) {
            uint8_t rateIndex = [savedRate unsignedCharValue];
            DDLogInfo(@"LogitechCIDActivator: activateDevice applying saved Report Rate index: %d", rateIndex);
            [[LogitechCIDActivator shared] setReportRate:rateIndex forDevice:s->device];
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
    if (sendAndWaitWithTimeout(s, pkt, 15) != kIOReturnSuccess) {
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
    if (!dev) return NULL;
    
    NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDProductKey));
    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDVendorIDKey));
    NSNumber *pid = (__bridge NSNumber *)IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDProductIDKey));
    
    // 如果没有 VID，只能做精确指针匹配
    if (vid == nil) {
        for (NSValue *v in activator.states) {
            MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
            if (s->device == dev || s->writeDevice == dev) {
                return s;
            }
        }
        return NULL;
    }
    
    // 搜集所有可能代表该物理鼠标（同名同VID）的状态
    NSMutableArray<NSValue *> *candidates = [NSMutableArray array];
    for (NSValue *v in activator.states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        BOOL isMatch = (s->device == dev || s->writeDevice == dev);
        if (!isMatch && name != nil) {
            NSString *sName = (__bridge NSString *)IOHIDDeviceGetProperty(s->device, CFSTR(kIOHIDProductKey));
            NSNumber *sVid = (__bridge NSNumber *)IOHIDDeviceGetProperty(s->device, CFSTR(kIOHIDVendorIDKey));
            if ([vid isEqualToNumber:sVid] && [name isEqualToString:sName]) {
                isMatch = YES;
            }
        }
        if (isMatch) {
            [candidates addObject:v];
        }
    }
    
    // 如果同名同VID未找到，尝试同PID（以防名字由于驱动等原因不完全一致）
    if (candidates.count == 0 && pid != nil) {
        for (NSValue *v in activator.states) {
            MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
            NSNumber *sVid = (__bridge NSNumber *)IOHIDDeviceGetProperty(s->device, CFSTR(kIOHIDVendorIDKey));
            NSNumber *sPid = (__bridge NSNumber *)IOHIDDeviceGetProperty(s->device, CFSTR(kIOHIDProductIDKey));
            if ([vid isEqualToNumber:sVid] && [pid isEqualToNumber:sPid]) {
                [candidates addObject:v];
            }
        }
    }
    
    if (candidates.count == 0) return NULL;
    
    // 遍历候选状态，选出功能最强大的那个（即 0x2111 Enhanced 智能无阻拥有者优先，其次为 0x2110）
    MFCIDDeviceState *bestState = NULL;
    for (NSValue *v in candidates) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        if (bestState == NULL) {
            bestState = s;
            continue;
        }
        
        BOOL sHasSmartShift = (s->featSmartShift != 0);
        BOOL bHasSmartShift = (bestState->featSmartShift != 0);
        
        if (sHasSmartShift && !bHasSmartShift) {
            bestState = s;
        } else if (sHasSmartShift && bHasSmartShift) {
            // 两者均支持，优先选择 Enhanced 属性的
            if (s->isSmartShiftEnhanced && !bestState->isSmartShiftEnhanced) {
                bestState = s;
            }
        } else if (s->featReprogV4 != 0 && bestState->featReprogV4 == 0) {
            bestState = s;
        }
    }
    
    return bestState;
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
    uint8_t featBattery = s->featBattery;
    BOOL is1004 = s->isBattery1004;
    
    if (featBattery != 0) {
        uint8_t pkt[20];
        memset(pkt, 0, 20);
        pkt[0] = kHIDPP_Long;
        pkt[1] = s->deviceIndex;
        pkt[2] = featBattery;
        pkt[3] = is1004 ? 0x1E : 0x0E; // Function 1 for 0x1004, Function 0 for 0x1000 (with software ID 0x0E)
        if (sendAndWaitWithTimeout(s, pkt, 30) == kIOReturnSuccess) {
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
    
    // 2. Query DPI — use cached feature indices from activateDevice() instead of re-querying.
    //    Re-querying via lookupFeature wastes HID++ bandwidth and can fail during reconnect windows.
    //    Prefer Extended DPI (0x2202) over standard (0x2201) to match setDpi: write priority.
    uint8_t featDPI = 0;
    BOOL isExtendedDPI = NO;
    if (s->featExtendedDpi != 0) {
        featDPI = s->featExtendedDpi;
        isExtendedDPI = YES;
    } else if (s->featAdjustableDpi != 0) {
        featDPI = s->featAdjustableDpi;
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
        if (sendAndWaitWithTimeout(s, pkt, 30) == kIOReturnSuccess) {
            DDLogInfo(@"LogitechCIDActivator: DPI raw response: [%02x %02x %02x %02x %02x %02x %02x %02x %02x %02x]",
                      s->resp[0], s->resp[1], s->resp[2], s->resp[3], s->resp[4], s->resp[5], s->resp[6], s->resp[7], s->resp[8], s->resp[9]);
            int dpi = (s->resp[5] << 8) | s->resp[6];
            if (dpi == 0 && !isExtendedDPI) {
                dpi = (s->resp[7] << 8) | s->resp[8];
            }
            // Sanity check: only accept plausible DPI values (1–32000)
            if (dpi > 0 && dpi <= 32000) {
                device.logitechDPI = dpi;
                DDLogInfo(@"LogitechCIDActivator: DPI query successful (feat 0x%04X). DPI: %d", isExtendedDPI ? 0x2202 : 0x2201, device.logitechDPI);
            } else {
                DDLogWarn(@"LogitechCIDActivator: DPI query returned implausible value %d (feat 0x%04X), keeping previous DPI %d",
                          dpi, isExtendedDPI ? 0x2202 : 0x2201, device.logitechDPI);
            }
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
    
    static NSTimeInterval lastReactivateTime = 0;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - lastReactivateTime < 2.0) {
        DDLogInfo(@"LogitechCIDActivator: Skipping reactivation request for device because another reactivation occurred less than 2.0s ago.");
        return;
    }
    lastReactivateTime = now;
    
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
    BOOL is2111 = s->isSmartShiftEnhanced;
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featSmartShift;
    pkt[3] = is2111 ? 0x0E : 0x1E; // 0x2111 GetCapabilities is F0 (0x0E), 0x2110 GetStatus is F1 (0x1E)
    
    DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: Sending get command (is2111: %d)...", is2111);
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret != kIOReturnSuccess) {
        DDLogError(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice failed to get current state, error: 0x%x, lastError: 0x%02X", ret, s->lastErrorCode);
        return NO;
    }
    
    uint8_t newWheelMode = 1;
    uint8_t newAutoShift = 0;
    uint8_t newMode = 0;
    uint8_t threshold = s->resp[5];
    uint8_t torque = is2111 ? s->resp[7] : 0;
    
    if (is2111) {
        uint8_t wheelMode = s->resp[4];
        uint8_t autoShift = s->resp[5];
        threshold = s->resp[6];
        torque = s->resp[7];
        
        if (autoShift == 1) {
            // 当前是 SmartShift，切换到固定无阻 (Freespin)
            newWheelMode = 0;
            newAutoShift = 0;
        } else {
            // 否则切回自动 SmartShift
            newWheelMode = 1;
            newAutoShift = 1;
        }
        DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice (is2111): Current wheelMode: %d, autoShift: %d. Toggling to wheelMode: %d, autoShift: %d",
                  wheelMode, autoShift, newWheelMode, newAutoShift);
    } else {
        uint8_t currentMode = s->resp[4]; // 2 = SmartShift, 1 = Freespin, 0 = Ratchet
        if (currentMode == 1) {
            newMode = 2; // Freespin -> SmartShift
        } else {
            newMode = 1; // Ratchet/SmartShift -> Freespin
        }
        DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice (is2110): Current mode: %d. Toggling to mode: %d",
                  currentMode, newMode);
    }
    
    // 2. Set new mode
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featSmartShift;
    
    if (is2111) {
        // SmartShift Enhanced (0x2111): 写操作使用 Function 2 (0x2E)
        // payload: [mode, threshold, torque]
        // mode: 0=SmartShift/Auto, 1=Freespin, 2=Ratchet
        uint8_t mode2111 = 0;
        if (newAutoShift == 1) {
            mode2111 = 0; // SmartShift auto
        } else if (newWheelMode == 0) {
            mode2111 = 1; // Freespin
        } else {
            mode2111 = 2; // Ratchet
        }
        pkt[3] = 0x2E; // Function 2
        pkt[4] = mode2111;
        pkt[5] = threshold;
        pkt[6] = torque;
    } else {
        pkt[3] = 0x2E; // 0x2110 SetStatus is F2 (0x2E)
        pkt[4] = newMode;
        pkt[5] = threshold;
    }
    
    ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret != kIOReturnSuccess) {
        DDLogWarn(@"[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice: Set state failed with error: 0x%x, lastError: 0x%02X", ret, s->lastErrorCode);
        return NO;
    }
    
    if (is2111) {
        DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - SmartShift mode toggled successfully (Enhanced). wheelMode: %d, autoShift: %d", newWheelMode, newAutoShift);
    } else {
        DDLogInfo(@"[SMARTSHIFT] LogitechCIDActivator - SmartShift mode toggled successfully (Basic) to mode: %d", newMode);
    }
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
    
    BOOL is2111 = s->isSmartShiftEnhanced;
    outState->supportsTunableTorque = is2111;
    
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featSmartShift;
    
    if (is2111) {
        // SmartShift Enhanced (0x2111): 读状态使用 Function 1 (0x1E)
        pkt[3] = 0x1E;
    } else {
        // SmartShift Basic (0x2110): 读状态使用 Function 0 (0x0E)
        pkt[3] = 0x0E;
    }
    
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret != kIOReturnSuccess) {
        DDLogError(@"LogitechCIDActivator: getSmartShiftState failed with error 0x%x, lastError: 0x%02X", ret, s->lastErrorCode);
        return NO;
    }
    
    if (is2111) {
        // resp[4]: mode (0=SmartShift, 1=Freespin, 2=Ratchet)
        // resp[5]: threshold
        // resp[6]: torque
        uint8_t currentMode = s->resp[4];
        if (currentMode == 0) {
            outState->autoShift = 1;
            outState->wheelMode = 1;
        } else if (currentMode == 1) {
            outState->autoShift = 0;
            outState->wheelMode = 0;
        } else {
            outState->autoShift = 0;
            outState->wheelMode = 1;
        }
        outState->threshold = s->resp[5];
        outState->torque = s->resp[6];
        DDLogInfo(@"LogitechCIDActivator: getSmartShiftState (is2111) mode: %d, threshold: %d, torque: %d",
                  currentMode, outState->threshold, outState->torque);
    } else {
        // resp[4]: mode (2=SmartShift, 1=Freespin, 0=Ratchet)
        // resp[5]: threshold
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
        outState->threshold = s->resp[5];
        outState->torque = 0;
        DDLogInfo(@"LogitechCIDActivator: getSmartShiftState (is2110) mode: %d, threshold: %d",
                  currentMode, outState->threshold);
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
    
    BOOL is2111 = s->isSmartShiftEnhanced;
    
    // 计算硬件对应的模式值：
    // Enhanced (0x2111): 0 = SmartShift, 1 = Freespin, 2 = Ratchet
    // Basic (0x2110):    2 = SmartShift, 1 = Freespin, 0 = Ratchet
    uint8_t mode = 0;
    if (state.autoShift == 1) {
        mode = is2111 ? 0 : 2;
    } else if (state.wheelMode == 0) { // UI 中的 wheelMode 0=无阻，1=分段
        mode = 1;
    } else {
        mode = is2111 ? 2 : 0;
    }
    uint8_t threshold = state.threshold;
    if (threshold == 0) {
        threshold = 20; // 默认值
    } else if (threshold > 50) {
        threshold = 50; // 限制在罗技硬件的最大允许值 50
    }
    
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featSmartShift;
    
    if (is2111) {
        // SmartShift Enhanced (0x2111): 写操作使用 Function 2 (0x2E)
        pkt[3] = 0x2E;
        pkt[4] = mode;
        pkt[5] = threshold;
        pkt[6] = state.torque;
    } else {
        // SmartShift Basic (0x2110): 写操作使用 Function 1 (0x1E)
        pkt[3] = 0x1E;
        pkt[4] = mode;
        pkt[5] = threshold;
    }
    
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret != kIOReturnSuccess) {
        DDLogError(@"LogitechCIDActivator: setSmartShiftState failed with error 0x%x, lastError: 0x%02X (mode: %d, is2111: %d)",
                   ret, s->lastErrorCode, mode, is2111);
    } else {
        DDLogInfo(@"LogitechCIDActivator: setSmartShiftState successfully set mode: %d, threshold: %d, torque: %d (is2111: %d)",
                   mode, threshold, is2111 ? state.torque : 0, is2111);
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
        // Sanity check: only accept plausible DPI values
        if (dpi > 0 && dpi <= 32000) {
            outCaps->currentDpi = dpi;
            outCaps->defaultDpi = dpi;
        } else {
            DDLogWarn(@"LogitechCIDActivator: getDPICapabilities returned implausible DPI %d, using fallback 1000", dpi);
            outCaps->currentDpi = 1000;
            outCaps->defaultDpi = 1000;
        }
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

#pragma mark - HiRes Scroll Wheel (0x2121)

static uint16_t rateIndexToHz(uint8_t idx) {
    switch(idx) {
        case 1: return 125;
        case 2: return 250;
        case 3: return 500;
        case 4: return 1000;
        case 5: return 2000;
        case 6: return 4000;
        case 8: return 8000;
        default: return 0;
    }
}

- (BOOL)getHiResWheelState:(LogitechHiResWheelState *)outState forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        if (name != nil) {
            for (NSValue *v in _states) {
                MFCIDDeviceState *otherS = (MFCIDDeviceState *)v.pointerValue;
                NSString *otherName = (__bridge NSString *)IOHIDDeviceGetProperty(otherS->device, CFSTR(kIOHIDProductKey));
                if ([name isEqualToString:otherName]) { s = otherS; break; }
            }
        }
    }
    if (!s || s->featHiResWheel == 0) {
        outState->supported = NO;
        return NO;
    }
    
    outState->supported = YES;
    
    // Function 0 (0x0E): getWheelCapability
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featHiResWheel;
    pkt[3] = 0x0E; // Function 0
    
    if (sendAndWaitWithTimeout(s, pkt, 100) == kIOReturnSuccess) {
        outState->multiplier = s->resp[4];
        outState->hasRatchetSwitch = (s->resp[5] & 0x04) != 0; // bit 2
    } else {
        outState->multiplier = 8; // Fallback
        outState->hasRatchetSwitch = NO;
    }
    
    // Function 1 (0x1E): getWheelMode
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featHiResWheel;
    pkt[3] = 0x1E; // Function 1
    
    if (sendAndWaitWithTimeout(s, pkt, 100) == kIOReturnSuccess) {
        outState->hiResEnabled = (s->resp[4] & 0x02) != 0; // Bit 1 = hiRes enabled
        DDLogInfo(@"LogitechCIDActivator: HiRes Wheel state: enabled=%d, multiplier=%d", outState->hiResEnabled, outState->multiplier);
    } else {
        outState->hiResEnabled = NO;
    }
    
    return YES;
}

- (BOOL)setHiResWheelMode:(BOOL)enabled forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        if (name != nil) {
            for (NSValue *v in _states) {
                MFCIDDeviceState *otherS = (MFCIDDeviceState *)v.pointerValue;
                NSString *otherName = (__bridge NSString *)IOHIDDeviceGetProperty(otherS->device, CFSTR(kIOHIDProductKey));
                if ([name isEqualToString:otherName]) { s = otherS; break; }
            }
        }
    }
    if (!s || s->featHiResWheel == 0) return NO;
    
    // Function 2 (0x2E): setWheelMode
    // Bitmask flags in pkt[4]:
    //   bit 0 = invert value,  bit 1 = invert valid
    //   bit 2 = hiRes value,   bit 3 = hiRes valid
    // CRITICAL: Always set inversion bits alongside hiRes bits to prevent
    // firmware from resetting scroll direction when toggling HiRes mode.
    BOOL shouldInvert = [(NSNumber *)config(@"Scroll.reverseDirection") boolValue];
    
    uint8_t flags = 0;
    if (enabled) {
        flags |= 0x02; // Bit 1: HiresSmoothResolution (15x)
        if (shouldInvert) {
            flags |= 0x04; // Bit 2: HiresSmoothInvert (硬件反转方向)
        }
    }
    
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featHiResWheel;
    pkt[3] = 0x2E; // Function 2
    pkt[4] = flags;
    
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret == kIOReturnSuccess) {
        DDLogInfo(@"LogitechCIDActivator: HiRes Scroll Wheel mode set to %d, invert: %d (flags: 0x%02X)", enabled, shouldInvert, flags);
    } else {
        DDLogError(@"LogitechCIDActivator: Failed to set HiRes Scroll Wheel mode, error: 0x%x", ret);
    }
    return (ret == kIOReturnSuccess);
}

- (BOOL)setFirmwareScrollDirection:(BOOL)inverted forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        if (name != nil) {
            for (NSValue *v in _states) {
                MFCIDDeviceState *otherS = (MFCIDDeviceState *)v.pointerValue;
                NSString *otherName = (__bridge NSString *)IOHIDDeviceGetProperty(otherS->device, CFSTR(kIOHIDProductKey));
                if ([name isEqualToString:otherName]) { s = otherS; break; }
            }
        }
    }
    if (!s || s->featHiResWheel == 0) return NO;
    
    // Function 2 (0x2E): setWheelMode
    // CRITICAL: MX Anywhere 3S firmware treats the entire byte as a complete write.
    // Any bit pair with valid=0 will have its value reset to 0 by firmware.
    // We MUST always write ALL valid+value bits to avoid clearing hiRes state
    // when setting invert, and vice versa.
    // Read hiRes state from MMF config (not firmware — firmware may already be stale).
    BOOL hiResEnabled = [(NSNumber *)config(@"Pointer.logitechHiResWheel") boolValue];
    
    uint8_t flags = 0;
    if (hiResEnabled) {
        flags |= 0x02; // Bit 1: HiresSmoothResolution (15x)
        if (inverted) {
            flags |= 0x04; // Bit 2: HiresSmoothInvert
        }
    }
    
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featHiResWheel;
    pkt[3] = 0x2E; // Function 2
    pkt[4] = flags;
    
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret == kIOReturnSuccess) {
        DDLogInfo(@"LogitechCIDActivator: Firmware scroll direction set to %@ (hiRes: %d, flags: 0x%02X)", inverted ? @"inverted" : @"normal", hiResEnabled, flags);
    } else {
        DDLogError(@"LogitechCIDActivator: Failed to set firmware scroll direction, error: 0x%x", ret);
    }
    return (ret == kIOReturnSuccess);
}

#pragma mark - Report Rate (0x8060 / 0x8061)

- (BOOL)getReportRateInfo:(LogitechReportRateInfo *)outInfo forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        if (name != nil) {
            for (NSValue *v in _states) {
                MFCIDDeviceState *otherS = (MFCIDDeviceState *)v.pointerValue;
                NSString *otherName = (__bridge NSString *)IOHIDDeviceGetProperty(otherS->device, CFSTR(kIOHIDProductKey));
                if ([name isEqualToString:otherName]) { s = otherS; break; }
            }
        }
    }
    
    uint8_t feat = s ? (s->featReportRate != 0 ? s->featReportRate : s->featReportRateExt) : 0;
    if (!s || feat == 0) return NO;
    
    memset(outInfo, 0, sizeof(LogitechReportRateInfo));
    
    // Function 0 (0x0E): getReportRateList
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = feat;
    pkt[3] = 0x0E; // Function 0
    
    if (sendAndWaitWithTimeout(s, pkt, 100) == kIOReturnSuccess) {
        int count = 0;
        for (int i = 4; i < 12 && count < 8; i++) {
            if (s->resp[i] == 0) break;
            uint16_t hz = rateIndexToHz(s->resp[i]);
            if (hz > 0) {
                outInfo->rates[count++] = hz;
            }
        }
        outInfo->rateCount = count;
    }
    
    // Function 2 (0x2E): getReportRate
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = feat;
    pkt[3] = 0x2E; // Function 2
    
    if (sendAndWaitWithTimeout(s, pkt, 100) == kIOReturnSuccess) {
        outInfo->currentRate = s->resp[4];
        DDLogInfo(@"LogitechCIDActivator: Report Rate query: current index=%d (%d Hz), %d rates supported",
                  outInfo->currentRate, rateIndexToHz(outInfo->currentRate), outInfo->rateCount);
    }
    
    return YES;
}

- (BOOL)setReportRate:(uint8_t)rateIndex forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        if (name != nil) {
            for (NSValue *v in _states) {
                MFCIDDeviceState *otherS = (MFCIDDeviceState *)v.pointerValue;
                NSString *otherName = (__bridge NSString *)IOHIDDeviceGetProperty(otherS->device, CFSTR(kIOHIDProductKey));
                if ([name isEqualToString:otherName]) { s = otherS; break; }
            }
        }
    }
    
    uint8_t feat = s ? (s->featReportRate != 0 ? s->featReportRate : s->featReportRateExt) : 0;
    if (!s || feat == 0) return NO;
    
    // Function 3 (0x3E): setReportRate
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = feat;
    pkt[3] = 0x3E; // Function 3
    pkt[4] = rateIndex;
    
    IOReturn ret = sendAndWaitWithTimeout(s, pkt, 100);
    if (ret == kIOReturnSuccess) {
        DDLogInfo(@"LogitechCIDActivator: Report Rate set to index %d (%d Hz)", rateIndex, rateIndexToHz(rateIndex));
    } else {
        DDLogError(@"LogitechCIDActivator: Failed to set Report Rate, error: 0x%x", ret);
    }
    return (ret == kIOReturnSuccess);
}

@end
