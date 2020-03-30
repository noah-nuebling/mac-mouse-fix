//
// --------------------------------------------------------------------------
// MouseInputReceiver.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MouseInputReceiver.h"
#import "DeviceManager.h"
#import "IOKit/hid/IOHIDManager.h"
#import "InputParser.h"
#import "AppDelegate.h"
#import "../MessagePort/MessagePort_HelperApp.h"
#import <ApplicationServices/ApplicationServices.h>

#import "Utility_HelperApp.h"

#import "ScrollControl.h"

@implementation MouseInputReceiver

// global variables
static BOOL _relevantDevicesAreAttached;
+ (BOOL)relevantDevicesAreAttached {
    return _relevantDevicesAreAttached;
}

BOOL inputSourceIsDeviceOfInterest;
CGEventSourceRef eventSource;
CFMachPortRef eventTapMouse;


+ (void)initialize {
    NSLog(@"initializing (InputReceiver)");
    eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
    setupMouseInputCallback_CGEvent();
}

+ (void)decide {
    if ([DeviceManager relevantDevicesAreAttached]) {
        NSLog(@"started (InputReceiver)");
        [MouseInputReceiver start];
    } else {
        NSLog(@"stopped (InputReceiver)");
        [MouseInputReceiver stop];
    }
}
// we don't start/stop the IOHIDDeviceRegisterInputValueCallback.
// I think new devices should be attached to the callback by DeviceManager if a relevant device is attached to the computer
// I think there is no cleanup we need to do if a device is detached from the computer.
+ (void)start {
    inputSourceIsDeviceOfInterest = false;
    CGEventTapEnable(eventTapMouse, true);
}
+ (void)stop {
    CGEventTapEnable(eventTapMouse, false);
}

+ (void)Register_InputCallback_HID:(IOHIDDeviceRef)device {
    NSLog(@"Registering HID (InputReceiver)");
    IOHIDDeviceRegisterInputValueCallback(device, &Handle_InputCallback_HID, NULL);
}
static void Handle_InputCallback_HID(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    
    NSLog(@"Input HID (InputReceiver)");
    
    inputSourceIsDeviceOfInterest = true;
        //NSLog(@"Button Input from Registered Device %@, button: %@", sender, value);
}

static void setupMouseInputCallback_CGEvent() {
    NSLog(@"Registering CG (InputReceiver)");
    
    // Register event Tap Callback
    CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp);

    eventTapMouse = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, Handle_MouseEvent_CGEvent, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTapMouse, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    
    CFRelease(runLoopSource);
}

CGEventRef Handle_MouseEvent_CGEvent(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    NSLog(@"Input CG (InputReceiver)");
    
                                        /*
                                        NSLog(@"HANDLE EVENT");
                                        NSLog(@"current button: %d", currentButton);
                                        NSLog(@"inputSourceIsDeviceOfInterest: %d", inputSourceIsDeviceOfInterest);
                                         */
    
    if (inputSourceIsDeviceOfInterest) {
        
        inputSourceIsDeviceOfInterest = false;
        
        int currentButton = (int) CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
        int currentButtonState = (int) CGEventGetIntegerValueField(event, kCGMouseEventPressure);
        if (currentButtonState == 255) {
            currentButtonState = 1;
        }
        
        if ( (3 <= currentButton) && (currentButton <= 5) ) {
//            if (currentButton == 4) {
//                if (currentButtonState) {
//                    [SmoothScroll magnificationScrolling:YES];
//                } else {
//                    [SmoothScroll magnificationScrolling:NO];
//                }
//            } else if (currentButton == 5) {
//                if (currentButtonState) {
//                    [SmoothScroll horizontalScrolling:YES];
//                } else {
//                    [SmoothScroll horizontalScrolling:NO];
//                }
//            }
            CGEventRef eventPass = [InputParser parse:currentButton state:currentButtonState event:event];
            // this doesn't really make sense - passing through events is never needed except when there are no remaps at all. It also sometimes passes through events, when releasing a button after a long press, which doesn't make sense but which also doesn't break anything
            return eventPass;
        }
    }
    
    inputSourceIsDeviceOfInterest = false;
    return event;
}


/*
static void setupHIDManagerAndCallbacks() {

    
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
    
    int up = 1;
    int u = 2;
    CFNumberRef genericDesktopPrimaryUsagePage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &up);
    CFNumberRef mousePrimaryUsage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &u);
    
    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsage"), genericDesktopPrimaryUsagePage);
    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsage"), mousePrimaryUsage);         // add mice
    CFDictionarySetValue(matchDict1, CFSTR("Transport"), CFSTR("USB"));                 // add USB devices
    
    CFMutableDictionaryRef matchesList[] = {matchDict1};
    matches = CFArrayCreate(kCFAllocatorDefault, (const void **)matchesList, 1, NULL);
    
    
    NSLog(@"HIDManager: %@", _hidManager);
    NSLog(@"matches: %@", matchDict2);
    
    //Register the Matching Dictionary to the HID Manager
    IOHIDManagerSetDeviceMatchingMultiple(_hidManager, matches);
    
    CFRelease(matches);
    CFRelease(matchDict1);
    CFRelease(matchDict2);
    CFRelease(matchDict3);
    
    
    
    
    // Register the HID Manager on our app’s run loop
    IOHIDManagerScheduleWithRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    // Open the HID Manager
    IOReturn IOReturn = IOHIDManagerOpen(_hidManager, kIOHIDOptionsTypeNone);
    if(IOReturn) NSLog(@"IOHIDManagerOpen failed.");  //  Couldn't open the HID manager! TODO: proper error handling
    
    
    
    // Register a callback for USB device detection with the HID Manager, this will in turn register an button input callback for all devices that pass devicePassesFiltering()
    IOHIDManagerRegisterDeviceMatchingCallback(_hidManager, &Handle_DeviceMatchingCallbackHID, NULL);
    
    
    // Register a callback for USB device removal with the HID Manager
    IOHIDManagerRegisterDeviceRemovalCallback(_hidManager, &Handle_DeviceRemovalCallbackHID, NULL);
    
}
 */



/* HID Manager Callback Handlers */


/*
static void Handle_DeviceRemovalCallback_HID(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    // MomentumScroll
    CFSetRef devices = IOHIDManagerCopyDevices(_hidManager);
    if (CFSetGetCount(devices) == 0) {
        _relevantDevicesAreAttached = FALSE;
        [MomentumScroll decide];
    }
}
 */

/*
static void Handle_DeviceMatchingCallbackHID (void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    NSLog(@"New matching device");
    
    // register callback for button presses, if device passes filtering
    // currently filters devices with "magic" in their name string - untested
    if (devicePassesFiltering(device) ) {
        NSLog(@"Device Passed filtering");
        registerButtonInputCallbackForDevice(device);
    }
    
    // MomentumScroll
 
    // 29. June 2019 - As far as I understand, we can't easily differentiate between devices that did or didn't pass filtering, so we enable / disable momentum scroll based on all devices that the IOHIDmanager attaches to)
    _relevantDevicesAreAttached = TRUE;
    [MomentumScroll decide];
    NSLog(@"MomentumScroll.isEnabled: %hhd", MomentumScroll.isEnabled);
    NSLog(@"MomentumScroll.isRunning: %hhd", MomentumScroll.isRunning);
    
    
    
    
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

*/



// Convenience Functions


/*
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
    IOHIDDeviceRegisterInputValueCallback(device, &Handle_InputCallbackHID, NULL);
    
    
    CFRelease(elementMatchDict1);
    CFRelease(buttonRef);
    
    
    // v2.0 TODO: (code for adding scrollwheel input to the callback is in the USBHID Project)
    
    
}
 */

/*
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
 */
@end
