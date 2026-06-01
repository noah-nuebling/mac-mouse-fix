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
#import "Logging.h"

/// Old notes: (basically all outdated as of 28.08.2024)
///     Consider refactoring:
///     - There is device specific state scattered around the program (I can think of the the ButtonStates in ButtonTriggerGenerator, as well as the ModifedDragStates in ModiferManager). This state should probably be owned by MFDevice instances instead.
///     - This class is cluttered up with code using the IOHID framework, intended to capture mouse moved input while preventing the mouse pointer from moving. This is used for ModifiedDrags which stop the mouse pointer from moving. We should probably move this code to some other class, which MFDevice's can own instances of, to make stuff less cluttered.
///     - I've since found another way to stop the mouse pointer (See PointerFreeze class). So most of the stuff in this class is obsolete. Trying to seize the device using IOKit is super buggy and leads to weird crashes and broken mouse down state and many other issues.
///
///     We've moved this to Shared/ to be able to access the device name and button number from the mainApp for the Buttons tabs. But to access the buttonNumber you have to open the device which requires accessibility access. So instead we'll have the mainApp ask the helper for that info instead. The registryEntryID based init's are not used after this removal.

@interface StrangeDevice : Device

+ (StrangeDevice *)shared;

@end

@implementation Device {
    int _nOfButtons;
}

#pragma mark - Init

- (Device *)init { /// This is just so that StrangeDevice works.
    self->_nOfButtons = 0;
    self->_iohidDevice = NULL;
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
            assert(false); /// Should we add some error handling or just try to keep proceeding as normal?
            DDLogError(@"Error opening device. Code: %x", ret);
        }
        
        ///
        /// Fill instance variables
        ///
        
        ///
        /// Get nOfButtons
        ///
        
        /// Get button elements
        IOHIDDeviceRef device = self.iohidDevice;
        NSDictionary *match = @{
            @(kIOHIDElementUsagePageKey): @(kHIDPage_Button)
        };
        NSArray *elements = (__bridge_transfer NSArray *)IOHIDDeviceCopyMatchingElements(device, (__bridge CFDictionaryRef)match, 0);
        
        /// Get max button number
        ///     Could probably also just count the number elements instead of this. But this might be more robust.
        int maxButtonNumber = 0;
        for (id e in elements) { /// e is of the private type `HIDElement *` which is bridged with `IOHIDElementRef`
            IOHIDElementRef element = (__bridge IOHIDElementRef)e;
            int buttonNumber = IOHIDElementGetUsage(element);
            maxButtonNumber = MAX(maxButtonNumber, buttonNumber);
        }
        
        /// Store result
        _nOfButtons = maxButtonNumber;
        
#if IS_HELPER
        /// Register low-level input callback for all elements (without SetInputValueMatching filter)
        IOHIDDeviceScheduleWithRunLoop(self.iohidDevice, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        IOHIDDeviceRegisterInputValueCallback(self.iohidDevice, &handleInput, (__bridge void * _Nullable)(self));
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


#if IS_HELPER
static void postVirtualButtonEvent(MFMouseButtonNumber button, BOOL down) {
    CGEventTapLocation tapLoc = kCGHIDEventTap;
    CGEventRef ourEvent = CGEventCreate(NULL);
    CGPoint mouseLoc = CGPointZero;
    if (ourEvent != NULL) {
        mouseLoc = CGEventGetLocation(ourEvent);
        CFRelease(ourEvent);
    }
    
    CGEventType eventType = [SharedUtility CGEventTypeForButtonNumber:button isMouseDown:down];
    CGMouseButton buttonCG = [SharedUtility CGMouseButtonFromMFMouseButtonNumber:button];
    
    CGEventRef event = CGEventCreateMouseEvent(NULL, eventType, mouseLoc, buttonCG);
    if (event == NULL) return;
    
    CGEventSetIntegerValueField(event, kCGMouseEventClickState, 1);
    
    if (button >= 4) {
        CGEventSetIntegerValueField(event, kCGMouseEventButtonNumber, button - 1);
    }
    
    CGEventPost(tapLoc, event);
    CFRelease(event);
}

static BOOL deviceHasNativeButton(Device *device, MFMouseButtonNumber button) {
    return button > 0 && device.nOfButtons >= button;
}
#endif

//static int64_t _previousDeltaY;

static void handleInput(void *context, IOReturn result, void *sender, IOHIDValueRef value) {

    /// EDIT: This is unused now. Instead we're using our new `CGEventGetSendingDevice()` method
    
    /// Original comments:
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
    CFIndex integerValue = IOHIDValueGetIntegerValue(value);

    // Ignore Generic Desktop Page (X/Y mouse pointer coordinates) to avoid flooding the logs
    if (usagePage == 1 && (usage == 48 || usage == 49)) {
        return;
    }

    DDLogInfo(@"[TEMP LowLevel HID Log] Device: %@, UsagePage: %u, Usage: %u, Value: %ld", 
              sendingDev.name, usagePage, usage, (long)integerValue);

    // Remap legacy Logitech proprietary button reports (Usage Page 65347/0xFF43) to standard buttons.
    // Newer Logi devices also report Back/Forward natively on Usage Page 9. Do not synthesize
    // buttons 4/5 for those devices, or Page 65347 zero packets can prematurely end hold/drag gestures.
    if (usagePage == 65347 && !sendingDev.isLogitechDiverted) {
        static NSMutableDictionary<NSNumber *, NSNumber *> *logiValueToButton = nil;
        static NSMutableSet<NSNumber *> *logiButtonsDown = nil;
        
        if (logiValueToButton == nil) {
            logiValueToButton = [@{
                @83: @4,       // Older Logi back button report
                @86: @5,       // Older Logi forward button report
                @196: @6,      // Older Logi mode-shift button report
                @1052927: @6,  // Newer Logi mode-shift button report (0x1010ff)
                @82: @7,       // Older Logi gesture button report
            } mutableCopy];
            logiButtonsDown = [NSMutableSet set];
        }
        
        if (integerValue == 0) {
            for (NSNumber *button in logiButtonsDown.allObjects) {
                DDLogInfo(@"[TEMP Logi Remap] Posting virtual Button %@ up", button);
                postVirtualButtonEvent(button.intValue, NO);
            }
            [logiButtonsDown removeAllObjects];
        } else {
            NSNumber *valueKey = @(integerValue);
            NSNumber *button = logiValueToButton[valueKey];
            
            if (button == nil) {
                return;
            }

            if ((button.intValue == 4 || button.intValue == 5) && deviceHasNativeButton(sendingDev, button.intValue)) {
                DDLogDebug(@"Ignoring legacy Logitech Page 65347 value %@ for native Button %@", valueKey, button);
                return;
            }
            
            for (NSNumber *pressedButton in logiButtonsDown.allObjects) {
                if (![pressedButton isEqualToNumber:button]) {
                    DDLogInfo(@"[TEMP Logi Remap] Posting virtual Button %@ up before switching to Button %@", pressedButton, button);
                    postVirtualButtonEvent(pressedButton.intValue, NO);
                    [logiButtonsDown removeObject:pressedButton];
                }
            }
            
            if (![logiButtonsDown containsObject:button]) {
                DDLogInfo(@"[TEMP Logi Remap] Detected Logi report value %@ (0x%lx), posting virtual Button %@ down", valueKey, (long)integerValue, button);
                [logiButtonsDown addObject:button];
                postVirtualButtonEvent(button.intValue, YES);
            }
        }
    }

    // Stop momentumScroll on LMB (Usage Page 9, Usage 1) click
    if (usagePage == 9 && usage == 1 && integerValue != 0) {
        [GestureScrollSimulator stopMomentumScroll];
    }

#endif

}

#pragma mark - Properties + override NSObject methods

- (NSNumber *)uniqueID {
    return (__bridge NSNumber *)IOHIDDeviceGetProperty(_iohidDevice, CFSTR(kIOHIDUniqueIDKey));
}

- (BOOL)wrapsIOHIDDevice:(IOHIDDeviceRef)iohidDevice {
    
    if (iohidDevice == NULL) {
        assert(false);
        return NO;
    }
        
    NSNumber *otherID = (__bridge NSNumber *)IOHIDDeviceGetProperty(iohidDevice, CFSTR(kIOHIDUniqueIDKey));
    return [self.uniqueID isEqual:otherID];
}

- (BOOL)isEqual:(Device *)other {
    
    /// Notes:
    ///     - In the template where we copied this from, they also used ![super isEqual:other] but that didn't work for us.
    
    if (other == nil) { /// Check nil
        assert(false);
        return NO;
    } else if (other == self) { /// Check for pointer equality
        return YES;
    } else if (![other isKindOfClass:self.class]) { ///  Check for class equality
        return NO;
    } else { /// Custom equality logic
        
        /// Guard NULL
        ///     (28.08.2024 on macOS Sequoia Beta) I've just seen a crash where IIRC the .iohidDevice was NULL. I saw that happen where this was called from the Button-input handling code. It happened around the time of connecting/disconnecting a device IIRC.
        ///         I don't know why this could happen, since a `device` instance retains its `.iohidDevice` instance, so it should never become NULL. Maybe there was a race condition?
        
        if (other.iohidDevice == NULL) {
            assert(false); /// Should never happen since Device instances retain their .iohidDevice's || Update: [Jul 2025] I think this is expected for StrangeDevice (at least on master branch, writing this on feature-strings-catalog). I actually wonder why we haven't seen this crash more often. We should replace all the CF functions with NULL-safe alternatives such as MFCFEqual!
            return NO;
        }
        if (self.iohidDevice == NULL) {
            assert(false);
            return NO;
        }
        
        /// Use CFEqual
        BOOL result = CFEqual(self.iohidDevice, other.iohidDevice);
        
        /// Return
        return result;
    }
}

- (NSUInteger)hash {
//    return CFHash(_IOHIDDevice) << 1;
    return (NSUInteger)self; /// TODO: Are we sure just using the self pointer as hash is a good idea? Maybe use uniqueID instead? Why don't we use CFHash() anymore?
}

- (NSString *)name {
    
    IOHIDDeviceRef device = self.iohidDevice;
    NSString *product = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    
    return product;
}

- (NSString *)manufacturer {
    
    IOHIDDeviceRef device = self.iohidDevice;
    NSString *manufacturer = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDManufacturerKey));
    
    return manufacturer;
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
