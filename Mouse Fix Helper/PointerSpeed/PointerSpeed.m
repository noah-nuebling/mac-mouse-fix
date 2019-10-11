//
// --------------------------------------------------------------------------
// PointerSpeed.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "PointerSpeed.h"
#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDTypes.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/hid/IOHIDProperties.h>


@implementation PointerSpeed

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);

static mach_port_t _IOHIDSystemHandle;
+ (void)load {
    _IOHIDSystemHandle = myNXOpenEventStatus();
}


#pragma mark Sensitivity

+ (void)setSensitivityTo:(int)sens device:(IOHIDDeviceRef)dev {

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
    
    NSLog(@"NAMEEE: %@", IORegistryEntryCopyPath(devService, "IOService"));
    
    
    // Getting service clients from Event system client
    
    IOHIDEventSystemClientRef eventSystemClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault); // using this self-defined function (extern) instead of ...CreateSimpleClient - maybe you can do "privilege escalation" here.
    CFArrayRef services = IOHIDEventSystemClientCopyServices(eventSystemClient);
    
    NSLog(@"services: %@", services);
    
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
            

            
            
            
            
            // trying to set / read from the registry entry (it's obtained through the Service Client stuff above, but it's right one - it contains HIDPointerResolution, and you can read it, but until now not write it)
            // None of these 3 methods seemed to have any effect. BUT I also forgot to turn steermouse off, so more testing is needed.

            
            
            
            int sens = 425; // 400 is default
            int newPointerRes = IntToFixed(sens);
            CFNumberRef newPointerRefCF = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &newPointerRes);
            kern_return_t kr = IORegistryEntrySetCFProperty(matchingService, CFSTR("HIDPointerResolution"), newPointerRefCF); // doesn't work
            
            // --
              
            io_connect_t drvHandle;
            IOServiceOpen(matchingService, mach_task_self(), kIOHIDParamConnectType, &drvHandle);
            IOConnectSetCFProperty(drvHandle, CFSTR("HIDPointerResolution"), newPointerRefCF); // doesn't work either
              
            // --
            
            IOHIDServiceClientSetProperty(service, CFSTR("HIDPointerResolution"), newPointerRefCF); // doesn't work - its the cursor sense does it though...
            
            // --
            
            
            CFTypeRef pointerResCF = IORegistryEntryCreateCFProperty(matchingService, CFSTR("HIDPointerResolution"), kCFAllocatorDefault, 0);
            int pointerRes;
            CFNumberGetValue(pointerResCF, kCFNumberSInt32Type, &pointerRes);
            
            NSLog(@"prt res: %d", FixedToInt(pointerRes));
            
            
            

            
            
            
        }
    }
    

                
                
//                CFTypeRef prop = IOHIDServiceClientCopyProperty((IOHIDServiceClientRef)service, CFSTR("HIDPointerResolution"));
//                int ptrRes;
//                NSLog(@"type: %@", CFNumberGetType(prop));
//
//                CFNumberGetValue(prop, kCFNumberSInt32Type, &ptrRes);
//
//                NSLog(@"RES: %d", ptrRes);
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
//                NSLog(@"DEV NAME: %s", matchingServiceName);
////                NSLog(@"WRITE ERR: %d", writeError);
//                NSLog(@"DEVS: %@", IORegistryEntrySearchCFProperty(matchingService, kIOServicePlane, CFSTR(kIOHIDPointerAccelerationKey), kCFAllocatorDefault, kIORegistryIterateRecursively));
//            }
//        }
    
}

#pragma mark Acceleration

/// Sets the mouse pointer acceleration to a certain value.
/// Changes the same value that the "Tracking Speed" option in System Preferences > Mouse or the "defaults write .GlobalPreferences com.apple.mouse.scaling x" command changes.
/// @param acc The value to set the acceleration to. Shouldn't be much higher than 4.0 or 5.0. Negative values turn off acceleration and also seem to affect base pointer sensitivity.
+ (void)setAccelerationTo:(double)acc {
    
    
    NSLog(@"Current Pointer Acceleration: %f", [self getActualAcceleration]);
    
    IOHIDSetCFTypeParameter(_IOHIDSystemHandle, CFSTR("HIDMouseAcceleration"), (__bridge CFNumberRef)[NSNumber numberWithDouble: FloatToFixed(acc)]);
    // reading values
    
    NSLog(@"Current Pointer Acceleration: %f", [self getActualAcceleration]);
    
}

/// Gets the actual current Mouse Acceleration value.
/// (As opposed to the one obtained by "defaults read .GlobalPreferences com.apple.mouse.scaling".)
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
//                        NSLog(@"DEV NAME: %s", matchingServiceName);
//                        NSLog(@"WRITE ERR: %d", writeError);
//                        NSLog(@"DEVS: %@", IORegistryEntrySearchCFProperty(matchingService, kIOServicePlane, CFSTR(kIOHIDPointerAccelerationKey), kCFAllocatorDefault, kIORegistryIterateRecursively));
//                    }
//                }
//
//
//
//       // --------------------------------
