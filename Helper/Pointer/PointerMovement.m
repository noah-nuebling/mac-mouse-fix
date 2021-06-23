//
// --------------------------------------------------------------------------
// PointerMovement.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This class can set sensitivity and acceleration for a specific or all attached pointing devices

/// Imports

#import "PointerMovement.h"
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import "IOUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "DeviceManager.h"

/// Get private Apple stuff
/// See PointerSpeedExperiments2.m for more info

typedef NS_ENUM(NSInteger, HIDEventSystemClientType) {
    HIDEventSystemClientTypeAdmin,
    HIDEventSystemClientTypeMonitor,
    HIDEventSystemClientTypePassive,
    HIDEventSystemClientTypeRateControlled,
    HIDEventSystemClientTypeSimple
};
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreateWithType(CFAllocatorRef allocator,
                                                                      HIDEventSystemClientType clientType,
                                                                      CFDictionaryRef _Nullable attributes);
extern IOHIDServiceClientRef IOHIDEventSystemClientCopyServiceForRegistryID(IOHIDEventSystemClientRef client, uint64_t entryID);

/// Implementation

@implementation PointerMovement

/// Interface

+ (void)setForAllDevices {
    /// Calls setForDevice: on all attached devices
    /// This should be called after  the pointer movement settings have been reset for all devices.
    /// The CursorSense source code makes me think that happens after the computer wakes up from sleep or after a new display has been attached and etc. but more testing is needed. We might not need this at all
    
    for (Device *device in DeviceManager.attachedDevices) {
        [self setForDevice:device.IOHIDDevice];
    }
    
}

+ (void) setForDevice:(IOHIDDeviceRef)device {
    /// Sets the sensitivity and acceleration defined by PointerConfig `device`.
    /// This should be called after a new device has been attached.
    
    [self setForDevice:device sensitivity:PointerConfig.sensitivity acceleration:PointerConfig.acceleration];
}

/// Doing the actual stuff

+ (void)setForDevice:(IOHIDDeviceRef)device
         sensitivity:(double)sensitivity
        acceleration:(double)acceleration {
    /// Sets pointer  sensitivity and pointer acceleration on a specific IOHIDDevice. Source for this is `PointerSpeedExperiments2.m`
    /// `sensitivity` is a multiplier on the default macOS pointer sensitivity
    /// `acceleration` should be between 0.0 and 3.0.
///         - It's the same value that can be set through the `defaults write .GlobalPreferences com.apple.mouse.scaling x` terminal command or through the "Tracking speed" slider in System Preferences > Mouse.
    ///     - x in `defaults write .GlobalPreferences com.apple.mouse.scaling x` can also be -1 (or any other negative number) which will turn the acceleration off (just like 0), but it will also increase the sensitivity. I haven't experimented with setting `acceleration` to -1. But we can change sensitivity through `sensitivity` anyways so it's not that interesting.
    
    /// Declare stuff
    kern_return_t kr;
    Boolean success;
    
    /// Get eventSystemClient
    IOHIDEventSystemClientRef eventSystemClient = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, HIDEventSystemClientTypePassive, NULL);
    
    /// Get IOService of the driver driving `dev`
    io_service_t IOHIDDeviceService = IOHIDDeviceGetService(device);
    io_service_t interfaceService = [IOUtility createChildOfRegistryEntry:IOHIDDeviceService withName:@"IOHIDInterface"];
    io_service_t driverService = [IOUtility createChildOfRegistryEntry:interfaceService withName:@"AppleUserHIDEventDriver"];
    
    /// Get ID of the driver
    uint64_t driverServiceID;
    kr = IORegistryEntryGetRegistryEntryID(driverService, &driverServiceID);
    assert(kr == 0);
    
    /// Get service client of the driver
    IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, driverServiceID);
    assert(serviceClient);
    
    /// Get pointerResolution from sensitivity
    /// - 400 is the default (unchangeable) pointer resolution in macOS.
    /// - Smaller pointerResolution -> higher sensitivity
    /// - Like this, `sensitvity` will act like a multiplier on the default sensitivity.
    double pointerResolution = 400.0 / sensitivity;
    
    /// Get pointerResolution as fixed point CFNumber
    CFNumberRef pointerResolutionCF = (__bridge  CFNumberRef)@(FloatToFixed(pointerResolution));
    
    /// Set pointer resolution on the driver
    success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolutionCF);
    assert(success);
    
    /// Get acceleration as fixed point CFNumber
    CFNumberRef mouseAccelerationCF = (__bridge CFNumberRef)@(FloatToFixed(acceleration));
    
    /// Set mouse acceleration on the driver
    success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDMouseAccelerationTypeKey), mouseAccelerationCF);
    assert(success);
    
    /// Release stuff
    IOObjectRelease(IOHIDDeviceService); /// Not sure if necessary because of function name used to create it (See CreateRule)
    IOObjectRelease(interfaceService);
    IOObjectRelease(driverService);
    CFRelease(eventSystemClient);
    CFRelease(serviceClient);
    
}

@end
