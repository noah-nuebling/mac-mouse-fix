//
// --------------------------------------------------------------------------
// DeviceManager.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
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

#import "ScrollControl.h"
#import "ButtonInputReceiver.h"
#import "ConfigInterface_Helper.h"
#import "PointerSpeed.h"

#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

#import "SharedUtility.h"



@implementation DeviceManager

# pragma mark - Global vars
static IOHIDManagerRef _HIDManager;
static NSMutableArray<MFDevice *> *_attachedDevices;

+ (BOOL)devicesAreAttached {
    return _attachedDevices.count > 0;
}
+ (NSArray<MFDevice *> *)attachedDevices {
    return _attachedDevices;
}

/**
 True entry point of the program
 */
+ (void)load_Manual {
    setupDeviceMatchingAndRemovalCallbacks();
    _attachedDevices = [NSMutableArray array];
}

# pragma mark - Interface

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


# pragma mark - Setup callbacks
static void setupDeviceMatchingAndRemovalCallbacks() {
    
    // Create an HID Manager
    
    _HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone); // TODO: kIOHIDManagerOptionIndependentDevices -> This might be worth a try for independent seizing of devices.
    
    // Specify properties of the devices which we want to add to the HID Manager in the Matching Dictionary
    
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

    NSArray *matchDicts = @[matchDict1, matchDict2, matchDict3];
    
    // Register the Matching Dictionary to the HID Manager
    IOHIDManagerSetDeviceMatchingMultiple(_HIDManager, (__bridge CFArrayRef)matchDicts);
    
    // Register the HID Manager on our app’s run loop
    IOHIDManagerScheduleWithRunLoop(_HIDManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    // Open the HID Manager
//    IOReturn IOReturn = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeNone);
//    IOReturn IOReturn = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeSeizeDevice);
//    if(IOReturn) DDLogInfo(@"IOHIDManagerOpen failed.");  //  Couldn't open the HID manager! TODO: proper error handling

    // Register a callback for USB device detection with the HID Manager, this will in turn register an button input callback for all devices that getFilteredDevicesFromManager() returns
    IOHIDManagerRegisterDeviceMatchingCallback(_HIDManager, &handleDeviceMatching, NULL);
    
    // Register a callback for USB device removal with the HID Manager
    IOHIDManagerRegisterDeviceRemovalCallback(_HIDManager, &handleDeviceRemoval, NULL);

}

# pragma mark - Handle callbacks

static void handleDeviceMatching(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    DDLogDebug(@"New matching IOHIDDevice: %@", device);
    
    if (devicePassesFiltering(device)) {
        
        
        MFDevice *newMFDevice = [MFDevice deviceWithIOHIDDevice:device];
        [_attachedDevices addObject:newMFDevice];
        
        [ScrollControl decide];
        [ButtonInputReceiver decide];
        
        DDLogInfo(@"New matching IOHIDDevice passed filtering and corresponding MFDevice was attached to device manager:\n%@", newMFDevice);
        
        // Testing PointerSpeed
        //[PointerSpeed setSensitivityViaIORegTo:1000 device:device];
    } else {
        DDLogInfo(@"New matching IOHIDDevice device didn't pass filtering");
    }
    
    DDLogDebug(@"%@", deviceInfo());
    
    return;
    
}

static void handleDeviceRemoval(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    MFDevice *removedMFDevice = [MFDevice deviceWithIOHIDDevice:device];
    [_attachedDevices removeObject:removedMFDevice]; // This might do nothing if this device wasn't contained in _attachedDevice (that's if it didn't pass filtering in `handleDeviceMatching()`)
    
    // If there aren't any relevant devices attached, then we might want to turn off some parts of the program.
    [ScrollControl decide];
    [ButtonInputReceiver decide];
    
    DDLogInfo(@"Matching IOHIDDevice was removed:\n%@", device);
    
    DDLogDebug(@"%@", deviceInfo());
    
}

/// This function is only used for debugging
static NSString *deviceInfo() {
    
    NSString *relevantDevices = stringf(@"Relevant devices:\n%@", _attachedDevices); // Relevant devices are those that are matching the match dicts defined in setupDeviceMatchingAndRemovalCallbacks() and which also pass the filtering in handleDeviceMatching()
    CFSetRef devices = IOHIDManagerCopyDevices(_HIDManager);
    NSString *matchingDevices = stringf(@"Matching devices: %@", devices);
    CFRelease(devices);
    
    return [relevantDevices stringByAppendingFormat:@"%@\n", matchingDevices];
}

# pragma mark - Helper Functions


static BOOL devicePassesFiltering(IOHIDDeviceRef device) {
    
    NSString *deviceName = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR("Product"));
    NSNumber *deviceVendorID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR("VendorID"));
    
    if ([deviceName isEqualToString:@"Apple Internal Keyboard / Trackpad"]) { // TODO: Does it make sense? Does this work on other machines that are not mine? Shouldn't ignoring all Apple devices be enough?
        return NO;
    }
    if (deviceVendorID.integerValue == 1452) { // Apple's Vendor ID is 1452 (sometimes written as 0x5ac or 05ac)
        return NO;
    }
    return YES;

}

@end
