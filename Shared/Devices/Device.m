//
// --------------------------------------------------------------------------
// InputReceiver_HID.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Device.h"
#import "ModifiedDrag.h"
#import "GestureScrollSimulator.h"
#import "DeviceManager.h"
#import "ButtonInputReceiver.h"
#import "ModificationUtility.h"
#import "CFRuntime.h"
#import "SharedUtility.h"
#import <Cocoa/Cocoa.h>

/// TODO: Consider refactoring
///  - There is device specific state scattered around the program (I can think of the the ButtonStates in ButtonTriggerGenerator, as well as the ModifedDragStates in ModiferManager). This state should probably be owned by MFDevice instances instead.
///  - This class is cluttered up with code using the IOHID framework, intended to capture mouse moved input while preventing the mouse pointer from moving. This is used for ModifiedDrags which stop the mouse pointer from moving. We should probably move this code to some other class, which MFDevice's can own instances of, to make stuff less cluttered.
///  - I've since found another way to stop the mouse pointer (See PointerFreeze class). So most of the stuff in this class is obsolete. Trying to seize the device using IOKit is super buggy and leads to weird crashes and broken mouse down state and many other issues.

/// We've moved this to shared to be able to access the device name and button number from the mainApp for the Buttons tabs. But to access the buttonNumber you have to open the device which requires accessibility access. So instead we'll have the mainApp ask the helper for that info instead. The registryEntryID based init's are not used after this removal.

@interface StrangeDevice : Device

+ (StrangeDevice *)shared;

@end

@implementation Device {
    int _nOfButtons;
}

#pragma mark - Init

- (Device *)init { /// This is just so that StrangeDevice works.
    self->_nOfButtons = 0;
    self->_iohidDevice = nil;
    return [super init];
}
+ (Device *)strangeDevice {
    return [StrangeDevice shared];
}

+ (Device * _Nullable)deviceWithRegistryID:(uint64_t)registryID {
    Device *device = [[Device alloc] initWithRegistryID:registryID];
    return device;
}

- (Device * _Nullable)initWithRegistryID:(uint64_t)registryID {
    
    self = [super init];
    if (self) {
        CFMutableDictionaryRef match = IORegistryEntryIDMatching(registryID);
        mach_port_t port;
        if (@available(macOS 12.0, *)) {
            port = kIOMainPortDefault;
        } else {
            port = kIOMasterPortDefault;
        }
        io_service_t service = IOServiceGetMatchingService(port, match);
        IOHIDDeviceRef iohidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, service);
        if (iohidDevice == NULL) {
            return nil;
        }
        self = [self initWithIOHIDDevice:iohidDevice];
        CFRelease(iohidDevice);
    }
    return self;
}

+ (Device *)deviceWithIOHIDDevice:(IOHIDDeviceRef)iohidDevice {
    
    /// Create instances with this function
    /// DeviceManager calls this for each relevant device it finds
    
    Device *device = [[Device alloc] initWithIOHIDDevice:iohidDevice];
    return device;
}


- (Device *)initWithIOHIDDevice:(IOHIDDeviceRef)IOHIDDevice {
    
    /// This is the core init method which all others call (at time of writing)
    
    self = [super init];
    if (self) {
        
        ///
        /// Store & retain device
        ///
        _iohidDevice = IOHIDDevice;
        CFRetain(_iohidDevice);
        
        /// Open device
        ///     This seems to be necessary in the Ventura Beta.
        ///     See https://github.com/noah-nuebling/mac-mouse-fix/issues/297. And thanks to @chamburr!!
        ///     Not sure if this is also necessary in the mainApp
        IOReturn ret = IOHIDDeviceOpen(self.iohidDevice, kIOHIDOptionsTypeNone);
        if (ret) {
            DDLogError(@"Error opening device. Code: %x", ret);
        }
        
        ///
        /// Fill instance variables
        ///
        
        ///
        /// Calculate nOfButtons
        /// 
        
        /// Get button elements
        IOHIDDeviceRef device = self.iohidDevice;
        NSDictionary *match = @{
            @(kIOHIDElementUsagePageKey): @(kHIDPage_Button)
        };
        NSArray *elements = (__bridge_transfer NSArray *)IOHIDDeviceCopyMatchingElements(device, (__bridge CFDictionaryRef)match, 0);
        
        /// Get max button number
        ///     Could proabably also just count the number elements instead of this. But this might be more robust.
        int maxButtonNumber = 0;
        for (id e in elements) { /// e is of the private type `HIDElement *` which is bridged with `IOHIDElementRef`
            IOHIDElementRef element = (__bridge IOHIDElementRef)e;
            int buttonNumber = IOHIDElementGetUsage(element);
            maxButtonNumber = MAX(maxButtonNumber, buttonNumber);
        }
        
        /// Store result
        _nOfButtons = maxButtonNumber;
        
#if IS_HELPER
        
//        /// Set values of interest for callback
//        NSDictionary *buttonMatchDict = @{ @(kIOHIDElementUsagePageKey): @(kHIDPage_Button) };
//        IOHIDDeviceSetInputValueMatching(_iohidDevice, (__bridge CFDictionaryRef)buttonMatchDict);
//
//        /// Register callback
//        IOHIDDeviceScheduleWithRunLoop(IOHIDDevice, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
//        IOHIDDeviceRegisterInputValueCallback(IOHIDDevice, &handleInput, (__bridge void * _Nullable)(self));
#endif
        
    }
    
    return self;
}

- (void)dealloc {
    /// Note: `_iohidDevice` shouldn't really ever be NULL, but during the init it happens for some reason
    if (_iohidDevice != NULL) {
        CFRelease(_iohidDevice);
    }
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


//static int64_t _previousDeltaY;

static void handleInput(void *context, IOReturn result, void *sender, IOHIDValueRef value) {

    /// EDIT: This is unused now. Instead we're using our new `CGEventGetSendingDevice()` method
    
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
    
#if IS_HELPER

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
    /// Not needed now since we deactivated AppSwitcher feature. If we do implement it in the future we'll probably take a completely different approach
//    [ButtonInputReceiver handleHIDButtonInputFromRelevantDeviceOccured:sendingDev button:@(button)];

    /// Stop momentumScroll on LMB click
    ///     ButtonInputReceiver tries to filter out LMB and RMB events as early as possible, so it's better to do this here
    int64_t pressure = IOHIDValueGetIntegerValue(value);
    if (button == 1 && pressure != 0) {
        [GestureScrollSimulator stopMomentumScroll];
    }

#endif

}

#pragma mark - Properties + override NSObject methods

- (NSNumber *)uniqueID {
    /// This seems to change after a reboot of the computer.
    return (__bridge NSNumber *)IOHIDDeviceGetProperty(_iohidDevice, CFSTR(kIOHIDUniqueIDKey));
}

- (BOOL)wrapsIOHIDDevice:(IOHIDDeviceRef)iohidDevice {
    NSNumber *otherID = (__bridge NSNumber *)IOHIDDeviceGetProperty(iohidDevice, CFSTR(kIOHIDUniqueIDKey));
    return [self.uniqueID isEqual:otherID];
}
- (BOOL)isEqualToDevice:(Device *)device {
    
    /// What does this function do? Why do we have 2 equality check functions?
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
    return IOHIDDeviceGetProperty(_iohidDevice, CFSTR(kIOHIDProductKey));
}

- (NSString *)manufacturer {
    return IOHIDDeviceGetProperty(_iohidDevice, CFSTR(kIOHIDManufacturerKey));
}

- (NSString *)physicalDeviceID {
    /// Note: This is returning empty string on my Roccat Mouse connected working on my Roccat Kone Pure connected via dongle to my MacBook - since it's not reliably available, we should instead combine the vendorID, productID and serialNumber to get a physicalDeviceID
//    assert(false);
    return IOHIDDeviceGetProperty(_iohidDevice, CFSTR(kIOHIDPhysicalDeviceUniqueIDKey));
}

- (NSString *)serialNumber {
    /// Note: This returning emptyString on my Roccat Kone Pure
    return IOHIDDeviceGetProperty(_iohidDevice, CFSTR(kIOHIDSerialNumberKey));
}
- (NSNumber *)productID {
    return IOHIDDeviceGetProperty(_iohidDevice, CFSTR(kIOHIDProductIDKey));
}
- (NSNumber *)vendorID {
    return IOHIDDeviceGetProperty(_iohidDevice, CFSTR(kIOHIDVendorIDKey));
}

- (int)nOfButtons {
    return self->_nOfButtons;
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
                               "    nOfButtons: %d\n"
                               "    UsagePairs: %@\n"
                               "    ProductID: %@\n"
                               "    VendorID: %@\n",
                               product,
                               manufacturer,
                               [self nOfButtons],
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
    CFRuntimeBase                   cfBase;   /// base CFType information

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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"

static uint64_t IOHIDDeviceGetRegistryID(IOHIDDeviceRef  _Nonnull device) {
    /// TODO: Put this in some utility class
    io_service_t service = IOHIDDeviceGetService(device);
    uint64_t deviceID;
    IORegistryEntryGetRegistryEntryID(service, &deviceID);
    return deviceID;
}

#pragma clang diagnostic pop

@end

@implementation StrangeDevice

/// This is a subclass of `Device` which doesn't hold an IOHIDDevice.
/// Many of the codes that parse input events expect to be passed a `Device` alongside the input events. `StrangeDevice` is passed to those codes if we can't retrieve a Device from the events the normal way, but we still want to parse the input events. (See ButtonInputReceiver) We created this class because we thought it might be good to allow for playback of recorded mouse events to be parsed by MMF. But not sure if that'll work. I think it might be smarter to not have a separate class for this and instead just create an instance of `Device` with an `isStrangeDevice` flag.

+ (StrangeDevice *)shared {
    /// Retrieve singleton instance.
    
    static StrangeDevice *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{ /// Use `dispatch_once` for thread safety.
        sharedInstance = [[StrangeDevice alloc] init];
    });
    
    return sharedInstance;
}

- (Device * _Nullable)initWithRegistryID:(uint64_t)registryID {
    assert(false);
    exit(1);
}
- (Device *)initWithIOHIDDevice:(IOHIDDeviceRef)IOHIDDevice {
    assert(false);
    exit(1);
}

- (NSNumber *)uniqueID {
    return 0;
}

- (BOOL)isEqualToDevice:(Device *)device {
    return NO;
}

- (NSString *)name {
    return @"Strange Device";
}

- (NSString *)manufacturer {
    return @"Unknown Manufacturer";
}

- (int)nOfButtons {
    return 0;
}

- (NSString *)description {
    return @"This device does not exist.";
}

@end
