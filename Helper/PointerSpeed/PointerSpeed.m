//
// --------------------------------------------------------------------------
// PointerSpeed.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This class can set sensitivity and acceleration for a specific or all attached pointing devices

/// Imports

#import "PointerSpeed.h"
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

//extern void IOHIDServiceClientRemoveProperty(IOHIDServiceClientRef, CFStringRef); /// Doesn't exist :/

/// Implementation

@implementation PointerSpeed

/// Interface

+ (void)setForAllDevices {
    /// Calls setForDevice: on all attached devices
    /// This should be called after  the pointer movement settings have been reset for all devices.
    /// The CursorSense source code makes me think that happens after the computer wakes up from sleep or after a new display has been attached and etc. but more testing is needed. We might not need this at all
    
    for (Device *device in DeviceManager.attachedDevices) {
        [self setForDevice:device.IOHIDDevice];
    }
    
}

+ (void)setForDevice:(IOHIDDeviceRef)device {
    /// Sets the sensitivity and acceleration defined by PointerConfig `device`.
    /// This should be called after a new device has been attached.
    
//    [self old_setForDevice:device sensitivity:PointerConfig.sensitivity acceleration:PointerConfig.systemAccelerationCurvePresetIndex]; /// Debug

    if (PointerConfig.useSystemAccelerationCurve) {
        [self setForDevice:device sensitivity:PointerConfig.sensitivity accelerationPreset:PointerConfig.systemAccelerationCurvePresetIndex];
    } else {
        [self setForDevice:device sensitivity:PointerConfig.sensitivity accelerationCurve:PointerConfig.linearAccelerationCurve];
    }
}

// MARK: Doing stuff

+ (void)setForDevice:(IOHIDDeviceRef)device
         sensitivity:(double)sensitivity
        accelerationCurve:(MFAppleAccelerationCurveParams)accelerationCurve {
    /// Sets pointer  sensitivity and pointer acceleration on a specific IOHIDDevice. Source for this is `PointerSpeedExperiments2.m`
    
    /// Declare stuff
    Boolean success;
    
    /// Get eventSystemClient
    IOHIDEventSystemClientRef systemClient = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, HIDEventSystemClientTypePassive, NULL);
    
    /// Get eventServiceClient
    IOHIDServiceClientRef serviceClient = copyEventServiceClient(device, systemClient);
    if (serviceClient == NULL) {
        DDLogWarn(@"Failed to get service client. Can't set PointerSpeed");
        return;
    }
    
    /// Set sensitivity on the driver
    success = setSensitivity(sensitivity, serviceClient);
    assert(success);
    
    /// Set mouse acceleration on the driver
    success = setAccelerationToCurve(accelerationCurve, serviceClient);
    assert(success);
    
    CFRelease(serviceClient);
    CFRelease(systemClient);
}

+ (void)setForDevice:(IOHIDDeviceRef)device
         sensitivity:(double)sensitivity
  accelerationPreset:(double)acceleration {
    /// Sets pointer  sensitivity and pointer acceleration on a specific IOHIDDevice. Source for this is `PointerSpeedExperiments2.m`
    
    /// Validate
    ///     These are the values settable through System Preferences. Not sure if it makes sense to restrict to these values?
    assert(0 <= acceleration && acceleration <= 3.0);
    
    /// Declare stuff
    Boolean success;
    
    /// Get eventSystemClient
    IOHIDEventSystemClientRef systemClient = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, HIDEventSystemClientTypePassive, NULL);
    
    /// Get eventServiceClient
    IOHIDServiceClientRef serviceClient = copyEventServiceClient(device, systemClient);
    if (serviceClient == NULL) {
        DDLogWarn(@"Failed to get service client. Can't set PointerSpeed");
        return;
    }
    
    /// Set sensitivity on the driver
    success = setSensitivity(sensitivity, serviceClient);
    assert(success);
    
    /// Delete custom curves
//    cleanupCustomCurve(serviceClient);
    
    /// Set mouse acceleration on the driver
    success = setAccelerationPreset(acceleration, serviceClient);
    assert(success);
    
    CFRelease(serviceClient);
    CFRelease(systemClient);
}

// MARK: - Core

static IOHIDServiceClientRef copyEventServiceClient(IOHIDDeviceRef device, IOHIDEventSystemClientRef eventSystemClient) {
    
    /// Declare stuff
    kern_return_t kr;
    
    /// Get IOService of the driver driving `dev`
    io_service_t IOHIDDeviceService = IOHIDDeviceGetService(device);
    io_service_t interfaceService = [IOUtility createChildOfRegistryEntry:IOHIDDeviceService withName:@"IOHIDInterface"];
    io_service_t driverService = [IOUtility createChildOfRegistryEntry:interfaceService withName:@"AppleUserHIDEventDriver"];
    
    /// Get registryID of the driver
    uint64_t driverServiceID;
    kr = IORegistryEntryGetRegistryEntryID(driverService, &driverServiceID);
    
    /// Get event service client of the driver
    IOHIDServiceClientRef eventServiceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, driverServiceID);
    
    /// Release stuff
    IOObjectRelease(IOHIDDeviceService); /// Not sure if necessary because of function name used to create it (See CreateRule)
    IOObjectRelease(interfaceService);
    IOObjectRelease(driverService);
    
    /// Return
    return eventServiceClient;
}

static Boolean setSensitivity(double sensitivity, IOHIDServiceClientRef serviceClient) {
    /// `sensitivity` acts like a multiplier on the mouse speed before that speed is passed into the accelerationCurve. It can be used to compensate for different CPI on different mice.
    /// This only seems to work if we set the acceleration afterwards
    
    /// Declare success
    Boolean success;
    
    /// Get pointerResolution from sensitivity
    /// - 400 is the default (unchangeable) pointer resolution in macOS.
    /// - Smaller pointerResolution -> higher sensitivity
    /// - Like this, `sensitvity` will act like a multiplier on the default sensitivity.
    double pointerResolution = 400.0 / sensitivity;
    
    /// Get pointerResolution as fixed point CFNumber
    CFTypeRef pointerResolutionCF = (__bridge  CFTypeRef)@(FloatToFixed(pointerResolution));
    
    /// Set pointer resolution on the driver
    success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolutionCF);
    
    /// Return
    return success;
}

static Boolean setAccelerationPreset(double accelerationPresetIndex, IOHIDServiceClientRef eventServiceClient) {
    /// `accelerationPresetIndex` should be a double between 0.0 and 3.0.
    /// - It's the same value that can be set through the `defaults write .GlobalPreferences com.apple.mouse.scaling x` terminal command or through the "Tracking speed" slider in System Preferences > Mouse.
    /// - x in `defaults write .GlobalPreferences com.apple.mouse.scaling x` can also be -1 (or any other negative number) which will turn the acceleration off (just like 0), but it will also increase the sensitivity. I haven't experimented with setting `acceleration` to -1. But we can change sensitivity through `sensitivity` anyways so it's not that interesting.
    /// - See NotePlan "MMF - Scraps - macOS Pointer Acceleration Investigation 11.06.2022" for more info on how this works
    
    /// Debug
    NSString *accelType = (__bridge NSString *)IOHIDServiceClientCopyProperty(eventServiceClient, CFSTR(kIOHIDPointerAccelerationTypeKey));
    DDLogDebug(@"Setting accel preset %f for eventServiceClient: %@ with kIOHIDPointerAccelerationTypeKey: %@", accelerationPresetIndex, eventServiceClient, accelType);
    
    /// Delete custom curve
    cleanupCustomCurve(eventServiceClient);
    
    /// Get accelerationPresetIndex as fixed point CFNumber
    CFNumberRef mouseAccelerationCF = (__bridge CFNumberRef)@(FloatToFixed(accelerationPresetIndex));
    
    /// Set accel
    ///     Note: For as key for the acc value, the Apple driver uses the string that is the value for the key `kIOHIDPointerAccelerationTypeKey`. It's usually kIOHIDMouseAccelerationType.
    ///         (See NotePlan "MMF - Scraps - macOS Pointer Acceleration Investigation 11.06.2022")
    Boolean success = IOHIDServiceClientSetProperty(eventServiceClient, CFSTR(kIOHIDMouseAccelerationType), mouseAccelerationCF);
    
    /// Return success
    return success;
}


static double customCurveIndex = 100.0; /// This is arbitrary. But Apples curves have 0.0 <= index <= 3.0, so we should probably place our curve outside of the range (0.0, 3.0)

static Boolean setAccelerationToCurve(MFAppleAccelerationCurveParams params, IOHIDServiceClientRef eventServiceClient) {
    // TODO: Test if this works
    /// Set acceleration to a custom curve
    ///     Also see
    ///     - MFAppleAccelerationCurveParams documentation
    ///     - NotePlan "MMF - Scraps - macOS Pointer Acceleration Investigation 11.06.2022"
    
    /// Declare stuff
    Boolean success;
    
    /// Delete existing custom curves
    cleanupCustomCurve(eventServiceClient);
    
    /// Create custom curveParamDict
    ///     See IOHIDParameter.h
    NSDictionary *customCurveParams = @{
        @(kHIDAccelIndexKey): @(FloatToFixed(customCurveIndex)),
        @(kHIDAccelGainLinearKey): @(FloatToFixed(params.linearGain)),
        @(kHIDAccelGainParabolicKey): @(FloatToFixed(params.parabolicGain)),
        @(kHIDAccelGainCubicKey): @(FloatToFixed(params.cubicGain)),
        @(kHIDAccelGainQuarticKey): @(FloatToFixed(params.quarticGain)),
        @(kHIDAccelTangentSpeedLinearKey): @(FloatToFixed(params.capSpeedLinear)),
        @(kHIDAccelTangentSpeedParabolicRootKey): @(FloatToFixed(params.capSpeedParabolicRoot)),
    };
    
    /// Get curves
    NSMutableArray *curveParams = [NSMutableArray arrayWithArray:getCurves(eventServiceClient)];
    
    /// Debug
    DDLogDebug(@"Acceleration curve array before adding: %@", curveParams);
    
    /// Validate
    assert(![curveParams containsObject:customCurveParams]);
            
    /// Add curve
    [curveParams addObject:customCurveParams];
        
    /// Write curves
    success = setCurves(curveParams, eventServiceClient);
    
    /// Debug
    DDLogDebug(@"Acceleration curve array after adding: %@", getCurves(eventServiceClient));
        
    /// Early return
    if (!success) return false;
    
    /// Select custom curve
    success = setAccelerationPreset(customCurveIndex, eventServiceClient);
    
    /// Return
    return success;
}

// MARK: Helper

static NSArray *getCurves(IOHIDServiceClientRef eventServiceClient) {
    CFArrayRef curveParams = IOHIDServiceClientCopyProperty(eventServiceClient, CFSTR(kHIDAccelParametricCurvesKey));
//    CFArrayRef curveParams = IOHIDServiceClientCopyProperty(eventServiceClient, CFSTR(kIOHIDUserPointerAccelCurvesKey));
    return (__bridge_transfer NSArray *)curveParams;
}
static Boolean setCurves(NSArray *curves, IOHIDServiceClientRef eventServiceClient) {
    return IOHIDServiceClientSetProperty(eventServiceClient, CFSTR(kHIDAccelParametricCurvesKey), (__bridge CFArrayRef)curves);
}

//static Boolean setCurvesToDefault(IOHIDServiceClientRef eventServiceClient, IOHIDEventSystemClientRef eventSystemClient) {
//    /// Get default
//    NSArray *defaultCurves = (__bridge_transfer NSArray *)IOHIDEventSystemClientCopyProperty(eventSystemClient, CFSTR(kHIDAccelParametricCurvesKey));
//    return setCurves(defaultCurves, eventServiceClient);
//}

static void cleanupCustomCurve(IOHIDServiceClientRef eventServiceClient) {

    /// This doesn't work, don't use
    assert(false);
    
    NSMutableArray *curveParams = [NSMutableArray arrayWithArray:getCurves(eventServiceClient)];
    
    DDLogDebug(@"Deleting custom acceleration curves. Initial curves: %@", curveParams);
    
    NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
    for (int i = 0; i < curveParams.count; i++) {
        NSDictionary *curveParamDict = curveParams[i];
        NSNumber *curveIndexNS = curveParamDict[@(kHIDAccelIndexKey)];
        double curveIndex = FixedToFloat(curveIndexNS.integerValue);
        if (curveIndex == customCurveIndex) {
            [indexesToRemove addIndex:i];
        }
    }
    [curveParams removeObjectsAtIndexes:indexesToRemove];
    
    setCurves(curveParams, eventServiceClient);
    
    DDLogDebug(@"Deleted custom acceleration curves at indexes, %@ newCurves: %@", indexesToRemove, getCurves(eventServiceClient));
    
    setCurves(nil, eventServiceClient);
    
    
    DDLogDebug(@"Deleted custom acceleration curves. Result: %@", getCurves(eventServiceClient));
}

// MARK: Old

/// -------------------------------------------------------------------------------
/// Old implementation, that isn't modular and doesn't support totally custom curves. TODO: Remove or move to Experiments folder.
+ (void)old_setForDevice:(IOHIDDeviceRef)device
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
