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

@implementation EventUtility

IOHIDDeviceRef HIDEventCopySendingDevice(HIDEvent *hidEvent) {
    
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
    /// Gets timestamp in seconds from CGEvent
    
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
