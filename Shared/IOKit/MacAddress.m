//
// --------------------------------------------------------------------------
// MacAddress.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// This file retrieves the MAC (Media Access Control) address for the current device
///     This can be used to **uniquely identify the hardware** we're running on
///
///     This code is copied from these Apple docs:
///         https://developer.apple.com/documentation/appstorereceipts/validating_receipts_on_the_device#//apple_ref/doc/uid/TP40010573-CH1-SW14
///
///     The Apple docs suggest that getting the MAC address in this fashion is the proper way to get a unique device id on macOS, whereas on iOS the proper way is using`UIDevice.currentDevice.identifierForVendor`.
///
/// PRIVACY:
///     Apple has anonymized Device IDs on iOS using `UIDevice.currentDevice.identifierForVendor`. Unfortunately this isn't available on macOS.
///     A macAddress is a *globally unique hardware identifier* – do not store or send without thinking thoroughly about the privacy implications.
///     Currently (Nov 2024) we only use the macAddress as an input to an SHA-256 hash for our offline license validation (so it's not sent and cannot be retrieved from any data we store, because SHA-256 hashes are irreversible)

#import "MacAddress.h"
#import <IOKit/network/IONetworkLib.h>
#import "WannabePrefixHeader.h" /// To import CocoaLumberJack
#import "SharedUtility.h"

@interface MacAddress : NSObject @end

@implementation MacAddress

uint64 mac_address_to_int(NSData *_Nullable mac_address_data) {
    
    if (mac_address_data == nil) return 0;
    
    NSUInteger len = [mac_address_data length];
    
    if (len != 6 && len != 8) {
        DDLogError(@"mac address has unexpected byte count: %lu (Mac addresses normally have 6 bytes, sometimes 8. Anything over 8 won't fit into int64 and will be truncated in our return value.)", (unsigned long)len);
    }
    
    uint64 result = 0;
    [mac_address_data getBytes:&result length:MIN(len, 8)];
    
    return result;
}

NSString *_Nullable mac_address_to_string(NSData *_Nullable mac_address_data) {

    if (mac_address_data == nil) return nil;

    NSUInteger len = [mac_address_data length];
    
    NSString *result;
    if (len == 6) {
        char buf[6];
        [mac_address_data getBytes:&buf length:6];
        result = stringf(@"%02hhx:%02hhx:%02hhx:%02hhx:%02hhx:%02hhx", buf[0], buf[1], buf[2], buf[3], buf[4], buf[5]);
    } else if (len == 8) {
        char buf[8];
        [mac_address_data getBytes:&buf length:8];
        result = stringf(@"%02hhx:%02hhx:%02hhx:%02hhx:%02hhx:%02hhx:%02hhx:%02hhx", buf[0], buf[1], buf[2], buf[3], buf[4], buf[5], buf[6], buf[7]);
    } else {
        DDLogError(@"Failed to convert mac address to string. It has neither 6 nor 8 bytes. Has %lu bytes", len);
        result = nil;
    }
    
    return result;
}

NSData *_Nullable get_mac_address(void) {

    /// Apple comments:     (This code is originally copied from Apple's documentation - see the discussion at the top of the file)
    ///     Prefer built-in network interfaces.
    ///     For example, an external Ethernet adaptor can displace
    ///     the built-in Wi-Fi as en0.

    /// Copy service
    io_service_t service = copy_io_service("en0", true) ?:
                           copy_io_service("en1", true) ?:
                           copy_io_service("en0", false);
    MFDefer ^{ if (service) IOObjectRelease(service); };
    if (!service) {
        return nil;
    }
    
    /// Get macAddress
    CFTypeRef macAddress = IORegistryEntrySearchCFProperty(service,
                                                           kIOServicePlane,
                                                           CFSTR(kIOMACAddress),
                                                           kCFAllocatorDefault,
                                                           kIORegistryIterateRecursively | kIORegistryIterateParents);
    MFDefer ^{ if (macAddress) CFRelease(macAddress); };
    if (!macAddress || CFGetTypeID(macAddress) != CFDataGetTypeID()) {
        return nil;
    }
    
    /// Cast
    NSData *result = (__bridge NSData *)macAddress;
    
    /// Make sure result is not empty
    ///     (Not sure if necessary)
    if (result && result.length == 0) result = nil;
    
    /// Return
    return result;
}

io_service_t copy_io_service(const char *name, BOOL wantBuiltIn) {
    
    /// Helper function
    ///     Returns an IOService with the name `name` and with a `kIOBuiltin` property that must match `wantBuiltIn`.
    ///     The caller must release the return value (unless it's 0 aka `IO_OBJECT_NULL`)
    
    /// Performance:
    ///     [Feb 2025] Instruments says `get_mac_address()` is relatively slow and takes 100% of the time in our `GetLicenseState.get()` calls (If I understand correctly). IOServiceGetMatchingServices() takes 100% inside `get_mac_address()`. But it's only called once on my M1 MBA (finds a builtin en0 – the first thing we check for) so not sure how to optimize, except by caching.
    
    /// Get default port
    ///     `kIOMasterPortDefault` is a constant that tells functions to get the default master port themselves.
    ///      We could get the real default master port ourselves by using `IOMasterPort(MACH_PORT_NULL, &default_port)`. That might be more efficient.
    mach_port_t default_port = kIOMasterPortDefault;

    /// Create matching dict
    CFMutableDictionaryRef matchingDict = IOBSDNameMatching(default_port, 0, name);
    if (!matchingDict) {
        return IO_OBJECT_NULL;
    }
    
    /// Get iterator
    ///     This consumes a ref on the matchingDict so no need to free it.
    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t rt = IOServiceGetMatchingServices(default_port, matchingDict, &iterator);
    MFDefer ^{ if (iterator) IOObjectRelease(iterator); };
    if (!iterator || rt != KERN_SUCCESS) {
        return IO_OBJECT_NULL;
    }
        
    /// Iterate
    io_service_t result = IO_OBJECT_NULL;
    while (1) {
    
        /// Get candidate
        io_service_t candidate = IOIteratorNext(iterator);
        MFDefer ^{ if (candidate) IOObjectRelease(candidate); };
    
        /// Break
        if (!candidate) {
            break;
        }
        
        /// Retrieve isBuiltIn
        ///     The Apple code that this is based on seemingly forgot to release this!
        ///     Update: I think `CFBoolean`s are singleton instances that never get dealloced anyways, so it's ok not to free this result (if you're sure it always returns a `CFBoolean`). That's probably why Apple did it this way.
        CFTypeRef isBuiltInCF = IORegistryEntryCreateCFProperty(candidate, CFSTR(kIOBuiltin), kCFAllocatorDefault, 0);
        MFDefer ^{ if (isBuiltInCF) CFRelease(isBuiltInCF); };
        
        /// Check isBuiltin
        if (isBuiltInCF &&
            CFGetTypeID(isBuiltInCF) == CFBooleanGetTypeID() &&
            CFBooleanGetValue(isBuiltInCF) == wantBuiltIn)      /// Random sidenote: If wantBuiltInt wasn't a variable we could just use `CFEqual()`
        {
            IOObjectRetain(candidate); /// Due to this, the retainCount of the result should come out to 1 after the function returns.
            result = candidate;
            break;
        }
    }

    /// Return
    return result;
}

@end
