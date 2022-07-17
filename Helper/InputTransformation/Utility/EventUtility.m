//
// --------------------------------------------------------------------------
// EventUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "WannabePrefixHeader.h"

#import "EventUtility.h"
#import "MFIOKitImports.h"
#import "IOUtility.h"
#import "SharedUtility.h"

@implementation EventUtility

extern CFTimeInterval CATimeWithHostTime(UInt64 mach_absolute_time);

NSMutableDictionary *_hidDeviceCache = nil;

IOHIDDeviceRef _Nullable HIDEventGetSendingDevice(HIDEvent *hidEvent) {
    /// This version uses a cache to avoid calling IOHIDDeviceCreate() (which is super slow) over and over.
    ///     \note Do we need to reset the cache at certain points?
    ///     \note Now that we use the cache we should be able to use the version that iterates over all parents instead of only checking the second parent, without it being too slow.
    
    
    assert(hidEvent != NULL);
    if (hidEvent == NULL) return NULL;
    
    uint64_t senderID;
    
    if ([hidEvent respondsToSelector:@selector(senderID)]) {
        senderID = hidEvent.senderID;
    } else {
        senderID = IOHIDEventGetSenderID((__bridge IOHIDEventRef)hidEvent);
    }
    /// ^ Sometimes `- senderID` gives an unrecognized selector error. Only when I'm not starting the app via the debugger though. Weird. IOHIDEventGetSenderID() works in those cases. Even though `- senderID` just calls it. Really weird.
    
    if (_hidDeviceCache == nil) {
        _hidDeviceCache = [NSMutableDictionary dictionary];
    }
    
    id iohidDeviceFromCache = _hidDeviceCache[@(senderID)];
    
    if (iohidDeviceFromCache != nil) {
        
//        CFIndex retainCount = CFGetRetainCount((__bridge CFTypeRef)(iohidDeviceFromCache));
//        DDLogDebug(@"cache retainCount: %ld", (long)retainCount);
        
        return (__bridge IOHIDDeviceRef)iohidDeviceFromCache;
    }
    
    IOHIDDeviceRef iohidDevice = HIDEventCopySendingReliable(hidEvent);
    assert(iohidDevice != NULL);
    
    if (iohidDevice != NULL) {
//        CFRetain(iohidDevice);
        _hidDeviceCache[@(senderID)] = (__bridge_transfer id _Nullable)(iohidDevice);
    }
    
    return iohidDevice;
    
}

IOHIDDeviceRef HIDEventCopySendingDeviceFaster(HIDEvent *hidEvent) {
    /// This gets the second parent of the registryEntry that sent the hidEvent. If that doesn't work, it returns NULL.
    /// This is still super slow because IOHIDDeviceCreate() is super slow
    
    /// Get IOService
    uint64_t senderID = hidEvent.senderID;
    
    CFMutableDictionaryRef idMatching = IORegistryEntryIDMatching(senderID);
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, idMatching);
    
    io_service_t parent1;
    io_service_t parent2;
    IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent1);
    IORegistryEntryGetParentEntry(parent1, kIOServicePlane, &parent2);
    
    IOHIDDeviceRef iohidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, parent2);
    
    IOObjectRelease(parent1);
    IOObjectRelease(parent2);
    
    return iohidDevice;
}

IOHIDDeviceRef HIDEventCopySendingReliable(HIDEvent *hidEvent) {
    /// This iterates all parents of the service which send the hidEvent until it finds one that it can convert to and IOHIDDevice.
    /// Calling IOHIDDeviceCreate() on all these non-hid device is super slow unfortunately.
    
    /// Get IOService
    uint64_t senderID = hidEvent.senderID;
    CFMutableDictionaryRef idMatching = IORegistryEntryIDMatching(senderID);
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, idMatching);
    
    /// Get IOHIDDevice
    __block IOHIDDeviceRef iohidDevice;
    [IOUtility iterateParentsOfEntry:service forEach:^Boolean(io_registry_entry_t parent) {
        iohidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, parent);
        return (iohidDevice == NULL); /// Keep going while device not found
    }];
    
    return iohidDevice;
}

/// Other helper functions

CFTimeInterval CGEventGetTimestampInSeconds(CGEventRef event) {
    /// Gets timestamp in seconds from CGEvent. More accurate and less volatile than calling CACurrentMediaTime() in the eventTapCallback.
    ///     I've found that this doesn't work for mouseMoved events in PollingRateMeasurer. Those timestamps are already in nanosecs. No idea why.
    
    /// Stuff below doesn't work properly ;?
    
    /// Get raw mach timestamp
    CGEventTimestamp tsMach = CGEventGetTimestamp(event);
    
    /// Get the timebase info
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    
    /// Convert to nanoseconds
    double tsNano = tsMach;
    tsNano *= info.numer;
    tsNano /= info.denom;
    
    /// Convert to seconds
    CFTimeInterval tsSeconds = tsNano / NSEC_PER_SEC;
    
    return tsSeconds;
    
    if ((/* DISABLES CODE */ (NO))) {
        
        CFTimeInterval tickTimeCG = (100/2.4)*tsMach/NSEC_PER_SEC;
        /// ^ The docs say that CGEventGetTimestamp() is in nanoseconds, no idea where the extra (100/2.4) factor comes from. But it works, to make it scaled the same as CACurrentMediaTime()
        ///     I hope this also works on other macOS versions?
        /// Edit: We should to use mach_timebase_info() to convert insteads of 100/2.4
        
        /// Debug
        
        CFTimeInterval tickTime = CACurrentMediaTime();
        /// ^ This works but is less accurate than getting the time from the CGEvent
        
        static CFTimeInterval lastTickTime = 0;
        static CFTimeInterval lastTickTimeCG = 0;
        double tickPeriod = 0;
        double tickPeriodCG = 0;
        if (lastTickTime != 0) {
            tickPeriod = tickTime - lastTickTime;
            tickPeriodCG = tickTimeCG - lastTickTimeCG;
        }
        lastTickTime = tickTime;
        lastTickTimeCG = tickTimeCG;
        static double pSum = 0;
        static double pSumCG = 0;
        pSum += tickPeriod;
        pSumCG += tickPeriodCG;
        DDLogDebug(@"tickPeriod: %.3f, CG: %.3f", tickPeriod*1000, tickPeriodCG*1000);
        DDLogDebug(@"ticksPerSec: %.3f, CG: %.3f", 1/tickPeriod, 1/tickPeriodCG);
        DDLogDebug(@"tickPeriodSum: %.0f, CG: %.0f, ratio: %.5f", pSum, pSumCG, pSumCG/pSum);
    }
}

@end
