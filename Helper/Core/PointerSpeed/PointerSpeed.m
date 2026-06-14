//
// --------------------------------------------------------------------------
// PointerSpeed.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
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
#import "Device.h"
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
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef key);

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

    double multiplier = 1.0;
    BOOL ignoreSensitivity = NO;
    Device *attachedDev = [DeviceManager attachedDeviceWithIOHIDDevice:device];
    
    BOOL isLogitechDPI = NO;
    if (attachedDev != nil) {
        NSNumber *vid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
        if (vid != nil && vid.intValue == 0x046D) { // Logitech
            if (attachedDev.supportsLogitechDPI || [PointerConfig hasSavedLogitechDPI]) {
                isLogitechDPI = YES;
            }
        }
    }
    
    if (isLogitechDPI) {
        // Align driver resolution with physical mouse DPI to keep acceleration curve inputs consistent.
        // The custom curve output gains will scale linearly by (DPI / 400) in PointerConfig.
        double dpi = [PointerConfig logitechDPI];
        if (dpi < 200) { dpi = 1000; } // Sanity check fallback
        multiplier = 400.0 / dpi;
        ignoreSensitivity = YES;
    }

    if (PointerConfig.useSystemSpeed) {
        [self deconfigureDevice:device];
    } else if (PointerConfig.useParametricCurve) {
        [self setForDevice:device sensitivity:(PointerConfig.CPIMultiplier * multiplier) parametricCurve:[PointerConfig parametricCurveWithIgnoreSensitivity:ignoreSensitivity isLogitechDPI:isLogitechDPI]];
    } else {
        [self setForDevice:device sensitivity:(PointerConfig.CPIMultiplier * multiplier) tableBasedCurve:[PointerConfig tableBasedCurveWithIgnoreSensitivity:ignoreSensitivity isLogitechDPI:isLogitechDPI]];
    }
}

+ (void)deconfigureDevice:(IOHIDDeviceRef)device {
    /// Restore the default macOS settings for `device`
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
    
    if (serviceClient == NULL) {
        if (systemClient != NULL) CFRelease(systemClient);
        return false;
    }
    
    /// Set sensitivity on the driver
    success = setSensitivity(sensitivity, serviceClient);
    if (!success) {
        CFRelease(serviceClient);
        CFRelease(systemClient);
        return false;
    }
    
    /// Set mouse acceleration on the driver
    /// TODO: This fails sometimes randomly - try again in a loop or sth
    success = setAccelToTableBasedCurve(points, serviceClient);
    
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
    
    if (serviceClient == NULL) {
        if (systemClient != NULL) CFRelease(systemClient);
        return false;
    }
    
    /// Set sensitivity on the driver
    success = setSensitivity(sensitivity, serviceClient);
    if (!success) {
        CFRelease(serviceClient);
        CFRelease(systemClient);
        return false;
    }
    
    /// Set mouse acceleration on the driver
    success = setAccelToParametricCurve(accelCurve, serviceClient);
    
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
    if (curveIndex < -1.0) {
        curveIndex = -1.0;
    }
    
    /// Declare stuff
    Boolean success;
    
    /// Get eventServiceClient
    IOHIDServiceClientRef serviceClient;
    IOHIDEventSystemClientRef systemClient;
    copyEventServiceAndSystemClients(device, &serviceClient, &systemClient);
    
    if (serviceClient == NULL) {
        if (systemClient != NULL) CFRelease(systemClient);
        return;
    }
    
    /// Set sensitivity on the driver
    success = setSensitivity(sensitivity, serviceClient);
    if (!success) {
        CFRelease(serviceClient);
        CFRelease(systemClient);
        return;
    }
    
    /// Delete custom curves
    removeCustomCurves(serviceClient, serviceClient);
    
    /// Set mouse acceleration on the driver
    success = selectAccelCurveWithIndex(curveIndex, serviceClient);
    
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
    if (runningPreRelease()) {
        NSString *accelType = (__bridge_transfer NSString *)IOHIDServiceClientCopyProperty(eventServiceClient, CFSTR(kIOHIDPointerAccelerationTypeKey));
        DDLogDebug(@"Setting AccelCurve preset %f for eventServiceClient: %@ with kIOHIDPointerAccelerationTypeKey: %@", accelerationPresetIndex, eventServiceClient, accelType);
    }
    
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
    
    BOOL result = NO;
    
    if (parametricCurves != NULL) {
        CFRelease(parametricCurves);
        result = YES;
    }
    
    return result;
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


typedef struct IOHIDServiceFilterPlugInInterface {
    
    /// TESTING - Currently unused
    
    /// Wrote this myself based on `IOHIDPointerScrollFilter.cpp` -> `sIOHIDPointerScrollFilterFtbl` definition as well as `IOHIDDevicePlugIn.h` ->` `struct IOHIDDeviceDeviceInterface` definition
    /// Since `IOHIDPointerScrollFilter.cpp` -> `QueryInterface()` just returns `this`, I think we might be able to simply cast an instance of `IOHIDPointerScrollFilter` to this interface and then call the methods. But my understanding of using COM to interact with kernel drivers and whether IOHIDPointerScrollFilter is even a driver in this sense is lacking so idk.
    
    /// Required COM functions
    void *padding1;
    HRESULT         (STDMETHODCALLTYPE *QueryInterface)(void *this, REFIID iid, LPVOID *ppv);
    ULONG           (STDMETHODCALLTYPE *AddRef)(void *this);
    ULONG           (STDMETHODCALLTYPE *Release)(void *this);
        
    /// IOHIDSimpleServiceFilterPlugInInterface functions
    SInt32          (STDMETHODCALLTYPE *match)(void *this, IOHIDServiceRef service, IOOptionBits options);
    IOHIDEventRef   (STDMETHODCALLTYPE *filter)(void *this, IOHIDEventRef event);
    void *padding2;
    
    /// IOHIDServiceFilterPlugInInterface functions
    void            (STDMETHODCALLTYPE *open)(void *this, IOHIDServiceRef service, IOOptionBits options);
    void            (STDMETHODCALLTYPE *close)(void *this, IOHIDServiceRef service, IOOptionBits options);
    void            (STDMETHODCALLTYPE *scheduleWithDispatchQueue)(void *this, dispatch_queue_t queue);
    void            (STDMETHODCALLTYPE *unscheduleFromDispatchQueue)(void *this, dispatch_queue_t queue);
    CFTypeRef       (STDMETHODCALLTYPE *copyPropertyForClient)(void *this, CFStringRef key, CFTypeRef client);
    void            (STDMETHODCALLTYPE *setPropertyForClient)(void *this, CFStringRef key, CFTypeRef property, CFTypeRef client);
    void *padding3;
    void            (STDMETHODCALLTYPE *setEventCallback)(void *this, IOHIDServiceEventCallback callback, void * target, void * refcon);
    
} IOHIDServiceFilterPlugInInterface;

static IOHIDServiceClientRef copyEventServiceClient_WithEventSystem(io_service_t service, IOHIDEventSystemClientRef eventSystemClient) {
    if (service == 0) {
        return NULL;
    }
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
    
    NSString *product = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    DDLogInfo(@"[PointerSpeed] copyEventServiceAndSystemClients starting for device: %@", product);
    
    /// Get eventSystemClient
    *systemClient = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, HIDEventSystemClientTypePassive, NULL);
    if (*systemClient == NULL) {
        DDLogWarn(@"[PointerSpeed] Failed to create passive eventSystemClient");
    }
    
    /// Get eventServiceClient via traditional copyDriverService
    io_service_t driverService = copyDriverService(device);
    if (driverService != 0) {
        uint64_t entryID = 0;
        IORegistryEntryGetRegistryEntryID(driverService, &entryID);
        DDLogInfo(@"[PointerSpeed] driverService registry ID: 0x%llx", entryID);
        *serviceClient = copyEventServiceClient_WithEventSystem(driverService, *systemClient);
        IOObjectRelease(driverService);
    } else {
        *serviceClient = NULL;
    }
    
    /// Fallback: if serviceClient is NULL, find it by matching properties in the event system client
    if (*serviceClient == NULL && *systemClient != NULL) {
        DDLogInfo(@"[PointerSpeed] copyDriverService failed or returned defunct client, attempting fallback property-matching search");
        NSNumber *deviceVid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
        NSNumber *devicePid = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
        NSNumber *deviceLoc = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDLocationIDKey));
        NSString *deviceUnique = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDUniqueIDKey));
        
        DDLogInfo(@"[PointerSpeed] Target device properties: Vid = %@, Pid = %@, Loc = %@, Unique = %@", deviceVid, devicePid, deviceLoc, deviceUnique);
        
        CFArrayRef services = IOHIDEventSystemClientCopyServices(*systemClient);
        if (services != NULL) {
            DDLogInfo(@"[PointerSpeed] Number of services found: %ld", (long)CFArrayGetCount(services));
            for (id serviceClientUntyped in (__bridge NSArray *)services) {
                IOHIDServiceClientRef client = (__bridge IOHIDServiceClientRef)serviceClientUntyped;
                
                NSNumber *clientVid = (__bridge_transfer NSNumber *)IOHIDServiceClientCopyProperty(client, CFSTR(kIOHIDVendorIDKey));
                NSNumber *clientPid = (__bridge_transfer NSNumber *)IOHIDServiceClientCopyProperty(client, CFSTR(kIOHIDProductIDKey));
                NSNumber *clientLoc = (__bridge_transfer NSNumber *)IOHIDServiceClientCopyProperty(client, CFSTR(kIOHIDLocationIDKey));
                NSString *clientUnique = (__bridge_transfer NSString *)IOHIDServiceClientCopyProperty(client, CFSTR(kIOHIDUniqueIDKey));
                NSString *clientProduct = (__bridge_transfer NSString *)IOHIDServiceClientCopyProperty(client, CFSTR(kIOHIDProductKey));
                
                DDLogInfo(@"[PointerSpeed] Client product: '%@', properties: Vid = %@, Pid = %@, Loc = %@, Unique = %@", clientProduct, clientVid, clientPid, clientLoc, clientUnique);
                
                BOOL match = NO;
                
                // Safely convert unique IDs to string representations if present
                NSString *deviceUniqueStr = deviceUnique ? [NSString stringWithFormat:@"%@", deviceUnique] : nil;
                NSString *clientUniqueStr = clientUnique ? [NSString stringWithFormat:@"%@", clientUnique] : nil;
                
                if (deviceUniqueStr != nil && clientUniqueStr != nil && deviceUniqueStr.length > 0) {
                    if ([deviceUniqueStr isEqualToString:clientUniqueStr]) {
                        match = YES;
                    }
                }
                
                if (!match && deviceVid != nil && clientVid != nil && devicePid != nil && clientPid != nil) {
                    if ([deviceVid isEqual:clientVid] && [devicePid isEqual:clientPid]) {
                        // Check if the service client conforms to Mouse or Pointer usage
                        BOOL conforms = IOHIDServiceClientConformsTo(client, 0x01, 0x02) ||  // kHIDPage_GenericDesktop, kHIDUsage_GD_Mouse
                                        IOHIDServiceClientConformsTo(client, 0x01, 0x01);    // kHIDPage_GenericDesktop, kHIDUsage_GD_Pointer
                        
                        if (conforms) {
                            NSInteger devLocVal = deviceLoc ? [deviceLoc integerValue] : 0;
                            NSInteger cliLocVal = clientLoc ? [clientLoc integerValue] : 0;
                            
                            if (devLocVal != 0 && cliLocVal != 0) {
                                if (devLocVal == cliLocVal) {
                                    match = YES;
                                }
                            } else {
                                // If location ID is 0 or missing on either, match by product name if available
                                if (product != nil && clientProduct != nil) {
                                    if ([product.lowercaseString isEqualToString:clientProduct.lowercaseString]) {
                                        match = YES;
                                    }
                                } else {
                                    // Fallback: if we don't have product names, match by Vid and Pid
                                    match = YES;
                                }
                            }
                        }
                    }
                }
                
                if (match) {
                    // Retain the service client as the caller is responsible for releasing it
                    CFRetain(client);
                    *serviceClient = client;
                    DDLogInfo(@"[PointerSpeed] Found matching service client via property matching for device: %@", product);
                    break;
                }
            }
            CFRelease(services);
        } else {
            DDLogWarn(@"[PointerSpeed] IOHIDEventSystemClientCopyServices returned NULL");
        }
    }
    
    if (*serviceClient == NULL) {
        DDLogWarn(@"Failed to get service client. Can't set PointerSpeed (device: %@)", product);
    } else {
        DDLogInfo(@"[PointerSpeed] Successfully got service client for device %@", product);
    }
    
    if (false) {
        
        /// TESTING
        /// Findings: (Under Ventura 13.3.1)
        ///     - When you set props on the IORegistryEntry they actually get set in the "HIDEventServiceProperties" subdict of the IORegistryEntry. When you write props using IOHIDServiceClientSetProperty() on the serviceClient (which we've been doing so far to successfully change the acceleration), the props also end up inside "HIDEventServiceProperties". Setting on the IORegistryEntry directly might allow us to remove the kHIDAccelParametricCurvesKey value in order to activate table-based accel
        ///     - When you set the mouse tracking speed to lowest in system settings, the kHIDAccelParametricCurvesKey value seems to disappear??
        ///     - Right now – after successfull removing the kHIDAccelParametricCurvesKey using IORegistryEntrySetCFProperties – the kHIDAccelParametricCurvesKey value is never showing up inside the "HIDEventServiceProperties" subdict - even when we reconnect the mouse???? Edit: And even when we restart the computer???
        ///     -
        
        /// Try to access plug-in intefaces
        
        //    NSDictionary *plugInTypes = (__bridge_transfer NSDictionary *)IORegistryEntryCreateCFProperty(driverService, CFSTR(kIOCFPlugInTypesKey), kCFAllocatorDefault, kNilOptions);
        //
        //    for (NSString *plugInTypeIDString in plugInTypes.allKeys) {
        //        CFUUIDRef plugInTypeID = CFUUIDCreateFromString(kCFAllocatorDefault, (__bridge CFStringRef)plugInTypeIDString);
        //
        //        NSArray *factoryIDs = (__bridge NSArray *)CFPlugInFindFactoriesForPlugInType(plugInTypeID);
        //
        //        for (id f in factoryIDs) {
        //            CFUUIDRef factoryID = (__bridge CFUUIDRef)f;
        //
        //            IUnknownVTbl **iunknown = CFPlugInInstanceCreate(kCFAllocatorDefault, factoryID, plugInTypeID);
        //            CFPlu
        //        }
        //
        //    }
        
        
        
        /// Try to modifiy IORegistryEntry
        
        //    IORegistryEntrySetCFProperty(driverService, CFSTR("Noah"), (__bridge CFArrayRef)@[@1, @2, @3]);
        //    IORegistryEntrySetCFProperty(driverService, CFSTR(kHIDAccelParametricCurvesKey), <#CFTypeRef property#>)
        
        CFMutableDictionaryRef props = NULL;
        IORegistryEntryCreateCFProperties(driverService, &props, kCFAllocatorDefault, 0);
        NSMutableDictionary *eventServiceProps = [((__bridge NSMutableDictionary *)props) objectForKey:@"HIDEventServiceProperties"];
        
        //    [eventServiceProps setObject:@[@1, @2, @3] forKey:@(kHIDAccelParametricCurvesKey)];
        [eventServiceProps removeObjectForKey:@(kHIDAccelParametricCurvesKey)]; /// This doesn't work since we can't remove things, but when you boot without a mouse attached the value is nil!!!!!  Also see my StackOverflow question: https://stackoverflow.com/questions/76176480/how-to-remove-a-property-from-an-ioregistryentry-from-user-space
        
        [eventServiceProps setObject:@YES forKey:@("FlipLeftAndRightEdgeGestures")];
        //    [eventServiceProps setObject:@"It workedddddd!" forKey:@"Noah's test"];
        //    [eventServiceProps setObject:@"It workeddddddd, too!" forKey:@"Noah's second test"];
        [eventServiceProps removeObjectForKey:@"Noah's second test"]; /// Setting works, but removing doesn't seem to do anything
        [eventServiceProps removeObjectForKey:@"Noah's test"];
        
        //    [eventServiceProps setObject:@[@1, @2, @3] forKey:@(kHIDAccelParametricCurvesKey)];
        
        /// Try to set generally
        IORegistryEntrySetCFProperties(driverService, (__bridge CFMutableDictionaryRef)eventServiceProps);
        
        /// Try to set for key
        ///     This creates a nested entry inside `HIDEventServiceProperties`
        IORegistryEntrySetCFProperty(driverService, CFSTR("HIDEventServiceProperties"), (__bridge CFMutableDictionaryRef)eventServiceProps);
        
        
        
        /// Try to modify eventService through queryInterface
        //    IOHIDServiceFilterPlugInInterface *interface = (IOHIDServiceFilterPlugInInterface *)serviceClient;
        //
        //    IOReturn ret = kIOReturnError;
        //    IOCFPlugInInterface **plugin = NULL;
        //    SInt32 score = 0;
        //
        //    ret = IOCreatePlugInInterfaceForService(driverService, kIOHIDDeviceTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
        
        //    IOCreatePlugInInterfaceForService(driverService, <#CFUUIDRef pluginType#>, IUnknownUUID, <#IOCFPlugInInterface ***theInterface#>, <#SInt32 *theScore#>)
        //    interface->setPropertyForClient(interface, CFSTR(kHIDAccelParametricCurvesKey), (__bridge CFArrayRef)@[@1, @2, @3], NULL);
        
        
        /// `e IOHIDServiceClientCopyProperty(*serviceClient, CFSTR("HIDAccelCurves"))`
        
        /// Try to get the changes into eventService
        selectAccelCurveWithIndex(1.5, *serviceClient); /// CRASH when u set kHIDAccelParametricCurvesKey to sth weird.
        setSensitivity(1.1, *serviceClient);
        
        /// Test
        CFTypeRef noahsTest = IOHIDServiceClientCopyProperty(*serviceClient, CFSTR("Noah's test"));
        CFTypeRef parametricCurves = IOHIDServiceClientCopyProperty(*serviceClient, CFSTR(kHIDAccelParametricCurvesKey));
        
        DDLogDebug(@"EventService values – test: %@, parametricCurves: %@", noahsTest, parametricCurves);
    }
    
    
    /// Release
    if (driverService != 0) {
        IOObjectRelease(driverService);
    }
}

static io_registry_entry_t findChildOfRegistryEntryRecursive(io_registry_entry_t entry, NSString *name) {
    if (entry == 0) return 0;
    io_iterator_t iterator;
    kern_return_t kr = IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator);
    if (kr != KERN_SUCCESS) {
        return 0;
    }
    io_registry_entry_t childEntry;
    BOOL childEntryFound = NO;
    while ((childEntry = IOIteratorNext(iterator))) {
        char childName[1000];
        IORegistryEntryGetNameInPlane(childEntry, kIOServicePlane, childName);
        if ([name isEqualToString:@(childName)]) {
            childEntryFound = YES;
            break;
        }
        
        io_registry_entry_t deepChild = findChildOfRegistryEntryRecursive(childEntry, name);
        if (deepChild != 0) {
            childEntryFound = YES;
            IOObjectRelease(childEntry);
            childEntry = deepChild;
            break;
        }
        IOObjectRelease(childEntry);
    }
    IOObjectRelease(iterator);
    return childEntryFound ? childEntry : 0;
}

static void printRegistrySubtree(io_registry_entry_t entry, int indent) {
    io_name_t name;
    io_name_t className;
    IORegistryEntryGetName(entry, name);
    IOObjectGetClass(entry, className);
    uint64_t entryID = 0;
    IORegistryEntryGetRegistryEntryID(entry, &entryID);
    
    NSMutableString *indentStr = [NSMutableString string];
    for (int i = 0; i < indent; i++) [indentStr appendString:@"  "];
    DDLogInfo(@"[PointerSpeed] Subtree: %@Name: %s, Class: %s, ID: 0x%llx", indentStr, name, className, entryID);
    
    io_iterator_t iterator;
    kern_return_t kr = IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator);
    if (kr == KERN_SUCCESS) {
        io_registry_entry_t child;
        while ((child = IOIteratorNext(iterator))) {
            printRegistrySubtree(child, indent + 1);
            IOObjectRelease(child);
        }
        IOObjectRelease(iterator);
    }
}

static io_service_t copyDriverService(IOHIDDeviceRef device) {
    if (!device) return 0;
    /// Get IOService of the driver driving `dev`
    io_service_t iohidDeviceService = IOHIDDeviceGetService(device);
    if (iohidDeviceService == 0) {
        DDLogWarn(@"[PointerSpeed] IOHIDDeviceGetService returned 0");
        return 0;
    }
    uint64_t parentID = 0;
    IORegistryEntryGetRegistryEntryID(iohidDeviceService, &parentID);
    io_name_t parentClassName;
    IOObjectGetClass(iohidDeviceService, parentClassName);
    DDLogInfo(@"[PointerSpeed] copyDriverService checking iohidDeviceService ID: 0x%llx, Class: %s", parentID, parentClassName);
    
    io_service_t interfaceService = findChildOfRegistryEntryRecursive(iohidDeviceService, @"IOHIDInterface");
    if (interfaceService == 0) {
        DDLogWarn(@"[PointerSpeed] failed to find IOHIDInterface under iohidDeviceService (ID: 0x%llx)", parentID);
        printRegistrySubtree(iohidDeviceService, 0);
        IOObjectRelease(iohidDeviceService);
        return 0;
    }
    io_service_t driverService = findChildOfRegistryEntryRecursive(interfaceService, @"AppleUserHIDEventDriver");
    if (driverService == 0) {
        DDLogWarn(@"[PointerSpeed] failed to find AppleUserHIDEventDriver under IOHIDInterface");
        printRegistrySubtree(iohidDeviceService, 0);
    }
    
    /// Release stuff
    IOObjectRelease(iohidDeviceService);
    IOObjectRelease(interfaceService);
    
    /// Return
    return driverService;
}


@end
