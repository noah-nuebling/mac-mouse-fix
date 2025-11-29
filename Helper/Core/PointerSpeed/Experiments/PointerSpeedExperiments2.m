//
// --------------------------------------------------------------------------
// PointerSpeed2.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// The original PointerSpeedExperiments.m was getting a little long and confusing, so we created this
/// Also see NotePlan daily notes from 16.06.21 and the week after for more info.


#import "PointerSpeedExperiments2.h"
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import "IOUtility.h"
@import IOKit; /// In hopes this will import the IOHIDEventSystemClientCreate(void) function that CursorSense seems to be using


@implementation PointerSpeedExperiments2

#pragma mark - Edit 26.06.2022

/// Moved this out of PointerSpeed.m on 26.06.2022. Old implementation, that isn't modular and doesn't support totally custom curves. Keeping it for reference.
+ (void)old_setForDevice:(IOHIDDeviceRef)device
         sensitivity:(double)sensitivity
        acceleration:(double)acceleration {
    /// Sets pointer  sensitivity and pointer acceleration on a specific IOHIDDevice. Source for this is `PointerSpeedExperiments2.m`
    /// `sensitivity` is a multiplier on the default macOS pointer sensitivity
    /// `acceleration` should be between 0.0 and 3.0.
///         - It's the same value that can be set through the `defaults write .GlobalPreferences com.apple.mouse.scaling x` terminal command or through the "Tracking speed" slider in System Preferences > Mouse.
    ///     - x in `defaults write .GlobalPreferences com.apple.mouse.scaling x` can also be -1 (or any other negative number) which will turn the acceleration off (just like 0), but it will also increase the sensitivity. I haven't experimented with setting `acceleration` to -1. But we can change sensitivity through `sensitivity` anyways so it's not that interesting.
    
    /// Declare stuff
    kern_return_t kr;
    Boolean success;
    
    /// Get eventSystemClient
    IOHIDEventSystemClientRef eventSystemClient = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, HIDEventSystemClientTypePassive, NULL);
    
    /// Get IOService of the driver driving `dev`
    io_service_t IOHIDDeviceService = IOHIDDeviceGetService(device);
    io_service_t interfaceService = [IOUtility createChildOfRegistryEntry:IOHIDDeviceService withName:@"IOHIDInterface"];
    io_service_t driverService = [IOUtility createChildOfRegistryEntry:interfaceService withName:@"AppleUserHIDEventDriver"];
    
    /// Get ID of the driver
    uint64_t driverServiceID;
    kr = IORegistryEntryGetRegistryEntryID(driverService, &driverServiceID);
    assert(kr == 0);
    
    /// Get service client of the driver
    IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, driverServiceID);
    assert(serviceClient);
    
    /// Get pointerResolution from sensitivity
    /// - 400 is the default (unchangeable) pointer resolution in macOS.
    /// - Smaller pointerResolution -> higher sensitivity
    /// - Like this, `sensitvity` will act like a multiplier on the default sensitivity.
    double pointerResolution = 400.0 / sensitivity;
    
    /// Get pointerResolution as fixed point CFNumber
    CFNumberRef pointerResolutionCF = (__bridge  CFNumberRef)@(FloatToFixed(pointerResolution));
    
    /// Set pointer resolution on the driver
    success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolutionCF);
    assert(success);
    
    /// Get acceleration as fixed point CFNumber
    CFNumberRef mouseAccelerationCF = (__bridge CFNumberRef)@(FloatToFixed(acceleration));
    
    /// Set mouse acceleration on the driver
    success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDMouseAccelerationTypeKey), mouseAccelerationCF);
    assert(success);
    
    /// Release stuff
    IOObjectRelease(IOHIDDeviceService); /// Not sure if necessary because of function name used to create it (See CreateRule)
    IOObjectRelease(interfaceService);
    IOObjectRelease(driverService);
    CFRelease(eventSystemClient);
    CFRelease(serviceClient);
    
}

#pragma mark - External declarations

/*!
 * @typedef HIDEventSystemClientType
 *
 * @abstract
 * Enumerator of HIDEventSystemClient types.
 *
 * @field HIDEventSystemClientTypeAdmin
 * Admin client will receive blanket access to all HIDEventSystemClient API,
 * and will receive events before monitor/rate controlled clients. This client
 * type requires entitlement 'com.apple.private.hid.client.admin', and in
 * general should not be used.
 *
 * @field HIDEventSystemClientTypeMonitor
 * Client type used for receiving HID events from the HID event system. Requires
 * entitlement 'com.apple.private.hid.client.event-monitor'.
 *
 * @field HIDEventSystemClientTypePassive
 * Client type that does not require any entitlements, but may not receive HID
 * events. Passive clients can be used for querying/setting properties on
 * HID services.
 *
 * @field HIDEventSystemClientTypeRateControlled
 * Client type used for receiving HID events from the HID event system. This is
 * similar to the monitor client, except rate controlled clients have the
 * ability to set the report and batch interval for the services they are
 * monitoring. Requires entitlement 'com.apple.private.hid.client.event-monitor'.
 *
 * @field HIDEventSystemClientTypeSimple
 * Public client type used by third parties. Simple clients do not have the
 * ability to monitor events, and have a restricted set of properties on which
 * they can query/set on a HID service.
 */
typedef NS_ENUM(NSInteger, HIDEventSystemClientType) {
    /// src: ~/Documents/Projekte/Programmieren/Xcode/Xcode Projekte/Mac Mouse Fix/Other/IOKit source code (19.06.2021)/IOHIDFamily-1633.100.36/HID/HIDEventSystemClient.h
    HIDEventSystemClientTypeAdmin,
    HIDEventSystemClientTypeMonitor,
    HIDEventSystemClientTypePassive,
    HIDEventSystemClientTypeRateControlled,
    HIDEventSystemClientTypeSimple
};

/// src: Saw this being used around the IOHIDFamily source code
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreateWithType(CFAllocatorRef allocator,
                                                                      HIDEventSystemClientType clientType,
                                                                      CFDictionaryRef _Nullable attributes);
/// src: CursorSense disassembly
/// This function call doesn't work. It seems the CursorSense disassembly is just messing up and this function doesn't event exist.
//extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(void);
/// src: Variation of above function I found on Google
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);

/// src: I forgot
extern IOHIDServiceClientRef IOHIDEventSystemClientCopyServiceForRegistryID(IOHIDEventSystemClientRef client, uint64_t entryID);

/// src: CursorSense
extern void IOHIDEventSystemClientScheduleWithRunLoop(IOHIDEventSystemClientRef client, CFRunLoopRef runLoop, CFRunLoopMode mode);
extern void IOHIDEventSystemClientUnscheduleFromRunLoop(IOHIDEventSystemClientRef client, CFRunLoopRef runLoop, CFRunLoopMode mode);

/// src: CursorSense / IOKit source
extern void IOHIDEventSystemClientSetMatchingMultiple(IOHIDEventSystemClientRef client, CFArrayRef matchDictArray);

typedef void (*IOHIDEventSystemClientDeviceMatchingCallbackFunction)(void *context, void *refcon, IOHIDServiceClientRef service);
extern void IOHIDEventSystemClientRegisterDeviceMatchingCallback(IOHIDEventSystemClientRef client, IOHIDEventSystemClientDeviceMatchingCallbackFunction callback, void *context, void *unknown);


#pragma mark - Set sensitivity

#pragma mark Helper

void deviceMatchingCallback(void *context, void *refcon, IOHIDServiceClientRef serviceClient) {
    /// This is called by Test 9
    
    [IOUtility afterDelay:0.5 runBlock:^{ /// Post with delay because that's what CursorSense does
    
        DDLogDebug(@"New matching service client: %@", [IOUtility registryPathForServiceClient:serviceClient]);
        
        
        /// Get pointerResolution as CFNumber
//        int64_t sens = IntToFixed(((int64_t)100));
//        CFNumberRef pointerResolution = (__bridge CFNumberRef)[NSNumber numberWithLongLong:sens];
        
        /// Get pointerResolution as CFNumber
        ///     But do it exactly like CursorSense disassembly
        Fixed sens = X2Fix(20.0);
        CFNumberRef pointerResolution = (__bridge CFNumberRef)[NSNumber numberWithInt:sens];
        
        /// Set pointerResolution
        Boolean success = IOHIDServiceClientSetProperty(serviceClient, CFSTR("HIDPointerResolution"), pointerResolution);
        assert(success);
        
    }];
    
}

#pragma mark Main

+ (void)setSensitivityTo:(int)sensitivity onDevice:(IOHIDDeviceRef)dev {
    /// More info on what we're doing here in [PointerSpeedExperiments + setSensitivityTo:onDevice:]
    /// And in the header comment of [PointerSpeedExperiments + newSetSensitivityViaIORegTo:device:]
    
    /// Guard calling this
    
    NSAssert(false, @"This is just experimentation code. It shouldn't be called in production.");
    
    /// Log
    
    DDLogDebug(@"BEGIN SERVICE LOGGING");
    
    /// Get event system client
    
    IOHIDEventSystemClientRef eventSystemClient = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, HIDEventSystemClientTypePassive, NULL);
    /// ^ We could probably use IOHIDEventSystemClientCreate() instead of this - That's what CursorSense is doing. But I have no idea what that does or where it comes from. I also tried using IOHIDEventSystemClientCreateSimpleClient(), but that doesn't let you set the pointerResolution.
    
    /// Test cases
    
    if ((NO)) {
        /**
         Test 12:
         Trying to set the props directly on the eventSystemClient, and foregoing (is that a word?) the deviceSpecific serviceClients
         Since we don't support device specific settings anyways, that would simplify things if it works.
         This works! Problem is it also affects the MacBooks internal trackpad, which we don't want. So setting the stuff per device is better after all.
         Also, I just tested and these settings don't survive a restart which is good.
         */
        
        /// Define stuff
        double sensitivity = 10.0;
        double acceleration = 0.5;
        Boolean success;
        
        /// Get pointerResolution as CFNumber
        int pointerResolutionFixed = IntToFixed(400 * (1/sensitivity));
        CFNumberRef pointerResolutionCF = (__bridge  CFNumberRef)@(pointerResolutionFixed);
        
        /// Set pointer resolution on the driver
        success = IOHIDEventSystemClientSetProperty(eventSystemClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolutionCF);
        assert(success);
        
        /// Get acceleration (aka trackingSpeed) as CFNumber
        int accelerationFixed = FloatToFixed(acceleration);
        CFNumberRef accelerationCF = (__bridge  CFNumberRef)@(accelerationFixed);
        
        /// Set mouse acceleration on the driver
        success = IOHIDEventSystemClientSetProperty(eventSystemClient, CFSTR(kIOHIDMouseAccelerationTypeKey), accelerationCF);
        assert(success);
        
    }
    if ((NO)) {
        /**
         Test 11:
         Setting properties on the serviceClient just like CursorSense to get it to update it's internal state or something
         Mostly based on Test 4;
         Conclusion: It works!!!!!! I just need to set the mouse acceleration after setting the pointer resolution, and then both of them are actually applied  to the mouse !! Omg I'm literally so happy. I spent the last week trying to figure this out.*Ouffff of relief*
         The only things lef to figure out now are
         - What are these system default values for resetting? Can we somehow get the tracking speed which the user has set in System Preferences and translate and apply that to reset to the default?
            - pointer Res default: 400
            - acceleration default: com.apple.mouse.scaling in NSDefaults.
         - What range of values is sensible for letting the use choose, and how do we parametrize that stuff?
            - The default (unchangeable) pointerRes is 400. I think it makes sens to let the use choose between 0.5x to 2.0x of the original pointer res. The formula would be 400 * 1/(x). Actual values would range from 800 (lowest sens) to 200 (highest sens).
            - The HIDMouseAcceleration values settable on the driver  through System Prefs range from 0.0 to 3.0. IIRC that means it perfectly corresponds to the values settable through "defaults write .GlobalPreferences com.apple.mouse.scaling x". See Apple Note "Improve Pointer Acceleration" for acceleration values between 0.0 and 3.0 which I thought made sense as options.
         - How and when do we (re)apply the settings?
            - CursorSense reapplies the stuff when, logging in, when the computer wakes from sleep, when display configuration changes, etc. We should check if that's necessary and implement that stuff too, if yes.
         - How and when do we reset the values to the system default?
            - Whenever Mac Mouse Fix Helper quits should be fine. Maybe also when a mouse is detached, on the driver of that mouse. When MMF quits we'd have to iterate through all attached mice and reset them individually. This would all be easier if we set the pointerRes and acceleration on the eventSystemClient instead of the individual mouse drivers. But that might also be less robust because if MMF crashes then the settings would be stuck and be applied even on newly attached mice. Idk until when. Maybe until next restart or maybe until forever? I should do more testing there.
         
         
         Edit: Actually we had CursorSense enabled during these last few tests so we need to test this stuff again.
            -> It still works! Setting the acceleration is also still necessary to make setting the pointerResolution work. So having CursorSense enabled doesn't seem to have influenced the tests (somehow - from my understanding of the disassembly it should have because it listens to property changes in the eventSystemClient and re-applies it's settings if it detects them IIRC)
         */
        
        /// Declare stuff
        kern_return_t kr;
        Boolean success;
        
        /// Get IOService of the driver driving `dev`
        io_service_t IOHIDDeviceService = IOHIDDeviceGetService(dev);
        io_service_t interfaceService = [IOUtility createChildOfRegistryEntry:IOHIDDeviceService withName:@"IOHIDInterface"];
        io_service_t driverService = [IOUtility createChildOfRegistryEntry:interfaceService withName:@"AppleUserHIDEventDriver"];
        
        /// Get ID of the driver
        uint64_t driverServiceID;
        kr = IORegistryEntryGetRegistryEntryID(driverService, &driverServiceID);
        assert(kr == 0);
        
        /// Get service client of the driver
        IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, driverServiceID);
        assert(serviceClient);
        
        /// Get pointerResolution as CFNumber
        int sens = IntToFixed(20);
        CFNumberRef pointerResolution = (__bridge  CFNumberRef)@(sens);
        
        /// Set pointer resolution on the driver
        success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolution);
        assert(success);
        
        /// Get acceleration (aka trackingSpeed) as CFNumber
        int acc = FloatToFixed(0.68);
        CFNumberRef mouseAcceleration = (__bridge  CFNumberRef)@(acc);
        
        /// Set mouse acceleration on the driver
        success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDMouseAccelerationTypeKey), mouseAcceleration);
        assert(success);
        
    }
    if ((NO)) {
        /// Test 10
        /// Trying to get a minimum working example of the breakthrough made in Test 9
        /// Conclusion:
        /// - Plugging larger numbers into X2Fix(x) makes the sensitivity lower and vice versa.
        /// - The changing of the sensitivity is only due to IOHIDEventSystemClientSetProperty(). IOHIDServiceClientSetProperty() doesn't do anything in the scenario of Test 9.
        /// - To achieve the change in sens you have to
        ///     - Run the code of Test 10 while the mouse is plugged in
        ///     - Plug the the mouse out and in again.
        ///     - Sensitivity will change!
        ///     - If the mouse is not plugged in while the Test 10 code runs it won't do anything once you plug it in. If you don't plug it out and in again it won't do anything, either. Very weird.
        /// Ideas:
        /// - I feel like, by plugging it out and in again we're forcing the serviceClient driver to update its internal state to the properties set on eventSystemClient somehow.
        /// - Maybe if we set exactly the properties on the serviceClient that SteerMouse is setting, we'll also provoke the serviceClient drivers internal state to update somehow. -> We'll test this in Test 11.
        
        /// Get pointerResolution as CFNumber
        Fixed sens = X2Fix(400.0); CFNumberRef pointerRes = (__bridge CFNumberRef)[NSNumber numberWithInt:sens];
        
        /// Set pointer resolution on the eventSystemClient
        IOHIDEventSystemClientSetProperty(eventSystemClient, CFSTR(kIOHIDPointerResolutionKey), pointerRes);
        
    }
    
    if ((NO)) {
        /// Test 9:
        /// Trying to obtain the serviceClients from the eventSystemClient via matching callbacks like CursorSense does.
        /// Don't know why that would make a difference but I"m out of ideas.
        /// Conclusion: I feel like I'm doing everything like CursorSense is. I'm soooo out of ideas.
        /// I was about to go to bed but then I tried some random stuff (at the bottom of Test 9) and it worked!
        /// I'll try to simplify this and distill it into the minimum working setup in Test 10.
        /// After some more investigation, it seems that
        
        static dispatch_once_t predicate;
        dispatch_once(&predicate, ^{
        
            /// Create eventSystemClient
            IOHIDEventSystemClientRef eventSystemClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
            
            /// Create matching dict array
            
            NSDictionary *matchDict1 = @{
                @(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
                @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Pointer),
            };
            NSDictionary *matchDict2 = @{
                @(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
                @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Mouse),
            };
            NSArray *matchArray = @[matchDict1, matchDict2];
            
            /// Set matching to eventSystemClient
            
            IOHIDEventSystemClientSetMatchingMultiple(eventSystemClient, (__bridge CFArrayRef)(matchArray));
            
            /// Schedule with runloop
            
            IOHIDEventSystemClientScheduleWithRunLoop(eventSystemClient, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
            
            /// Register device matching callback
            
            IOHIDEventSystemClientRegisterDeviceMatchingCallback(eventSystemClient, &deviceMatchingCallback, NULL, NULL);
            
            /// Set pointerRes to the eventSystemClient directly. I have no reason to believe this will work, but I'm desperate
            /// WTF THIS WORKS!!!
            /// It works really weird though: When I set the pointer res to X2Fix(20.0) on the eventSystemClient here, and then set then set the pointerRes to X2Fix(20.0) on the serviceClient of my mouse in the deviceMatchingCallback(), then the pointer becomes sinsitive af!
            /// Wtf that doesn't make any sense whatsoever (baseline pointer res is 400, so 20 should be slow?), and why do I have to set it on both to have any effect? Why doesn't it have an effect on the trackpad when I set the pointer res on the eventSystemClient?
            /// It's so weird. But it does something!! I started trying to change pointer res like 2 years ago and now it just works from doing this random bs wtf!!
            /// I just checked and CursorSense doesn't use IOHIDEventSystemClientSetProperty() at all. Wtf.
            /// Idea: Maybe this is more about tapping the eventSystemClient to kick it off for customization instead of setting the pointerResolution specifically?
            
            Fixed sens = X2Fix(400.0); CFNumberRef pointerRes = (__bridge CFNumberRef)[NSNumber numberWithInt:sens];
            IOHIDEventSystemClientSetProperty(eventSystemClient, CFSTR(kIOHIDPointerResolutionKey), pointerRes);
        });
        
    }
    if ((NO)) {
        /// Test 8
        /// Like test 7 but we use IOHIDEventSystemClientCreate() (with no arguments)
        /// That seems to be what CursorSense is using, but maybe the arguments are just missing in the disassembly
        /// I think what CursorSense is actually calling is probably IOHIDEventSystemClientCreate(kCFAllocatorDefault).
        /// That function exists, but doesn't do anything, either.
        
        /// Get eventSystemClient like CursorSense
        
        IOHIDEventSystemClientRef eventSystemClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        
        static dispatch_once_t predicate;
        dispatch_once(&predicate, ^{
            
            /// Set pointerResolution on all serviceClients
            
            CFArrayRef serviceClients = IOHIDEventSystemClientCopyServices(eventSystemClient);
            for (id serviceClientUntyped in (__bridge NSArray *)serviceClients) {
                
                IOHIDServiceClientRef serviceClient = (__bridge IOHIDServiceClientRef)serviceClientUntyped;
                
                /// Get pointerResolution as CFNumber
                int64_t sens = IntToFixed(((int64_t)100));
                CFNumberRef pointerResolution = (__bridge CFNumberRef)[NSNumber numberWithLongLong:sens];
                
                /// Set pointerResolution
                
                Boolean success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolution);
                assert(success);
            }
            
        });
        
    }
    if ((NO)) {
        /// Test 7
        /// Simply set pointerResolution on all serviceClients obtained via the eventSystemClient
        
        static dispatch_once_t predicate;
        dispatch_once(&predicate, ^{
            
            /// Set pointerResolution on all serviceClients
            
            CFArrayRef serviceClients = IOHIDEventSystemClientCopyServices(eventSystemClient);
            for (id serviceClientUntyped in (__bridge NSArray *)serviceClients) {
                
                IOHIDServiceClientRef serviceClient = (__bridge IOHIDServiceClientRef)serviceClientUntyped;
                
                /// Get pointerResolution as CFNumber
                int64_t sens = IntToFixed(((int64_t)200));
                CFNumberRef pointerResolution = (__bridge CFNumberRef)[NSNumber numberWithLongLong:sens];
                
                /// Set pointerResolution
                
                Boolean success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolution);
                assert(success);
            }
            
        });
        
    }
    if ((NO)) {
        /// Test 6:
        /// Like Test 4, but for trying out some extra details obtained from CursorSense source code (posting with delay)
        
        
        /// Declare stuff
        kern_return_t kr;
        
        /// Get IOService of the driver driving `dev`
        io_service_t IOHIDDeviceService = IOHIDDeviceGetService(dev);
        io_service_t interfaceService = [IOUtility createChildOfRegistryEntry:IOHIDDeviceService withName:@"IOHIDInterface"];
        io_service_t driverService = [IOUtility createChildOfRegistryEntry:interfaceService withName:@"AppleUserHIDEventDriver"];
        
        /// Get ID of the driver
        uint64_t driverServiceID;
        kr = IORegistryEntryGetRegistryEntryID(driverService, &driverServiceID);
        assert(kr == 0);
        
        /// Get service client of the driver
        IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, driverServiceID);
        assert(serviceClient);
        
        /// Get pointerResolution as CFNumber
        int64_t sens = IntToFixed(((int64_t)200));
        CFNumberRef pointerResolution = (__bridge CFNumberRef)[NSNumber numberWithLongLong:sens];
        
        [IOUtility afterDelay:2.0 runBlock:^{ /// Post with delay because that's what CursorSense does
            
            /// Set pointer resolution of the driver
            
            Boolean success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolution);
            assert(success);
            
            /// Debug
            
            printServiceClientInfo(serviceClient);
            
        }];
    }
    if ((NO)) {
        /// Test 5;
        /// Setting pointerResolution on the service client at IOService:/IOResources/IOHIDSystem
        /// Doesn't work either :/ The IOHIDSystem registry entry doesn't even have a pointerResolution property..
        /// More ideas I have:
        /// - Maybe I need to tell the system to actually apply the new pointer resolution somehow after setting it like in Test 4?
        /// - Maybe the CursorSense code I had been looking at is just to bamboozle people like me? (Very unlikely)
        /// - Maybe I'm using the IOHIDEventSystemClient wrong and I actually need to to escalate the privileges further or open it as an IOConnection or sth like that to make it actually react to setting properties
        /// - Maybe I need to set some other properties to enable the pointerResolution property. - That was the Bingo :)
        /// -  Maybe you need some special entitlements on the app or something to set pointerResolution
        
        
        /// Declare stuff
        register kern_return_t kr;
        mach_port_t            masterPort;
        
        /// Get masterPort
        kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
        
        /// Get IOHIDSystem service (copied from myNXOpenEventStatus)
        io_service_t IOHIDSystemService = IORegistryEntryFromPath(masterPort, kIOServicePlane ":/IOResources/IOHIDSystem");
        
        /// Get ID of the driver
        uint64_t IOHIDSystemServiceID;
        IORegistryEntryGetRegistryEntryID(IOHIDSystemService, &IOHIDSystemServiceID);
        
        /// Get service client for the IOHIDSystem
        IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, IOHIDSystemServiceID);
        
        /// Get pointerResolution as CFNumber
        int sens = IntToFixed(500);
        CFNumberRef pointerResolution = (__bridge CFNumberRef)@(sens);
        
        /// Set pointer resolution of the driver
        Boolean ret = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolution);
        
        /// Debug
        DDLogDebug(@"Set prop return: %d", ret);
        printServiceClientInfo(serviceClient);
        
    }
    if ((NO)) {
        /// Test 4:
        /// Putting it all together and changing pointer resolution
        /// Conclusion:
        ///     On the driver registry entry, this successfully changes the property at `HIDEventServiceProperties > HIDPointerResolution`, but not the one at `HIDPointerResolution`
        ///     There is no noticable effect due to this at all though :(
        ///     Setting sens in CursorSense also changes the value at `HIDEventServiceProperties > HIDPointerResolution`
        ///     The last idea I have is to use IOHIDServiceClientSetProperty on the HIDSystem's (or sth like that) serviceClient which showed up in the results for IOHIDEventSystemClientCopyServices()
        ///         Just checked and that service client was at registry path IOService:/IOResources/IOHIDSystem. See Test 5 for results
        
        /// Declare stuff
        kern_return_t kr;
        Boolean success;
        
        /// Get IOService of the driver driving `dev`
        io_service_t IOHIDDeviceService = IOHIDDeviceGetService(dev);
        io_service_t interfaceService = [IOUtility createChildOfRegistryEntry:IOHIDDeviceService withName:@"IOHIDInterface"];
        io_service_t driverService = [IOUtility createChildOfRegistryEntry:interfaceService withName:@"AppleUserHIDEventDriver"];
        
        /// Get ID of the driver
        uint64_t driverServiceID;
        kr = IORegistryEntryGetRegistryEntryID(driverService, &driverServiceID);
        assert(kr == 0);
        
        /// Get service client of the driver
        IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, driverServiceID);
        assert(serviceClient);
        
        /// Get pointerResolution as CFNumber
        int sens = IntToFixed(350);
        CFNumberRef pointerResolution = (__bridge  CFNumberRef)@(sens);
        
        /// Set pointer resolution of the driver
        
        success = IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), pointerResolution);
        assert(success);
        
        /// Debug
        
        printServiceClientInfo(serviceClient);
        
    }
    if ((NO)) {
        /// Test 3:
        /// Refined version of Test 2. See Test 2 for explanation
        
        io_service_t IOHIDDeviceService = IOHIDDeviceGetService(dev);
        io_service_t interfaceService = [IOUtility createChildOfRegistryEntry:IOHIDDeviceService withName:@"IOHIDInterface"];
        io_service_t driverService = [IOUtility createChildOfRegistryEntry:interfaceService withName:@"AppleUserHIDEventDriver"];
        
        /// Get ID
        uint64_t driverServiceID;
        IORegistryEntryGetRegistryEntryID(driverService, &driverServiceID);
        IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, driverServiceID);
        
        /// Print info
        printServiceClientInfo(serviceClient);
        /// ^ It seems to work! this logs the right thing!
        /// So now we might be able to call IOHIDServiceClientSetProperty on this serviceClient to change the pointer resolution!
        
    }
    
    if ((NO)) {
        /// Test 2
        /// Get the serviceClient for my mouse directly from the IOHIDDeviceRef
        /// This approach almost works, but doesn't, because the paths obtained by IOHIDDeviceGetService() and IOHIDEventSystemClientCopyServices() don't match. See below.
        
        /// Get registryEntryID for IOHIDDeviceRef
        /// Get service
        io_service_t IOHIDDeviceService = IOHIDDeviceGetService(dev);
        /// Print info on IOHIDDeviceService
        char IOHIDDeviceServicePath[100];
        IORegistryEntryGetPath(IOHIDDeviceService, kIOServicePlane, IOHIDDeviceServicePath);
        DDLogDebug(@"IOHIDDeviceServicePath: %s", IOHIDDeviceServicePath);
        
        /// Get ID
        uint64_t IOHIDDeviceServiceID;
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceService, &IOHIDDeviceServiceID);
        /// Get serviceClient
        /// This doesn't work. It seems the IOService returned by IOHIDDeviceGetService() is not the one which corresponds to a serviceClient
        /// Edit: Yes that theory was correct.
        /// Path obtained via IOHIDEventSystemClientCopyServices()
        ///     IOService:/IOResources/IOHIDResource/IOHIDResourceDeviceUserClient/IOHIDUserDevice/IOHIDInterface/AppleUserHIDEventDriver
        /// Path obtained via IOHIDDeviceGetService()
        ///     IOService:/IOResources/IOHIDResource/IOHIDResourceDeviceUserClient/IOHIDUserDevice
        IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, IOHIDDeviceServiceID);
        
        printServiceClientInfo(serviceClient);
    }
    
    
    if ((NO)) {
        /// Test 1
        /// Copy all services of the eventSystemClient to get an overview
        /// Conclusion:
        /// - There is only one serviceClient provided by the eventSystemClient that relates to my mouse. (Logitech M720 attached via Bluetooth)
        /// - The registryPath of the IOService derived from that serviceClient is
        ///  IOService:/IOResources/IOHIDResource/IOHIDResourceDeviceUserClient/IOHIDUserDevice/IOHIDInterface/AppleUserHIDEventDriver
        /// Edit: Using IOHIDServiceClientSetProperty to set pointerResolution on this serviceClient doesn't do anything :(
        ///     But there's another interesting serviceClient that shows up here. It has the path IOService:/IOResources/IOHIDSystem. Maybe setting pointerResolution on this will do something.

        static dispatch_once_t predicate;
        dispatch_once(&predicate, ^{
            
            /// Print all service clients
            
            CFArrayRef serviceClients = IOHIDEventSystemClientCopyServices(eventSystemClient);
            for (id serviceClientUntyped in (__bridge NSArray *)serviceClients) {
                
                IOHIDServiceClientRef serviceClient = (__bridge IOHIDServiceClientRef)serviceClientUntyped;
                
                printServiceClientInfo(serviceClient);
            }
            
        });
    }
    
    DDLogDebug(@"END SERVICE LOGGING");

}

static void printServiceClientInfo(IOHIDServiceClientRef serviceClient) {
    
    uint64_t serviceClientRegistryID = ((__bridge NSNumber *)IOHIDServiceClientGetRegistryID(serviceClient)).longLongValue;
    CFMutableDictionaryRef serviceClientMatchingDict = IORegistryEntryIDMatching(serviceClientRegistryID);
    io_service_t serviceClientService = IOServiceGetMatchingService(kIOMasterPortDefault, serviceClientMatchingDict);
    
    /// Get IORegistry path
    
    char serviceClientPath[1000];
    IORegistryEntryGetPath(serviceClientService, kIOServicePlane, serviceClientPath);
    /// ^ This makes the program crash after the function returns for some reason. Seems to be a stack overflow
    /// After enabling Address Sanitizer it presents itself as EXC_BAD_ACCESS (code=EXC_I386_GPFLT)
    /// After enabling NSZombies there's a stack-buffer-overflow when printing serviceClientPath with DDLogDebug. Doesn't matter if we cast to NSString and use %@ or print using %s.
    /// If we comment out DDLogDebug, we get the old error after the function returns.
    /// When allocating 1000 characters for the serviceClientPath array, the crash disappears!
    /// But then why was is also crashing when we only got serviceClientProperties? ... Now it doesn't do that anymore.
    
    /// Get properties
    
    CFMutableDictionaryRef serviceClientProperties = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
    IORegistryEntryCreateCFProperties(serviceClientService, &serviceClientProperties, kCFAllocatorDefault, 0);
    
    DDLogDebug(@"ServiceClientPath: %s", serviceClientPath);
    DDLogDebug(@"ServiceClientProperties: \n%@", (__bridge NSDictionary *)serviceClientProperties);
    
    CFRelease(serviceClientProperties);
}

@end
