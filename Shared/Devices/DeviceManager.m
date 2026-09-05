//
// --------------------------------------------------------------------------
// DeviceManager.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

// Reference
// ref1:
    // IOHIDKeys:
    // https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.6.sdk/System/Library/Frameworks/IOKit.framework/Versions/A/Headers/hid/IOHIDKeys.h

// ref2:
    // HID Usage table
    // What the numbers for Usage and UsagePage mean
    // http://www.freebsddiary.org/APC/usb_hid_usages.php

#import "DeviceManager.h"
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDDevice.h>
#import <IOKit/hid/IOHIDKeys.h>

#import "Scroll.h"
#import "ButtonInputReceiver.h"
#import "Config.h"
#import "PointerSpeed.h"

#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

#import "SharedUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation DeviceManager

# pragma mark - Accessing attached devices

static IOHIDManagerRef _manager;
static NSMutableArray<Device *> *_attachedDevices;

/// Removal callbacks carry the exact IOHIDDeviceRef retained by Device. Logical
/// identifiers are deliberately excluded here because they may be absent or collide.
static Device * _Nullable attachedDeviceWithExactIOHIDDevice(IOHIDDeviceRef iohidDevice) {
    for (Device *device in _attachedDevices) {
        if (device.iohidDevice == iohidDevice) {
            return device;
        }
    }
    return nil;
}

+ (BOOL)devicesAreAttached {
    return _attachedDevices.count > 0;
}
+ (NSArray<Device *> *)attachedDevices {
    return _attachedDevices;
}

static NSMutableDictionary<NSNumber *, Device *> *_iohidToAttachedCache;
+ (Device * _Nullable)attachedDeviceWithIOHIDDevice:(IOHIDDeviceRef)iohidDevice {
    
    /// NOTE: Tried caching here using `_iohidToAttachedCache`, but it actually makes things slower.
    /// TODO: Remove caching
    
//    if (_iohidToAttachedCache == nil) {
//        _iohidToAttachedCache = [NSMutableDictionary dictionary];
//    }
//
//    NSNumber *key = (__bridge NSNumber *)IOHIDDeviceGetProperty(iohidDevice, CFSTR(kIOHIDUniqueIDKey));
//
//    Device *fromCache = _iohidToAttachedCache[key];
//
//    if (fromCache != nil) {
//        return fromCache;
//    } else {
//
        /// EventUtility may recreate a handle for the same logical device, so public
        /// event routing keeps the legacy fallback after preferring pointer identity.
        Device *result = attachedDeviceWithExactIOHIDDevice(iohidDevice);
        if (result != nil) {
            return result;
        }

        for (Device *device in _attachedDevices) {
            if ([device wrapsIOHIDDevice:iohidDevice]) {
                result = device;
                break;
            }
        }
        
//        if (result != nil && key != nil) {
//            [_iohidToAttachedCache setObject:result forKey:key];
//        }
        return result;
//    }
    

}

# pragma mark - Lifecycle

/**
 True entry point of the program.
 Edit Really?
 */
+ (void)load_Manual {
    _attachedDevices = [NSMutableArray array];
    setupDeviceMatchingAndRemovalCallbacks();
}

+ (void)deconfigureDevicesWithCompletion:(void (^)(BOOL completedBeforeDeadline))completion {
    [M720ShutdownCoordinator.shared beginShutdownWithCompletion:completion];
}

# pragma mark - Seize devices (Remove this)

//+ (void)seizeDevices:(BOOL)seize {
//    IOReturn retClose;
//    IOReturn retOpen;
//    
//    IOHIDManagerUnscheduleFromRunLoop(_HIDManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
//    retClose = IOHIDManagerClose(_HIDManager, kIOHIDOptionsTypeNone);
//    IOHIDManagerScheduleWithRunLoop(_HIDManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
//    if (seize) {
//        retOpen = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeSeizeDevice);
//    } else {
//        retOpen = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeNone);
//    }
//    _devicesAreSeized = seize;
//    DDLogInfo("Seize manager close return: %d", retClose);
//    DDLogInfo("Seize manager open return: %d", retOpen);
//}

#pragma mark - Device information

+ (BOOL)someDeviceHasScrollWheel {
    return _attachedDevices.count > 0;
}

+ (BOOL)someDeviceHasPointing {
    return _attachedDevices.count > 0;
}
+ (BOOL)someDeviceHasUsableButtons {
    /// We ignore MB 1 and MB 2. That's also why it's called "deviceHas**Usable**Buttons", and not just "deviceHasButtons"
    return self.maxButtonNumberAmongDevices > 2;
}

static BOOL _maxButtonNumberAmongDevices_IsCached = false;
+ (int)maxButtonNumberAmongDevices {
    
    static MFMouseButtonNumber _result = 0;
    
    if (_maxButtonNumberAmongDevices_IsCached) {
        return _result;
    } else {
        
        _result = 0;
        for (Device *device in _attachedDevices) {
            int b = device.nOfButtons;
            if (b > _result) {
                _result = b;
            }
        }
        
        _maxButtonNumberAmongDevices_IsCached = true;
        return _result;
    }
}

static void resetAttachedDeviceCaches(void) {
    _maxButtonNumberAmongDevices_IsCached = false;
    [_iohidToAttachedCache removeAllObjects];
}

+ (void)deviceMetadataDidChange:(Device *)device {
    if (_attachedDevices == nil ||
        [_attachedDevices indexOfObjectIdenticalTo:device] == NSNotFound) {
        return;
    }
    resetAttachedDeviceCaches();
    [SwitchMaster.shared attachedDevicesChangedWithDevices:_attachedDevices];
}

static void attachDevice(
    Device *device,
    NSMutableArray<Device *> *attachedDevices,
    BOOL resetsGlobalCaches,
    void (^notify)(NSArray<Device *> *devices),
    void (^controllerAttach)(Device *device)
) {
    [attachedDevices addObject:device];
    if (resetsGlobalCaches) {
        resetAttachedDeviceCaches();
    }
    notify(attachedDevices);
    controllerAttach(device);
}

static void prepareDeviceRemoval(
    Device *device,
    NSMutableArray<Device *> *attachedDevices,
    BOOL resetsGlobalCaches,
    void (^prepare)(Device *device, void (^completion)(void)),
    void (^notify)(NSArray<Device *> *devices)
) {
    __block BOOL didFinish = false;
    prepare(device, ^{
        if (didFinish) {
            return;
        }
        didFinish = true;

        NSUInteger index = [attachedDevices indexOfObjectIdenticalTo:device];
        if (index == NSNotFound) {
            return;
        }
        [attachedDevices removeObjectAtIndex:index];
        if (resetsGlobalCaches) {
            resetAttachedDeviceCaches();
        }
        notify(attachedDevices);
    });
}

#if DEBUG
+ (void)unitTestAttachDevice:(Device *)device
             attachedDevices:(NSMutableArray<Device *> *)attachedDevices
                      notify:(void (^)(NSArray<Device *> *devices))notify
            controllerAttach:(void (^)(Device *device))controllerAttach {
    attachDevice(device, attachedDevices, false, notify, controllerAttach);
}

+ (void)unitTestRemoveDevice:(Device *)device
             attachedDevices:(NSMutableArray<Device *> *)attachedDevices
                     prepare:(void (^)(Device *device, void (^completion)(void)))prepare
                      notify:(void (^)(NSArray<Device *> *devices))notify {
    prepareDeviceRemoval(device, attachedDevices, false, prepare, notify);
}
#endif

# pragma mark - Setup callbacks

static void setupDeviceMatchingAndRemovalCallbacks() {
    
    /// Create HID Manager
    
    _manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone); // TODO: kIOHIDManagerOptionIndependentDevices -> This might be worth a try for independent seizing of devices.
    
    /// Specify properties of the devices which we want to add to the HID Manager in the Matching Dictionary
    /// TODO:...
    ///     - Can't I simply omit the kIOHIDTransportKey to match mice on any transport? - Edit: No because that also matches Internal Trackpads
    ///     - Also what about kHIDUsage_GD_Pointer? Shouldn't I match for that, too?
    
    NSDictionary *matchDict1 = @{
        @(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
        @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Mouse),
        @(kIOHIDTransportKey): @(kIOHIDTransportUSBValue),
    };
    NSDictionary *matchDict2 = @{
        @(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
        @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Mouse),
        @(kIOHIDTransportKey): @(kIOHIDTransportBluetoothValue),
    };
    NSDictionary *matchDict3 = @{
        @(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
        @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Mouse),
        @(kIOHIDTransportKey): @("Bluetooth Low Energy"), // kIOHIDTransportBluetoothLowEnergyValue doesn't work (resolves to "BluetoothLowEnergy")
    };

    NSArray *matchArray = @[matchDict1, matchDict2, matchDict3];
    
    /// Register the Matching Dictionary to the HID Manager
    IOHIDManagerSetDeviceMatchingMultiple(_manager, (__bridge CFArrayRef)matchArray);
    
    /// Register the HID Manager on our app's run loop
    IOHIDManagerScheduleWithRunLoop(_manager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    /// Open the HID Manager
//    IOReturn IOReturn = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeNone);
//    IOReturn IOReturn = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeSeizeDevice);
//    if(IOReturn) DDLogInfo("IOHIDManagerOpen failed.");  //  Couldn't open the HID manager! TODO: proper error handling

    /// Register a callback for USB device detection with the HID Manager, this will in turn register an button input callback for all devices that getFilteredDevicesFromManager() returns
    IOHIDManagerRegisterDeviceMatchingCallback(_manager, &handleDeviceMatching, NULL);
    
    /// Register a callback for USB device removal with the HID Manager
    IOHIDManagerRegisterDeviceRemovalCallback(_manager, &handleDeviceRemoval, NULL);

}

# pragma mark - Handle callbacks

static void handleDeviceMatching(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    DDLogDebug("New matching IOHIDDevice: %@", device);
    
    if (devicePassesFiltering(device)) {
        
        /// Attach
        
        /// Create Device instance
        Device *newDevice = [Device deviceWithIOHIDDevice:device];

        attachDevice(
            newDevice,
            _attachedDevices,
            true,
            ^(NSArray<Device *> *devices) {
                [SwitchMaster.shared attachedDevicesChangedWithDevices:devices];
            },
            ^(Device *attachedDevice) {
                [M720HIDPPController.shared deviceDidAttach:attachedDevice];
            }
        );
        
        ///  Notify other objects
//        [Scroll decide];
//        [ButtonInputReceiver decide];
        
        ///
        /// Testing
        ///
        
        /// Set pointer sensitivity and acceleration for device
        ///     Edit: Seems that parametric curves are always set under Ventura, so we can't use tableBased curves :/ And in its current form this code will always crash. See PointerSpeed for more details.
    //    DDLogDebug("Setting PointerSpeed for device: %@", newDevice.description);
    //    [PointerSpeed setForDevice:newDevice.IOHIDDevice];
        
        ///
        
    #if 0 /// Polling rate measurer is unused so far and has a strange bug where it sometimes receives an event long after it's disabled and then crashes.
        
        /// Measure Polling Rate of new device
        static NSMutableArray *measurerMap = nil;
        if (measurerMap == nil) {
            measurerMap = [NSMutableArray array];
        }
        PollingRateMeasurer *measurer = [[PollingRateMeasurer alloc] init];
        [measurerMap addObject:measurer];
        [measurer measureOnDevice:newDevice numberOfSamples:400 completionCallback:^(double period, NSInteger rate) {
            DDLogDebug("Completed polling rate measurement! Period: %f ms, Rate: %ld Hz", period, rate);
        } progressCallback:^(double completion, double period, NSInteger rate) {
            DDLogDebug("Polling rate measurement %d\%% completed. Current estimate: %ld", (int)(completion*100), (long)rate);
        }];
        
    #endif
        
        /// Log
        DDLogInfo("New device added to attached devices:\n%@", newDevice);
        
    } else {
        DDLogInfo("New matching IOHIDDevice device didn't pass filtering");
    }
    
    DDLogDebug("%@", debugInfo());
    
    return;
    
}

static void handleDeviceRemoval(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    Device *attachedDevice = attachedDeviceWithExactIOHIDDevice(device);
    
    if (attachedDevice == nil) {
        
        DDLogDebug("Device was removed but it wasn't attached to Mac Mouse Fix: %@", device);
        
    } else {

        prepareDeviceRemoval(
            attachedDevice,
            _attachedDevices,
            true,
            ^(Device *removingDevice, void (^completion)(void)) {
                [M720HIDPPController.shared
                    prepareForDeviceRemoval:removingDevice
                    completion:completion];
            },
            ^(NSArray<Device *> *devices) {
                [SwitchMaster.shared attachedDevicesChangedWithDevices:devices];
                DDLogInfo("Attached device was removed:\n%@", attachedDevice);
                DDLogDebug("Device Manager state after removal %@", debugInfo());
            }
        );
    }
}

# pragma mark - Helper Functions

static BOOL devicePassesFiltering(IOHIDDeviceRef device) {
    /// Helper function for handleDeviceMatching()
    ///     [May 2025] Perhaps we could specify this Product/VendorID-based filtering directly in the matching dict with the kIOPropertyMatchKey?  ... But there doesn't seem to be 'negative' matching.
    
    NSString *deviceName = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR("Product"));
    NSNumber *deviceVendorID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR("VendorID"));
    
    if ([deviceName isEqualToString:@"Apple Internal Keyboard / Trackpad"]) { // TODO: Does it make sense? Does this work on other machines that are not mine? Shouldn't ignoring all Apple devices be enough?
        return NO;
    }
    if (deviceVendorID.integerValue == 1452) { /// Apple's Vendor ID is 1452 (sometimes written as 0x5ac or 05ac) || Update: [May 2025] My Magic Mouse has a VendorID of 76.
        return NO;
    }
    return YES;

}

static NSString *debugInfo() {
    
    NSString *relevantDevices = stringf(@"Relevant devices:\n%@", _attachedDevices); /// Relevant devices are those that are matching the match dicts defined in setupDeviceMatchingAndRemovalCallbacks() and which also pass the filtering in handleDeviceMatching()
    CFSetRef devices = IOHIDManagerCopyDevices(_manager);
    NSString *matchingDevices = stringf(@"Matching devices: %@", devices);
    CFRelease(devices);
    
    return [relevantDevices stringByAppendingFormat:@"%@\n", matchingDevices];
}

@end
