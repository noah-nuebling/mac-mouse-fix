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
#import "ButtonInputReceiver_CG.h"
#import "MFDevice.h"
#import "ConfigFileInterface_HelperApp.h"
#import "PointerSpeed.h"

#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>



@implementation DeviceManager

# pragma mark - Global vars
static IOHIDManagerRef _HIDManager;
static NSMutableArray<MFDevice *> *_relevantDevices;

+ (BOOL)relevantDevicesAreAttached {
    return _relevantDevices.count > 0;
}



/**
 True entry point of the program
 */
+ (void)load_Manual {
    setupDeviceMatchingAndRemovalCallbacks();
    _relevantDevices = [NSMutableArray array];
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
//    NSLog(@"Seize manager close return: %d", retClose);
//    NSLog(@"Seize manager open return: %d", retOpen);
//}


# pragma mark - Setup callbacks
static void setupDeviceMatchingAndRemovalCallbacks() {
    
    
    // Create an HID Manager
//    _HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);
    _HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionIndependentDevices); // TODO: This might be worth a try for independent seizing of devices.
    
    // Create a Matching Dictionary
    CFMutableDictionaryRef matchDict1 = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                  2,
                                                                  &kCFTypeDictionaryKeyCallBacks,
                                                                  &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef matchDict2 = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                  2,
                                                                  &kCFTypeDictionaryKeyCallBacks,
                                                                  &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef matchDict3 = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                  2,
                                                                  &kCFTypeDictionaryKeyCallBacks,
                                                                  &kCFTypeDictionaryValueCallBacks);
    
    
    
    // Specify properties of the devices which we want to add to the HID Manager in the Matching Dictionary
    
    //int n = 0x227;
    
    CFArrayRef matches;
    
    int UP = 1;
    int U = 2;
    CFNumberRef genericDesktopUsagePage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &UP);
    CFNumberRef mouseUsage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &U);
    
    CFDictionarySetValue(matchDict1, CFSTR(kIOHIDElementUsagePageKey), kHIDPage_GenericDesktop);
    CFDictionarySetValue(matchDict1, CFSTR("DeviceUsage"), kHIDUsage_Mouse);
    CFDictionarySetValue(matchDict1, CFSTR("Transport"), CFSTR("USB")); // TODO: Shouldn't using only one matchDict instead of three and not specifying Transport work as well?

    CFDictionarySetValue(matchDict2, CFSTR("DeviceUsagePage"), genericDesktopUsagePage);
    CFDictionarySetValue(matchDict2, CFSTR("DeviceUsage"), mouseUsage);
    CFDictionarySetValue(matchDict2, CFSTR("Transport"), CFSTR("Bluetooth"));

    CFDictionarySetValue(matchDict3, CFSTR("DeviceUsagePage"), genericDesktopUsagePage);
    CFDictionarySetValue(matchDict3, CFSTR("DeviceUsage"), mouseUsage);
    CFDictionarySetValue(matchDict3, CFSTR("Transport"), CFSTR("Bluetooth Low Energy"));
  

    
    CFMutableDictionaryRef matchesList[] = {matchDict1, matchDict2, matchDict3};
    matches = CFArrayCreate(kCFAllocatorDefault, (const void **)matchesList, 3, NULL);
    
    // Register the Matching Dictionary to the HID Manager
    IOHIDManagerSetDeviceMatchingMultiple(_HIDManager, matches);
    
    CFRelease(matches);
    CFRelease(matchDict1);
    CFRelease(matchDict2);
    CFRelease(matchDict3);
    CFRelease(mouseUsage);
    CFRelease(genericDesktopUsagePage);
    
    // Register the HID Manager on our app’s run loop
    IOHIDManagerScheduleWithRunLoop(_HIDManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    // Open the HID Manager
//    IOReturn IOReturn = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeNone);
//    IOReturn IOReturn = IOHIDManagerOpen(_HIDManager, kIOHIDOptionsTypeSeizeDevice);
//    if(IOReturn) NSLog(@"IOHIDManagerOpen failed.");  //  Couldn't open the HID manager! TODO: proper error handling
    

    // Register a callback for USB device detection with the HID Manager, this will in turn register an button input callback for all devices that getFilteredDevicesFromManager() returns
    IOHIDManagerRegisterDeviceMatchingCallback(_HIDManager, &handleDeviceMatching, NULL);
    
    // Register a callback for USB device removal with the HID Manager
    IOHIDManagerRegisterDeviceRemovalCallback(_HIDManager, &handleDeviceRemoval, NULL);

}

# pragma mark - Handle callbacks

static void handleDeviceMatching(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    NSLog(@"New matching device");
    
    if (devicePassesFiltering(device)) {
        
        NSLog(@"Device Passed filtering");
        
        MFDevice *newMFDevice = [MFDevice deviceWithIOHIDDevice:device];
        [_relevantDevices addObject:newMFDevice];
        NSLog(@"Added device:\n%@", newMFDevice.description);
        NSLog(@"Relevant devices:\n%@", _relevantDevices);
        
        [ScrollControl decide];
        [ButtonInputReceiver_CG decide];
    }

    
    
    return;
    
}

static void handleDeviceRemoval(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    NSLog(@"Device Removed");
    
//    CFSetRef devices = IOHIDManagerCopyDevices(_HIDManager); // for some reason this copies the device which was just removed
//    NSLog(@"Devices still attached (includes device which was just removed): %@", devices);
//    CFRelease(devices);
    
    MFDevice *removedMFDevice = [MFDevice deviceWithIOHIDDevice:device];
    [_relevantDevices removeObject:removedMFDevice];
    NSLog(@"Removed device:\n%@", removedMFDevice);
    
    // If there aren't any relevant devices attached, then we might want to turn off some parts of the program.
    [ScrollControl decide];
    [ButtonInputReceiver_CG decide];
}


# pragma mark - Helper Functions

static BOOL devicePassesFiltering(IOHIDDeviceRef device) {

    
    NSString *deviceName = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR("Product"));
    NSNumber *deviceVendorID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR("VendorID"));
    
    if ([deviceName.lowercaseString rangeOfString:@"magic"].location != NSNotFound) { // TODO: Does it make sense? Shouldn't ignoring all Apple devices be enough? (This is untested)
        return NO;
    }
    if ([deviceName isEqualToString:@"Apple Internal Keyboard / Trackpad"]) { // TODO: Does it make sense? Does this work on other machines that are not mine? Shouldn't ignoring all Apple devices be enough?
        return NO;
    }
    if (deviceVendorID.integerValue == 1452) { // Apple's Vendor ID is 1452 (sometimes written as 0x5ac or 05ac)
        return NO;
    }
    return YES;

}

@end
