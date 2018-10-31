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

// global variables
BOOL inputSourceIsDeviceOfInterest;
NSDictionary * buttonRemapDictFromFile;
CGEventSourceRef eventSource;
CFMachPortRef eventTap;
IOHIDManagerRef HIDManager;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSLog(@"running Mouse Remap Helper");
    
    // initialize global variables
    inputSourceIsDeviceOfInterest = false;
    eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);

    
    // setup callback which monitors changes to remaps.plist
    [self setupFSEventStreamCallback];
    
    // setup callbacks for mouse input
    setupBothInputCallbacks();
    
    // generate dict from remaps.plist
    buttonRemapDictFromFile = [AppDelegate fillButtonRemapDictFromFile];
    if (buttonRemapDictFromFile == nil) {
        NSLog(@"no remaps loaded");
    }
}


- (void) setupFSEventStreamCallback {
    NSBundle *thisBundle = [NSBundle bundleForClass:[AppDelegate class]];
    CFStringRef remapsFilePath = (__bridge CFStringRef) [thisBundle pathForResource:@"remaps" ofType:@"plist"];
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&remapsFilePath, 1, NULL);
    void *callbackInfo = NULL; // could put stream-specific data here.
    NSLog(@"pathsToWatch : %@", pathsToWatch);
    
    CFAbsoluteTime latency = 0.3;
    FSEventStreamRef remapsFileEventStream = FSEventStreamCreate(kCFAllocatorDefault, &Handle_FSEventStreamCallback, callbackInfo, pathsToWatch, kFSEventStreamEventIdSinceNow, latency, kFSEventStreamCreateFlagFileEvents ^ kFSEventStreamCreateFlagUseCFTypes);
    // kFSEventStreamCreateFlagNone
    // kFSEventStreamCreateFlagFileEvents
    
    FSEventStreamScheduleWithRunLoop(remapsFileEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    BOOL EventStreamStarted = FSEventStreamStart(remapsFileEventStream);
    NSLog(@"EventStreamStarted: %d", EventStreamStarted);
}


void Handle_FSEventStreamCallback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSLog(@"remaps.plist changed - reloading buttonRemapDictFromFile");
    
    buttonRemapDictFromFile = [AppDelegate fillButtonRemapDictFromFile];

}



CGEventRef Handle_EventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    NSLog(@"CGEventTap Callback Called");
    
    if (buttonRemapDictFromFile == nil) {
        NSLog(@"but no remaps are loaded");
        return event;
    }

    int currentButton = (int) CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
    int currentButtonState = (int) CGEventGetIntegerValueField(event, kCGMouseEventPressure);
    
    NSLog(@"Current Button: %d", currentButton);
    NSLog(@"State: %d", currentButtonState);
    NSLog(@"inputSourceIsDeviceOfInterest: %d", inputSourceIsDeviceOfInterest);
    NSLog(@"");
    
    
    if (inputSourceIsDeviceOfInterest) {
        
        if (currentButtonState == 0) { // -> button up event
            
            inputSourceIsDeviceOfInterest = false;
            return event;
            
        } else { // -> button down event
            
            
            // Get single click remap for pressed button and simulate corresponding key event
            NSString * currentButtonAsNSString = [NSString stringWithFormat: @"%d", currentButton];
            NSDictionary * remapsForCurrentButton = [buttonRemapDictFromFile objectForKey: currentButtonAsNSString];
            if (remapsForCurrentButton == nil) {
                inputSourceIsDeviceOfInterest = false;
                NSLog(@"No remap for this button");
                NSLog(@"");
                NSLog(@"");
                return event;
            }
            
            NSArray *singleClickRemapForCurrentButton;
            @try {
                singleClickRemapForCurrentButton = [[remapsForCurrentButton objectForKey:@"single"] objectForKey:@"click"];
            }
            @catch (NSException *exception){
                NSLog(@"%@", exception.reason);
                NSLog(@"Couldn't get remaps for button %d, there might be something wrong with remaps.plist", currentButton);
            }

            int keyCode = [[singleClickRemapForCurrentButton objectAtIndex:0] intValue];
            int modifierFlags = [[singleClickRemapForCurrentButton objectAtIndex:1] intValue];
            
            // simulate key events
            postKeyEvent(keyCode, modifierFlags, true, eventSource);    // posting keyDown Event
            postKeyEvent(keyCode, modifierFlags, false, eventSource);   // posting keyUp Event
            
            
            
            inputSourceIsDeviceOfInterest = false;
            return NULL;
            
        }
    }
    
    else { // -> input source is *not* device of interest
        return event;
    }
    
}


static void setupBothInputCallbacks() {
    /* Register event Tap Callback */
    CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown)                               |CGEventMaskBit(kCGEventOtherMouseDown)
    | CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventRightMouseUp)                               |CGEventMaskBit(kCGEventOtherMouseUp);
    eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, Handle_EventTapCallback, NULL);
    
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource);
    
    
    
    setupHIDManagerAndCallbacks();
    
}

static void setupHIDManagerAndCallbacks() {
    
    
    
    // Create an HID Manager
    HIDManager = IOHIDManagerCreate(kCFAllocatorDefault,
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
    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsage"), (const void *)0x227);       // add mice
    CFDictionarySetValue(matchDict1, CFSTR("Transport"), CFSTR("USB"));                 // add USB devices
    CFDictionarySetValue(matchDict2, CFSTR("Transport"), CFSTR("Bluetooth"));           // add Bluetooth Devices
    CFDictionarySetValue(matchDict3, CFSTR("Transport"), CFSTR("BluetoothLowEnergy"));  // add bluetooth low energy devices
    
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
    

    
    // Register a callback for USB device detection with the HID Manager, this will in turn register an button input callback for all devices that getFilteredDevicesFromManager() returns
    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, &Handle_DeviceMatchingCallback, NULL);
    
    
    
    // Register a callback for USB device removal with the HID Manager
    //IOHIDManagerRegisterDeviceRemovalCallback(HIDManager, &Handle_DeviceRemovalCallback, NULL);
    //CFArrayRef device_array = getFilteredDevicesFromManager(HIDManager);
    //registerButtonInputCallbackForDevices(device_array);
}



/* HID Manager Callback Handlers */



static void Handle_InputValueCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    
    inputSourceIsDeviceOfInterest = true;
    
    //NSLog(@"Button Input from Registered Device %@, button: %@", sender, value);
}


static void Handle_DeviceMatchingCallback (void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    NSLog(@"New matching device");
    
    if (devicePassesFiltering(device) ) {
        NSLog(@"Device Passed filtering");
        registerButtonInputCallbackForDevice(device);
    }
    


    
    
    
    
    // print stuff
    
    
    // Retrieve the device name & serial number
    NSString *devName = [NSString stringWithUTF8String:
                         CFStringGetCStringPtr(IOHIDDeviceGetProperty(device, CFSTR("Product")), kCFStringEncodingMacRoman)];
    
    
    NSString *devPrimaryUsage = IOHIDDeviceGetProperty(device, CFSTR("PrimaryUsage"));
    
    // Log the device reference, Name, Serial Number & device count
    NSLog(@"\nMatching device added: %p\nModel: %@\nUsage: %@\nMatching",
          device,
          devName,
          devPrimaryUsage
          //filteredUSBDeviceCount(sender)
          );
    
    
    
    
    return;
    
}


/*
static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    // log info
    long matchingDeviceCount = filteredUSBDeviceCount(sender);
    NSLog(@"\nMatching device removed: %p\nMatching device count: %ld",
          (void *) device, matchingDeviceCount);
    
    
    
    
    // TODO: only do stuff if the removed device had its input report callback attached to the run loop
    
    
    
    if (matchingDeviceCount > 0) {
        
        IOHIDManagerClose(sender, kIOHIDOptionsTypeNone);
        setupHIDManagerAndCallbacks();
        
    }
}
*/






// Convenience Functions


+ (NSDictionary*) fillButtonRemapDictFromFile {
    // Import the remaps from file
    NSBundle *thisBundle = [NSBundle bundleForClass:[AppDelegate class]];
    NSString *remapsFilePath = [thisBundle pathForResource:@"remaps" ofType:@"plist"];
    
    NSDictionary *outDict = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ( [fileManager fileExistsAtPath: remapsFilePath] == TRUE ) {
        NSData *fileData = [NSData dataWithContentsOfFile: remapsFilePath];
        
        NSError *error = nil;
        outDict = [NSPropertyListSerialization propertyListWithData:fileData options:NSPropertyListImmutable format:NULL error:&error];
        //NSLog(@"Serialization: %@", [NSPropertyListSerialization propertyListWithData:fileData options:NSPropertyListImmutable format:NULL error:&error]);
        if (  ![outDict isKindOfClass:[NSDictionary class]] || [[outDict allKeys] count] == 0 || (outDict == nil) || (error != nil) ) {
            outDict = nil;
            NSLog(@"No remaps found in remaps.plist");
        }
        
    } else {
        NSLog(@"No remaps.plist file found");
    }
    
    if (outDict == nil) {
        NSLog(@"disabling event Tap and HIDManager Callback");
        CGEventTapEnable(eventTap, FALSE);
        IOHIDManagerUnscheduleFromRunLoop(HIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    } else if (CGEventTapIsEnabled(eventTap) == FALSE) {
        NSLog(@"enabling event Tap and HIDManager Callback");
        CGEventTapEnable(eventTap, TRUE);
        IOHIDManagerScheduleWithRunLoop(HIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }

    return outDict;
}


static void postKeyEvent(int keyCode, CGEventFlags modifierFlags, BOOL keyDownBool, CGEventSourceRef eventSource) {
    
    @autoreleasepool {
        
        CGEventRef keyEvent = CGEventCreateKeyboardEvent (eventSource, (CGKeyCode)keyCode, keyDownBool);
        CGEventSetFlags(keyEvent, modifierFlags);
        CGEventTapLocation location = kCGHIDEventTap;
        
        CGEventPost(location, keyEvent);
        
        CFRelease(keyEvent);
    }
    
}


static void registerButtonInputCallbackForDevice(IOHIDDeviceRef device) {

    NSLog(@"registering device: %@", device);
    NSCAssert(device != NULL, @"tried to register a device which equals NULL");
    
    
    // Add callback function for the button input from the device
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
    CFRelease(buttonRef);
    
    
    // v2.0 TODO: (code for adding scrollwheel input to the callback is in the USBHID Project)

    
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

/*
static CFArrayRef getFilteredDevicesFromManager(IOHIDManagerRef HIDManager) {
    
    // get set of devices registered to the HID Manager (and convert it to a cArray so you can iterate over it or something like that??)
    CFSetRef device_set = IOHIDManagerCopyDevices(HIDManager);
    
    int d_arr_fltrd_iterator = 0;
    if (device_set != NULL) {
        CFIndex num_devices = CFSetGetCount(device_set);
        
        IOHIDDeviceRef *device_array_unfiltered = calloc(num_devices, sizeof(IOHIDDeviceRef));
        CFSetGetValues(device_set, (const void **) device_array_unfiltered);
        
        
        CFRelease(device_set);
        
        // filter devices that have "magic" in their product string
        IOHIDDeviceRef *device_array_filtered = calloc(num_devices, sizeof(IOHIDDeviceRef));
        for (int i = 0; i < num_devices; i++) {
            IOHIDDeviceRef curr_device = device_array_unfiltered[i];
            //NSLog(@"curr_device: %@", curr_device);
            NSString *devName = [NSString stringWithUTF8String:
                                 CFStringGetCStringPtr(IOHIDDeviceGetProperty(curr_device, CFSTR("Product")), kCFStringEncodingMacRoman)];
            NSString *devNameLower = [devName lowercaseString];
            
            if ([devNameLower rangeOfString:@"magic"].location == NSNotFound) {
                //device is not magic mouse, or magic trackpad (hopefully - cant test) don't append it to device array filtered
                device_array_filtered[d_arr_fltrd_iterator] = curr_device;
                //NSLog(@"tried to attach device to filtered device array");
                //NSLog(@"d_arr_fltrd_iterator: %d", d_arr_fltrd_iterator);
                //NSLog(@"device_array_filtered entry: %@", device_array_filtered[d_arr_fltrd_iterator]);
                //NSLog(@"device_array_filtered size: %zd", malloc_size((void **)device_array_filtered));
                //NSLog(@"curr_device size: %d", sizeof(IOHIDDeviceRef));
                d_arr_fltrd_iterator += 1;
            }
        }

        CFArrayRef device_array_filtered_CFArray = CFArrayCreate(kCFAllocatorDefault,(const void **)device_array_filtered, d_arr_fltrd_iterator, NULL);
        
        free (device_array_filtered);
        free (device_array_unfiltered);
        
        return device_array_filtered_CFArray;
    }
    
    return 0;
}
*/

/*
// Counts the number of devices in the device set (incudes all USB devices that match our dictionary)
static long filteredUSBDeviceCount(IOHIDManagerRef HIDManager){
    
    
    //TODO: just use cfsetgetcount and subtract a global "filtered devices variable" instead of this
    
    
    
    
    NSLog(@"filteredUSBDeviceCount Called");
    
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
*/

@end
