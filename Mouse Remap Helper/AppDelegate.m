//
//  AppDelegate.m
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 25.07.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import "AppDelegate.h"
#import "IOKit/hid/IOHIDManager.h"

@interface AppDelegate ()
@end

@implementation AppDelegate


CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    // kCGMouseEventButtonNumber (which key is pressed), kCGMouseEventClickState (double clicks),
    
    // kCGKeyboardEventKeycode
    
    int64_t eventValue = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
    NSLog(@"Value: %d", eventValue);
    
    CGEventType eventType = CGEventGetType(event);
    NSLog(@"Type: %d", eventType);
    
    
    return NULL;

}

NSMutableArray * pressedButtonList;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // pressed button list being filled by Handle_InputValueCallback (HIDManager)
    pressedButtonList = [[NSMutableArray alloc] init];
    
    // Register event Tap Callback
    CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown)                               |CGEventMaskBit(kCGEventOtherMouseDown) |
    CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventRightMouseUp) |CGEventMaskBit(kCGEventOtherMouseUp); //| CGEventMaskBit(kCGEventScrollWheel);
    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, eventTapCallback, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
    
    
    

    // Setup HID Manager and its callbacks
    initialize_everything();
    
    
}

static void initialize_everything() {
    // Insert code here to initialize your application
    
    
    
    
    
    // Create an HID Manager
    IOHIDManagerRef HIDManager = IOHIDManagerCreate(kCFAllocatorDefault,
                                                    kIOHIDOptionsTypeNone);
    
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
    
    CFArrayRef matches;
    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsage"), (const void *)0x227); // add mice
    CFDictionarySetValue(matchDict1, CFSTR("Transport"), CFSTR("USB")); // add USB devices
    CFDictionarySetValue(matchDict2, CFSTR("Transport"), CFSTR("Bluetooth")); // add Bluetooth Devices
    CFDictionarySetValue(matchDict3, CFSTR("Transport"), CFSTR("BluetoothLowEnergy")); // add bluetooth low energy devices
    
    CFMutableDictionaryRef matchesList[] = {matchDict1, matchDict2, matchDict3};
    matches = CFArrayCreate(kCFAllocatorDefault, (const void **)matchesList, 3, NULL);
    
    
    //Register the Matching Dictionary to the HID Manager
    IOHIDManagerSetDeviceMatchingMultiple(HIDManager, matches);
    
    CFRelease(matches);
    CFRelease(matchDict1);
    CFRelease(matchDict2);
    CFRelease(matchDict3);
    
    
    
    
    // Register the HID Manager on our app’s run loop
    IOHIDManagerScheduleWithRunLoop(HIDManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    // Open the HID Manager
    IOReturn IOReturn = IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone);
    if(IOReturn) NSLog(@"IOHIDManagerOpen failed.");  //  Couldn't open the HID manager! TODO: proper error handling
    
    
    
    
    
    
    
    IOHIDDeviceRef* device_array = getDevicesFromManager(HIDManager);
    
    
    
    
    
    
    /* register the device at index 0 */
    // If multiple mice are attached, it will refer to a random one
    
    if (device_array != NULL) {
        IOHIDDeviceRef dev_to_open = device_array[0];
        
        registerDeviceButtonInputCallback(dev_to_open);
        
         }
    
     free (device_array);
    
    

    
    
    
    
    // Register a callback for USB device detection with the HID Manager
    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, &Handle_DeviceMatchingCallback, NULL);
    // Register a callback for USB device removal with the HID Manager
    IOHIDManagerRegisterDeviceRemovalCallback(HIDManager, &Handle_DeviceRemovalCallback, NULL);
    
    
    
}










/* HID Manager Callback Handlers */



static void Handle_InputValueCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    IOHIDElementRef element = IOHIDValueGetElement(value);
    int state = (int) IOHIDValueGetIntegerValue(value);
    //UInt32 usagePage = IOHIDElementGetUsagePage(element);
    UInt32 button = IOHIDElementGetUsage(element);
    
    if (state == 1) {
        NSLog(@"STAAAATE");
        NSLog(@"Button: %u", (unsigned int)button);

        [pressedButtonList addObject: [NSNumber numberWithInt: (unsigned int)button]];
    }
    else {
        [pressedButtonList removeObject: [NSNumber numberWithInt:button]];
    }
    
    
    NSLog(@"pressedButtonList: %@", pressedButtonList);
    
    
}


static void Handle_DeviceMatchingCallback (void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    
    // if this one is the only device attached, attach it to the run loop
    
    if (USBDeviceCount(sender) == 1) {
        
        registerDeviceButtonInputCallback(device);
        
    }
    
    
    
    
    /* print stuff */
    
    
    // Retrieve the device name & serial number
    NSString *devName = [NSString stringWithUTF8String:
                         CFStringGetCStringPtr(IOHIDDeviceGetProperty(device, CFSTR("Product")), kCFStringEncodingMacRoman)];
    
    
    NSString *devPrimaryUsage = IOHIDDeviceGetProperty(device, CFSTR("PrimaryUsage"));
    
    // Log the device reference, Name, Serial Number & device count
    NSLog(@"\nMatching device added: %p\nModel: %@\nUsage: %@\nMatching device count: %ld",
          device,
          devName,
          devPrimaryUsage,
          USBDeviceCount(sender));
    
    
    
    
    return;
    
}



static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    // log info
    long matchingDeviceCount = USBDeviceCount(sender);
    NSLog(@"\nMatching device removed: %p\nMatching device count: %ld",
          (void *) device, matchingDeviceCount);
    
    
    
    
    // TODO: only do stuff if the removed device had its input report callback attached to the run loop
    
    
    
    if (matchingDeviceCount > 0) {
        
        IOHIDManagerClose(sender, kIOHIDOptionsTypeNone);
        initialize_everything();
        
    }
}




// Convenience Functions

static void registerDeviceButtonInputCallback(IOHIDDeviceRef device) {
    
    // Add callback function for the button input
    CFMutableDictionaryRef elementMatchDict1 = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                         2,
                                                                         &kCFTypeDictionaryKeyCallBacks,
                                                                         &kCFTypeDictionaryValueCallBacks);
    int nine = 9; // "usage Page" for Buttons
    CFNumberRef buttonRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &nine);
    CFDictionarySetValue (elementMatchDict1, CFSTR("UsagePage"), buttonRef);
    IOHIDDeviceSetInputValueMatching(device, elementMatchDict1);
    IOHIDDeviceRegisterInputValueCallback(device, &Handle_InputValueCallback, NULL);
    
    
    CFRelease(elementMatchDict1);
    
    
    // v2.0 TODO: (code for adding scrollwheel input to the callback is in the USBHID Project)
    
}


static IOHIDDeviceRef* getDevicesFromManager(IOHIDManagerRef HIDManager) {
    
    // get set of devices registered to the HID Manager (and convert it to a cArray so you can iterate over it or something like that??)
    CFSetRef device_set = IOHIDManagerCopyDevices(HIDManager);
    
    if (device_set != NULL) {
        CFIndex num_devices = CFSetGetCount(device_set);
        
        IOHIDDeviceRef *device_array = calloc(num_devices, sizeof(IOHIDDeviceRef));
        CFSetGetValues(device_set, (const void **) device_array);
        CFRelease(device_set);
        
        // filter devices that have "magic" in their product string
        IOHIDDeviceRef* device_array_filtered = calloc(num_devices, 8);
        int d_arr_fltrd_iterator = 0;
        for (int i = 0; i < num_devices; i++) {
            IOHIDDeviceRef curr_device = device_array[i];
            NSString *devName = [NSString stringWithUTF8String:
                                 CFStringGetCStringPtr(IOHIDDeviceGetProperty(curr_device, CFSTR("Product")), kCFStringEncodingMacRoman)];
            NSString *devNameLower = [devName lowercaseString];
            
            if ([devNameLower rangeOfString:@"magic"].location == NSNotFound) {
                //device is not magic mouse, or magic trackpad (hopefully - cant test) don't append it to device array filtered
                device_array_filtered[d_arr_fltrd_iterator] = device_array[0];
                d_arr_fltrd_iterator += 1;
            }
        }
        
        free (device_array);
        return device_array_filtered;
    }
    
    return 0;
}



// Counts the number of devices in the device set (incudes all USB devices that match our dictionary)
static long USBDeviceCount(IOHIDManagerRef HIDManager){
    
    
    //TODO: just use cfsetgetcount and subtract a global "filtered devices variable" instead of this
    
    
    
    
    NSLog(@"USBDeviceCount Called");
    
    // get set of devices registered to the HID Manager (and convert it to a cArray so you can iterate over it or something like that??)
    CFSetRef device_set = IOHIDManagerCopyDevices(HIDManager);
    
    if (device_set != NULL) {
        CFIndex num_devices = CFSetGetCount(device_set);
        
        IOHIDDeviceRef *device_array = calloc(num_devices, sizeof(IOHIDDeviceRef));
        CFSetGetValues(device_set, (const void **) device_array);
        CFRelease(device_set);
        
        
        
        // filter devices that have "magic" in their product string
        
        int num_devices_filtered = 0;
        
        
        for (int i = 0; i < num_devices; i++) {
            IOHIDDeviceRef curr_device = device_array[i];
            NSString *devName = [NSString stringWithUTF8String:
                                 CFStringGetCStringPtr(IOHIDDeviceGetProperty(curr_device, CFSTR("Product")), kCFStringEncodingMacRoman)];
            NSString *devNameLower = [devName lowercaseString];
            
            if ([devNameLower rangeOfString:@"magic"].location == NSNotFound) {
                //device is not magic mouse, or magic trackpad (hopefully - cant test) don't append it to device array filtered
                num_devices_filtered += 1;
            }
        }
        free (device_array);
        
        return num_devices_filtered;
    }
    
    return 0;
}

@end

