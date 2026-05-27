//
// --------------------------------------------------------------------------
// ScrollOutputUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ScrollOutputUtility.h"
#import "Constants.h"
#import <CoreAudio/CoreAudio.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>
#import <IOKit/IOKitLib.h>
#import <dlfcn.h>

// ─── IOAVService DDC (arm64 external displays) ───────────────────────────────

typedef CFTypeRef IOAVServiceRef;
typedef IOReturn (*IOAVServiceWriteI2CFunc)(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void *buf, uint32_t size);
typedef IOAVServiceRef (*IOAVServiceCreateWithServiceFunc)(CFAllocatorRef allocator, io_service_t service);

static IOAVServiceWriteI2CFunc        _IOAVServiceWriteI2C        = NULL;
static IOAVServiceCreateWithServiceFunc _IOAVServiceCreateWithService = NULL;

static void loadIOAVServiceSymbols(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (!handle) handle = RTLD_DEFAULT;
        _IOAVServiceWriteI2C         = dlsym(handle, "IOAVServiceWriteI2C");
        _IOAVServiceCreateWithService = dlsym(handle, "IOAVServiceCreateWithService");
    });
}

// ─── OSD (private OSD.framework — same HUD as keyboard keys) ─────────────────

static void loadOSDFramework(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dlopen("/System/Library/PrivateFrameworks/OSD.framework/OSD", RTLD_LAZY);
    });
}

/// OSD image IDs
typedef NS_ENUM(int64_t, MFOSDImage) {
    MFOSDImageBrightness    = 1,
    MFOSDImageVolume        = 3,
    MFOSDImageVolumeMuted   = 4,
};

static void showOSD(CGDirectDisplayID displayID, MFOSDImage imageID, float value) {
    loadOSDFramework();
    
    /// Load OSDManager at runtime — it lives in the dyld shared cache, not a linkable stub
    Class OSDManagerClass = NSClassFromString(@"OSDManager");
    if (!OSDManagerClass) return;
    id mgr = [OSDManagerClass performSelector:@selector(sharedManager)];
    if (!mgr) return;
    
    /// 16 chiclets total, same as macOS keyboard HUD
    uint32_t filled = (uint32_t)roundf(value * 16.0f);
    filled = MIN(filled, 16);
    uint32_t total = 16;
    uint32_t priority = 0x1F4;
    uint32_t msec = 1000;
    BOOL locked = NO;
    
    /// Use NSInvocation since the method has too many args for performSelector
    SEL sel = @selector(showImage:onDisplayID:priority:msecUntilFade:filledChiclets:totalChiclets:locked:);
    NSMethodSignature *sig = [mgr methodSignatureForSelector:sel];
    if (!sig) return;
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:mgr];
    [inv setSelector:sel];
    [inv setArgument:&imageID      atIndex:2];
    [inv setArgument:&displayID    atIndex:3];
    [inv setArgument:&priority     atIndex:4];
    [inv setArgument:&msec         atIndex:5];
    [inv setArgument:&filled       atIndex:6];
    [inv setArgument:&total        atIndex:7];
    [inv setArgument:&locked       atIndex:8];
    [inv invoke];
}

// ─── DisplayServices (built-in display brightness) ───────────────────────────

typedef int (*DisplayServicesGetBrightnessFunc)(CGDirectDisplayID display, float *brightness);
typedef int (*DisplayServicesSetBrightnessFunc)(CGDirectDisplayID display, float brightness);

static void *displayServicesHandle(void) {
    static void *handle = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY);
    });
    return handle;
}

// ─── Brightness accumulator (for sub-step scroll deltas) ─────────────────────

static float _brightnessAccumulator = 0.0f;

@implementation ScrollOutputUtility

#pragma mark - Volume (CoreAudio scalar — smooth, no steps)

+ (AudioDeviceID)defaultOutputDevice {
    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioDeviceID deviceID = kAudioObjectUnknown;
    UInt32 size = sizeof(deviceID);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &deviceID);
    return deviceID;
}

+ (float)getSystemVolume {
    AudioDeviceID device = [self defaultOutputDevice];
    if (device == kAudioObjectUnknown) return 0.0f;
    
    AudioObjectPropertyAddress addr = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput,
        1 // channel 1 (left)
    };
    if (!AudioObjectHasProperty(device, &addr)) {
        addr.mElement = 0; // master fallback
        if (!AudioObjectHasProperty(device, &addr)) return 0.0f;
    }
    Float32 vol = 0.0f;
    UInt32 size = sizeof(vol);
    AudioObjectGetPropertyData(device, &addr, 0, NULL, &size, &vol);
    return vol;
}

+ (void)setSystemVolume:(float)volume {
    volume = fmaxf(0.0f, fminf(1.0f, volume));
    AudioDeviceID device = [self defaultOutputDevice];
    if (device == kAudioObjectUnknown) return;
    
    for (UInt32 ch = 1; ch <= 2; ch++) {
        AudioObjectPropertyAddress addr = {
            kAudioDevicePropertyVolumeScalar,
            kAudioDevicePropertyScopeOutput,
            ch
        };
        if (!AudioObjectHasProperty(device, &addr)) {
            if (ch == 1) { // try master
                addr.mElement = 0;
                if (AudioObjectHasProperty(device, &addr))
                    AudioObjectSetPropertyData(device, &addr, 0, NULL, sizeof(volume), &volume);
            }
            break;
        }
        AudioObjectSetPropertyData(device, &addr, 0, NULL, sizeof(volume), &volume);
    }
    
    /// Show volume HUD on the display under the mouse
    CGDirectDisplayID display = [self displayUnderMouse];
    showOSD(display, MFOSDImageVolume, volume);
}

#pragma mark - Display under mouse pointer

+ (CGDirectDisplayID)displayUnderMouse {
    NSPoint mouse = [NSEvent mouseLocation];
    CGPoint point = CGPointMake(mouse.x, mouse.y);
    CGDirectDisplayID displayID = kCGNullDirectDisplay;
    uint32_t count = 0;
    CGGetDisplaysWithPoint(point, 1, &displayID, &count);
    if (count == 0) return CGMainDisplayID();
    return displayID;
}

#pragma mark - Brightness

+ (float)getDisplayBrightness {
    void *handle = displayServicesHandle();
    if (!handle) return 0.5f;
    DisplayServicesGetBrightnessFunc fn = dlsym(handle, "DisplayServicesGetBrightness");
    if (!fn) return 0.5f;
    float brightness = 0.5f;
    fn(CGMainDisplayID(), &brightness); // read from built-in as reference
    return brightness;
}

+ (void)adjustBrightnessByDelta:(float)delta {
    /// Accumulate delta and apply in discrete steps.
    /// Built-in display: DisplayServicesSetBrightness (smooth, continuous).
    /// External display: DDC VCP 0x10 write via IOAVService (per-monitor, shows HUD in MonitorControl).
    
    _brightnessAccumulator += delta;
    
    CGDirectDisplayID display = [self displayUnderMouse];
    BOOL isBuiltIn = CGDisplayIsBuiltin(display);
    
    if (isBuiltIn) {
        /// Built-in: apply continuously via DisplayServices
        void *handle = displayServicesHandle();
        if (!handle) return;
        DisplayServicesGetBrightnessFunc getFn = dlsym(handle, "DisplayServicesGetBrightness");
        DisplayServicesSetBrightnessFunc setFn = dlsym(handle, "DisplayServicesSetBrightness");
        if (!getFn || !setFn) return;
        
        float current = 0.5f;
        getFn(display, &current);
        float newVal = fmaxf(0.0f, fminf(1.0f, current + _brightnessAccumulator));
        setFn(display, newVal);
        _brightnessAccumulator = 0.0f;
        
        showOSD(display, MFOSDImageBrightness, newVal);
        
    } else {
        /// External: DDC in steps of 1/100 (DDC range 0–100)
        float step = 1.0f / 100.0f;
        int steps = 0;
        while (_brightnessAccumulator >= step)  { steps++;  _brightnessAccumulator -= step; }
        while (_brightnessAccumulator <= -step) { steps--;  _brightnessAccumulator += step; }
        if (steps == 0) return;
        
        [self writeDDCBrightnessSteps:steps forDisplay:display];
        /// OSD shown inside writeDDCBrightnessSteps after cache update
    }
}

+ (void)setDisplayBrightness:(float)brightness {
    /// Used by scroll output — compute delta from current and apply.
    float current = [self getDisplayBrightness];
    [self adjustBrightnessByDelta:brightness - current];
}

#pragma mark - DDC write (external displays, arm64)

+ (void)writeDDCBrightnessSteps:(int)steps forDisplay:(CGDirectDisplayID)displayID {
    loadIOAVServiceSymbols();
    if (!_IOAVServiceWriteI2C || !_IOAVServiceCreateWithService) return;
    
    /// Find the IOAVService for this display via IORegistry
    IOAVServiceRef service = [self avServiceForDisplay:displayID];
    if (!service) return;
    
    /// Read current DDC brightness (VCP 0x10), then write new value
    /// For simplicity we track the value in a static cache keyed by displayID
    static NSMutableDictionary *brightnessCache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ brightnessCache = [NSMutableDictionary dictionary]; });
    
    NSNumber *key = @(displayID);
    int current = brightnessCache[key] ? [brightnessCache[key] intValue] : 50; // default 50%
    int newVal = MAX(0, MIN(100, current + steps));
    brightnessCache[key] = @(newVal);
    
    /// Show brightness HUD on the external display
    showOSD(displayID, MFOSDImageBrightness, newVal / 100.0f);
    
    /// DDC Set VCP Feature (0x03) packet for VCP code 0x10 (brightness)
    uint8_t vcpCode = 0x10;
    uint8_t valHigh = (newVal >> 8) & 0xFF;
    uint8_t valLow  = newVal & 0xFF;
    
    /// Packet: [0x80|len, 0x03, vcpCode, valHigh, valLow, checksum]
    /// checksum = XOR of (destination<<1) ^ all bytes before checksum
    uint8_t packet[6];
    packet[0] = 0x84;       // 0x80 | 4 (payload length)
    packet[1] = 0x03;       // Set VCP Feature opcode
    packet[2] = vcpCode;
    packet[3] = valHigh;
    packet[4] = valLow;
    packet[5] = 0x6E ^ packet[0] ^ packet[1] ^ packet[2] ^ packet[3] ^ packet[4]; // 0x6E = 0x37<<1
    
    uint32_t chipAddress = 0x37;
    uint32_t dataAddress = 0x51;
    
    /// Copy packet to heap so it can be captured by the block
    NSData *packetData = [NSData dataWithBytes:packet length:sizeof(packet)];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        _IOAVServiceWriteI2C(service, chipAddress, dataAddress, (void *)packetData.bytes, (uint32_t)packetData.length);
        CFRelease(service);
    });
}

+ (IOAVServiceRef)avServiceForDisplay:(CGDirectDisplayID)displayID {
    loadIOAVServiceSymbols();
    if (!_IOAVServiceCreateWithService) return NULL;
    
    BOOL isBuiltIn = CGDisplayIsBuiltin(displayID);
    NSString *targetLocation = isBuiltIn ? @"Embedded" : @"External";
    
    /// On Apple Silicon, displays use DCPAVServiceProxy instead of IOAVService.
    /// Match by Location property ("Embedded" for built-in, "External" for external).
    const char *classes[] = { "DCPAVServiceProxy", "IOAVService", NULL };
    
    for (int i = 0; classes[i] != NULL; i++) {
        io_iterator_t iter = IO_OBJECT_NULL;
        IOServiceGetMatchingServices(kIOMainPortDefault,
                                     IOServiceMatching(classes[i]),
                                     &iter);
        io_service_t entry;
        while ((entry = IOIteratorNext(iter)) != IO_OBJECT_NULL) {
            CFMutableDictionaryRef props = NULL;
            IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0);
            
            BOOL locationMatch = NO;
            if (props) {
                CFStringRef location = CFDictionaryGetValue(props, CFSTR("Location"));
                if (location) {
                    NSString *loc = (__bridge NSString *)location;
                    locationMatch = [loc isEqualToString:targetLocation];
                }
                CFRelease(props);
            }
            
            if (locationMatch) {
                IOAVServiceRef service = _IOAVServiceCreateWithService(kCFAllocatorDefault, entry);
                IOObjectRelease(entry);
                IOObjectRelease(iter);
                return service;
            }
            IOObjectRelease(entry);
        }
        IOObjectRelease(iter);
    }
    return NULL;
}

@end
