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

+ (io_registry_entry_t)createChildOfRegistryEntry:(io_registry_entry_t)entry withName:(NSString *)name {
    /// Caller is responsible for releasing the returned registryEntry
    /// I feel like maybe I could call CFAutorelease or sth on the result before returning it to make it easier for the caller but not too sure how that works.
    ///     Edit: need to call IOObjectRelease on the result and that doesn't have an autorelease variant.
    
    io_iterator_t iterator;
    IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator);
    
    io_registry_entry_t childEntry;
    Boolean found = false;
    while ((childEntry = IOIteratorNext(iterator))) {
        char childEntryName[1000]; /// Buffer size 1000 is untested
        IORegistryEntryGetNameInPlane(childEntry, kIOServicePlane, childEntryName);
        if ([@(childEntryName) isEqual:name]) {
            found = true;
            break;
        }
        IOObjectRelease(childEntry);
    }
    IOObjectRelease(iterator);
    
    assert(found);
    
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
    
    NSString *result = @(serviceClientServicePath);
    
    /// Release stuff
    /// Not sure if necessary because none of these were created by a function with `create` or `copy` in its name (see CreateRule)
    
    CFRelease(entryIDCF);
    CFRelease(idMatching);
    IOObjectRelease(serviceClientService);
    
    /// Return
    
    return result;
}

@end
