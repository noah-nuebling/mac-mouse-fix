//
// --------------------------------------------------------------------------
// ButtonInputReceiver.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonInputReceiver.h"
#import "DeviceManager.h"
#import "IOKit/hid/IOHIDManager.h"
#import "ButtonInputParser.h"
#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>

#import "Utility_HelperApp.h"

#import "ScrollControl.h"

@implementation ButtonInputReceiver

BOOL _buttonEventInputSourceIsDeviceOfInterest;
CGEventSourceRef eventSource;
CFMachPortRef eventTap;


+ (void)initialize {
    NSLog(@"initializing (InputReceiver)");
    eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
    registerInputCallback_CG();
}

+ (void)decide {
    if ([DeviceManager relevantDevicesAreAttached]) {
        NSLog(@"started (InputReceiver)"); 
        [ButtonInputReceiver start];
    } else {
        NSLog(@"stopped (InputReceiver)");
        [ButtonInputReceiver stop];
    }
}
/// we don't start/stop the IOHIDDeviceRegisterInputValueCallback.
/// I think new devices should be attached to the callback by DeviceManager if a relevant device is attached to the computer
/// I think there is no cleanup we need to do if a device is detached from the computer.
+ (void)start {
    _buttonEventInputSourceIsDeviceOfInterest = false;
    CGEventTapEnable(eventTap, true);
}
+ (void)stop {
    CGEventTapEnable(eventTap, false);
}

/// Device manager calls this for each relevant device  it finds.
+ (void)registerInputCallback_HID:(IOHIDDeviceRef)device {
    NSCAssert(device != NULL, @"tried to register a device which equals NULL");
    
    CFMutableDictionaryRef buttonMatchDict = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    int nine = 9; // "usage Page" for Buttons
    CFNumberRef nineCF = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &nine);
    CFDictionarySetValue(buttonMatchDict, CFSTR("UsagePage"), nineCF);
    IOHIDDeviceSetInputValueMatching(device, buttonMatchDict);
    
    IOHIDDeviceRegisterInputValueCallback(device, &handleInput_HID, NULL);
    
    CFRelease(buttonMatchDict);
    CFRelease(nineCF);
}
/// CGEvent functions which we use to intercept and manipulate events cannot discriminate between devices. We use this IOHID function to solve the problem.
/// This function can filter different types of devices and when an input from a relevant device occurs, this function seems to always be called very shortly before any CGEvent function responding to the same input.
/// Then we can check if the _buttonEventInputSourceIsDeviceOfInterest flag is currently set from within CGEvent functions to filter devices.
/// Currently this mechanism is only implemented for Mouse Button input. It might be a good idea to implement it for scroll wheel input as well.

/// Device filtering criteria are set within setupDeviceMatchingAndRemovalCallbacks()
/// Which specific types of input from these devices trigger this callback function is set within registerInputCallback_HID (it's only buttons currently)
static void handleInput_HID(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    _buttonEventInputSourceIsDeviceOfInterest = true;
}

static void registerInputCallback_CG() {
    // Register event Tap Callback
    CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp);

    eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, handleInput_CG, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    
    CFRelease(runLoopSource);
}

CGEventRef handleInput_CG(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    BOOL b = _buttonEventInputSourceIsDeviceOfInterest;
    _buttonEventInputSourceIsDeviceOfInterest = false;
    
    if (b) {
        int buttonNumber = (int) CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
        
        long long pr = CGEventGetIntegerValueField(event, kCGMouseEventPressure);
        MFButtonInputType type = pr == 0 ? kMFButtonInputTypeButtonUp : kMFButtonInputTypeButtonDown;
        
        if (3 <= buttonNumber) {
            MFEventPassThroughEvaluation rt = [ButtonInputParser sendActionTriggersForInputWithButton:buttonNumber type:type];
            if (rt == kMFEventPassThroughRefusal) {
                return nil;
            }
        } else {
            NSLog(@"Received input from primary / secondary mouse button. This should never happen!");
        }
    }
    return event;
}

@end
