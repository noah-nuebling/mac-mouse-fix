//
// --------------------------------------------------------------------------
// ScrollOutputUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ScrollOutputUtility.h"
#import "Constants.h"
#import "WannabePrefixHeader.h"
#import <CoreAudio/CoreAudio.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/graphics/IOGraphicsTypes.h>
#import <IOKit/i2c/IOI2CInterface.h>
#import <dlfcn.h>

// ─── IOAVService DDC (arm64 external displays) ───────────────────────────────

typedef CFTypeRef IOAVServiceRef;
typedef IOReturn (*IOAVServiceWriteI2CFunc)(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void *buf, uint32_t size);
typedef IOReturn (*IOAVServiceReadI2CFunc)(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void *buf, uint32_t size);
typedef IOAVServiceRef (*IOAVServiceCreateWithServiceFunc)(CFAllocatorRef allocator, io_service_t service);

/// CoreDisplay private API for getting EDID info from a CGDirectDisplayID
typedef CFDictionaryRef (*CoreDisplay_DisplayCreateInfoDictionaryFunc)(CGDirectDisplayID displayID);

static IOAVServiceWriteI2CFunc        _IOAVServiceWriteI2C        = NULL;
static IOAVServiceReadI2CFunc         _IOAVServiceReadI2C         = NULL;
static IOAVServiceCreateWithServiceFunc _IOAVServiceCreateWithService = NULL;
static CoreDisplay_DisplayCreateInfoDictionaryFunc _CoreDisplay_DisplayCreateInfoDictionary = NULL;

static void loadIOAVServiceSymbols(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (!handle) handle = RTLD_DEFAULT;
        _IOAVServiceWriteI2C         = dlsym(handle, "IOAVServiceWriteI2C");
        _IOAVServiceReadI2C          = dlsym(handle, "IOAVServiceReadI2C");
        _IOAVServiceCreateWithService = dlsym(handle, "IOAVServiceCreateWithService");
        
        /// CoreDisplay is in the CoreDisplay framework
        void *cdHandle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY);
        if (!cdHandle) cdHandle = RTLD_DEFAULT;
        _CoreDisplay_DisplayCreateInfoDictionary = dlsym(cdHandle, "CoreDisplay_DisplayCreateInfoDictionary");
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

// ─── Custom brightness overlay for external displays (macOS Tahoe+) ───────────

static NSWindow *_overlayWindow = nil;
static NSView *_overlayBarFill = nil;
static NSImageView *_overlayIcon = nil;
static NSTextField *_overlayLabel = nil;
static NSTimer *_overlayFadeTimer = nil;

static void ensureOverlayWindow(void) {
    if (_overlayWindow) return;
    
    /// Create a dark rounded overlay window (220x44) — taller to fit monitor name
    CGFloat width = 220.0, height = 44.0, cornerRadius = 12.0;
    NSRect frame = NSMakeRect(0, 0, width, height);
    
    _overlayWindow = [[NSWindow alloc] initWithContentRect:frame
                                                 styleMask:NSWindowStyleMaskBorderless
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
    _overlayWindow.level = NSStatusWindowLevel + 1;
    _overlayWindow.backgroundColor = [NSColor clearColor];
    _overlayWindow.opaque = NO;
    _overlayWindow.hasShadow = YES;
    _overlayWindow.ignoresMouseEvents = YES;
    _overlayWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary;
    
    /// Background view with rounded corners
    NSView *contentView = _overlayWindow.contentView;
    contentView.wantsLayer = YES;
    contentView.layer.cornerRadius = cornerRadius;
    contentView.layer.masksToBounds = YES;
    contentView.layer.backgroundColor = [[NSColor colorWithWhite:0.1 alpha:0.85] CGColor];
    
    /// Monitor name label (top row)
    _overlayLabel = [NSTextField labelWithString:@""];
    _overlayLabel.frame = NSMakeRect(10, 24, width - 20, 16);
    _overlayLabel.font = [NSFont systemFontOfSize:10 weight:NSFontWeightMedium];
    _overlayLabel.textColor = [NSColor colorWithWhite:0.7 alpha:1.0];
    _overlayLabel.alignment = NSTextAlignmentCenter;
    _overlayLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [contentView addSubview:_overlayLabel];
    
    /// Icon (left side, bottom row)
    _overlayIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 5, 16, 16)];
    _overlayIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
    [contentView addSubview:_overlayIcon];
    
    /// Bar background (dark track, bottom row)
    CGFloat barX = 32, barY = 9, barW = width - barX - 12, barH = 7;
    NSView *barBg = [[NSView alloc] initWithFrame:NSMakeRect(barX, barY, barW, barH)];
    barBg.wantsLayer = YES;
    barBg.layer.cornerRadius = barH / 2.0;
    barBg.layer.backgroundColor = [[NSColor colorWithWhite:0.3 alpha:1.0] CGColor];
    [contentView addSubview:barBg];
    
    /// Bar fill (bright, bottom row)
    _overlayBarFill = [[NSView alloc] initWithFrame:NSMakeRect(barX, barY, 0, barH)];
    _overlayBarFill.wantsLayer = YES;
    _overlayBarFill.layer.cornerRadius = barH / 2.0;
    _overlayBarFill.layer.backgroundColor = [[NSColor whiteColor] CGColor];
    [contentView addSubview:_overlayBarFill];
}

static NSString *displayNameForID(CGDirectDisplayID displayID) {
    /// Get the localized display name from NSScreen
    for (NSScreen *screen in [NSScreen screens]) {
        NSDictionary *desc = [screen deviceDescription];
        NSNumber *screenNumber = desc[@"NSScreenNumber"];
        if (screenNumber && (CGDirectDisplayID)screenNumber.unsignedIntValue == displayID) {
            return screen.localizedName;
        }
    }
    return @"External Display";
}

static void showCustomOverlay(CGDirectDisplayID displayID, float value) {
    dispatch_async(dispatch_get_main_queue(), ^{
        ensureOverlayWindow();
        
        /// Position on the target display (bottom center, 80px from bottom)
        NSRect screenFrame = NSZeroRect;
        for (NSScreen *screen in [NSScreen screens]) {
            NSDictionary *desc = [screen deviceDescription];
            NSNumber *screenNumber = desc[@"NSScreenNumber"];
            if (screenNumber && (CGDirectDisplayID)screenNumber.unsignedIntValue == displayID) {
                screenFrame = screen.frame;
                break;
            }
        }
        if (NSIsEmptyRect(screenFrame)) {
            screenFrame = [NSScreen mainScreen].frame;
        }
        
        CGFloat winW = _overlayWindow.frame.size.width;
        CGFloat x = screenFrame.origin.x + (screenFrame.size.width - winW) / 2.0;
        CGFloat y = screenFrame.origin.y + 80.0;
        [_overlayWindow setFrameOrigin:NSMakePoint(x, y)];
        
        /// Update monitor name
        _overlayLabel.stringValue = displayNameForID(displayID);
        
        /// Update icon (always brightness sun for this overlay)
        NSImage *icon = [NSImage imageWithSystemSymbolName:@"sun.max.fill" accessibilityDescription:nil];
        if (icon) {
            NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightMedium];
            _overlayIcon.image = [icon imageWithSymbolConfiguration:config];
            _overlayIcon.contentTintColor = [NSColor whiteColor];
        }
        
        /// Update bar fill width
        CGFloat barX = 32, barMaxW = _overlayWindow.frame.size.width - barX - 12;
        CGFloat fillW = fmaxf(0, fminf(1.0f, value)) * barMaxW;
        NSRect fillFrame = _overlayBarFill.frame;
        fillFrame.size.width = fillW;
        _overlayBarFill.frame = fillFrame;
        
        /// Show
        _overlayWindow.alphaValue = 1.0;
        [_overlayWindow orderFrontRegardless];
        
        /// Cancel previous fade timer, start new one
        [_overlayFadeTimer invalidate];
        _overlayFadeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer *timer) {
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
                ctx.duration = 0.3;
                _overlayWindow.animator.alphaValue = 0.0;
            } completionHandler:^{
                [_overlayWindow orderOut:nil];
            }];
        }];
    });
}

static void showOSD(CGDirectDisplayID displayID, MFOSDImage imageID, float value) {
    /// For brightness on external displays, use custom overlay (system OSD is broken on Tahoe+)
    /// Volume still uses the native system OSD which works fine
    if (!CGDisplayIsBuiltin(displayID) && imageID == MFOSDImageBrightness) {
        showCustomOverlay(displayID, value);
        return;
    }
    
    loadOSDFramework();
    
    /// Load OSDManager at runtime — it lives in the dyld shared cache, not a linkable stub
    Class OSDManagerClass = NSClassFromString(@"OSDManager");
    if (!OSDManagerClass) return;
    id mgr = [OSDManagerClass performSelector:@selector(sharedManager)];
    if (!mgr) return;
    
    /// Standard 16-chiclet mode for built-in display
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
    /// Accumulate delta and apply.
    /// Built-in display: DisplayServicesSetBrightness (smooth, continuous).
    /// External display: Also try DisplayServicesSetBrightness first (works on macOS 12+),
    /// fall back to DDC VCP 0x10 write via IOAVService.
    /// All external displays support software gamma dimming below hardware zero.
    
    _brightnessAccumulator += delta;
    
    CGDirectDisplayID display = [self displayUnderMouse];
    BOOL isBuiltIn = CGDisplayIsBuiltin(display);
    
    DDLogInfo(@"Brightness: delta=%.4f accum=%.4f display=%u builtIn=%d", delta, _brightnessAccumulator, display, isBuiltIn);
    
    /// Built-in display: just use DisplayServices, no software dimming needed
    if (isBuiltIn) {
        void *handle = displayServicesHandle();
        if (handle) {
            DisplayServicesGetBrightnessFunc getFn = dlsym(handle, "DisplayServicesGetBrightness");
            DisplayServicesSetBrightnessFunc setFn = dlsym(handle, "DisplayServicesSetBrightness");
            if (getFn && setFn) {
                float current = 0.5f;
                if (getFn(display, &current) == 0) {
                    float newVal = fmaxf(0.0f, fminf(1.0f, current + _brightnessAccumulator * 4.0f));
                    setFn(display, newVal);
                    _brightnessAccumulator = 0.0f;
                    showOSD(display, MFOSDImageBrightness, newVal);
                    return;
                }
            }
        }
        _brightnessAccumulator = 0.0f;
        return;
    }
    
    /// External display: check if DisplayServices works, otherwise use DDC
    /// Either way, use combined hardware + software (gamma) dimming
    BOOL usesDisplayServices = NO;
    void *handle = displayServicesHandle();
    if (handle) {
        DisplayServicesGetBrightnessFunc getFn = dlsym(handle, "DisplayServicesGetBrightness");
        if (getFn) {
            float tmp = 0;
            usesDisplayServices = (getFn(display, &tmp) == 0);
        }
    }
    
    [self adjustCombinedBrightness:_brightnessAccumulator forDisplay:display usesDisplayServices:usesDisplayServices];
    _brightnessAccumulator = 0.0f;
}

+ (void)adjustBrightnessByDelta:(float)delta forDisplayID:(CGDirectDisplayID)displayID {
    /// Same as adjustBrightnessByDelta: but with an explicit display ID (used by drag when pointer is frozen)
    _brightnessAccumulator += delta;
    
    BOOL isBuiltIn = CGDisplayIsBuiltin(displayID);
    
    if (isBuiltIn) {
        void *handle = displayServicesHandle();
        if (handle) {
            DisplayServicesGetBrightnessFunc getFn = dlsym(handle, "DisplayServicesGetBrightness");
            DisplayServicesSetBrightnessFunc setFn = dlsym(handle, "DisplayServicesSetBrightness");
            if (getFn && setFn) {
                float current = 0.5f;
                if (getFn(displayID, &current) == 0) {
                    float newVal = fmaxf(0.0f, fminf(1.0f, current + _brightnessAccumulator * 4.0f));
                    setFn(displayID, newVal);
                    _brightnessAccumulator = 0.0f;
                    showOSD(displayID, MFOSDImageBrightness, newVal);
                    return;
                }
            }
        }
        _brightnessAccumulator = 0.0f;
        return;
    }
    
    BOOL usesDisplayServices = NO;
    void *handle = displayServicesHandle();
    if (handle) {
        DisplayServicesGetBrightnessFunc getFn = dlsym(handle, "DisplayServicesGetBrightness");
        if (getFn) {
            float tmp = 0;
            usesDisplayServices = (getFn(displayID, &tmp) == 0);
        }
    }
    
    [self adjustCombinedBrightness:_brightnessAccumulator forDisplay:displayID usesDisplayServices:usesDisplayServices];
    _brightnessAccumulator = 0.0f;
}

+ (void)setDisplayBrightness:(float)brightness {
    /// Used by scroll output — compute delta from current and apply.
    float current = [self getDisplayBrightness];
    [self adjustBrightnessByDelta:brightness - current];
}

#pragma mark - Combined hardware + software brightness

/// Logical brightness per display: 0.0 = full black, 1.0 = DDC zero / gamma crossover, 2.0 = DDC 100%
/// Upper half (1.0–2.0): DDC hardware brightness 0–100, gamma = 1.0
/// Lower half (0.0–1.0): DDC locked at 0, gamma dims from 1.0 to 0.0
static NSMutableDictionary<NSNumber *, NSNumber *> *_logicalBrightness = nil;
static dispatch_once_t _logicalBrightnessOnce;

static void ensureLogicalBrightness(void) {
    dispatch_once(&_logicalBrightnessOnce, ^{
        _logicalBrightness = [NSMutableDictionary dictionary];
    });
}

+ (void)adjustCombinedBrightness:(float)delta forDisplay:(CGDirectDisplayID)displayID usesDisplayServices:(BOOL)usesDisplayServices {
    ensureLogicalBrightness();
    ensureCaches();
    
    NSNumber *key = @(displayID);
    
    /// Initialize logical brightness on first use
    if (!_logicalBrightness[key]) {
        float hwBrightness = 0.5f;
        if (usesDisplayServices) {
            void *handle = displayServicesHandle();
            if (handle) {
                DisplayServicesGetBrightnessFunc getFn = dlsym(handle, "DisplayServicesGetBrightness");
                if (getFn) getFn(displayID, &hwBrightness);
            }
        } else {
            int ddcVal = 50;
            /// Try arm64 IOAVService first, fall back to Intel framebuffer
            IOAVServiceRef service = [self avServiceForDisplay:displayID];
            if (service) {
                ddcVal = [self readDDCBrightness:service];
            } else {
                ddcVal = [self readDDCBrightnessViaFramebuffer:displayID];
            }
            hwBrightness = ddcVal / 100.0f;
        }
        /// Map hardware 0.0–1.0 to logical 1.0–2.0 (software gamma range is 0.0–1.0)
        float logical = 1.0f + hwBrightness;
        _logicalBrightness[key] = @(logical);
        DDLogInfo(@"Brightness combined: seeded display %u logical=%.3f (hw=%.3f)", displayID, logical, hwBrightness);
    }
    
    float current = [_logicalBrightness[key] floatValue];
    /// Apply 4x multiplier for responsiveness
    float newLogical = fmaxf(0.0f, fminf(2.0f, current + delta * 4.0f));
    _logicalBrightness[key] = @(newLogical);
    
    /// Determine hardware and software values
    float hwValue;      // 0.0–1.0 hardware brightness
    float gammaMultiplier; // 1.0 = normal, 0.0 = black
    
    if (newLogical >= 1.0f) {
        /// Upper range: hardware active, no software dimming
        hwValue = newLogical - 1.0f; // 0.0–1.0
        gammaMultiplier = 1.0f;
    } else {
        /// Lower range: hardware at 0, software gamma dims
        hwValue = 0.0f;
        gammaMultiplier = fmaxf(0.0f, newLogical); // 0.0–1.0
    }
    
    /// Show OSD: map logical 0.0–2.0 to display 0.0–1.0
    float osdValue = newLogical / 2.0f;
    showOSD(displayID, MFOSDImageBrightness, osdValue);
    
    /// Apply hardware brightness
    if (usesDisplayServices) {
        void *handle = displayServicesHandle();
        if (handle) {
            DisplayServicesSetBrightnessFunc setFn = dlsym(handle, "DisplayServicesSetBrightness");
            if (setFn) setFn(displayID, hwValue);
        }
    } else {
        int ddcValue = (int)roundf(hwValue * 100.0f);
        ddcValue = MAX(0, MIN(100, ddcValue));
        int cachedDDC = _brightnessCache[key] ? [_brightnessCache[key] intValue] : -1;
        if (ddcValue != cachedDDC) {
            _brightnessCache[key] = @(ddcValue);
            [self writeDDCValue:ddcValue forDisplay:displayID];
        }
    }
    
    /// Apply software gamma (for both DisplayServices and DDC displays)
    [self setGammaMultiplier:gammaMultiplier forDisplay:displayID];
    
    DDLogInfo(@"Brightness combined: display %u logical=%.3f hw=%.3f gamma=%.3f OSD=%.3f",
              displayID, newLogical, hwValue, gammaMultiplier, osdValue);
}

#pragma mark - Software gamma dimming

+ (void)setGammaMultiplier:(float)multiplier forDisplay:(CGDirectDisplayID)displayID {
    /// Use CGSetDisplayTransferByTable to dim the display via gamma
    /// multiplier=1.0 means normal, multiplier=0.0 means full black
    
    multiplier = fmaxf(0.0f, fminf(1.0f, multiplier));
    
    if (multiplier >= 0.999f) {
        /// Restore default gamma (no dimming)
        CGDisplayRestoreColorSyncSettings();
        return;
    }
    
    /// Build a linear gamma table scaled by the multiplier
    uint32_t sampleCount = 256;
    CGGammaValue red[256], green[256], blue[256];
    for (uint32_t i = 0; i < sampleCount; i++) {
        float v = ((float)i / 255.0f) * multiplier;
        red[i] = v;
        green[i] = v;
        blue[i] = v;
    }
    
    CGSetDisplayTransferByTable(displayID, sampleCount, red, green, blue);
}

#pragma mark - DDC write (external displays, arm64)

/// Cached mapping: CGDirectDisplayID → IOAVServiceRef (retained)
static NSMutableDictionary<NSNumber *, id> *_serviceCache = nil;
/// Cached DDC brightness values per display
static NSMutableDictionary<NSNumber *, NSNumber *> *_brightnessCache = nil;
static dispatch_once_t _cachesOnce;

static void ensureCaches(void) {
    dispatch_once(&_cachesOnce, ^{
        _serviceCache = [NSMutableDictionary dictionary];
        _brightnessCache = [NSMutableDictionary dictionary];
        
        /// Register for display reconfiguration to invalidate caches
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, NULL);
    });
}

static void displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    if (flags & kCGDisplayBeginConfigurationFlag) return; /// Wait for end
    /// Clear all caches — display IDs may have changed
    [_serviceCache removeAllObjects];
    [_brightnessCache removeAllObjects];
    if (_logicalBrightness) {
        [_logicalBrightness removeAllObjects];
    }
    DDLogInfo(@"Brightness: display reconfiguration detected, caches cleared");
}

+ (void)writeDDCValue:(int)ddcValue forDisplay:(CGDirectDisplayID)displayID {
    loadIOAVServiceSymbols();
    
    ddcValue = MAX(0, MIN(100, ddcValue));
    
    /// Try arm64 IOAVService path first
    if (_IOAVServiceWriteI2C && _IOAVServiceCreateWithService) {
        IOAVServiceRef service = [self avServiceForDisplay:displayID];
        if (service) {
            uint8_t packet[6];
            packet[0] = 0x84;
            packet[1] = 0x03;
            packet[2] = 0x10;
            packet[3] = (ddcValue >> 8) & 0xFF;
            packet[4] = ddcValue & 0xFF;
            packet[5] = 0x6E ^ 0x51 ^ packet[0] ^ packet[1] ^ packet[2] ^ packet[3] ^ packet[4];
            
            NSData *packetData = [NSData dataWithBytes:packet length:sizeof(packet)];
            CFRetain(service);
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
                _IOAVServiceWriteI2C(service, 0x37, 0x51, (void *)packetData.bytes, (uint32_t)packetData.length);
                CFRelease(service);
            });
            return;
        }
    }
    
    /// Fallback: Intel IOFramebuffer I2C path
    [self writeDDCValueViaFramebuffer:ddcValue forDisplay:displayID];
}

#pragma mark - DDC Read (VCP Get for brightness seeding)

+ (int)readDDCBrightness:(IOAVServiceRef)service {
    if (!_IOAVServiceReadI2C || !_IOAVServiceWriteI2C) return 50;
    
    /// DDC Get VCP Feature request: send VCP code 0x10
    uint8_t sendPacket[4];
    sendPacket[0] = 0x82;   // 0x80 | 2 (payload length)
    sendPacket[1] = 0x01;   // Get VCP Feature opcode
    sendPacket[2] = 0x10;   // VCP code: brightness
    sendPacket[3] = 0x6E ^ 0x51 ^ sendPacket[0] ^ sendPacket[1] ^ sendPacket[2];
    
    /// Write the request
    usleep(10000);
    IOReturn writeResult = _IOAVServiceWriteI2C(service, 0x37, 0x51, sendPacket, sizeof(sendPacket));
    if (writeResult != kIOReturnSuccess) {
        DDLogInfo(@"Brightness DDC read: write request failed (%d)", writeResult);
        return 50;
    }
    
    /// Read the response (11 bytes)
    usleep(50000);
    uint8_t reply[11] = {0};
    IOReturn readResult = _IOAVServiceReadI2C(service, 0x37, 0, reply, sizeof(reply));
    if (readResult != kIOReturnSuccess) {
        DDLogInfo(@"Brightness DDC read: read response failed (%d)", readResult);
        return 50;
    }
    
    /// Validate checksum: XOR of 0x50 and all bytes except last should equal last byte
    uint8_t chk = 0x50;
    for (int i = 0; i < 10; i++) chk ^= reply[i];
    if (chk != reply[10]) {
        DDLogInfo(@"Brightness DDC read: checksum mismatch");
        return 50;
    }
    
    /// Response format: [src|len, result, opcode, type, maxH, maxL, curH, curL, chk]
    /// Bytes 8,9 = current value (big-endian)
    int currentBrightness = (reply[8] << 8) | reply[9];
    DDLogInfo(@"Brightness DDC read: current=%d", currentBrightness);
    return MAX(0, MIN(100, currentBrightness));
}

#pragma mark - Intel DDC via IOFramebuffer (x86_64 fallback)

/// Get the IOFramebuffer service port for a given display ID
static io_service_t framebufferPortForDisplay(CGDirectDisplayID displayID) {
    if (CGDisplayIsBuiltin(displayID)) return IO_OBJECT_NULL;
    
    io_iterator_t iter;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iter) != KERN_SUCCESS) {
        return IO_OBJECT_NULL;
    }
    
    io_service_t service;
    while ((service = IOIteratorNext(iter)) != IO_OBJECT_NULL) {
        CFDictionaryRef info = IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
        if (info) {
            CFNumberRef vendorRef = CFDictionaryGetValue(info, CFSTR(kDisplayVendorID));
            CFNumberRef productRef = CFDictionaryGetValue(info, CFSTR(kDisplayProductID));
            
            uint32_t vendor = 0, product = 0;
            if (vendorRef) CFNumberGetValue(vendorRef, kCFNumberSInt32Type, &vendor);
            if (productRef) CFNumberGetValue(productRef, kCFNumberSInt32Type, &product);
            CFRelease(info);
            
            /// Match by vendor + product (same as CGDisplay)
            if (CGDisplayVendorNumber(displayID) == vendor && CGDisplayModelNumber(displayID) == product) {
                /// Get the framebuffer parent
                io_service_t framebuffer = IO_OBJECT_NULL;
                IORegistryEntryGetParentEntry(service, kIOServicePlane, &framebuffer);
                IOObjectRelease(service);
                IOObjectRelease(iter);
                return framebuffer;
            }
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iter);
    return IO_OBJECT_NULL;
}

/// Send an I2C request via IOFramebuffer
static BOOL sendI2CRequest(io_service_t framebuffer, IOI2CRequest *request) {
    IOItemCount busCount = 0;
    if (IOFBGetI2CInterfaceCount(framebuffer, &busCount) != KERN_SUCCESS || busCount == 0) {
        return NO;
    }
    
    for (IOOptionBits bus = 0; bus < busCount; bus++) {
        io_service_t interface = IO_OBJECT_NULL;
        if (IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface) != KERN_SUCCESS) continue;
        
        IOI2CConnectRef connect = NULL;
        if (IOI2CInterfaceOpen(interface, 0, &connect) != KERN_SUCCESS) {
            IOObjectRelease(interface);
            continue;
        }
        
        kern_return_t result = IOI2CSendRequest(connect, 0, request);
        IOI2CInterfaceClose(connect, 0);
        IOObjectRelease(interface);
        
        if (result == KERN_SUCCESS && request->result == kIOReturnSuccess) {
            return YES;
        }
    }
    return NO;
}

+ (void)writeDDCValueViaFramebuffer:(int)ddcValue forDisplay:(CGDirectDisplayID)displayID {
    io_service_t framebuffer = framebufferPortForDisplay(displayID);
    if (framebuffer == IO_OBJECT_NULL) {
        DDLogInfo(@"Brightness DDC Intel: no framebuffer for display %u", displayID);
        return;
    }
    
    /// Build DDC Set VCP packet
    uint8_t data[7];
    data[0] = 0x51;         // destination address
    data[1] = 0x84;         // 0x80 | length(4)
    data[2] = 0x03;         // Set VCP opcode
    data[3] = 0x10;         // VCP code: brightness
    data[4] = (ddcValue >> 8) & 0xFF;
    data[5] = ddcValue & 0xFF;
    data[6] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5]; // checksum
    
    IOI2CRequest request = {};
    request.commFlags = 0;
    request.sendAddress = 0x6E;
    request.sendTransactionType = kIOI2CSimpleTransactionType;
    request.sendBuffer = (vm_address_t)data;
    request.sendBytes = sizeof(data);
    request.replyTransactionType = kIOI2CNoTransactionType;
    request.replyBytes = 0;
    
    usleep(10000);
    BOOL success = sendI2CRequest(framebuffer, &request);
    IOObjectRelease(framebuffer);
    
    if (!success) {
        DDLogInfo(@"Brightness DDC Intel: write failed for display %u", displayID);
    }
}

+ (int)readDDCBrightnessViaFramebuffer:(CGDirectDisplayID)displayID {
    io_service_t framebuffer = framebufferPortForDisplay(displayID);
    if (framebuffer == IO_OBJECT_NULL) return 50;
    
    /// Build DDC Get VCP request
    uint8_t sendData[5];
    sendData[0] = 0x51;     // destination
    sendData[1] = 0x82;     // 0x80 | length(2)
    sendData[2] = 0x01;     // Get VCP opcode
    sendData[3] = 0x10;     // VCP code: brightness
    sendData[4] = 0x6E ^ sendData[0] ^ sendData[1] ^ sendData[2] ^ sendData[3]; // checksum
    
    uint8_t replyData[11] = {0};
    
    IOI2CRequest request = {};
    request.commFlags = 0;
    request.sendAddress = 0x6E;
    request.sendTransactionType = kIOI2CSimpleTransactionType;
    request.sendBuffer = (vm_address_t)sendData;
    request.sendBytes = sizeof(sendData);
    request.replyAddress = 0x6F;
    request.replyTransactionType = kIOI2CDDCciReplyTransactionType;
    request.replyBuffer = (vm_address_t)replyData;
    request.replyBytes = sizeof(replyData);
    request.minReplyDelay = 50 * 1000 * 1000; // 50ms in nanoseconds
    
    usleep(10000);
    BOOL success = sendI2CRequest(framebuffer, &request);
    IOObjectRelease(framebuffer);
    
    if (!success) return 50;
    
    /// Validate checksum
    uint8_t chk = 0x50;
    for (int i = 0; i < 10; i++) chk ^= replyData[i];
    if (chk != replyData[10]) return 50;
    
    int brightness = (replyData[8] << 8) | replyData[9];
    return MAX(0, MIN(100, brightness));
}

#pragma mark - EDID-based IOAVService matching

/// Structure to hold IORegistry service info for matching
typedef struct {
    char edidUUID[64];
    char productName[128];
    int64_t serialNumber;
    char ioDisplayLocation[512];
    io_service_t entry;
    int serviceLocation;
} IORegServiceInfo;

+ (IOAVServiceRef)avServiceForDisplay:(CGDirectDisplayID)displayID {
    loadIOAVServiceSymbols();
    if (!_IOAVServiceCreateWithService) return NULL;
    ensureCaches();
    
    /// Check cache first
    NSNumber *key = @(displayID);
    id cached = _serviceCache[key];
    if (cached) {
        if (cached == [NSNull null]) return NULL;
        IOAVServiceRef service = (__bridge IOAVServiceRef)cached;
        CFRetain(service);
        return service;
    }
    
    /// Build all display→service mappings at once (handles multiple externals correctly)
    [self rebuildServiceMappings];
    
    cached = _serviceCache[key];
    if (cached && cached != [NSNull null]) {
        IOAVServiceRef service = (__bridge IOAVServiceRef)cached;
        CFRetain(service);
        return service;
    }
    return NULL;
}

+ (void)rebuildServiceMappings {
    loadIOAVServiceSymbols();
    if (!_IOAVServiceCreateWithService || !_CoreDisplay_DisplayCreateInfoDictionary) return;
    ensureCaches();
    
    /// Clear existing cache
    [_serviceCache removeAllObjects];
    
    /// Step 1: Enumerate all DCPAVServiceProxy entries from IORegistry
    /// We walk the IOService plane looking for framebuffer entries (to get EDID info)
    /// followed by their DCPAVServiceProxy children (to get the IOAVService handle)
    NSMutableArray *ioregServices = [NSMutableArray array];
    
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    io_iterator_t iterator = IO_OBJECT_NULL;
    if (IORegistryEntryCreateIterator(root, kIOServicePlane, kIORegistryIterateRecursively, &iterator) != KERN_SUCCESS) {
        IOObjectRelease(root);
        return;
    }
    IOObjectRelease(root);
    
    /// Track current framebuffer context as we iterate
    NSString *currentEdidUUID = nil;
    NSString *currentProductName = nil;
    int64_t currentSerial = 0;
    NSString *currentIODisplayLocation = nil;
    int serviceLocation = 0;
    
    io_service_t entry;
    char nameBuffer[256];
    while ((entry = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        if (IORegistryEntryGetName(entry, nameBuffer) != KERN_SUCCESS) {
            IOObjectRelease(entry);
            continue;
        }
        NSString *name = @(nameBuffer);
        
        /// Framebuffer entries contain EDID/display info
        if ([name containsString:@"AppleCLCD2"] || [name containsString:@"IOMobileFramebufferShim"]) {
            serviceLocation++;
            currentEdidUUID = nil;
            currentProductName = nil;
            currentSerial = 0;
            currentIODisplayLocation = nil;
            
            /// Read EDID UUID
            CFTypeRef edidRef = IORegistryEntryCreateCFProperty(entry, CFSTR("EDID UUID"), kCFAllocatorDefault, kIORegistryIterateRecursively);
            if (edidRef) {
                if (CFGetTypeID(edidRef) == CFStringGetTypeID()) {
                    currentEdidUUID = (__bridge_transfer NSString *)edidRef;
                } else {
                    CFRelease(edidRef);
                }
            }
            
            /// Read IOService path as display location identifier
            char pathBuffer[512];
            if (IORegistryEntryGetPath(entry, kIOServicePlane, pathBuffer) == KERN_SUCCESS) {
                currentIODisplayLocation = @(pathBuffer);
            }
            
            /// Read DisplayAttributes for product name and serial
            CFTypeRef attrsRef = IORegistryEntryCreateCFProperty(entry, CFSTR("DisplayAttributes"), kCFAllocatorDefault, kIORegistryIterateRecursively);
            if (attrsRef) {
                NSDictionary *attrs = (__bridge_transfer NSDictionary *)attrsRef;
                NSDictionary *productAttrs = attrs[@"ProductAttributes"];
                if (productAttrs) {
                    currentProductName = productAttrs[@"ProductName"];
                    NSNumber *serial = productAttrs[@"SerialNumber"];
                    if (serial) currentSerial = serial.longLongValue;
                }
            }
            
            IOObjectRelease(entry);
            continue;
        }
        
        /// DCPAVServiceProxy — create the IOAVService from this entry
        if ([name isEqualToString:@"DCPAVServiceProxy"]) {
            CFTypeRef locationRef = IORegistryEntryCreateCFProperty(entry, CFSTR("Location"), kCFAllocatorDefault, 0);
            NSString *location = nil;
            if (locationRef) {
                location = (__bridge_transfer NSString *)locationRef;
            }
            
            /// Only create services for external displays
            if ([location isEqualToString:@"External"]) {
                IOAVServiceRef service = _IOAVServiceCreateWithService(kCFAllocatorDefault, entry);
                if (service) {
                    NSDictionary *info = @{
                        @"service": (__bridge id)service,
                        @"edidUUID": currentEdidUUID ?: @"",
                        @"productName": currentProductName ?: @"",
                        @"serialNumber": @(currentSerial),
                        @"ioDisplayLocation": currentIODisplayLocation ?: @"",
                        @"serviceLocation": @(serviceLocation),
                    };
                    [ioregServices addObject:info];
                    /// Don't release service here — it's retained in the array via bridge
                }
            }
            IOObjectRelease(entry);
            continue;
        }
        
        IOObjectRelease(entry);
    }
    IOObjectRelease(iterator);
    
    DDLogInfo(@"Brightness DDC: found %lu IOAVService entries from IORegistry", (unsigned long)ioregServices.count);
    
    if (ioregServices.count == 0) return;
    
    /// Step 2: Get all active external display IDs
    uint32_t maxDisplays = 16;
    CGDirectDisplayID displays[16];
    uint32_t displayCount = 0;
    CGGetActiveDisplayList(maxDisplays, displays, &displayCount);
    
    /// Step 3: Score each (displayID, ioregService) pair and find best matches
    /// Use a greedy approach: highest score first, no reuse of either display or service
    typedef struct {
        CGDirectDisplayID displayID;
        int serviceIndex;
        int score;
    } MatchCandidate;
    
    NSMutableArray *candidates = [NSMutableArray array];
    
    for (uint32_t d = 0; d < displayCount; d++) {
        CGDirectDisplayID did = displays[d];
        if (CGDisplayIsBuiltin(did)) continue;
        
        for (NSUInteger s = 0; s < ioregServices.count; s++) {
            NSDictionary *svc = ioregServices[s];
            int score = [self matchScoreForDisplay:did
                                     ioregEdidUUID:svc[@"edidUUID"]
                                  ioDisplayLocation:svc[@"ioDisplayLocation"]
                                   ioregProductName:svc[@"productName"]
                                  ioregSerialNumber:[svc[@"serialNumber"] longLongValue]];
            
            NSMutableDictionary *candidate = [NSMutableDictionary dictionary];
            candidate[@"displayID"] = @(did);
            candidate[@"serviceIndex"] = @(s);
            candidate[@"score"] = @(score);
            [candidates addObject:candidate];
        }
    }
    
    /// Sort by score descending
    [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];
    
    /// Greedy assignment
    NSMutableSet *takenDisplays = [NSMutableSet set];
    NSMutableSet *takenServices = [NSMutableSet set];
    
    for (NSDictionary *candidate in candidates) {
        NSNumber *did = candidate[@"displayID"];
        NSNumber *sidx = candidate[@"serviceIndex"];
        int score = [candidate[@"score"] intValue];
        
        if (score <= 0) continue;
        if ([takenDisplays containsObject:did] || [takenServices containsObject:sidx]) continue;
        
        [takenDisplays addObject:did];
        [takenServices addObject:sidx];
        
        NSDictionary *svc = ioregServices[[sidx unsignedIntegerValue]];
        IOAVServiceRef service = (__bridge IOAVServiceRef)svc[@"service"];
        
        /// Store in cache (retain for cache lifetime)
        CFRetain(service);
        _serviceCache[did] = (__bridge id)service;
        
        DDLogInfo(@"Brightness DDC: matched display %u → service[%@] (score=%d, name=%@)",
                  [did unsignedIntValue], sidx, score, svc[@"productName"]);
    }
    
    /// Mark unmatched displays as NSNull so we don't re-enumerate every time
    for (uint32_t d = 0; d < displayCount; d++) {
        CGDirectDisplayID did = displays[d];
        if (CGDisplayIsBuiltin(did)) continue;
        NSNumber *key = @(did);
        if (!_serviceCache[key]) {
            _serviceCache[key] = [NSNull null];
            DDLogInfo(@"Brightness DDC: no match for display %u", did);
        }
    }
    
    /// Release the services from the ioregServices array (they were retained by CFRetain above if cached)
    for (NSDictionary *svc in ioregServices) {
        IOAVServiceRef service = (__bridge IOAVServiceRef)svc[@"service"];
        CFRelease(service);
    }
}

#pragma mark - EDID Match Scoring

+ (int)matchScoreForDisplay:(CGDirectDisplayID)displayID
               ioregEdidUUID:(NSString *)ioregEdidUUID
            ioDisplayLocation:(NSString *)ioDisplayLocation
             ioregProductName:(NSString *)ioregProductName
            ioregSerialNumber:(int64_t)ioregSerialNumber {
    
    if (!_CoreDisplay_DisplayCreateInfoDictionary) return 0;
    
    CFDictionaryRef dictRef = _CoreDisplay_DisplayCreateInfoDictionary(displayID);
    if (!dictRef) return 0;
    NSDictionary *dictionary = (__bridge_transfer NSDictionary *)dictRef;
    
    int matchScore = 0;
    
    /// EDID UUID field matching (vendor, product, manufacture date, image size)
    if (ioregEdidUUID.length >= 34) {
        NSNumber *yearNum = dictionary[@(kDisplayYearOfManufacture)];
        NSNumber *weekNum = dictionary[@(kDisplayWeekOfManufacture)];
        NSNumber *vendorNum = dictionary[@(kDisplayVendorID)];
        NSNumber *productNum = dictionary[@(kDisplayProductID)];
        NSNumber *vSizeNum = dictionary[@(kDisplayVerticalImageSize)];
        NSNumber *hSizeNum = dictionary[@(kDisplayHorizontalImageSize)];
        
        if (yearNum && weekNum && vendorNum && productNum && vSizeNum && hSizeNum) {
            int64_t vendorID = vendorNum.longLongValue;
            int64_t productID = productNum.longLongValue;
            int64_t week = weekNum.longLongValue;
            int64_t year = yearNum.longLongValue;
            int64_t hSize = hSizeNum.longLongValue;
            int64_t vSize = vSizeNum.longLongValue;
            
            /// Vendor ID at offset 0 (4 hex chars)
            uint16_t vid = (uint16_t)MAX(0, MIN(vendorID, 0xFFFF));
            NSString *vendorHex = [NSString stringWithFormat:@"%04X", vid];
            if ([vendorHex isEqualToString:[ioregEdidUUID substringWithRange:NSMakeRange(0, 4)]]) {
                matchScore++;
            }
            
            /// Product ID at offset 4 (4 hex chars, byte-swapped)
            uint16_t pid = (uint16_t)MAX(0, MIN(productID, 0xFFFF));
            NSString *productHex = [NSString stringWithFormat:@"%02X%02X",
                                    (uint8_t)(pid & 0xFF), (uint8_t)((pid >> 8) & 0xFF)];
            if ([productHex isEqualToString:[ioregEdidUUID substringWithRange:NSMakeRange(4, 4)]]) {
                matchScore++;
            }
            
            /// Manufacture date at offset 19 (4 hex chars)
            uint8_t weekByte = (uint8_t)MAX(0, MIN(week, 255));
            uint8_t yearByte = (uint8_t)MAX(0, MIN(year - 1990, 255));
            NSString *dateHex = [NSString stringWithFormat:@"%02X%02X", weekByte, yearByte];
            if ([dateHex isEqualToString:[ioregEdidUUID substringWithRange:NSMakeRange(19, 4)]]) {
                matchScore++;
            }
            
            /// Image size at offset 30 (4 hex chars)
            uint8_t hByte = (uint8_t)MAX(0, MIN(hSize / 10, 255));
            uint8_t vByte = (uint8_t)MAX(0, MIN(vSize / 10, 255));
            NSString *sizeHex = [NSString stringWithFormat:@"%02X%02X", hByte, vByte];
            if (ioregEdidUUID.length >= 34 &&
                [sizeHex isEqualToString:[ioregEdidUUID substringWithRange:NSMakeRange(30, 4)]]) {
                matchScore++;
            }
        }
    }
    
    /// IODisplayLocation path match (strongest signal — worth 10 points like MonitorControl)
    if (ioDisplayLocation.length > 0) {
        NSString *dictLocation = dictionary[(__bridge NSString *)CFSTR(kIODisplayLocationKey)];
        if ([ioDisplayLocation isEqualToString:dictLocation]) {
            matchScore += 10;
        }
    }
    
    /// Product name match
    if (ioregProductName.length > 0) {
        NSDictionary *nameList = dictionary[@"DisplayProductName"];
        NSString *name = nameList[@"en_US"] ?: nameList.allValues.firstObject;
        if (name && [name caseInsensitiveCompare:ioregProductName] == NSOrderedSame) {
            matchScore++;
        }
    }
    
    /// Serial number match
    if (ioregSerialNumber != 0) {
        NSNumber *serial = dictionary[@(kDisplaySerialNumber)];
        if (serial && serial.longLongValue == ioregSerialNumber) {
            matchScore++;
        }
    }
    
    return matchScore;
}

@end
