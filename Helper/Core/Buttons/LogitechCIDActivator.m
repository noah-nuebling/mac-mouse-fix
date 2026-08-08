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

#define kLogitechVID    0x046D
#define kHIDPP_Long     0x11
#define kHIDPP_Device   0xFF
#define kFeat_ReprogV4  0x1B04

/// SetCidReporting flags — Solaar hidpp20.py "valid bit" pattern:
///   each flag bit has a corresponding valid bit = flag << 1
///   0x03 = divert=1 (bit0) + divert_valid=1 (bit1)
#define kDivertFlags    0x03

/// TIDs of controls that already report natively — must NOT be diverted
///   0x0038=left, 0x0039=right, 0x003A=middle, 0x003C=back, 0x003E=forward
static const uint16_t kNativeTIDs[] = { 0x0038, 0x0039, 0x003A, 0x003C, 0x003E };

/// CGEvent button numbers are 0-based. 5 = MMF "button 6" (first above L/R/M/Back/Fwd)
#define kFirstCGButton  6

typedef struct {
    IOHIDDeviceRef  device;
    uint8_t         reportBuf[64];
    uint16_t        cidMap[32];
    int             cidCount;
    uint16_t        pressedCIDs[32];
    int             pressedCount;
} MFCIDDeviceState;

static uint8_t sResp[20];
static BOOL    sGotResp = NO;

static BOOL isNativeTID(uint16_t tid) {
    for (int i = 0; i < 5; i++) if (kNativeTIDs[i] == tid) return YES;
    return NO;
}

static int buttonForCID(MFCIDDeviceState *s, uint16_t cid) {
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
    if (report[3] != 0x00) {
        memcpy(sResp, report, len < 20 ? (size_t)len : 20);
        sGotResp = YES;
        return;
    }
    uint16_t cid = ((uint16_t)report[4] << 8) | report[5];
    if (cid == 0) {
        for (int i = 0; i < s->pressedCount; i++) injectButton(s, s->pressedCIDs[i], NO);
        s->pressedCount = 0;
    } else {
        for (int i = 0; i < s->pressedCount; i++) if (s->pressedCIDs[i] == cid) return;
        injectButton(s, cid, YES);
        if (s->pressedCount < 32) s->pressedCIDs[s->pressedCount++] = cid;
    }
}

static IOReturn sendAndWait(IOHIDDeviceRef dev, uint8_t *pkt) {
    sGotResp = NO;
    IOReturn r = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, pkt[0], pkt, 20);
    if (r != kIOReturnSuccess) return r;
    for (int i = 0; i < 100 && !sGotResp; i++) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
    if (!sGotResp) return kIOReturnTimeout;
    if (sResp[2] == 0xFF) return kIOReturnError;
    return kIOReturnSuccess;
}

static int activateDevice(IOHIDDeviceRef dev, MFCIDDeviceState *s) {
    uint8_t pkt[20];

    /// 1. GetFeature(0x1B04)
    memset(pkt, 0, 20);
    pkt[0]=kHIDPP_Long; pkt[1]=kHIDPP_Device; pkt[2]=0x00; pkt[3]=0x0E;
    pkt[4]=(kFeat_ReprogV4>>8)&0xFF; pkt[5]=kFeat_ReprogV4&0xFF;
    if (sendAndWait(dev, pkt) != kIOReturnSuccess || sResp[4] == 0) return 0;
    uint8_t feat = sResp[4];

    /// 2. GetCount
    memset(pkt, 0, 20);
    pkt[0]=kHIDPP_Long; pkt[1]=kHIDPP_Device; pkt[2]=feat; pkt[3]=0x0E;
    if (sendAndWait(dev, pkt) != kIOReturnSuccess) return 0;
    int count = sResp[4];

    /// 3. GetCidInfo — collect divertable CIDs
    uint16_t todivert[32]; int ndiv = 0;
    for (int i = 0; i < count && ndiv < 32; i++) {
        memset(pkt, 0, 20);
        pkt[0]=kHIDPP_Long; pkt[1]=kHIDPP_Device; pkt[2]=feat; pkt[3]=0x1E; pkt[4]=(uint8_t)i;
        if (sendAndWait(dev, pkt) != kIOReturnSuccess) continue;
        uint16_t cid = ((uint16_t)sResp[4]<<8)|sResp[5];
        uint16_t tid = ((uint16_t)sResp[6]<<8)|sResp[7];
        uint8_t flags = sResp[8];
        if ((flags & (1<<4)) && !isNativeTID(tid)) todivert[ndiv++] = cid;
    }

    /// 4. Pre-register button mapping for stable numbering
    for (int i = 0; i < ndiv; i++) buttonForCID(s, todivert[i]);

    /// 5. SetCidReporting — divert
    int diverted = 0;
    for (int i = 0; i < ndiv; i++) {
        memset(pkt, 0, 20);
        pkt[0]=kHIDPP_Long; pkt[1]=kHIDPP_Device; pkt[2]=feat; pkt[3]=0x3E;
        pkt[4]=(todivert[i]>>8)&0xFF; pkt[5]=todivert[i]&0xFF; pkt[6]=kDivertFlags;
        if (sendAndWait(dev, pkt) == kIOReturnSuccess) diverted++;
    }
    return diverted;
}

@interface LogitechCIDActivator ()
@property (nonatomic) NSMutableArray *states;
@property (nonatomic) NSTimer *reactivateTimer;
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
    for (NSValue *v in _states) {
        MFCIDDeviceState *s = (MFCIDDeviceState *)v.pointerValue;
        activateDevice(s->device, s);
    }
    DDLogDebug(@"LogitechCIDActivator: re-activated %lu device(s)", (unsigned long)_states.count);
}

- (void)handleDeviceAttached: (IOHIDDeviceRef)device {
    NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    if (vid.integerValue != kLogitechVID) return;
    if (IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone) != kIOReturnSuccess) return;

    MFCIDDeviceState *s = calloc(1, sizeof(MFCIDDeviceState));
    s->device = device;
    IOHIDDeviceRegisterInputReportCallback(device, s->reportBuf, sizeof(s->reportBuf), inputReportCallback, s);
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);

    int diverted = activateDevice(device, s);
    if (diverted > 0) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        DDLogInfo(@"LogitechCIDActivator: diverted %d CIDs on '%@'", diverted, name);
        [_states addObject: [NSValue valueWithPointer: s]];
    } else {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
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
    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
    free(s);
    [_states removeObject: found];
}

@end
