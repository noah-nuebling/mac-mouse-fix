//
// --------------------------------------------------------------------------
// IOUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "IOUtility.h"

@implementation IOUtility

+ (io_registry_entry_t)getChildOfRegistryEntry:(io_registry_entry_t)entry withName:(NSString *)name {
    
    io_iterator_t hostServiceChildIterator;
    IORegistryEntryGetChildIterator(entry, kIOServicePlane, &hostServiceChildIterator);
    
    io_registry_entry_t childEntry;
    while ((childEntry = IOIteratorNext(hostServiceChildIterator))) {
        char childEntryName[1000]; /// Buffer size 100 is untested
        IORegistryEntryGetNameInPlane(childEntry, kIOServicePlane, childEntryName);
        if ([@(childEntryName) isEqual:name]) {
            break;
        }
    }
    
    assert(childEntry != -1);
    return childEntry;
}

+ (void)afterDelay:(double)delay runBlock:(void(^)(void))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*delay), dispatch_get_main_queue(), block);
}

+ (NSString *)registryPathForServiceClient:(IOHIDServiceClientRef)service {
    CFTypeRef entryIDCF = IOHIDServiceClientGetRegistryID(service);
    uint64_t entryID = ((__bridge NSNumber *)entryIDCF).unsignedLongLongValue;
    CFMutableDictionaryRef idMatching = IORegistryEntryIDMatching(entryID);
    io_service_t serviceClientService = IOServiceGetMatchingService(kIOMasterPortDefault, idMatching);
    
    char serviceClientServicePath[1000];
    IORegistryEntryGetPath(serviceClientService, kIOServicePlane, serviceClientServicePath);
    
    return @(serviceClientServicePath);
}

@end
