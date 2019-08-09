#import "DeviceManager.h"
#import "IOKit/hid/IOHIDManager.h"
#import "MomentumScroll.h"
#import "MouseInputReceiver.h"
#import "ConfigFileInterface.h"

@implementation DeviceManager

# pragma mark - Global vars
IOHIDManagerRef _hidManager;
static BOOL _relevantDevicesAreAttached;


+ (void)load {
    setupDeviceAddedAndRemovedCallbacks();
}

# pragma mark - Interface
+ (BOOL)relevantDevicesAreAttached {
    return _relevantDevicesAreAttached;
}

# pragma mark - Setup callbacks
static void setupDeviceAddedAndRemovedCallbacks() {
    
    
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
    CFNumberRef genericDesktopPrimaryUsagePage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &UP);
    CFNumberRef mousePrimaryUsage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &U);
    
    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsagePage"), genericDesktopPrimaryUsagePage);
    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsage"), mousePrimaryUsage);         // add mice
    CFDictionarySetValue(matchDict1, CFSTR("Transport"), CFSTR("USB"));                 // add USB devices
    
    CFMutableDictionaryRef matchesList[] = {matchDict1};
    matches = CFArrayCreate(kCFAllocatorDefault, (const void **)matchesList, 1, NULL);
    
    
    NSLog(@"matches: %@", matchDict2);
    
    //Register the Matching Dictionary to the HID Manager
    IOHIDManagerSetDeviceMatchingMultiple(_hidManager, matches);
    
    CFRelease(matches);
    CFRelease(matchDict1);
    CFRelease(matchDict2);
    CFRelease(matchDict3);
    CFRelease(mousePrimaryUsage);
    CFRelease(genericDesktopPrimaryUsagePage);
    
    
    
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
    
    // disable MomentumScroll if no relevant devices are attached
    CFSetRef devices = IOHIDManagerCopyDevices(_hidManager);
    if (CFSetGetCount(devices) == 0) {
        _relevantDevicesAreAttached = FALSE;
    }
    CFRelease(devices);
    
    [MomentumScroll startOrStopDecide];
    [MouseInputReceiver startOrStopDecide];
}


static void Handle_DeviceMatchingCallback (void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    NSLog(@"New matching device");
    
    if (devicePassesFiltering(device) ) {
        
        NSLog(@"Device Passed filtering");
        
        registerDeviceButtonInputCallback_InInputReceiverClass(device);
        
        _relevantDevicesAreAttached = TRUE;
        [MomentumScroll startOrStopDecide];
        [MouseInputReceiver startOrStopDecide];
    }
    
    
    
    
    
    // print stuff
    
    CFNumberRef vendorID = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    CFNumberRef productID = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    CFNumberRef version = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVersionNumberKey));
    CFStringRef vendor = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDManufacturerKey));
    CFStringRef product = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    
    

    
    NSLog(@"\nMatching device added: %@ %@ \nVendorID:%@ \nVendorName:%@ \nVersion:%@",
          vendor,
          product,
          vendorID,
          productID,
          version
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
    
    NSString *deviceName = [NSString stringWithUTF8String:
                            CFStringGetCStringPtr(IOHIDDeviceGetProperty(device, CFSTR("Product")), kCFStringEncodingMacRoman)];
    NSString *deviceNameLower = [deviceName lowercaseString];
    
    
    BOOL pass = YES;
    if (!([deviceNameLower rangeOfString:@"magic"].location == NSNotFound)) {
        pass = NO;
    } else {
        // check if config file disables this device
        CFNumberRef vendorID = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
        CFNumberRef productID = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
        NSString *deviceKey = [NSString stringWithFormat:@"VendorID:%@ ProductID:%@",vendorID,productID];
        NSNumber *deviceEnabled = [[[ConfigFileInterface.config objectForKey:@"DeviceOverrides"] objectForKey:deviceKey] objectForKey:@"enabled"];
        if (![deviceEnabled boolValue] && deviceEnabled != NULL) {
            pass = NO;
        }
    }
    
    return pass;
}

@end
