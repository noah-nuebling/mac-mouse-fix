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
        Device *result = nil;
        
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
    setupDeviceMatchingAndRemovalCallbacks();
    _attachedDevices = [NSMutableArray array];
}

+ (void)deconfigureDevices {
    
    /// Meant to be called when the app closes
    
    for (Device *device in _attachedDevices) {
//        [PointerSpeed deconfigureDevice:device.iohidDevice];
    }
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
//    DDLogInfo(@"Seize manager close return: %d", retClose);
//    DDLogInfo(@"Seize manager open return: %d", retOpen);
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
    
    /// Register the HID Manager on our app’s run loop
    IOHIDManagerScheduleWithRunLoop(_manager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    /// Open the HID Manager
//    IOReturn IOReturn = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeNone);
//    IOReturn IOReturn = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeSeizeDevice);
//    if(IOReturn) DDLogInfo(@"IOHIDManagerOpen failed.");  //  Couldn't open the HID manager! TODO: proper error handling

    /// Register a callback for USB device detection with the HID Manager, this will in turn register an button input callback for all devices that getFilteredDevicesFromManager() returns
    IOHIDManagerRegisterDeviceMatchingCallback(_manager, &handleDeviceMatching, NULL);
    
    /// Register a callback for USB device removal with the HID Manager
    IOHIDManagerRegisterDeviceRemovalCallback(_manager, &handleDeviceRemoval, NULL);

}

# pragma mark - Handle callbacks

static void handleDeviceMatching(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    DDLogDebug(@"New matching IOHIDDevice: %@", device);
    
    if (devicePassesFiltering(device)) {
        
        /// Attach
        
        /// Create Device instance
        Device *newDevice = [Device deviceWithIOHIDDevice:device];
        
        /// Add to attachedDevices list
        [_attachedDevices addObject:newDevice];
//        [_iohidToAttachedCache removeAllObjects];
        
        /// Reset cache
        _maxButtonNumberAmongDevices_IsCached = false;
        
        /// Notify
//        [ReactiveDeviceManager.shared handleAttachedDevicesDidChange];
        [SwitchMaster.shared attachedDevicesChangedWithDevices:_attachedDevices];
        
        ///  Notify other objects
//        [Scroll decide];
//        [ButtonInputReceiver decide];
        
        ///
        /// Testing
        ///
        
        /// Set pointer sensitivity and acceleration for device
        ///     Edit: Seems that parametric curves are always set under Ventura, so we can't use tableBased curves :/ And in its current form this code will always crash. See PointerSpeed for more details.
    //    DDLogDebug(@"Setting PointerSpeed for device: %@", newDevice.description);
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
            DDLogDebug(@"Completed polling rate measurement! Period: %f ms, Rate: %ld Hz", period, rate);
        } progressCallback:^(double completion, double period, NSInteger rate) {
            DDLogDebug(@"Polling rate measurement %d\%% completed. Current estimate: %ld", (int)(completion*100), (long)rate);
        }];
        
    #endif
        
        /// Log
        DDLogInfo(@"New device added to attached devices:\n%@", newDevice);
        
    } else {
        DDLogInfo(@"New matching IOHIDDevice device didn't pass filtering");
    }
    
    DDLogDebug(@"%@", debugInfo());
    
    return;
    
}

static void handleDeviceRemoval(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    Device *attachedDevice = [DeviceManager attachedDeviceWithIOHIDDevice:device];
    
    if (attachedDevice == nil) {
        
        DDLogDebug(@"Device was removed but it wasn't attached to Mac Mouse Fix: %@", device);
        
    } else {
        
        /// Remove
        [_attachedDevices removeObject:attachedDevice];
        
        /// Reset cache
        
        _maxButtonNumberAmongDevices_IsCached = false;
        [_iohidToAttachedCache removeAllObjects];
        
        /// Notify
//        [ReactiveDeviceManager.shared handleAttachedDevicesDidChange];
        [SwitchMaster.shared attachedDevicesChangedWithDevices:_attachedDevices];
        
        /// Notifiy other objects
        ///     If there aren't any relevant devices attached, then we might want to turn off some parts of the program.
//        [Scroll decide];
//        [ButtonInputReceiver decide];
        
        /// Log
        
        DDLogInfo(@"Attached device was removed:\n%@", attachedDevice);
        DDLogDebug(@"Device Manager state after removal %@", debugInfo());
    }
}

# pragma mark - Helper Functions

static BOOL devicePassesFiltering(IOHIDDeviceRef device) {
    /// Helper function for handleDeviceMatching()
    
    NSString *deviceName = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR("Product"));
    NSNumber *deviceVendorID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR("VendorID"));
    
    if ([deviceName isEqualToString:@"Apple Internal Keyboard / Trackpad"]) { // TODO: Does it make sense? Does this work on other machines that are not mine? Shouldn't ignoring all Apple devices be enough?
        return NO;
    }
    if (deviceVendorID.integerValue == 1452) { /// Apple's Vendor ID is 1452 (sometimes written as 0x5ac or 05ac)
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
