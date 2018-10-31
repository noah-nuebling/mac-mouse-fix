//
//  AddingFieldView.m
//  Mouse Remap
//
//  Created by Noah Nübling on 31.10.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import "AddingFieldView.h"
#import "IOKit/hid/IOHIDManager.h"
#import "AppDelegate.h"


@implementation AddingFieldView

// global vars
IOHIDManagerRef HIDManager;
BOOL inputSourceIsDeviceOfInterest;
CFMachPortRef eventTap;

- (void)viewDidLoad {
    NSLog(@"Adding Field View did Load");
}


// (viewDidLoad)
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    setupBothInputCallbacks();
}
// better alternatives might be:
// viewDidUnhide, viewDidMoveToSuperview, viewDidMoveToWindow




//input callbacks

// eventTap Callback
CGEventRef Handle_EventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    NSLog(@"CGEventTap Callback Called");
    NSLog(@"inputSourceIsDeviceOfInterest: %d", inputSourceIsDeviceOfInterest);
    
    if (inputSourceIsDeviceOfInterest) {
        
        // parse input
        
        inputSourceIsDeviceOfInterest = FALSE;
        return nil;
    }
    return event;
}

// HIDManager callback
static void Handle_InputValueCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    NSLog(@"Button Input from Registered Device!");
    inputSourceIsDeviceOfInterest = TRUE;
}





// enable input callbacks while the mouse pointer is over Adding Field
- (void)mouseEntered:(NSEvent *)theEvent {
    NSLog(@"mouse entered AddingField");
    
    CFSetRef devicesSet = IOHIDManagerCopyDevices(HIDManager);
    CFIndex numOfDevices = CFSetGetCount(devicesSet);
    IOHIDDeviceRef *deviceArray = calloc(numOfDevices, sizeof(IOHIDDeviceRef));;
    CFSetGetValues(devicesSet, (const void **)deviceArray);
    for (int i = 0; i < numOfDevices; i++) {
        IOHIDDeviceRef device = deviceArray[i];
        if (devicePassesFiltering(device) ) {
            // Device Passed filtering
            registerButtonInputCallbackForDevice(device);
        }
    }
    CGEventTapEnable(eventTap, TRUE);
    IOHIDManagerScheduleWithRunLoop(HIDManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
} // disable, when it's not
- (void)mouseExited:(NSEvent *)theEvent {
    NSLog(@"mouse exited AddingField");
    CGEventTapEnable(eventTap, FALSE);
    IOHIDManagerUnscheduleFromRunLoop(HIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}








// setting up input callbacks

static void setupBothInputCallbacks() {
    /* Register event Tap Callback */
    CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown)                               |CGEventMaskBit(kCGEventOtherMouseDown)
    | CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventRightMouseUp)                               |CGEventMaskBit(kCGEventOtherMouseUp);
    eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, Handle_EventTapCallback, NULL);
    
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource);
    
    CGEventTapEnable(eventTap, FALSE);
    
    
    
    setupHIDManagerAndCallbacks();
    
    
}

// ----------------------------------------------------------------

// setting up HIDManager callbacks - everything below this line should be mostly identical to the implementation in Mouse Remap Helper

static void setupHIDManagerAndCallbacks() {
    
    NSLog(@"setting up HID Manager");
    
    HIDManager = IOHIDManagerCreate(kCFAllocatorDefault,
                                    kIOHIDManagerOptionNone);
    
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
    
    
    // schedule with runLoop
    
    
    // Open the HID Manager
    IOReturn IOReturn = IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone);
    if(IOReturn) NSLog(@"IOHIDManagerOpen failed.");  //  Couldn't open the HID manager! TODO: proper error handling
    
    
    // register device matching callback
    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, &Handle_DeviceMatchingCallback, NULL);
    

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

static void Handle_DeviceMatchingCallback (void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    NSLog(@"New matching device");
    
    if (devicePassesFiltering(device) ) {
        NSLog(@"Device Passed filtering");
        registerButtonInputCallbackForDevice(device);
    }
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
