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
    NSString *devName = [NSString stringWithUTF8String:
                         CFStringGetCStringPtr(IOHIDDeviceGetProperty(device, CFSTR("Product")), kCFStringEncodingMacRoman)];
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


static BOOL devicePassesFiltering(IOHIDDeviceRef HIDDevice) {
    
    NSString *deviceName = [NSString stringWithUTF8String:
                            CFStringGetCStringPtr(IOHIDDeviceGetProperty(HIDDevice, CFSTR("Product")), kCFStringEncodingMacRoman)];
    NSString *deviceNameLower = [deviceName lowercaseString];
    
    if ([deviceNameLower rangeOfString:@"magic"].location == NSNotFound) {
        return TRUE;
    } else {
        return FALSE;
    }
}

@end
