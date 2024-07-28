//
// --------------------------------------------------------------------------
// PointerSpeed.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "PointerSpeedExperiments.h"
#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDTypes.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/hid/IOHIDProperties.h>
#import "IOUtility.h"


@implementation PointerSpeedExperiments

#pragma mark - External declarations

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
//extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(void);
extern IOHIDServiceClientRef IOHIDEventSystemClientCopyServiceForRegistryID(IOHIDEventSystemClientRef client, uint64_t entryID);


#pragma mark - Variables and initialize

static mach_port_t _IOHIDSystemHandle;

+ (void)initialize
{
    if (self == [PointerSpeedExperiments class]) {
        _IOHIDSystemHandle = myNXOpenEventStatus();
    }
}

#pragma mark - Helper functions

kern_return_t IOHIDSetHIDParameterToEventSystem(io_connect_t handle, CFStringRef key, CFTypeRef parameter) {
    /// Copied this function from IOEventStatusAPI.c with some changes
    
//    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreateWithType (kCFAllocatorDefault, kIOHIDEventSystemClientTypePassive, NULL);
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    kern_return_t  kr = kIOReturnNotReady;
    if (!client) {
        goto exit;
    }
 
    kr = kIOReturnUnsupported;
    io_service_t  service = 0;
    if (IOConnectGetService (handle, &service) == kIOReturnSuccess) {
        if (IOObjectConformsTo (service, "IOHIDSystem")) {
            IOHIDEventSystemClientSetProperty(client, key, parameter);
            kr = kIOReturnSuccess;
        } else {
            kern_return_t r = setParameter(client, service, key, parameter);
            if (r) {
                kr = r;
            }
        }
        IOObjectRelease(service);
    }
    
 exit:

    if (client) {
        CFRelease(client);
    }
    if (kr) {
//        os_log_error(_IOHIDLog(), "Fail to set parameter with status 0x%x", kr);
        DDLogInfo(@"Fail to set parameter with status 0x%x", kr);
    }
    return kr;
}

kern_return_t setParameter(IOHIDEventSystemClientRef esClient, io_service_t service, CFStringRef key, CFTypeRef parameter) {
    /// Helper function for IOHIDSetHIDParameterToEventSystem()
    
    kern_return_t kr = kIOReturnSuccess;
    
    uint64_t entryID = 0;
    if (IORegistryEntryGetRegistryEntryID (service, &entryID) == kIOReturnSuccess) {
        IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(esClient, entryID);
        if (serviceClient) {
            if (IOHIDServiceClientSetProperty(serviceClient, key, parameter)) {
              kr = kIOReturnSuccess;
            } else {
              kr = kIOReturnInternalError;
            }
            CFRelease(serviceClient);
        }
    }
    return kr;
}


#pragma mark - Sensitivity

+ (void)setSensitivityTo:(int)sensitivity onDevice:(IOHIDDeviceRef)dev {
    /**
     2021 attempt at changing sensitivity based on my new understanding from reading the IOKit Fundamentals and related documents, as well as the the HIPointing.ccp and related Darwin source files.
        HIPointing.cpp and its superclass IOHIDevice.cpp (not sure if correct name) define `setProperties` functions, which updated the internal pointerResolution state when called. I think that setProperties should be called when we call IORegistryEntrySetCFProperties on the device driver which (I assume) is an instance of HIPointing.
        But it doesn't work :(
        I looked at the pre-Sierra CursorSense code, and there, they seem to have done it the way I thought would work ( they did it by calling either IORegistryEntrySetCFProperty or IOConnectSetCFProperty I'm spotty on the details). They also seemed to be able to fully customize the acceleration curve back then! But with Sierra, that approach broke, and now they are using IOHIDServiceClientSetProperty() to set the pointer resolution, and without any further customization of the curve.
        Something similar seems to have happened to Karabiner, with 10.12. - It completely broke the program.
            See: https://github.com/tekezo/Karabiner/issues/739
        This caused a huge shitstorm on the Karabiner GitHub. A few months later - possibly as a direct response to this, Apple released a technical note describing how to remap keys with new APIs available in 10.12.
            See: https://developer.apple.com/library/archive/technotes/tn2450/_index.html
        The APIs they are using in the tech note are IOHIDEventSystemClient.h and IOHIDServiceClient.h! Just like CursorSense!
        These APIs had been around since the release of Sierra, apparently, but because they were basically undocumented, no one knew how to use them (I think - haven't looked into this further)
        I've looked for more info on these new Sierra APIs in the Apple documentation archives but I couldn't find anything else.
        
        Either way the conclusion is: these IOHIDEventSystemClient.h and IOHIDServiceClient.h APIs are surely the designated way to set pointer resolution.
        Now we'll just have to find out how to use them. To guide us we should look at
        - The Apple technote on how to remap keys in Sierra
        - CursorSense source code using these APIs.
            - It's still unclear how they obtain the IOHIDServiceClientRef which they set the pointer resolution on.
        - Apple source code
            - In previous investigations (See below), I had the impression that there are different hidden methods to create an IOHIDEventSystemClient, which might impose different privilege levels. Maybe we need a certain privilege level in order to be able to set pointerResolution?
            - ~/Documents/Projekte/Programmieren/Xcode/Xcode Projekte/Mac Mouse Fix/Other/IOKit source code (19.06.2021)/IOHIDFamily-1633.100.36/HID/HIDEventSystemClient.h
                - Contains all the different types of eventSystemClient and what their priviledges are and how to create them! We probably want to use kIOHIDEventSystemClientTypePassive type.
            - IOHIDEventSystemClientCreateWithType() is used all over the IOKitFamilies source code, but I can't find the definition. Maybe it's defined in HIDEventSystemClientPrivate.h?
                - Should be able to use it by simply declaring extern IOHIDEventSystemClientCreateWithType()
            
        
     */
    
    sensitivity = 100; /// DEBUG
    
    /// Convert to fixed point
    
    int64_t sens = IntToFixed(sensitivity);
    
    /// Init err
    
    kern_return_t err = 0;

    /// Get device driver service
    
    io_service_t hostService = IOHIDDeviceGetService(dev);
    io_service_t interfaceService = [IOUtility createChildOfRegistryEntry:hostService withName:@"IOHIDInterface"];
    io_service_t driverService = [IOUtility createChildOfRegistryEntry:interfaceService withName:@"AppleUserHIDEventDriver"];

    /// Debug
    
//    char hostServicePath[100];
//    IORegistryEntryGetPath(hostService, kIOServicePlane, hostServicePath); /// This makes the program crash after the function returns for some reason.
//    DDLogDebug(@"Service Path: %@", @(hostServicePath));

    /// Get whole property dict
    
    CFMutableDictionaryRef properties = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
    err = IORegistryEntryCreateCFProperties(driverService, &properties, kCFAllocatorDefault, 0);
    assert (err == 0);

    /// Convert to dict NS and update pointerResolution
    
    NSMutableDictionary *propertiesNS = (__bridge_transfer NSMutableDictionary *)properties;
    propertiesNS[@(kIOHIDPointerResolutionKey)] = @(sens);

    /// Set updated property dict to driver registry entry
    
    err = IORegistryEntrySetCFProperties(driverService, (__bridge CFMutableDictionaryRef)propertiesNS);
    assert(err == 0);
    
    
    /// Approach 2:
    /// Opening a user client and settng properties on that
    /// Sort of inspired by skimming over this: https://developer.apple.com/forums/thread/90107
    
//    io_connect_t driverUserClient;
//    err = IOServiceOpen(driverService, mach_task_self(), kIOHIDEventSystemConnectType, &driverUserClient); /// Opening driverService or interfaceService or hostService returns different errors. The connectType doesn't seem to make a difference. IOServiceOpen worked in the experiments below. TODO: Investigate why. (Probably called it on different services.)
//    NSAssert(err == 0, @"Error is: %s", mach_error_string(err));
//    err = IOConnectSetCFProperties(driverUserClient, (__bridge CFMutableDictionaryRef)propertiesNS);
//    assert(err == 0);

    
    /// Approach 3:
    /// Try IOHIDServiceClientSetProperty again like SteerMouse
    
    IOHIDEventSystemClientRef eventSystemClient = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault);
    uint64_t entryID;
    IORegistryEntryGetRegistryEntryID(driverService, &entryID); // driverService doesn't do anything. interfaceService and hostService crash.
    IOHIDServiceClientRef serviceClient = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, entryID);
    IOHIDServiceClientSetProperty(serviceClient, CFSTR(kIOHIDPointerResolutionKey), (__bridge CFNumberRef)@(sens));
    
    
    /// Approach 4
    /// Use the device interface for communicating with the userClient which is provided by IOHIDDevice (user)
    /// Doesn't work either, who would've thunk

    
    Boolean success = IOHIDDeviceSetProperty(dev, CFSTR(kIOHIDPointerResolutionKey), (__bridge  CFNumberRef)@(sens));
    DDLogDebug(@"Setting property via IOHIDDevice was %ssuccessful", !success ? "not " : ""); /// Says it's succesful but doesn't do anything.
    
    /// Debug
    /// Check if pointerResolution updated
    /// -> It doesn't work, either
    CFTypeRef pointerResolution = IORegistryEntryCreateCFProperty(driverService, CFSTR(kIOHIDPointerResolutionKey), kCFAllocatorDefault, 0);
    int pointerResolutionInt = FixedToInt([((__bridge NSNumber *)pointerResolution) intValue]);
    DDLogDebug(@"Updated pointer res: %d", pointerResolutionInt);
    CFRelease(pointerResolution);
    
    
    
}

/// Doesn't work
/// Edit: Actually, I don't seem to have tried out the approach described in the header comment for some reason. So that approach might sitll work.
+ (void)newSetSensitivityViaIORegTo:(int)sens device:(IOHIDDeviceRef)dev {
    
    /*
     Approach:
     Cursor Sense seems to be able to change pointer resolution by calling `IOHIDServiceClientSetProperty` on an `IOHIDServiceClientRef`, so we'll try to make that work.
     
     Here are some functions I think I'll need. Got these functions from looking at usage examples in "IOKitUser-1726.140.1" and "IOHIDFamily-1446.140.2" downloaded from opensource.apple.com.
     
     Functions:
    
     // Getting a client
     // It seems that, depending on type, the client has permission to read/write different properties (I infer that from the `IOHIDEventSystemClientCreateSimpleClient()` documentation)
    
     // Found this function all over Apple source code
     IOHIDEventSystemClientCreateWithType (kCFAllocatorDefault, kIOHIDEventSystemClientTypePassive, NULL);
        kIOHIDEventSystemClientTypePassive
        kIOHIDEventSystemClientTypeMonitor
        kIOHIDEventSystemClientTypeSimple
     // Found this function on StackOverflow
     IOHIDEventSystemClientCreate(kCFAllocatorDefault)
     // Found this in Cursor Sense
     IOHIDEventSystemClientCreate()
     
     // Getting service clients given an event system client
     
     (CFArrayRef) IOHIDEventSystemClientCopyServices (client);
        IOHIDServiceClientConformsTo(service, kHIDPage_GenericDesktop, kHIDUsage_GD_Keyboard))
     IOHIDEventSystemClientCopyServiceForRegistryID(client, entryID);
        IORegistryEntryGetRegistryEntryID (service, &entryID)
     
     // Set Property to a service client
     IOHIDServiceClientSetProperty(service, key, state ? kCFBooleanTrue : kCFBooleanFalse);
     */
    
    io_service_t devService = IOHIDDeviceGetService(dev);
    io_service_t devServiceChild;
    io_service_t devServiceGrandChild;
    IOReturn childRet = IORegistryEntryGetChildEntry(devService, kIOServicePlane, &devServiceChild);
    IOReturn gcRet = IORegistryEntryGetChildEntry(devServiceChild, kIOServicePlane, &devServiceGrandChild);
    
    DDLogInfo(@"ChildRet: %ud, GCRet: %ud", childRet, gcRet);
    
    io_connect_t devConnect;
    IOReturn ret = IOServiceOpen(devService, mach_task_self(), 0, &devConnect); // This always fails for some reason
    
    // I've seen the connect type be some weird things in Apple source code:
    // 11
    // kIOHIDLibUserClientConnectManager = 0x00484944 /* HID */
    // kIOHIDResourceUserClientTypeDevice = 0
    // kIOHIDEventServiceUserClientType = 'HIDD'
    // Public values for connectTyp seem to end with 'ConnectType'
    
    if (ret != kIOReturnSuccess) {
        DDLogInfo(@"Open dev failed - dev: %@, IOReturn: %ud", dev, ret);
        return;
    }
    
    sens = 200; // 400 is default
    int newPointerRes = IntToFixed(sens);
    IOHIDSetHIDParameterToEventSystem(devConnect, CFSTR(kIOHIDPointerResolutionKey), (__bridge CFNumberRef)@(newPointerRes));
    /// ^ This function is made to set params to the eventSystem. devConnect is not a handle to the event system. I don't think this function call makes sense.
    
    IOServiceClose(devConnect);
    
}



/// Change pointer sensitity by manipulation IOHIDDevice properties. Doesn't work.
/// The kernel-space IOHIDDevice class (IOHIDDevice.cpp) can call `setProperty` on itself with the key kIOHIDPointerResolutionKey to change its pointer resolution. (Can be seen in IOHIDDevice.cpp found on opensource.apple.com)
/// But the userspace IOHIDDevice (IOHIDDevice.c) doesn't have the kIOHIDPointerResolutionKey property and setting it doesn't do anything
+ (void)setSensitivityViaIOHIDDeviceTo:(int)sens device:(IOHIDDeviceRef)dev {
    
    // Set new value
    sens = 12345; // 400 is default
//    int newPointerRes = IntToFixed(sens);
    int newPointerRes = sens;
    IOHIDDeviceSetProperty(dev, CFSTR(kIOHIDPointerResolutionKey), (__bridge CFNumberRef) @(newPointerRes));
    
    // Check what values actually are
    NSNumber *pointerResNS = (__bridge NSNumber *) IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDPointerResolutionKey));
    int pointerRes = pointerResNS.intValue;
    DDLogInfo(@"Set Pointer Resolution of device %@ to: %d, Actual Pointer Resolution: %d", dev, sens, FixedToInt(pointerRes));
    DDLogInfo(@"Set Pointer Resolution of device %@ to: %d, Actual Pointer Resolution: %d", dev, sens, pointerRes);
    
}

/// Change the pointer sensitivity of a device by manipulating finding and IORegistry Entry. Doesn't work.
+ (void)setSensitivityViaIORegTo:(int)sens device:(IOHIDDeviceRef)dev {
    
    // Ideas:
    // https://stackoverflow.com/questions/2615039/cant-edit-ioregistryentry
        // Use private getEVSHandle() function and do stuff with that. Author says that's how system preferences changes trackpad settings.
    
    
    
    
    

    io_service_t devService = IOHIDDeviceGetService(dev); // name: IOHIDUserDevice - grandchild has hidpointerresolution property (at least on the Nordic Semiconductor Mouse)
    io_connect_t devHandle;
    
    IOServiceOpen(devService, mach_task_self(), kIOHIDParamConnectType, &devHandle);
    
    IORegistryEntryCopyPath(devService, "IOService");
    
//    IORegistryEntryGetChildEntry(<#io_registry_entry_t entry#>, <#const char *plane#>, <#io_registry_entry_t *child#>)
    
//    CFTypeRef paramCF;

    
    
    io_name_t nm;
    IORegistryEntryGetName(devService, nm);
    
    CFTypeRef parameter;
    IOHIDCopyCFTypeParameter(devService, CFSTR("Product"), &parameter);
    
    IORegistryEntryCopyPath(devService, "IOService"); // works
//    IORegistryEntryCreateCFProperty(devService, CFSTR("ReportDescriptor"), kCFAllocatorDefault, 0) // works
    
    DDLogInfo(@"NAMEEE: %@", IORegistryEntryCopyPath(devService, "IOService"));
    
    
    // Getting service clients from Event system client
    
    IOHIDEventSystemClientRef eventSystemClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault); // using this self-defined function (extern) instead of ...CreateSimpleClient - maybe you can do "privilege escalation" here.
    CFArrayRef services = IOHIDEventSystemClientCopyServices(eventSystemClient);
    
//    DDLogInfo(@"services: %@", services);
    
    for (CFIndex i = 0; i < CFArrayGetCount(services); i++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        
        if(IOHIDServiceClientConformsTo(service, kHIDPage_GenericDesktop, kHIDUsage_GD_Mouse)) {
//            CFTypeRef prop = IOHIDServiceClientCopyProperty(service, CFSTR("HIDPointerResolution")); // doesn't work
            
            
            // -- getting the matching registry entry for service client -- think it's the same as grandchild of devService
            
            
            CFNumberRef entryIdCF = IOHIDServiceClientGetRegistryID(service);
            int64_t entryId;
            CFNumberGetValue(entryIdCF, CFNumberGetType(entryIdCF), &entryId);
            CFMutableDictionaryRef devEntryMatchDict = IORegistryEntryIDMatching(entryId);
            io_service_t matchingService = IOServiceGetMatchingService(kIOMasterPortDefault, devEntryMatchDict);
            

            
            
            
            
            // trying to set / read from the registry entry (it's obtained through the Service Client stuff above, but it's right one - it contains HIDPointerResolution, and you can read it, but until now, not write it)
            // None of these 3 methods seemed to have any effect. BUT I also forgot to turn steermouse off, so more testing is needed.

            
            
            
            int sens = 800; // 400 is default
            int newPointerRes = IntToFixed(sens);
            CFNumberRef newPointerRefCF = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &newPointerRes);
            kern_return_t kr = IORegistryEntrySetCFProperty(matchingService, CFSTR("HIDPointerResolution"), newPointerRefCF); // doesn't work
            #pragma unused(kr)
            
            // --
              
            io_connect_t drvHandle;
            IOReturn rt = IOServiceOpen(matchingService, mach_task_self(), kIOHIDParamConnectType, &drvHandle);
            // TODO: Maybe try opening the service with other parameters like kIOHIDEventSystemConnectType, or a different owning task.
            if (rt) {
                DDLogInfo(@"Opening device service failed with error code: %ud", rt);
            }
            
            // --
            
            IOConnectSetCFProperty(drvHandle, CFSTR("HIDPointerResolution"), newPointerRefCF); // doesn't work either
              
            // --
            
            IOHIDSetHIDParameterToEventSystem(drvHandle, CFSTR(kIOHIDPointerResolutionKey), newPointerRefCF);
            
            // --
//
            IOHIDServiceClientSetProperty(service, CFSTR("HIDPointerResolution"), newPointerRefCF); // doesn't work - its the way cursor sense does it though...
            
            
            // This manages to alter alter / create entries in HIDEventServiceProperties property. But creating HIDPointerResolution doesn't do anything.
            // CursorSense also creates a HIDPointerResolution entry in the HIDEventServiceProperties property.
//            CFBooleanRef falseCF = kCFBooleanFalse;
//            IORegistryEntrySetCFProperty(matchingService, CFSTR("HIDDefaultParameters"), falseCF);
            CFBooleanRef falseCF = kCFBooleanFalse;
            IORegistryEntrySetCFProperty(matchingService, CFSTR("TrackpadMomentumScroll"), falseCF);
            IORegistryEntrySetCFProperty(matchingService, CFSTR("HIDPointerResolution"), newPointerRefCF);
            IORegistryEntrySetCFProperty(matchingService, CFSTR("AAATESTTTT"), newPointerRefCF);
            
            // --
            
            
            // Print state
            
            CFTypeRef pointerResCF = IORegistryEntryCreateCFProperty(matchingService, CFSTR("HIDPointerResolution"), kCFAllocatorDefault, 0);
            int pointerRes;
            CFNumberGetValue(pointerResCF, kCFNumberSInt32Type, &pointerRes);
            
            DDLogInfo(@"Set Pointer Resolution to: %d, Actual Pointer Resolution: %d", sens, FixedToInt(pointerRes));
            
            NSDictionary *eventServiceProps = (__bridge NSDictionary *)IORegistryEntryCreateCFProperty(matchingService, CFSTR("HIDEventServiceProperties"), kCFAllocatorDefault, 0);
            DDLogInfo(@"Pointer Resolution in Event Service Properties: %d", FixedToInt([eventServiceProps[@"HIDPointerResolution"] integerValue]));

            
            
            DDLogInfo(@"Product: %@", IORegistryEntryCreateCFProperty(matchingService, CFSTR("Product"), kCFAllocatorDefault, 0));
//            DDLogInfo(@"Path: %@", IORegistryEntryCopyPath(matchingService, "IOService"));
            
            // trying to manipulate the eventserviceproperties property
            // Using IORegistryEntrySetCFProperty() on matching service actually creates/sets keys and values in the HIDEventServiceProperties dict, so we don't need this.
            
            
//            CFMutableDictionaryRef eventServiceProperties = IORegistryEntryCreateCFProperty(matchingService, CFSTR("HIDEventServiceProperties"), kCFAllocatorDefault, 0);
//
//            DDLogInfo(@"HODEventServiceProperties: %@", eventServiceProperties);
//
//            if (eventServiceProperties) {
//                int zero = 0;
//                CFNumberRef zeroCF = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &zero);
//                CFStringRef key = CFSTR("ActuateDetents");
//                CFDictionarySetValue(eventServiceProperties, key, zeroCF);
                
                    // This puts a copy of the HIDEventServiceProperties dict into the HIDEventServiceProperties dict. Not what we want.
//                IORegistryEntrySetCFProperty(matchingService, CFSTR("HIDEventServiceProperties"), eventServiceProperties);
                
//                DDLogInfo(@"HODEventServiceProperties New!: %@", IORegistryEntryCreateCFProperty(matchingService, CFSTR("HIDEventServiceProperties"), kCFAllocatorDefault, 0));
            
//            }
            
            
            
            
            /*
                     service = IORegistryEntryFromPath( masterPort, kIOServicePlane ":/IOResources/IOHIDResource/IOHIDResourceDeviceUserClient/IOHIDUserDevice/IOHIDInterface/AppleUserHIDEventDriver"); // this is where the mx master is at
             */
            
            
            
        }
    }
    

                
                
//                CFTypeRef prop = IOHIDServiceClientCopyProperty((IOHIDServiceClientRef)service, CFSTR("HIDPointerResolution"));
//                int ptrRes;
//                DDLogInfo(@"type: %@", CFNumberGetType(prop));
//
//                CFNumberGetValue(prop, kCFNumberSInt32Type, &ptrRes);
//
//                DDLogInfo(@"RES: %d", ptrRes);
//                prop = IOHIDServiceClientCopyProperty(service, CFSTR("HIDPointerResolution"));
//                CFNumberRef entryIdCF = IOHIDServiceClientGetRegistryID(service);
//                int64_t entryId;
//                CFNumberGetValue(entryIdCF, CFNumberGetType(entryIdCF), &entryId);
//
//
//                CFMutableDictionaryRef devEntryMatchDict = IORegistryEntryIDMatching(entryId);
//                io_service_t matchingService = IOServiceGetMatchingService(kIOMasterPortDefault, devEntryMatchDict);
//
//                io_name_t matchingServiceName;
//                IORegistryEntryGetName(matchingService, matchingServiceName);
//
////                kern_return_t writeError = IOConnectSetCFProperty(matchingService, CFSTR(kIOHIDPointerAccelerationKey), (__bridge CFNumberRef)[NSNumber numberWithInt:sens]);
//
////                (matchingService, CFSTR("HIDPointerResolution"), (__bridge CFNumberRef)[NSNumber numberWithInt:26214400]);
//
//                DDLogInfo(@"DEV NAME: %s", matchingServiceName);
////                DDLogInfo(@"WRITE ERR: %d", writeError);
//                DDLogInfo(@"DEVS: %@", IORegistryEntrySearchCFProperty(matchingService, kIOServicePlane, CFSTR(kIOHIDPointerAccelerationKey), kCFAllocatorDefault, kIORegistryIterateRecursively));
//            }
//        }
    
}

#pragma mark - Acceleration

/// Sets the mouse pointer acceleration to a certain value.
/// Changes the same value that the "Tracking Speed" option in System Preferences > Mouse or the "defaults write .GlobalPreferences com.apple.mouse.scaling x" command changes.
/// @param acc The value to set the acceleration to. Shouldn't be much higher than 4.0 or 5.0. Negative values turn off acceleration and also seem to affect pointer sensitivity.
+ (void)setAccelerationTo:(double)acc {
    
    
    DDLogInfo(@"Current Pointer Acceleration: %f", [self getActualAcceleration]);
    
    IOHIDSetCFTypeParameter(_IOHIDSystemHandle, CFSTR("HIDMouseAcceleration"), (__bridge CFNumberRef)[NSNumber numberWithDouble: FloatToFixed(acc)]);
    // reading values
    
    DDLogInfo(@"Current Pointer Acceleration: %f", [self getActualAcceleration]);
    
}

/// Gets the actual current Mouse Acceleration value. (As opposed to the one obtained by "defaults read .GlobalPreferences com.apple.mouse.scaling".)
+ (double)getActualAcceleration {
    
    CFTypeRef readNumCF = NULL;
    int32_t readNum;
    
    IOHIDCopyCFTypeParameter(_IOHIDSystemHandle, CFSTR("HIDMouseAcceleration"), &readNumCF);
    CFNumberGetValue(readNumCF, kCFNumberSInt32Type, &readNum);
    
    return (double) FixedToFloat(readNum);
}


# pragma mark Helper Functions


/// Copy of the deprecated NXOpenEventStatus() function source code found [here]
/// (https://opensource.apple.com/source/IOKitUser/IOKitUser-1445.40.1/hidsystem.subproj/IOEventStatusAPI.c.auto.html) .
NXEventHandle myNXOpenEventStatus(void) {
    
    NXEventHandle         handle = MACH_PORT_NULL;
    register kern_return_t    kr;
    io_service_t        service = MACH_PORT_NULL;
    mach_port_t            masterPort;

    do {

    kr = IOMasterPort( MACH_PORT_NULL, &masterPort );
    if( kr != KERN_SUCCESS)
        break;

        service = IORegistryEntryFromPath( masterPort,
                    kIOServicePlane ":/IOResources/IOHIDSystem" );
    if( !service)
        break;

        kr = IOServiceOpen(service,
            mach_task_self(),
            kIOHIDParamConnectType,
            &handle);

        IOObjectRelease( service );

    } while( false );

    return( handle );
}


@end



        // Trying to set HIDPointerResolution (sensitivity)

    //    io_service_t service = IOHIDDeviceGetService(device);
        
//    //---------------------------------
//
//        io_object_t hidSystemParametersConnection = IO_OBJECT_NULL;
//
//        // We're looking for a service of the IOHIDSystem class
//        CFMutableDictionaryRef classesToMatch = IOServiceMatching("IOHIDSystem");
//        if (!classesToMatch)
//            /* handle failure */;
//
//        // The following call implicitly releases classesToMatch
//        io_iterator_t matchingServicesIterator = IO_OBJECT_NULL;
//        IOReturn ret = IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatch, &matchingServicesIterator);
//        if (ret != kIOReturnSuccess)
//            /* handle failure */;
//
//        io_object_t service;
//        while ((service = IOIteratorNext(matchingServicesIterator)))
//        {
//            // Open the parameters connection to the HIDSystem service
//            ret = IOServiceOpen(service, mach_task_self(), kIOHIDParamConnectType, &hidSystemParametersConnection);
//            IOObjectRelease(service);
//
//            if (ret == kIOReturnSuccess && hidSystemParametersConnection != IO_OBJECT_NULL)
//                break;
//        }
//
//        IOObjectRelease(matchingServicesIterator);
//
//        CFTypeRef value;
//        ret = IOHIDCopyCFTypeParameter(hidSystemParametersConnection, CFSTR(kIOHIDPointerAccelerationKey), &value);
//        if (ret != kIOReturnSuccess || !value)
//            /* handle failure */;
//
//        if (CFGetTypeID(value) != CFNumberGetTypeID())
//        {
//            CFRelease(value);
//            /* handle wrong type */
//        }
//
//        NSNumber* accel = CFBridgingRelease(value);
//        double newAccel = accel.doubleValue / 2;
//
//        ret = IOHIDSetCFTypeParameter(hidSystemParametersConnection, CFSTR(kIOHIDPointerAccelerationKey), (__bridge CFTypeRef)@(newAccel));
//        if (ret != kIOReturnSuccess)
//            /* handle failure */;
//
//        IOServiceClose(hidSystemParametersConnection);
//
//        // -----------
//
//        IOHIDEventSystemClientRef sysClient = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault);
//                CFArrayRef services = IOHIDEventSystemClientCopyServices(sysClient);
//
//
//                for (CFIndex i = 0; i < CFArrayGetCount(services); i++) {
//                    IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
//                    if(IOHIDServiceClientConformsTo(service, kHIDPage_GenericDesktop, kHIDUsage_GD_Mouse)) {
//        //                prop = IOHIDServiceClientCopyProperty(service, CFSTR("HIDPointerResolution"));
//                        CFNumberRef entryIdCF = IOHIDServiceClientGetRegistryID(service);
//                        int64_t entryId;
//                        CFNumberGetValue(entryIdCF, CFNumberGetType(entryIdCF), &entryId);
//
//
//                        CFMutableDictionaryRef devEntryMatchDict = IORegistryEntryIDMatching(entryId);
//                        io_service_t matchingService = IOServiceGetMatchingService(kIOMasterPortDefault, devEntryMatchDict);
//
//                        io_name_t matchingServiceName;
//                        IORegistryEntryGetName(matchingService, matchingServiceName);
//
//                        io_registry_entry_t child;
//                        IORegistryEntryGetChildEntry(matchingService, kIOServicePlane, &child);
//                        io_name_t childName;
//                        IORegistryEntryGetName(child, childName);
//
//                        kern_return_t writeError = IOConnectSetCFProperty(matchingService, CFSTR(kIOHIDPointerAccelerationKey), (__bridge CFNumberRef)[NSNumber numberWithInt:10]);
//
//        //                (matchingService, CFSTR("HIDPointerResolution"), (__bridge CFNumberRef)[NSNumber numberWithInt:26214400]);
//
//                        DDLogInfo(@"DEV NAME: %s", matchingServiceName);
//                        DDLogInfo(@"WRITE ERR: %d", writeError);
//                        DDLogInfo(@"DEVS: %@", IORegistryEntrySearchCFProperty(matchingService, kIOServicePlane, CFSTR(kIOHIDPointerAccelerationKey), kCFAllocatorDefault, kIORegistryIterateRecursively));
//                    }
//                }
//
//
//
//       // --------------------------------
