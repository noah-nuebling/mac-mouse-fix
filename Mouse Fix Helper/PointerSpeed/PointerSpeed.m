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

@implementation PointerSpeed

+ (void)setAccelerationTo:(double)acc {
//    IOHIDSetCFTypeParameter(myNXOpenEventStatus(), CFSTR("HIDMouseAcceleration"), (__bridge CFNumberRef)[NSNumber numberWithDouble:acc]); //not sure if this works
//    IOHIDSetPointerAccelerationWithKey(myNXOpenEventStatus(), CFSTR("HIDMouseAcceleration"), acc);hardened
}


# pragma mark helper functions

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
