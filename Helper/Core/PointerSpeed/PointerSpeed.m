//
// --------------------------------------------------------------------------
// PointerSpeed.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This class can set sensitivity and acceleration curves for a specific or all attached pointing devices

/// Imports

#import "PointerSpeed.h"
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import "IOUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "DeviceManager.h"
#import "IOHIDAccelerationTableBridge.hpp"

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

@implementation PointerSpeed

/// Interface

+ (void)setForAllDevices {
    /// Calls setForDevice: on all attached devices
    /// This should be called after the pointer movement settings have been reset for all devices.
    /// The CursorSense source code makes me think that happens after the computer wakes up from sleep or after a new display has been attached and etc. but more testing is needed. We might not need this at all.
    
    for (Device *device in DeviceManager.attachedDevices) {
        [self setForDevice:device.iohidDevice];
    }
    
}

+ (void)setForDevice:(IOHIDDeviceRef)device {
    /// Sets pointer speed accoring to PointerConfig
    /// This should be called after a new device has been attached.

    if (PointerConfig.useSystemSpeed) {
        [self deconfigureDevice:device];
    } else if (PointerConfig.useParametricCurve) {
        [self setForDevice:device sensitivity:PointerConfig.CPIMultiplier parametricCurve:PointerConfig.parametricCurve];
    } else {
        [self setForDevice:device sensitivity:PointerConfig.CPIMultiplier tableBasedCurve:PointerConfig.tableBasedCurve];
    }
    
    /// Debug
    
//    double accelIndex = 123.0;
//    int pointCount = 3;
//    P points[3] = {
//        (P){.x = 0, .y = 0},
//        (P){.x = 1, .y = 2},
//        (P){.x = 2, .y = 4}
//    };
//    CFDataRef table = createAccelerationTableWithPoints(points, pointCount, accelIndex);
    CFDataRef defaultTable = copyDefaultAccelerationTable();
    printAccelerationTable(defaultTable);
}

+ (void)deconfigureDevice:(IOHIDDeviceRef)device {
    /// Restore the default macOS settigns for `device`
    [self setForDevice:device sensitivity:PointerConfig.systemSensitivity systemCurveIndex:PointerConfig.systemAccelCurveIndex];
}

// MARK: - Surface

+ (Boolean)setForDevice:(IOHIDDeviceRef)device
         sensitivity:(double)sensitivity
     tableBasedCurve:(NSArray *)points {
    
    /// Declare stuff
    Boolean success;
    
    /// Get eventServiceClient
    IOHIDServiceClientRef serviceClient;
    IOHIDEventSystemClientRef systemClient;
    copyEventServiceAndSystemClients(device, &serviceClient, &systemClient);
    
    /// Set sensitivity on the driver
    success = setSensitivity(sensitivity, serviceClient);
    assert(success);
    
    /// Set mouse acceleration on the driver
    /// TODO: This fails sometimes randomly - try again in a loop or sth
    success = success && setAccelToTableBasedCurve(points, serviceClient);
    assert(success);
    
    CFRelease(serviceClient);
    CFRelease(systemClient);
    
    return success;
}

+ (Boolean)setForDevice:(IOHIDDeviceRef)device
         sensitivity:(double)sensitivity
        parametricCurve:(MFAppleAccelerationCurveParams)accelCurve {
    
    /// Declare stuff
    Boolean success;
    
    /// Get eventServiceClient
    IOHIDServiceClientRef serviceClient;
    IOHIDEventSystemClientRef systemClient;
    copyEventServiceAndSystemClients(device, &serviceClient, &systemClient);
    
    /// Set sensitivity on the driver
    success = setSensitivity(sensitivity, serviceClient);
    assert(success);
    
    /// Set mouse acceleration on the driver
    success = success && setAccelToParametricCurve(accelCurve, serviceClient);
    assert(success);
    
    CFRelease(serviceClient);
    CFRelease(systemClient);
    
    return success;
}

+ (void)setForDevice:(IOHIDDeviceRef)device
         sensitivity:(double)sensitivity
    systemCurveIndex:(double)curveIndex {
    /// Sets pointer  sensitivity and pointer acceleration on a specific IOHIDDevice. Source for this is `PointerSpeedExperiments2.m`
    
    /// Validate
    ///     These are the values settable through System Preferences. Not sure if it makes sense to restrict to these values?
    assert(0 <= curveIndex && curveIndex <= 3.0);
    
    /// Declare stuff
    Boolean success;
    
    /// Get eventServiceClient
    IOHIDServiceClientRef serviceClient;
    IOHIDEventSystemClientRef systemClient;
    copyEventServiceAndSystemClients(device, &serviceClient, &systemClient);
    
    /// Set sensitivity on the driver
    success = setSensitivity(sensitivity, serviceClient);
    assert(success);
    
    /// Delete custom curves
    removeCustomCurves(serviceClient, serviceClient);
    
    /// Set mouse acceleration on the driver
    success = selectAccelCurveWithIndex(curveIndex, serviceClient);
    assert(success);
    
    /// Release
    CFRelease(serviceClient);
    CFRelease(systemClient);
}

// MARK: - Core lvl 2

static Boolean setSensitivity(double sensitivity, IOHIDServiceClientRef serviceClient) {
    /// `sensitivity` acts like a multiplier on the mouse speed before that speed is passed into the accelerationCurve. It can be used to compensate for different CPI on different mice.
    /// This only seems to do anything if we set the acceleration preset right afterwards
    
    /// Declare success
    Boolean success;
    
    /// Get pointerResolution from sensitivity
    /// - 400 is the default (unchangeable) pointer resolution in macOS.
    /// - Smaller pointerResolution -> higher sensitivity
    double pointerResolution = 400.0 / sensitivity;
    
    /// Get pointerResolution as fixed point CFNumber
    CFTypeRef pointerResolutionCF = (__bridge CFTypeRef)@(FloatToFixed(pointerResolution));
    
    /// Set pointer resolution on the driver
    success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolutionCF);
    
    /// Return
    return success;
}

static Boolean selectAccelCurveWithIndex(double accelerationPresetIndex, IOHIDServiceClientRef eventServiceClient) {
    /// The default Apple curves have an `accelerationPresetIndex` between 0.0 and 3.0.
    /// - This is the same value that can be set through the `defaults write .GlobalPreferences com.apple.mouse.scaling x` terminal command or through the "Tracking speed" slider in System Preferences > Mouse.
    /// - x in `defaults write .GlobalPreferences com.apple.mouse.scaling x` can also be -1 (or any other negative number) which will turn the acceleration off (just like 0), but it will also increase the sensitivity. I haven't experimented with setting `acceleration` to -1. But we can change sensitivity through `sensitivity` anyways so it's not that interesting.
    /// - See NotePlan "MMF - Scraps - macOS Pointer Acceleration Investigation 11.06.2022" for more info
    
    /// Debug
    NSString *accelType = (__bridge NSString *)IOHIDServiceClientCopyProperty(eventServiceClient, CFSTR(kIOHIDPointerAccelerationTypeKey));
    DDLogDebug(@"Setting AccelCurve preset %f for eventServiceClient: %@ with kIOHIDPointerAccelerationTypeKey: %@", accelerationPresetIndex, eventServiceClient, accelType);
    
    /// Get accelerationPresetIndex as fixed point CFNumber
    CFNumberRef mouseAccelerationCF = (__bridge CFNumberRef)@(FloatToFixed(accelerationPresetIndex));
    
    /// Set accel
    ///     Note: For as key for the acc value, the Apple driver uses the string that is the value for the key `kIOHIDPointerAccelerationTypeKey`. It's usually kIOHIDMouseAccelerationType.
    ///         (See NotePlan "MMF - Scraps - macOS Pointer Acceleration Investigation 11.06.2022")
    Boolean success = IOHIDServiceClientSetProperty(eventServiceClient, CFSTR(kIOHIDMouseAccelerationType), mouseAccelerationCF);
    
    /// Return success
    return success;
}

static double customCurveIndex = 123; /// This is arbitrary. PointerConfig.defaultAccelCurves documentation

static Boolean setAccelToTableBasedCurve(NSArray *points, IOHIDServiceClientRef eventServiceClient) {
    
    /// Declare stuff
    Boolean success;
        
    /// Create CFData for table
    CFDataRef table = createAccelerationTableWithArray(points);
    
    /// Print table
    printAccelerationTable(table);
    
    /// Write curves
    success = setTableCurves(table, eventServiceClient);
    
    /// Release
    CFRelease(table);
        
    /// Early return
    if (!success) return false;
    
    /// Select custom curve
    success = selectAccelCurveWithIndex(1.5, eventServiceClient);
    
    /// Return
    return success;
}

static Boolean setAccelToParametricCurve(MFAppleAccelerationCurveParams params, IOHIDServiceClientRef eventServiceClient) {
    /// Set acceleration to a custom curve
    ///     Also see
    ///     - MFAppleAccelerationCurveParams documentation
    ///     - NotePlan "MMF - Scraps - macOS Pointer Acceleration Investigation 11.06.2022"
    
    /// Declare stuff
    Boolean success;
    
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
    
    NSArray *customCurveArray = @[customCurveParams];
        
    /// Write curves
    success = setParametricCurves(customCurveArray, eventServiceClient);
        
    /// Early return
    if (!success) return false;
    
    /// Select custom curve
    success = selectAccelCurveWithIndex(customCurveIndex, eventServiceClient);
    
    /// Return
    return success;
}

// MARK: Core lvl 1

static Boolean parametricCurvesAreSet(IOHIDServiceClientRef serviceClient) {
    /// Once parametricCurves are set we don't know of a way to remove them again. And they override tableBasedCurves.
    ///     So there is no way to activate tableBasedCurves once parametricCurves have been set.
    
    CFArrayRef parametricCurves = IOHIDServiceClientCopyProperty(serviceClient, CFSTR(kHIDAccelParametricCurvesKey));
    
    if (parametricCurves == NULL) {
        return false;
    } else {
        return true;
    }
}

static Boolean setTableCurves(CFDataRef curves, IOHIDServiceClientRef serviceClient) {
    
    if (parametricCurvesAreSet(serviceClient)) {
        /// TODO: This is always true under Ventura! Change code to make it work anyways (Might not be able use tableBased curves ://///)
        DDLogError(@"Trying to set tableBasedCurve but parametricCurve is already set. This has no effect.");
        return false;
    }
    
    return IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerAccelerationTableKey), curves);
}

static Boolean setParametricCurves(NSArray *curves, IOHIDServiceClientRef serviceClient) {
    return IOHIDServiceClientSetProperty(serviceClient, CFSTR(kHIDAccelParametricCurvesKey), (__bridge CFArrayRef)curves);
    /// ^ See PointerConfig.defaultAccelCurves documentation for context
    ///     Fun fact: Setting a number crashes the window server under 12.4 Monterey
}

static Boolean removeCustomCurves(IOHIDServiceClientRef eventServiceClient, IOHIDServiceClientRef serviceClient) {
    
    if (parametricCurvesAreSet(serviceClient)) {
        return setParametricCurves(PointerConfig.systemAccelCurves, serviceClient);
        /// ^ See PointerConfig.defaultAccelCurves documentation for context
    } else {
        CFDataRef defaultCurves = copyDefaultAccelerationTable();
        Boolean success = setTableCurves(defaultCurves, serviceClient);
        assert(success);
        CFRelease(defaultCurves);
        return success;
    }
}

static IOHIDServiceClientRef copyEventServiceClient_WithEventSystem(io_service_t service, IOHIDEventSystemClientRef eventSystemClient) {
    
    uint64_t serviceID;
    kern_return_t kr = IORegistryEntryGetRegistryEntryID(service, &serviceID);
    
    if (kr != KERN_SUCCESS) {
        return NULL;
    }
    /// Get event service client of the registryEntry
    IOHIDServiceClientRef eventServiceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, serviceID);
    
    /// Return
    return eventServiceClient;
}

static void copyEventServiceAndSystemClients(IOHIDDeviceRef device, IOHIDServiceClientRef *serviceClient, IOHIDEventSystemClientRef *systemClient) {
    
    /// Caller is responsible for releasing serviceClient and systemClient
    /// Releasing the systemClient will make the serviceClient unusable.
    
    /// Get eventSystemClient
    *systemClient = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, HIDEventSystemClientTypePassive, NULL);
    
    /// Get eventServiceClient
    io_service_t driverService = copyDriverService(device);
    *serviceClient = copyEventServiceClient_WithEventSystem(driverService, *systemClient);
    if (*serviceClient == NULL) {
        DDLogWarn(@"Failed to get service client. Can't set PointerSpeed");
    }
    
    /// Release
    IOObjectRelease(driverService);
}

static io_service_t copyDriverService(IOHIDDeviceRef device) {
    
    /// Get IOService of the driver driving `dev`
    io_service_t iohidDeviceService = IOHIDDeviceGetService(device);
    io_service_t interfaceService = [IOUtility createChildOfRegistryEntry:iohidDeviceService withName:@"IOHIDInterface"];
    io_service_t driverService = [IOUtility createChildOfRegistryEntry:interfaceService withName:@"AppleUserHIDEventDriver"];
    
    /// Release stuff
    IOObjectRelease(iohidDeviceService); /// Not sure if necessary because of function name used to create it (See CreateRule)
    IOObjectRelease(interfaceService);
    
    /// Return
    return driverService;
}


@end
