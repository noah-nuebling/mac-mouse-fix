//
// --------------------------------------------------------------------------
// DeviceManager.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "DeviceManager.h"
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDDevice.h>
#import <IOKit/hid/IOHIDKeys.h>

#import "ScrollControl.h"
#import "MouseInputReceiver.h"
#import "ConfigFileInterface_HelperApp.h"
#import "../PointerSpeed/PointerSpeed.h"

#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>



@implementation DeviceManager

# pragma mark - Global vars
IOHIDManagerRef _hidManager;
static BOOL _relevantDevicesAreAttached;


/**
 True entry point of the program
 */
+ (void)load_Manual {
    setupDeviceAddedAndRemovedCallbacks();
}

# pragma mark - Interface
+ (BOOL)relevantDevicesAreAttached {
    return _relevantDevicesAreAttached;
}

# pragma mark - Setup callbacks
static void setupDeviceAddedAndRemovedCallbacks() {
    
    // Reference
    // ref1:
        // IOHIDKeys:
        // https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.6.sdk/System/Library/Frameworks/IOKit.framework/Versions/A/Headers/hid/IOHIDKeys.h
    
    
    // Create an HID Manager
    _hidManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);
    
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
    
    CFDictionarySetValue(matchDict1, CFSTR("DeviceUsagePage"), genericDesktopUsagePage);
    CFDictionarySetValue(matchDict1, CFSTR("DeviceUsage"), mouseUsage);
    CFDictionarySetValue(matchDict1, CFSTR("Transport"), CFSTR("USB"));

    CFDictionarySetValue(matchDict2, CFSTR("DeviceUsagePage"), genericDesktopUsagePage);
    CFDictionarySetValue(matchDict2, CFSTR("DeviceUsage"), mouseUsage);
    CFDictionarySetValue(matchDict2, CFSTR("Transport"), CFSTR("Bluetooth"));

    CFDictionarySetValue(matchDict3, CFSTR("DeviceUsagePage"), genericDesktopUsagePage);
    CFDictionarySetValue(matchDict3, CFSTR("DeviceUsage"), mouseUsage);
    CFDictionarySetValue(matchDict3, CFSTR("Transport"), CFSTR("Bluetooth Low Energy"));
  
    // Old version - this doesn't match some mice like the mx master, bacause it only matches primary usage and usage page, not any pair of usage and usage page within the usagePairs dictionary of the device. Look to ref1 for a better explanation.
//    CFNumberRef genericDesktopPrimaryUsagePage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &UP);
//    CFNumberRef mousePrimaryUsage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &U);
//
//    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsagePage"), genericDesktopPrimaryUsagePage);
//    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsage"), mousePrimaryUsage);
//    CFDictionarySetValue(matchDict1, CFSTR("Transport"), CFSTR("USB"));
//
//    CFDictionarySetValue(matchDict2, CFSTR("PrimaryUsagePage"), genericDesktopPrimaryUsagePage);
//    CFDictionarySetValue(matchDict2, CFSTR("PrimaryUsage"), mousePrimaryUsage);
//    CFDictionarySetValue(matchDict2, CFSTR("Transport"), CFSTR("Bluetooth"));
//
//    CFDictionarySetValue(matchDict3, CFSTR("PrimaryUsagePage"), genericDesktopPrimaryUsagePage);
//    CFDictionarySetValue(matchDict3, CFSTR("PrimaryUsage"), mousePrimaryUsage);
//    CFDictionarySetValue(matchDict3, CFSTR("Transport"), CFSTR("Bluetooth Low Energy"));
    
    CFMutableDictionaryRef matchesList[] = {matchDict1, matchDict2, matchDict3};
    matches = CFArrayCreate(kCFAllocatorDefault, (const void **)matchesList, 3, NULL);
    
    

    
    // Register the Matching Dictionary to the HID Manager
    IOHIDManagerSetDeviceMatchingMultiple(_hidManager, matches);
    
    CFRelease(matches);
    CFRelease(matchDict1);
    CFRelease(matchDict2);
    CFRelease(matchDict3);
    CFRelease(mouseUsage);
    CFRelease(genericDesktopUsagePage);
    
    
    
    // Register the HID Manager on our app’s run loop
    IOHIDManagerScheduleWithRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    // Open the HID Manager
    IOReturn IOReturn = IOHIDManagerOpen(_hidManager, kIOHIDOptionsTypeNone);
    if(IOReturn) NSLog(@"IOHIDManagerOpen failed.");  //  Couldn't open the HID manager! TODO: proper error handling
    

    // Register a callback for USB device detection with the HID Manager, this will in turn register an button input callback for all devices that getFilteredDevicesFromManager() returns
    IOHIDManagerRegisterDeviceMatchingCallback(_hidManager, &Handle_DeviceMatchingCallback, NULL);
    
    // Register a callback for USB device removal with the HID Manager
    IOHIDManagerRegisterDeviceRemovalCallback(_hidManager, &Handle_DeviceRemovalCallback, NULL);

}

# pragma mark - Handle callbacks

static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    NSLog(@"Device Removed");
    
    // Check if there are still relevant devices atached.
    CFSetRef devices = IOHIDManagerCopyDevices(_hidManager); // for some reason this copies the device which was just removed
    NSLog(@"Devices still attached (includes device which was just removed): %@", devices);
    if (CFSetGetCount(devices) <= 1) { // so we're accounting for that by using a 1 here instead of a 0
        _relevantDevicesAreAttached = FALSE;
    }
    CFRelease(devices);
    
    // If there aren't any relevant devices attached, then we might want to turn off some parts of the program.
    [ScrollControl decide];
    [MouseInputReceiver decide];
}

static void Handle_DeviceMatchingCallback (void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    
    // TODO: Clean this up
//    [PointerSpeed setAccelerationTo:0.2];
//    [PointerSpeed setSensitivityTo:0 device:device];
    
    
    NSLog(@"New matching device");
    
    
    if (devicePassesFiltering(device) ) {
    
        
        
        NSLog(@"Device Passed filtering");
        
        registerDeviceButtonInputCallback_InInputReceiverClass(device);
        
        _relevantDevicesAreAttached = TRUE;
        [ScrollControl decide];
        [MouseInputReceiver decide];
    }
    

    
;
    NSLog(@"added device info: %@", (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR("VendorID")));
    
    NSString *devName = IOHIDDeviceGetProperty(device, CFSTR("Product"));
    NSString *devPrimaryUsage = IOHIDDeviceGetProperty(device, CFSTR("PrimaryUsage"));
    NSLog(@"\nMatching device added: %p\nModel: %@\nUsage: %@\nMatching",
          device,
          devName,
          devPrimaryUsage
          );
    
    
    return;
    
}


# pragma mark - Helper Functions

static void registerDeviceButtonInputCallback_InInputReceiverClass(IOHIDDeviceRef device) {
    
    NSCAssert(device != NULL, @"tried to register a device which equals NULL");
    
    CFMutableDictionaryRef elementMatchDict1 = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                         2,
                                                                         &kCFTypeDictionaryKeyCallBacks,
                                                                         &kCFTypeDictionaryValueCallBacks);
    int nine = 9; // "usage Page" for Buttons
    CFNumberRef buttonRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &nine);
    CFDictionarySetValue (elementMatchDict1, CFSTR("UsagePage"), buttonRef);
    IOHIDDeviceSetInputValueMatching(device, elementMatchDict1);
    
    
    [MouseInputReceiver Register_InputCallback_HID: device];
    
    CFRelease(elementMatchDict1);
    CFRelease(buttonRef);
}


static BOOL devicePassesFiltering(IOHIDDeviceRef device) {

    
    NSString *deviceName = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR("Product"));
    NSNumber *deviceVendorID = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR("VendorID"));
    
    if ([deviceName.lowercaseString rangeOfString:@"magic"].location != NSNotFound) {
        return NO;
    }
    if ([deviceName isEqualToString:@"Apple Internal Keyboard / Trackpad"]) {
        return NO;
    }
    if (deviceVendorID.integerValue == 1452) { // Apple's Vendor ID is 1452 (sometimes written as 0x5ac or 05ac)
        return NO;
    }
    return YES;

}

@end
