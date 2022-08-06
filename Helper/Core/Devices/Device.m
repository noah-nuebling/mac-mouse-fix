//
// --------------------------------------------------------------------------
// InputReceiver_HID.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Device.h"
#import "ModifiedDrag.h"
#import "GestureScrollSimulator.h"
#import "DeviceManager.h"
#import "ButtonInputReceiver.h"
#import "TransformationUtility.h"
#import "CFRuntime.h"
#import "SharedUtility.h"
#import <Cocoa/Cocoa.h>

/// TODO: Consider refactoring
///  - There is device specific state scattered around the program (I can think of the the ButtonStates in ButtonTriggerGenerator, as well as the ModifedDragStates in ModiferManager). This state should probably be owned by MFDevice instances instead.
///  - This class is cluttered up with code using the IOHID framework, intended to capture mouse moved input while preventing the mouse pointer from moving. This is used for ModifiedDrags which stop the mouse pointer from moving. We should probably move this code to some other class, which MFDevice's can own instances of, to make stuff less cluttered.
///  - I've since found another way to stop the mouse pointer (See PointerFreeze class). So most of the stuff in this class is obsolete. Trying to seize the device using IOKit is super buggy and leads to weird crashes and broken mouse down state and many other issues.
///     TODO: Clean this up and remove all the unused stuff

@implementation Device

#pragma mark - Init

/// Create instances with this function
/// DeviceManager calls this for each relevant device it finds

+ (Device *)deviceWithIOHIDDevice:(IOHIDDeviceRef)iohidDevice {
    Device *device = [[Device alloc] initWithIOHIDDevice:iohidDevice];
    return device;
}

- (Device *)initWithIOHIDDevice:(IOHIDDeviceRef)IOHIDDevice {
    self = [super init];
    if (self) {
        
        /// Set state
        _iohidDevice = IOHIDDevice;
        
        /// Open device
        ///     This seems to be necessary in the Ventura Beta.
        ///     See https://github.com/noah-nuebling/mac-mouse-fix/issues/297. And thanks to @chamburr!!
        IOReturn ret = IOHIDDeviceOpen(self.iohidDevice, kIOHIDOptionsTypeNone);
        if (ret) {
            DDLogInfo(@"Error opening device. Code: %x", ret);
        }
        
        /// Set values of interest for callback
        NSDictionary *buttonMatchDict = @{ @(kIOHIDElementUsagePageKey): @(kHIDPage_Button) };
        IOHIDDeviceSetInputValueMatching(_iohidDevice, (__bridge CFDictionaryRef)buttonMatchDict);
        
        /// Register callback
        IOHIDDeviceScheduleWithRunLoop(IOHIDDevice, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        IOHIDDeviceRegisterInputValueCallback(IOHIDDevice, &handleInput, (__bridge void * _Nullable)(self));
    }
    return self;
}

#pragma mark - Input callbacks

//- (void)openWithOption:(IOOptionBits)options {
//    IOReturn ret = IOHIDDeviceOpen(self.IOHIDDevice, options);
////    IOReturn ret = IOHIDDeviceOpen(self.IOHIDDevice, 0); // Ignoring options for testing purposes
//    if (ret) {
//        DDLogInfo(@"Error opening device. Code: %x", ret);
//    }
//}

//static NSArray *getPressedButtons(Device *dev) {
//
//    NSMutableArray *outArr = [NSMutableArray array];
//
//    NSDictionary *match = @{
//        @(kIOHIDElementUsagePageKey): @(kHIDPage_Button),
//        //@(kIOHIDElementTypeKey): @(kIOHIDElementTypeInput_Button),
//    };
//    CFArrayRef elems = IOHIDDeviceCopyMatchingElements(dev.IOHIDDevice, (__bridge CFDictionaryRef)match, 0);
//
//    for (int i = 0; i < CFArrayGetCount(elems); i++) {
//        IOHIDElementRef elem = (IOHIDElementRef)CFArrayGetValueAtIndex(elems, i);
//        IOHIDValueRef value;
//        IOHIDDeviceGetValue(dev.IOHIDDevice, elem, &value);
//        [outArr addObject:@(IOHIDValueGetIntegerValue(value))];
//    }
//
//    CFRelease(elems);
//
////    NSUInteger outBitmask = 0;
////
////    for (int i = 0; i < outArr.count; i++) {
////        if ([outArr[i] isEqual:@(1)]) {
////            outBitmask |= 1<<i;
////        }
////    }
//
//    return outArr;
//}



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
    
    Device *sendingDev = (__bridge Device *)context;
    
    /// Get elements
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    uint32_t usage = IOHIDElementGetUsage(elem);
    uint32_t usagePage = IOHIDElementGetUsagePage(elem);
    /// Get info
    BOOL isButton = usagePage == 9;
    assert(isButton);
    MFMouseButtonNumber button = usage;
    
    /// Debug
    DDLogDebug(@"Received HID input - usagePage: %d usage: %d value: %ld from device: %@", usagePage, usage, (long)IOHIDValueGetIntegerValue(value), sendingDev.name);
    
    /// Notify ButtonInputReceiver
    [ButtonInputReceiver handleHIDButtonInputFromRelevantDeviceOccured:sendingDev button:@(button)];
    
    /// Stop momentumScroll on LMB click
    ///     ButtonInputReceiver tries to filter out LMB and RMB events as early as possible, so it's better to do this here
    int64_t pressure = IOHIDValueGetIntegerValue(value);
    if (button == 1 && pressure != 0) {
        [GestureScrollSimulator stopMomentumScroll];
    }
}

#pragma mark - Properties + override NSObject methods

- (NSNumber *)uniqueID {
    return (__bridge NSNumber *)IOHIDDeviceGetProperty(_iohidDevice, CFSTR(kIOHIDUniqueIDKey));
}

- (BOOL)wrapsIOHIDDevice:(IOHIDDeviceRef)iohidDevice {
    NSNumber *otherID = (__bridge NSNumber *)IOHIDDeviceGetProperty(iohidDevice, CFSTR(kIOHIDUniqueIDKey));
    return [self.uniqueID isEqual:otherID];
}
- (BOOL)isEqualToDevice:(Device *)device {
    return CFEqual(self.iohidDevice, device.iohidDevice);
}
- (BOOL)isEqual:(Device *)other {
    
    if (other == self) { /// Check for pointer equality
        return YES;
//    } else if (![super isEqual:other]) { /// This is from the template idk what it does but it doesn't work
//        return NO;
//    }
    } else if (![other isKindOfClass:self.class]) { ///  Check for class equality
        return NO;
    } else {
        return [self isEqualToDevice:other];;
    }
}

- (NSUInteger)hash {
//    return CFHash(_IOHIDDevice) << 1;
    return (NSUInteger)self; /// TODO: Are we sure just using the self pointer as hash is a good idea? Maybe use uniqueID instead?
}

- (NSString *)name {
    
    IOHIDDeviceRef device = self.iohidDevice;
    NSString *product = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    NSString *manufacturer = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDManufacturerKey));
    
    return [NSString stringWithFormat:@"%@ – %@", product, manufacturer];
    
}

- (NSString *)description {
    
    @try {
        IOHIDDeviceRef device = self.iohidDevice;
        
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
        DDLogInfo(@"Exception while getting MFDevice description: %@", exception);
        /// After waking computer from sleep I just had a EXC_BAD_ACCESS exception. The debugger says the MFDevice is still allocated in debugger (I can look at all its properties and of the IOHIDDevice as well)) but the "properties" dict of the IOHIDDevice is a NULL pointer for some reason. Really strange. I don't know how to handle this situation, crashing is proabably better than to keep going in this weird state.
        DDLogInfo(@"Rethrowing exception because crashing the app is probably best in this situation.");
        @throw exception;
    }
}

#pragma mark - Old stuff that's interesting

/// Copied this from `IOHIDDevice.c`
/// Only used this for `closeWithOption:`
/// -> Now unused after we're not seizing devices anymore
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

#pragma mark - Doesn't belong here

static uint64_t IOHIDDeviceGetRegistryID(IOHIDDeviceRef  _Nonnull device) {
    /// TODO: Put this in some utility class
    io_service_t service = IOHIDDeviceGetService(device);
    uint64_t deviceID;
    IORegistryEntryGetRegistryEntryID(service, &deviceID);
    return deviceID;
}

@end
