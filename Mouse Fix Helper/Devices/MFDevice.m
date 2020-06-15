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
#import "DeviceManager.h"
#import "ButtonInputReceiver_CG.h"
#import "RemapUtility.h"

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
//    IOReturn ret = IOHIDDeviceOpen(self.IOHIDDevice, 0); // TODO: Ignoring options for testing purposes
    if (ret) {
        NSLog(@"Error opening device. Code: %x", ret);
    }
}

- (void)close {
    IOReturn ret = IOHIDDeviceClose(self.IOHIDDevice, kIOHIDOptionsTypeNone);
    if (ret) {
        NSLog(@"Error closing device. Code: %x", ret);
    }
}

/// We use this to prevent the mouse pointer from moving while modifiedDrag actions are active.
/// Unfortunately this fails sometimes and does weird stuff like not properly disabling or crashing the app
- (void)seize:(BOOL)B {
    
    if (_isSeized == B) {
        return;
    }
    
    [self close];
    
    if (B) {
        [self openWithOption:kIOHIDOptionsTypeSeizeDevice];
    } else {
        [self openWithOption:0];
    }
    
    _isSeized = B;
    
    registerInputCallbackForDevice(self);
}

- (void)receiveOnlyButtonInput {
    
    [self seize:NO];
    
    NSDictionary *buttonMatchDict = @{
        @(kIOHIDElementUsagePageKey): @(kHIDPage_Button)
    };
    IOHIDDeviceSetInputValueMatching(_IOHIDDevice, (__bridge CFDictionaryRef)buttonMatchDict);
}


- (void)receiveButtonAndAxisInputWithSeize:(BOOL)seize {
    
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
    
    NSLog(@"HID Input");
    
    MFDevice *sendingDev = (__bridge MFDevice *)context;
    
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(elem);
    uint32_t usagePage = IOHIDElementGetUsagePage(elem);
    
    BOOL isButton = usagePage == 9;
    
    if (isButton) {
        ButtonInputReceiver_CG.deviceWhichCausedThisButtonInput = sendingDev;

        if (sendingDev.isSeized) {

            NSLog(@"BUTTON INP COMES FORM SEIZED");

            CGEventType mouseType = kCGEventNull;
            int32_t button = usage - 1;

            if (IOHIDValueGetIntegerValue(value) == 0) {
                if (button == 0) {
                    mouseType = kCGEventLeftMouseUp;
                } else if (button == 1) {
                    mouseType = kCGEventRightMouseUp;
                } else {
                    mouseType = kCGEventOtherMouseUp;
                }
            } else {
                if (button == 0) {
                    mouseType = kCGEventLeftMouseDown;
                } else if (button == 1) {
                    mouseType = kCGEventRightMouseDown;
                } else {
                    mouseType = kCGEventOtherMouseDown;
                }
            }

            CGEventRef fakeEvent = CGEventCreateMouseEvent(NULL, mouseType, CGEventGetLocation(CGEventCreate(NULL)), button);
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
    
    return CFHash(_IOHIDDevice) << 1;
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
