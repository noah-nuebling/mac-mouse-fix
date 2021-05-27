//
// --------------------------------------------------------------------------
// InputReceiver_HID.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFDevice.h"
#import "ModifiedDrag.h"
#import "GestureScrollSimulator.h"
#import "DeviceManager.h"
#import "ButtonInputReceiver.h"
#import "Utility_Transformation.h"
#import "CFRuntime.h"
#import "SharedUtility.h"
#import <Cocoa/Cocoa.h>

// TODO: Consider refactoring
//  - There is device specific state scattered around the program (I can think of the the ButtonStates in ButtonTriggerGenerator, as well as the ModifedDragStates in ModiferManager). This state should probably be owned by MFDevice instances instead.
//  - This class is cluttered up with code using the IOHID framework, intended to capture mouse moved input while preventing the mouse pointer from moving. This is used for ModifiedDrags which stop the mouse pointer from moving. We should probably move this code to some other class, which MFDevice's can own instances of, to make stuff less cluttered.

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

#pragma mark - Capture input using IOHID

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

- (NSNumber *)uniqueID {
    return (__bridge NSNumber *)IOHIDDeviceGetProperty(_IOHIDDevice, CFSTR(kIOHIDUniqueIDKey));
}


// Copied this from `IOHIDDevice.c`
// Only using this for `closeWithOption:`
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

//static void printIOHIDDeviceState(IOHIDeviceRef dev) {
//    NSLog(@"IOHID DEVICE STATE - service: %@, deviceInterface: %@, plugInInterface: %@, props: %@, elements: %@, rootKey: %@, UUIDKey: %@, notifPort:");
//}

// I think the `option` doesn't make any difference when closing a device I think. It definitely doesn't help with the CFData zombie bug
- (void)closeWithOption:(IOOptionBits)option {
//    CFRetain(self.IOHIDDevice); // Retaining doesn't fix it though...
//    IOReturn ret = IOHIDDeviceClose(self.IOHIDDevice, option); // Closing seems to create zombies, which leads to crashes.
    IOReturn ret = (*self.IOHIDDevice->deviceInterface)->close(self.IOHIDDevice->deviceInterface, option); // This is some of what IOHIDDeviceClose() does. Might help with zombies. I got this from `IOHIDDevice.c`. Seems like it fixes the zombies issue!! :O
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
    
#if DEBUG
//    if (B) {
//        NSLog(@"SEIZE DEVICE");
//    } else {
//        NSLog(@"UNSEIZE DEVICE");
//    }
#endif
    
    if (_isSeized == B) {
        return;
    }
    
    // Close dev
    if (B) {
        [self closeWithOption:0];
    } else {
        [self closeWithOption:kIOHIDOptionsTypeSeizeDevice];
    }
    
    // Open dev
    if (B) {
        [self openWithOption:kIOHIDOptionsTypeSeizeDevice];
        dealWithAutomaticButtonUpEventsFromDeviceSeize(self);
    } else {
        [self openWithOption:0];
        
        // Trying to fix an issue where the first event after unseizing doesn't arrive in ButtonInputReceiver for some reason
        // Solution idea 1: Tried to "initialize" IOHIDDevice after unseizing by calling functions `IOHIDDeviceGetReportWithCallback`, `IOHIDDeviceCopyMatchingElements`, `IOHIDDeviceScheduleWithRunLoop`
        // -> Didn't work
        // Solution idea 2: Inserting the first event after unseizing into the CG Event Stream artificially.
        // -> Doesn't really work, because we have to translate the HID Value callbacks values into CGEvents manually - leads to problems if HID values which we are not listening to / don't know how to translate to a CGEvent change (then the next event would be sent twice, once real and once inserted)
        // Solution idea 3: We only seize the device once the mouse pointer moves while a modified drag is active
        // -> This stops problems from occuring in most cases but not all
        //Solution idea 3: Try to initialize by setting a value
        
        CFArrayRef allElems = IOHIDDeviceCopyMatchingElements(self.IOHIDDevice, NULL, 0);
        IOHIDElementRef firstElem = (IOHIDElementRef)CFArrayGetValueAtIndex(allElems, 0);
        CFRelease(allElems);
        IOHIDValueRef newVal = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, firstElem, mach_absolute_time(), 0);
        IOHIDDeviceSetValue(self.IOHIDDevice, firstElem, newVal);
        CFRelease(newVal);
        
    }
    
    _isSeized = B;
    
}

/// When a device is seized, button up events are sent for all pressed buttons by the system.
/// We want to tell ButtonInputReceiver where those events came from by calling `handleButtonInputFromRelevantDeviceOccured` for each currently pressed button, with the `stemsFromDeviceSeize` parameter set to `YES`
static void dealWithAutomaticButtonUpEventsFromDeviceSeize(MFDevice *dev) {
    //NSUInteger pressedButtons = NSEvent.pressedMouseButtons; // This seems to only see buttons as pressed if a mousedown CGEvent for that button has been sent or sth
    NSArray *pressedButtons = getPressedButtons(dev);
    int buttonNum = 0;
    for (NSNumber *k in pressedButtons) {
        BOOL isPressed = k.intValue == 1;
        if (isPressed) {
            NSLog(@"IS PRESSED WHILE SEIZING: %d", buttonNum);
            [ButtonInputReceiver handleHIDButtonInputFromRelevantDeviceOccured:dev button:@(buttonNum+1) stemsFromDeviceSeize:YES];
        }
        buttonNum++;
    }
}
static NSArray *getPressedButtons(MFDevice *dev) {
    
    NSMutableArray *outArr = [NSMutableArray array];
    
    NSDictionary *match = @{
        @(kIOHIDElementUsagePageKey): @(kHIDPage_Button),
        //@(kIOHIDElementTypeKey): @(kIOHIDElementTypeInput_Button),
    };
    CFArrayRef elems = IOHIDDeviceCopyMatchingElements(dev.IOHIDDevice, (__bridge CFDictionaryRef)match, 0);
    
    for (int i = 0; i < CFArrayGetCount(elems); i++) {
        IOHIDElementRef elem = (IOHIDElementRef)CFArrayGetValueAtIndex(elems, i);
        IOHIDValueRef value;
        IOHIDDeviceGetValue(dev.IOHIDDevice, elem, &value);
        [outArr addObject:@(IOHIDValueGetIntegerValue(value))];
    }
    
    CFRelease(elems);
    
//    NSUInteger outBitmask = 0;
//
//    for (int i = 0; i < outArr.count; i++) {
//        if ([outArr[i] isEqual:@(1)]) {
//            outBitmask |= 1<<i;
//        }
//    }
    
    return outArr;
}

- (void)receiveOnlyButtonInput {
    
#if DEBUG
    //NSLog(@"RECEIVE ONLY BUTTON INPUT");
#endif
    
    [self seize:NO];
    
    NSDictionary *buttonMatchDict = @{
        @(kIOHIDElementUsagePageKey): @(kHIDPage_Button),
    };
    IOHIDDeviceSetInputValueMatching(_IOHIDDevice, (__bridge CFDictionaryRef)buttonMatchDict);
}


- (void)receiveAxisInputAndDoSeizeDevice:(BOOL)seize {
    
#if DEBUG
    //NSLog(@"RECEIVE AXIS INPUT ON TOP OF BUTTON INPUT");
#endif
    
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
    
#if DEBUG
    NSLog(@"Received HID input - usagePage: %d usage: %d value: %ld from device: %@", usagePage, usage, (long)IOHIDValueGetIntegerValue(value), sendingDev.name);
#endif
    
    if (isButton) {
        
        MFMouseButtonNumber button = usage;
        
        [ButtonInputReceiver handleHIDButtonInputFromRelevantDeviceOccured:sendingDev button:@(button) stemsFromDeviceSeize:NO];
        
        int64_t pressure = IOHIDValueGetIntegerValue(value);
        
#if DEBUG
        //NSLog(@"BTN HIDDD - btn: %d, pressure: %lld", button, pressure);
#endif
        
        // Control modified actions
        
        // v TODO: Would it be better to put this into `ButtonInputReceiver.m`? It seems to be more reliable than this function.
        [GestureScrollSimulator breakMomentumScroll]; // Momentum scroll is started, when when a modified drag of type "twoFingerSwipe" is deactivated. We break it on any button input.
//        if (pressure == 0) { // Don't think we need this if inserting fake events works properly
//            [ModifiedDrag deactivate];
//        }
        
        // Post fake button input events, if the device is seized

        if (sendingDev.isSeized) {
#if DEBUG
            //NSLog(@"BUTTON INP COMES FORM SEIZED");
#endif
            [ButtonInputReceiver insertFakeEventWithButton:button isMouseDown:pressure!=0];
            
        }
    } else {
    
        BOOL isXAxis = usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_X;
        BOOL isYAxis = usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Y;
        
        if (isXAxis || isYAxis) {
            
            MFAxis axis = isXAxis ? kMFAxisHorizontal : kMFAxisVertical;
            
            if (axis == kMFAxisVertical) {
                _previousDeltaY = IOHIDValueGetIntegerValue(value); // Vertical axis delta value seems to always be sent before horizontal axis delta
            } else {
                int64_t currentDeltaX = IOHIDValueGetIntegerValue(value);
                
                if (currentDeltaX != 0 || _previousDeltaY != 0) {
                    
                    [ModifiedDrag handleMouseInputWithDeltaX:currentDeltaX deltaY:_previousDeltaY event:nil];
                    
    //                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{ // Multithreading in hopes of preventing some issues which I assume are caused by the hid callback (this function) being processed after the CG callback when the system is under load sometimes. Not sure if the multithreading helps though.
    //                    [ModifyingActions handleMouseInputWithDeltaX:currentDeltaX deltaY:_previousDeltaY];
    //                });
                }
            }
        }
    }
}


#pragma mark - Default functions

- (BOOL)isEqualToDevice:(MFDevice *)device {
    return CFEqual(self.IOHIDDevice, device.IOHIDDevice);
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

- (NSString *)name {
    
    IOHIDDeviceRef device = self.IOHIDDevice;
    NSString *product = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    NSString *manufacturer = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDManufacturerKey));
    
    return [NSString stringWithFormat:@"%@ – %@", product, manufacturer];
    
}

- (NSString *)description {
    
    @try {
        IOHIDDeviceRef device = self.IOHIDDevice;
        
        NSString *product = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        NSString *manufacturer = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDManufacturerKey));
        NSString *usagePairs = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDDeviceUsagePairsKey));
        
        NSString *productID = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
        NSString *vendorID = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
        
        NSString *outString = [NSString stringWithFormat:@"Device Info:\n"
                               "    Product: %@\n"
                               "    Manufacturer: %@\n"
                               "    UsagePairs: %@\n"
                               "    ProductID: %@\n"
                               "    VendorID: %@\n",
                               product,
                               manufacturer,
                               usagePairs,
                               productID,
                               vendorID];
        return outString;
    } @catch (NSException *exception) {
        NSLog(@"Exception while getting MFDevice description: %@", exception);
        // After waking computer from sleep I just had a EXC_BAD_ACCESS exception. The debugger says the MFDevice is still allocated in debugger (I can look at all its properties and of the IOHIDDevice as well)) but the "properties" dict of the IOHIDDevice is a NULL pointer for some reason. Really strange. I don't know how to handle this situation, crashing is proabably better than to keep going in this weird state.
        NSLog(@"Rethrowing exception because crashing the app is probably best in this situation.");
        @throw exception;
    }
}

@end
