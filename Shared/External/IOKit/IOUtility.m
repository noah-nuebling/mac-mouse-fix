//
// --------------------------------------------------------------------------
// IOUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "IOUtility.h"

@implementation IOUtility

+ (void)iterateParentsOfEntry:(io_registry_entry_t)entry forEach:(Boolean (^)(io_registry_entry_t))workload {
    /// This function calls `workload` with self and every parent, including parents of parents.
    /// The `workload` block can return false to stop iteration, (e.g. when it's found what it's searching for) otherwise it should return true.
    /// Otherwise the function will keep iterating until there are no more parents.
    /// IORegistryEntryGetParentIterator() only iterates over all immediate parents. Not parents of parents.
    /// TODO: This would be nicer to use if you had an arg `bool *continue` for the `forEach` block, instead of the return value.
    
    Boolean keepGoing = workload(entry);
    if (!keepGoing) return;
    
    IOObjectRetain(entry); /// Because we'll call IOObjectRelease() on it
    
    NSMutableSet *thisLvl = [NSMutableSet setWithObject:@(entry)];
    NSMutableSet *nextLvl = [NSMutableSet set];;
    
    while (true) {
     
        /// Iterate thisLvl and fill nextLvl
        
        for (NSNumber *entryNS in thisLvl) {
            
            io_registry_entry_t entry = entryNS.unsignedIntValue;
            
            /// Iterate all immediate parents of entry
            
            io_iterator_t parent_iterator = 0;
            IORegistryEntryGetParentIterator(entry, kIOServicePlane, &parent_iterator);
            
            while (true) {
                
                io_registry_entry_t parent = IOIteratorNext(parent_iterator);
                if (parent == 0) break;
                
                [nextLvl addObject:@(parent)]; /// Add before calling workload() so that parent is cleaned up
                
                Boolean keep_going = workload(parent);
                if (!keep_going)
                    goto clean_up;
            }
            
            IOObjectRelease(parent_iterator);
        }
        
        if (nextLvl.count == 0)
            goto clean_up;
        
        /// Clean up thisLvl before moving on to nextLevel
        for (NSNumber *entryNS in thisLvl) {
            io_registry_entry_t entry = entryNS.unsignedIntValue;
            IOObjectRelease(entry);
        }
        
        thisLvl = nextLvl;
        nextLvl = [NSMutableSet set];
    }
    
clean_up:
    
    /// thisLvl
    for (NSNumber *entryNS in thisLvl) {
        io_registry_entry_t entry = entryNS.unsignedIntValue;
        IOObjectRelease(entry);
    }
    /// nextLvl
    for (NSNumber *entryNS in nextLvl) {
        io_registry_entry_t entry = entryNS.unsignedIntValue;
        IOObjectRelease(entry);
    }
}

+ (io_registry_entry_t)createChildOfRegistryEntry:(io_registry_entry_t)entry withName:(NSString *)name {
    ///
    /// TODO: Don't use IORegistryEntryGetPath(). Use kIORegistryEntryIDKey or IORegistryEntryCopyPath().
    ///
    /// Caller is responsible for releasing the returned registryEntry
    /// I feel like maybe I could call CFAutorelease or sth on the result before returning it to make it easier for the caller but not too sure how that works.
    ///     Edit: need to call IOObjectRelease on the result and that doesn't have an autorelease variant.
    
    
    io_iterator_t iterator;
    IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator);
    
    io_registry_entry_t childEntry;
    Boolean childEntryFound = false;
    while ((childEntry = IOIteratorNext(iterator))) {
        char childEntryName[1000]; /// Buffer size 1000 is untested
        IORegistryEntryGetNameInPlane(childEntry, kIOServicePlane, childEntryName);
        if ([@(childEntryName) isEqual:name]) {
            childEntryFound = true;
            break;
        }
        IOObjectRelease(childEntry);
    }
    IOObjectRelease(iterator);
    
    assert(childEntryFound);
    
    return childEntry;
}

+ (void)afterDelay:(double)delay runBlock:(void(^)(void))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*delay), dispatch_get_main_queue(), block);
}

+ (NSString *)registryPathForServiceClient:(IOHIDServiceClientRef)service {
    /// TODO: Don't use IORegistryEntryGetPath(). Use kIORegistryEntryIDKey or IORegistryEntryCopyPath().
    
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
