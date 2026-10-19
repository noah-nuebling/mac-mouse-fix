//
// --------------------------------------------------------------------------
// SecureStorage.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#pragma once

#import <Foundation/Foundation.h>

/// Track errors in the keychain-read to avoid ever locking people out of the app in case of sporadic errors (See 'Free days are over' bug notes)
typedef enum {
    /// SecureStorage was read successfully, and returned in `outDict`
    kSecureStorageReadError_ReadSuccessful = 0,

    /// The keychain API indicates that the SecureStorage doesn't exist, yet (`errSecItemNotFound`). This is the normal case for fresh users. (But we're not totallyyy sure this doesn't also occur transiently (See 'Free days are over' bug notes) [Oct 2026]).
    ///     `outDict` has been set to an empty dictionary which you can fill and pass to `writeSecureStorage` along with this error code to create the keychainItem.
    kSecureStorageReadError_DoesntExistYet = 1,

    /// Some strange error occured with the keychain API. We think these errors might occur transiently for some people. Use some lenient fallback mechanism. ('lenient' meaning it lets people use the app, and doesn't lock them out) (See 'Free days are over' bug notes) [Oct 2026]
    ///     `outDict` has been set to nil. `writeSecureStorage` crashes if you pass it this error code. Override it with `kSecureStorageReadError_ForceWrite` if needed [Oct 2026]
    kSecureStorageReadError_UnexpectedError = 2,

    /// See `kSecureStorageReadError_UnexpectedError` [Oct 2026]
    kSecureStorageReadError_ForceWrite = kSecureStorageReadError_ReadSuccessful,
} SecureStorageReadError;

SecureStorageReadError readSecureStorage(NSString *callerName, NSMutableDictionary **outDict);
bool writeSecureStorage(NSString *callerName, NSMutableDictionary *dict, SecureStorageReadError readError);
