//
// --------------------------------------------------------------------------
// SecureStorage.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
    Overview:
        This is a wrapper for reading/writing a dictionary in the keychain. [Oct 2026]
        This dictionary is in a keychain item labeled `com.nuebling.mac-mouse-fix.secure-storage`.

    Differences vs config.plist
        Good: The keychain is synced to all the users devices
        Good: Isn't automatically deleted on uninstall by apps like AppCleaner by FreeMacSoft. This makes it a little more annoying to reset the trial period.
        Bad: Special entitlements on the mainApp and Helper is required to let both access the same keychain item.
            Makes it harder to build the app and I think increases compile times [Oct 2026]

    History:
        - Rewrote SecureStorage.swift -> SecureStorage.m as part of trying to solve 'Free days are over' bug. [Oct 2026]

    About `default_secureStorage.plist`: (Old, not sure if stale [Oct 2026])
        In the same folder as this file, there's `default_secureStorage.plist`. At the time of writing, this is unused.
        It's never actually installed like the `default_config.plist` is.
        It just serves a note on the structure of the secureStorage.

    Usage guide or whatever: (Old, not sure if stale [Oct 2026])
        When to use this?
            ... when losing the information could have negative consequences for the user.
                E.g. license key.
                Note: Currently this isn't that important since our maxNumberOfActivations is very high and most people will be able to retrieve the key from their email if they lose it .
            ... when manipulating the information allows you to use the app for free, AND there's no external source of truth like a server (So the value isn't just a cache that gets updated when there's internet)
                E.g. daysOfUse counter during trial period
            ... when the data shouldn't be deleted after uninstalling MMF
                E.g. license key, daysOfUse counter during trial
        When *not* to use this?
            In all other cases, just use config to store data. I assume it's faster and it's more accessible to users for debugging or deleting after uninstall.
        Do we use *NSUserDefaults*?
            - No. config.plist fills the same role.

    Also see:
        Great Apple documentation: https://developer.apple.com/documentation/security/keychain_services/keychain_items?language=objc
        'Free days are over' bug notes

    TODO:
        - Implement cleanup function. See Notes in NSDictionary+Additions.m for details. (Old, not sure if stale [Oct 2026])
*/

#import <Security/SecItem.h>
#import "SecureStorage.h"
#import "Logging.h"
#import "Threads.h"
#import "Constants.h"

#if IS_HELPER
    #define secureStorageRunLoop() IOThread.runLoop
#elif IS_MAIN_APP
    #define secureStorageRunLoop() CFRunLoopGetMain()
#endif

#define baseQuery \
    (id)kSecAttrSynchronizable: @YES, \
    (id)kSecClass: (id)kSecClassGenericPassword, \
    (id)kSecAttrLabel: @"com.nuebling.mac-mouse-fix.secure-storage" /** "MFSecureStorage" */


@implementation NSError (Additions)
    + (instancetype) mf_genericError: (NSString *)debugDescription /// Should make this a general helper, replacing `#define mferror`
        { return [NSError errorWithDomain: MFErrorDomain code: 0 userInfo: @{ /*NSDebugDescriptionErrorKey*/NSLocalizedDescriptionKey: debugDescription }]; }  /// Use `NSLocalizedDescriptionKey` there is identifying information if this ever bubbles up to a user and is printed via -localizedDescription? [Oct 2026]
@end

#define fail() { \
    if (outErr) { \
        if (!err) err = [NSError mf_genericError: @"Cocoa returned nil but set no error"]; /** Extra defensive nil checks probably can't happen because it breaks Cocoa contract, but our `readSecureStorage`/`writeSecureStorage` callers would have no way of knowing that something went wrong without it. (Which is exactly the kind of sporadic issue we're dealing with here. See 'Free days are over' bug notes) [Oct 2026] */\
        *outErr = err; \
    } \
    return nil; \
}
    static id<NSCoding> objectFromKeyedArchive(NSData *data, bool requireSecureCoding, NSError **outErr) {
        /// [Oct 2026] Standard pattern for 'insecure' unarchiving. Maybe make this reusable helper function like `SharedUtilitySwift.insecureUnarchive`. We have `MFDecode` but it is too overengineered. (Really gotta delete all that stuff)

        NSError *err = nil;

        err = nil;
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData: data error: &err];
        if (!unarchiver) fail();
        [unarchiver setRequiresSecureCoding: requireSecureCoding];

        err = nil;
        id result = [unarchiver decodeTopLevelObjectForKey: NSKeyedArchiveRootObjectKey error: &err];
        if (!result) fail()

        return result;
    }
    static NSData *keyedArchiveFromObject(id<NSCoding> object, bool requireSecureCoding, NSError **outErr) {
        NSError *err = nil;
        NSData *result = [NSKeyedArchiver archivedDataWithRootObject: object requiringSecureCoding: requireSecureCoding error: &err];
        if (!result) fail();
        return result;
    }
#undef fail

SecureStorageReadError readSecureStorage(NSString *callerName, NSMutableDictionary **outDict) {
    assertRunLoop(secureStorageRunLoop());

    NSError *nsError = nil;
    NSMutableDictionary *result;
    #define fail(nsError_) { result = nil; nsError = (nsError_); goto end; }

    /// Get the data from the keychain
    NSData *data = nil;
    {
        NSDictionary *query = @{
            baseQuery,
            (id)kSecReturnData: @YES
        };
        CFDataRef dataCF = NULL;
        OSStatus status = SecItemCopyMatching((__bridge void *)query, (void *)&dataCF);
        if (dataCF) data = CFBridgingRelease(dataCF);
        if (status) fail([NSError errorWithDomain: NSOSStatusErrorDomain code: status userInfo: nil]);
    }

    /// Decode the data
    result = (id)objectFromKeyedArchive(data, /*requireSecureCoding*/false, &nsError);
    if (!result) fail(nsError);

    /// Validate that we got a dict
    ///     Note from old Swift implementation: "For some reason I saw the item be a string at some point, causing a crash, so we guard against that here." (No clue why this might happen, I was probably mistaken? [Oct 2026])
    if (!isclass(result, NSDictionary)) fail([NSError mf_genericError: @"SecItemCopyMatching returned an object that wasn't a dictionary"]);

    /// Ensure the dict is mutable.
    ///     (Only works shallowly! Should've used NSPropertyListSerialization but not worth migrating now [Oct 2026])
    if (!isclass(result, NSMutableDictionary)) result = [result mutableCopy];

    /// Exit funnel
    end:;

    SecureStorageReadError err = kSecureStorageReadError_ReadSuccessful;
    if (!result) {
        if (nsError.domain == NSOSStatusErrorDomain && nsError.code == errSecItemNotFound) err = kSecureStorageReadError_DoesntExistYet;
        else                                                                               err = kSecureStorageReadError_UnexpectedError;
    }

    if (outDict) {
        if      (err == kSecureStorageReadError_ReadSuccessful)  *outDict = result;
        else if (err == kSecureStorageReadError_DoesntExistYet)  *outDict = [NSMutableDictionary new];
        else if (err == kSecureStorageReadError_UnexpectedError) *outDict = nil;
    }

    /// Debug logging
    if (result) DDLogDebug("%{public}@ > readSecureStorage succeeded: %{public}@", callerName, result);
    else        DDLogError("%{public}@ > readSecureStorage failed with error: %{public}@", callerName, nsError); /// {public} 'leaking' the users license key possibly - shouldn't matter, see Logging.h [Oct 2026]

    return err;
    #undef fail
}

static OSStatus _callSecItemUpdate(NSData *data) {
    NSDictionary *query = @{ baseQuery };
    NSDictionary *updates = @{ (id)kSecValueData: data };
    return SecItemUpdate((__bridge void *)query, (__bridge void *)updates);
}
static OSStatus _callSecItemAdd(NSData *data) {
    NSDictionary *attributes = @{ baseQuery,
                                  (id)kSecValueData: data };
    return SecItemAdd((__bridge void *)attributes, /*result*/NULL); /** Note: The docs say not to use SecItemAdd() from mainThread since it blocks the calling thread, but it seems fine so far. */
}

bool writeSecureStorage(NSString *callerName, NSMutableDictionary *dict, SecureStorageReadError readError) { /// Returns success
    assertRunLoop(secureStorageRunLoop());

    bool success = 1;
    NSError *nsErr = nil;
    #define fail(nsErr_) { success = 0; nsErr = (nsErr_); goto end; }

    /// Encode the dict
    NSData *data = keyedArchiveFromObject(dict, /*requireSecureCoding*/false, &nsErr);
    if (!data) fail(nsErr);

    /// Write to the keychain
    OSStatus status = 0;
    if (readError == kSecureStorageReadError_ReadSuccessful) { /// No read error -> update the item normally using `SecItemUpdate`
        status = _callSecItemUpdate(data);
        if (status == errSecItemNotFound)                      ///      Still fall back to `SecItemAdd` to let the user force a write regardless of error. Could also maybe avoid some sporadic issues. Should be safe [Oct 2026]
            status = _callSecItemAdd(data);
    } else if (readError == kSecureStorageReadError_DoesntExistYet) { /// Read failed with `errSecItemNotFound` -> use `SecItemAdd`. If the read failed spuriously, this will fail with `errSecDuplicateItem`, preventing accidental overrides.
        status = _callSecItemAdd(data);
    } else {
        mfrequire(false, @"Called writeSecureStorage with invalid readError. (If readSecureStorage fails with any error other than `errSecItemNotFound`, the caller should treat SecureStorage as temporarily unavailable or whatever and pass `kSecureStorageReadError_ForceWrite` to force a write. [Oct 2026])");
    }
    if (status) fail([NSError errorWithDomain: NSOSStatusErrorDomain code: status userInfo: nil]);

    /// Exit funnel
    end:

    /// Debug logging
    if (success) DDLogDebug("%{public}@ > writeSecureStorage succeeded: %{public}@", callerName, dict);
    else         DDLogError("%{public}@ > writeSecureStorage failed: %{public}@ (error: %{public}@)", callerName, dict, nsErr);

    return success;
    #undef fail
}
