//
// --------------------------------------------------------------------------
// ButtonInputReceiver.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonInputReceiver_CG.h"
#import "DeviceManager.h"
#import <IOKit/hid/IOHIDManager.h>
#import "ButtonInputParser.h"
#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>

#import "Utility_HelperApp.h"

#import "ScrollControl.h"

@implementation ButtonInputReceiver_CG

CGEventSourceRef eventSource;
CFMachPortRef eventTap;


+ (void)load_Manual {
    eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
    registerInputCallback();
}

+ (void)decide {
    if ([DeviceManager relevantDevicesAreAttached]) {
        NSLog(@"started (InputReceiver)"); 
        [ButtonInputReceiver_CG start];
    } else {
        NSLog(@"stopped (InputReceiver)");
        [ButtonInputReceiver_CG stop];
    }
}
/// we don't start/stop the IOHIDDeviceRegisterInputValueCallback.
/// I think new devices should be attached to the callback by DeviceManager if a relevant device is attached to the computer
/// I think there is no cleanup we need to do if a device is detached from the computer.
+ (void)start {
    _deviceWhichCausedThisButtonInput = nil; // Not sure if necessary
    CGEventTapEnable(eventTap, true);
}
+ (void)stop {
    CGEventTapEnable(eventTap, false);
}

static void registerInputCallback() {
    // Register event Tap Callback
    CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp);

    eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, handleInput, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    
    CFRelease(runLoopSource);
}

+ (void)insertFakeEvent:(CGEventRef)event {
    CGEventRef ret = handleInput(0,0,event,nil);
    if (ret) {
        CGEventPost(kCGHIDEventTap, ret);
    }
}

/// Instances of MFDevice set this value to themselves when they receive input from the IOHIDDevice which they own.
/// Input from the IOHIDDevice will always occur shortly before `ButtonInputReceiver::handleIput()`.
/// Only `ButtonInputReceiver::handleIput()` Shall use this value, and it will set the value to nil after using it.
/// This allows `ButtonInputReceiver::handleIput()` to gain information about the device causing the incoming event. It will also allow us to filter out input from devices which we didn't create an MFDevice instance for (All of those devices can be found in DeviceManager.relevantDevices).
static MFDevice *_deviceWhichCausedThisButtonInput;
+ (void)setDeviceWhichCausedThisButtonInput:(MFDevice *)dev {
    _deviceWhichCausedThisButtonInput = dev;
}
CGEventRef handleInput(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    NSLog(@"CG Button input");
    NSLog(@"Incoming event: %@", [NSEvent eventWithCGEvent:event]);
    
    MFDevice *dev = _deviceWhichCausedThisButtonInput;
    _deviceWhichCausedThisButtonInput = nil;
    
    if (dev) {
        
        NSLog(@"CG Button input comes from relevant device");
        
        int64_t buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
        
        long long pr = CGEventGetIntegerValueField(event, kCGMouseEventPressure);
        MFButtonInputType type = pr == 0 ? kMFButtonInputTypeButtonUp : kMFButtonInputTypeButtonDown;
        
        if (3 <= buttonNumber) {
            MFEventPassThroughEvaluation rt = [ButtonInputParser sendActionTriggersForInputWithButton:buttonNumber type:type inputDevice:dev];
            if (rt == kMFEventPassThroughRefusal) {
                return nil;
            } else {
                return event;
            }
        } else {
            NSLog(@"Received input from primary / secondary mouse button. This should never happen! Button Number: %lld", buttonNumber);
        }
    }
    return event;
}

@end
