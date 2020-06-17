//
// --------------------------------------------------------------------------
// InputReceiver_HID.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFDevice.h"
#import "ModifyingActions.h"
#import "GestureScrollSimulator.h"
#import "DeviceManager.h"
#import "ButtonInputReceiver_CG.h"
#import "RemapUtility.h"
#import "CFRuntime.h"


@implementation MFDevice

/// Create instances with this function
/// DeviceManager calls this for each relevant device it finds
+ (MFDevice *)deviceWithIOHIDDevice:(IOHIDDeviceRef)IOHIDDevice {
    MFDevice *newDevice = [[MFDevice alloc] initWithIOHIDDevice:IOHIDDevice];
    return newDevice;
}

- (MFDevice *)initWithIOHIDDevice:(IOHIDDeviceRef)IOHIDDevice {
    self = [super init];
    if (self) {
        _IOHIDDevice = IOHIDDevice;
        _isSeized = NO;
        
        NSDictionary *buttonMatchDict = @{
            @(kIOHIDElementUsagePageKey): @(kHIDPage_Button)
        };
        IOHIDDeviceSetInputValueMatching(_IOHIDDevice, (__bridge CFDictionaryRef)buttonMatchDict);
        registerInputCallbackForDevice(self);
    }
    return self;
}

static void registerInputCallbackForDevice(MFDevice *device) {
    IOHIDDeviceScheduleWithRunLoop(device.IOHIDDevice, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDDeviceRegisterInputValueCallback(device.IOHIDDevice, &handleInput, (__bridge void * _Nullable)(device));
}

- (void)openWithOption:(IOOptionBits)options {
    IOReturn ret = IOHIDDeviceOpen(self.IOHIDDevice, options);
//    IOReturn ret = IOHIDDeviceOpen(self.IOHIDDevice, 0); // Ignoring options for testing purposes
    if (ret) {
        NSLog(@"Error opening device. Code: %x", ret);
    }
}

typedef struct __IOHIDDevice
{
    CFRuntimeBase                   cfBase;   // base CFType information

    io_service_t                    service;
    IOHIDDeviceDeviceInterface**    deviceInterface;
    IOCFPlugInInterface **          plugInInterface;
    CFMutableDictionaryRef          properties;
    CFMutableSetRef                 elements;
    CFStringRef                     rootKey;
    CFStringRef                     UUIDKey;
    IONotificationPortRef           notificationPort;
    io_object_t                     notification;
    CFTypeRef                       asyncEventSource;
    CFRunLoopRef                    runLoop;
    CFStringRef                     runLoopMode;
    
    IOHIDQueueRef                   queue;
    CFArrayRef                      inputMatchingMultiple;
    Boolean                         loadProperties;
    Boolean                         isDirty;
    
    // For thread safety reasons, to add or remove an  element, first make a copy,
    // then modify that copy, then replace the original
    CFMutableArrayRef               removalCallbackArray;
    CFMutableArrayRef               reportCallbackArray;
    CFMutableArrayRef               inputCallbackArray;
} __IOHIDDevice, *__IOHIDDeviceRef;

// I think the `option` doesn't make any difference when closing a device I think. It definitely doesn't help with the CFData zombie bug
- (void)closeWithOption:(IOOptionBits)option {
//    CFRetain(self.IOHIDDevice); // Closing seems to create zombies, which leads to crashes. Retaining doesn't fix it though...
//    IOReturn ret = IOHIDDeviceClose(self.IOHIDDevice, option);
    IOReturn ret = (*self.IOHIDDevice->deviceInterface)->close(self.IOHIDDevice->deviceInterface, option); // This is some of what IOHIDDeviceClose() does. Might help with zombies. I got this from `IOHIDDevice.c`. Seems like it fixes the zombies issue!! :D
    if (ret) {
        NSLog(@"Error closing device. Code: %x", ret);
        CFRelease(self.IOHIDDevice);
    }
}

/// Seizing device is the only way I found for preventing the mouse pointer from moving while modifiedDrag actions are active.
/// Unfortunately this fails sometimes and does weird stuff like not properly disabling or crashing the app
/// Closing devices seems to deallocate something (Xcode zombies analysis says its CFData, but idk what it is or what it represents etc.) which will later lead to crashes. CFRetain ing devices before closing them doesn't seem to help.
/// I also think this leads to other weird issues e.g. I couldn't stop dragging an element once until I logged out. We create fake events and reinsert them into the event stream from within `MFDevice::handleInput()` if the device is seized, I think that caused it somehow.
- (void)seize:(BOOL)B {
    
//    return;
    
    if (B) {
        NSLog(@"Seize device");
    } else {
        NSLog(@"Unseize device");
    }
    
    if (_isSeized == B) {
        return;
    }
    
    if (self.isSeized) {
        [self closeWithOption:0];
    } else {
        [self closeWithOption:0];
    }
  
    // Thought this might help with the doodlebug. But it doesn't
//    mach_timespec_t timeout = {
//        .tv_sec = 5,
//    };
//    IOServiceWaitQuiet(self.IOHIDDevice->service, &timeout);
    
    if (B) {
        [self openWithOption:kIOHIDOptionsTypeSeizeDevice];
        // This seems to lead to a weird error where the CGEventTapCallback doesn't react opening the device unseized
    } else {
        [self openWithOption:0];
    }
    
    _isSeized = B;
    
//    registerInputCallbackForDevice(self);
}

- (void)receiveOnlyButtonInput {
    
    NSLog(@"Receive only button input");
    
    [self seize:NO];
    
    NSDictionary *buttonMatchDict = @{
        @(kIOHIDElementUsagePageKey): @(kHIDPage_Button)
    };
    IOHIDDeviceSetInputValueMatching(_IOHIDDevice, (__bridge CFDictionaryRef)buttonMatchDict);
}


- (void)receiveButtonAndAxisInputWithSeize:(BOOL)seize {
    
    NSLog(@"Receive button and axis input");
    
    [self seize:seize];
    
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
    
    IOHIDDeviceSetInputValueMatchingMultiple(_IOHIDDevice, (__bridge CFArrayRef)matchDictArray);
    
}

/// The CGEvent function which we use to intercept and manipulate incoming button events (`ButtonInputReceiver_CG::handleInput()`)  cannot gain any information about which devices is causing input, and it can therefore also not filter out input form certain devices. We use functions from the IOHID Framework (`MFDevice::handleInput()`) to solve this problem.
///
/// For each MFDevice instance which is created, we register an input callback for the IOHIDDevice which it owns. The callback is handled by `MFDevice::handleInput()`.
/// IOHID callback functions seem to always be called very shortly before any CGEvent callback function responding to the same input.
/// So what we can do to gain info about the device causing input from within the CGEvent callback function (`ButtonInputReceiver_CG::handleInput()`) is this:
///
/// From within `MFDevice::handleInput()` we set the ButtonInputReceiver_CG.deviceWhichCausedThisButtonInput property to the MFDeviceInstance which triggered `MFDevice::handleInput()`.
/// Then from within `ButtonInputReceiver_CG::handleInput()` we read this property to gain knowledge about the device which caused this input. After reading the property from within  `ButtonInputReceiver_CG::handleInput()`, we set it to nil.
/// If `ButtonInputReceiver_CG::handleInput()` is called while the `deviceWhichCausedThisButtonInput` is nil, we know that the input doesn't stem from a device which has an associated MFDevice instance. We use this to filter out input from devices without an associated MFDevice instances.
///
/// Filtering criteria for which attached devices we create an MFDevice for, are setup in  `DeviceManager::setupDeviceMatchingAndRemovalCallbacks()`

static int64_t _previousDeltaY;

static void handleInput(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    
    MFDevice *sendingDev = (__bridge MFDevice *)context;
    
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(elem);
    uint32_t usagePage = IOHIDElementGetUsagePage(elem);
    
    BOOL isButton = usagePage == 9;
    
    if (isButton) {
        
        NSLog(@"HID Input: Button");
        
        ButtonInputReceiver_CG.deviceWhichCausedThisButtonInput = sendingDev;
        
//        while (!ButtonInputReceiver_CG.deviceWhichCausedThisButtonInputHasBeenProcessed) {
//            [NSThread sleepForTimeInterval:0.0001];
//        }
        
        CGEventType mouseEventType = kCGEventNull;
        int32_t button = usage - 1;
        int64_t pressure = IOHIDValueGetIntegerValue(value);
        
        // Insert artificial CGEvents for button input, if the device is seized
        
        if (sendingDev.isSeized) {

            NSLog(@"BUTTON INP COMES FORM SEIZED");
            
            if (pressure == 0) {
                if (button == 0) {
                    mouseEventType = kCGEventLeftMouseUp;
                } else if (button == 1) {
                    mouseEventType = kCGEventRightMouseUp;
                } else {
                    mouseEventType = kCGEventOtherMouseUp;
                }
            } else {
                if (button == 0) {
                    mouseEventType = kCGEventLeftMouseDown;
                } else if (button == 1) {
                    mouseEventType = kCGEventRightMouseDown;
                } else {
                    mouseEventType = kCGEventOtherMouseDown;
                }
            }

//            CGEventRef locEvent = CGEventCreate(NULL);
            CGEventRef fakeEvent = CGEventCreateMouseEvent(NULL, mouseEventType, CGEventGetLocation(CGEventCreate(NULL)), button);
//            CFRetain(fakeEvent);
            [ButtonInputReceiver_CG insertFakeEvent:fakeEvent];
            CFRelease(fakeEvent);
//            CFRelease(locEvent);
            
        }
        
        // Control modified actions
        
        [GestureScrollSimulator breakMomentumScroll]; // Momentum scroll is started, when when a modified drag of type "twoFingerSwipe" is deactivated. We break it on any button input.
        if (pressure == 0) {
            MFActivationCondition *falsifiedCondition = &((MFActivationCondition) {
                .activatingDevice = sendingDev,
                .type = kMFActivationConditionTypeMouseButtonPressed,
                .value = button + 1,
            });
            [ModifyingActions deactivateAllInputModificationWithActivationCondition:falsifiedCondition];
        }
        
        return;
    }
    
    BOOL isXAxis = usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_X;
    BOOL isYAxis = usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Y;
    
    if (isXAxis || isYAxis) {
        
        MFAxis axis = isXAxis ? kMFAxisHorizontal : kMFAxisVertical;
        
        if (axis == kMFAxisVertical) {
            _previousDeltaY = IOHIDValueGetIntegerValue(value); // Vertical axis delta value seems to always be sent before horizontal axis delta
        } else {
            int64_t currentDeltaX = IOHIDValueGetIntegerValue(value);
            
            if (currentDeltaX != 0 || _previousDeltaY != 0) {
                
                [ModifyingActions handleMouseInputWithDeltaX:currentDeltaX deltaY:_previousDeltaY];
                
//                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{ // Multithreading in hopes of preventing some issues which I assume are caused by the hid callback (this function) being processed after the CG callback when the system is under load sometimes. Not sure if the multithreading helps though.
//                    [ModifyingActions handleMouseInputWithDeltaX:currentDeltaX deltaY:_previousDeltaY];
//                });
            }
        }
        
        return;
    }
}

#pragma mark - Default functions

- (BOOL)isEqualToDevice:(MFDevice *)device {
    return CFEqual(_IOHIDDevice, device.IOHIDDevice);
}
- (BOOL)isEqual:(MFDevice *)other {
    
    if (other == self) { // This checks for pointer equality
        return YES;
//    } else if (![super isEqual:other]) { // This is from the template idk what it does but it doesn't work
//        return NO;
//    }
    } else if (![other isKindOfClass:self.class]) { //  Checks for class equality
        return NO;
    } else {
        return [self isEqualToDevice:other];;
    }
}

- (NSUInteger)hash {
    
//    return CFHash(_IOHIDDevice) << 1;
    return (NSUInteger)self;
}

- (NSString *)description {
    
    IOHIDDeviceRef device = self.IOHIDDevice;
    
    NSString *vendorID = IOHIDDeviceGetProperty(device, CFSTR("VendorID"));
    NSString *devName = IOHIDDeviceGetProperty(device, CFSTR("Product"));
    NSString *devPrimaryUsage = IOHIDDeviceGetProperty(device, CFSTR("PrimaryUsage"));
    
    NSString *outString = [NSString stringWithFormat:
                           @"Device Info:\n"
                           "    Model: %@\n"
                           "    VendorID: %@\n"
                           "    Usage: %@",
                           devName, vendorID, devPrimaryUsage];
    return outString;
}

@end
