//
// --------------------------------------------------------------------------
// InputReceiver_HID.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "InputReceiver_HID.h"
#import "ModifyingActions.h"
#import "DeviceManager.h"
#import "ButtonInputReceiver_CG.h"

@implementation InputReceiver_HID

static NSMutableSet *_seizedDevices;

+ (void)load {
    _seizedDevices = [NSMutableSet set];
}

+ (NSNumber * _Nonnull)getDeviceID:(IOHIDDeviceRef _Nonnull)device {
//    NSNumber *val = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDPhysicalDeviceUniqueIDKey));
    NSNumber *val = (__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        return val;
}


+ (void)receiveButtonAndAxisInputForDevice:(IOHIDDeviceRef _Nonnull)device seize:(BOOL)seize {
    
    [DeviceManager seizeDevices:seize];
    
//    IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
////    NSNumber *devID = [InputReceiver_HID getDeviceID:device];
//
////    NSLog(@"DEVICE ID: %@", devID);
//
//    if (seize) {
//        IOHIDDeviceOpen(device, kIOHIDOptionsTypeSeizeDevice);
////        if (devID) {
////            [_seizedDevices addObject:devID];
////        }
//    } else {
//        IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
////        if (devID) {
////            [_seizedDevices removeObject:devID];
////        }
//    }
    
    NSDictionary *buttonMatchDict = @{
        @(kIOHIDElementUsagePageKey): @(kHIDPage_Button)
    };
    NSDictionary *xAxisMatchDict = @{
        @(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop),
        @(kIOHIDElementUsageKey): @(kHIDUsage_GD_X),
    };
    NSDictionary *yAxisMatchDict = @{
        @(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop),
        @(kIOHIDElementUsageKey): @(kHIDUsage_GD_Y),
    };
    
    NSArray *matchDictArray = @[buttonMatchDict, xAxisMatchDict, yAxisMatchDict];
    IOHIDDeviceSetInputValueMatchingMultiple(device, (__bridge CFArrayRef)matchDictArray);
    
    
//    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDDeviceRegisterInputValueCallback(device, &handleInput, NULL);
    
    
    
}

+ (void)receiveButtonInputForDevice:(IOHIDDeviceRef _Nonnull)device {
  
//    if (DeviceManager.devicesAreSeized) {
//        [DeviceManager seizeDevices:NO];
//    } // TODO: ??This causes weird errors
    
//    [DeviceManager seizeDevices:NO];
//    IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
//    IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
//    NSNumber *devID = [self getDeviceID:device];
////    if (devID) {
////        [_seizedDevices removeObject:devID];
////    }
    
    NSDictionary *buttonMatchDict = @{
        @(kIOHIDElementUsagePageKey): @(kHIDPage_Button)
    };
    IOHIDDeviceSetInputValueMatching(device, (__bridge CFDictionaryRef)buttonMatchDict);
    
    
    
//    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDDeviceRegisterInputValueCallback(device, &handleInput, NULL);
}

/// Device manager calls this for each relevant device  it finds.
+ (void)registerInputCallback:(IOHIDDeviceRef)device {
    NSCAssert(device != NULL, @"tried to register a device which equals NULL");
    
    [self receiveButtonInputForDevice:device];
    
//    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
//
//    IOHIDDeviceRegisterInputValueCallback(device, &handleInput, NULL);
    
    
}

+ (void)receiveButtonInputsForDevice {
    
}

/// `_buttonEventInputSourceIsDeviceOfInterest` shall exclusively be set and read by the method `[ButtonInputReceiver_CG handleInput]` in order to discriminate between different devices.
static BOOL _buttonEventInputSourceIsDeviceOfInterest;
+ (BOOL)buttonEventInputSourceIsDeviceOfInterest {
    return _buttonEventInputSourceIsDeviceOfInterest;
}
+ (void)setButtonEventInputSourceIsDeviceOfInterest:(BOOL)B {
    _buttonEventInputSourceIsDeviceOfInterest = B;
}
static IOHIDDeviceRef _deviceWhichCausedLastButtonInput;
+ (IOHIDDeviceRef)deviceWichCausedLastInput {
    return _deviceWhichCausedLastButtonInput;
}

/// CGEvent functions which we use to intercept and manipulate events cannot discriminate between devices. We use this IOHID function to solve the problem.
/// This function can filter different types of devices and when an input from a relevant device occurs, this function seems to always be called very shortly before any CGEvent function responding to the same input.
/// Then we can check if the _buttonEventInputSourceIsDeviceOfInterest flag is currently set from within CGEvent functions to filter devices.
/// Currently this mechanism is only implemented for Mouse Button input. It might be a good idea to implement it for scroll wheel input as well.

/// Device filtering criteria are set within setupDeviceMatchingAndRemovalCallbacks()
/// Which specific types of input from these devices trigger this callback function is set within registerInputCallback_HID (it's only buttons currently)
// TODO: Look into getting getting device information through CGEventGetIntegerValueField. There are tons of undocumented value fields and many public ones that I haven't checked out. One of them might very well contain a device id.

static int64_t _previousDeltaY;

static void handleInput(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    
//    NSLog(@"HID Input");
    
    IOHIDDeviceRef device = sender;
//    NSNumber *deviceID = [InputReceiver_HID getDeviceID:device];
    
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(elem);
    uint32_t usagePage = IOHIDElementGetUsagePage(elem);
    
    BOOL isButton = usagePage == 9;
    
    if (isButton) {
        _deviceWhichCausedLastButtonInput = device;
        _buttonEventInputSourceIsDeviceOfInterest = true;

        if (DeviceManager.devicesAreSeized) {

            NSLog(@"BUTTON INP COMES FORM SEIZED");

            CGEventType mouseType = kCGEventNull;

            if (IOHIDValueGetIntegerValue(value) == 0) {
                if (usage == 1) {
                    mouseType = kCGEventLeftMouseUp;
                } else if (usage == 2) {
                    mouseType = kCGEventRightMouseUp;
                } else {
                    mouseType = kCGEventOtherMouseUp;
                }
            } else {
                if (usage == 1) {
                    mouseType = kCGEventLeftMouseDown;
                } else if (usage == 2) {
                    mouseType = kCGEventRightMouseDown;
                } else {
                    mouseType = kCGEventOtherMouseDown;
                }
            }

            CGEventRef fakeEvent = CGEventCreateMouseEvent(NULL, mouseType, CGEventGetLocation(CGEventCreate(NULL)), usage);
            [ButtonInputReceiver_CG insertFakeEvent:fakeEvent];
        }
        
        return;
    }
    
    BOOL isXAxis = usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_X;
    BOOL isYAxis = usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Y;
    
    
    if (isXAxis || isYAxis) {
        
        MFAxis axis = isXAxis ? kMFAxisHorizontal : kMFAxisVertical;
        
        if (axis == kMFAxisVertical) {
            _previousDeltaY = IOHIDValueGetIntegerValue(value); // Vertical axis delta seems to always be sent before horizontal axis delta
        } else {
            int64_t currentDeltaX = IOHIDValueGetIntegerValue(value);
            
            if (currentDeltaX != 0 || _previousDeltaY != 0) {
                [ModifyingActions handleMouseInputWithDeltaX:currentDeltaX deltaY:_previousDeltaY];
            }
        }
        return;
    }
}
@end
