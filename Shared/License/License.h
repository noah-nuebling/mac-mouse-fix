//
// --------------------------------------------------------------------------
// Licensing.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// Use this only for stuff that's not possible in Swift, like creating enums and structs that are usable from both objc and swift

#ifndef Licensing_h
#define Licensing_h

typedef enum {
    kMFValueFreshnessNone,
    kMFValueFreshnessFresh,
    kMFValueFreshnessCached,
    kMFValueFreshnessFallback,
} MFValueFreshness;

typedef enum {
    kMFLicensingStateLicensed = 0,
    kMFLicensingStateUnlicensed = 1,
    kMFLicensingStateCachedLicensed = 2,
    kMFLicensingStateCachedUnlicended = 3,
} MFLicensingState;

typedef struct {
    MFLicensingState state;
    int daysOfUse;
    int trialDays;
} MFLicensingReturn;

/// Define custom errors
///     Notes:
///     - Not using enum because Swift is annoying about those
///     - Most of these are thrown in Gumroad.swift, but `kMFLicensingErrorCodeNoInternetAndNoCache` and `kMFLicensingErrorCodeEmailAndKeyNotFound` are thrown in Licensing.swift.
///     - Overall these should cover everything that can go wrong. With the `kMFLicensingErrorCodeGumroadServerResponseError` catching all the weird edge cases like a refunded license.
///     - The `kMFLicensingErrorCodeGumroadServerResponseError` also catches the case when a user just enters a wrong license.
///     - These could be used to inform the user about what's wrong.

#define MFLicensingErrorDomain @"MFLicensingErrorDomain"

#define kMFLicensingErrorCodeMismatchedEmails 1
#define kMFLicensingErrorCodeInvalidNumberOfActivations 2
#define kMFLicensingErrorCodeGumroadServerResponseError 3
#define kMFLicensingErrorCodeEmailOrKeyNotFound 4
#define kMFLicensingErrorCodeNoInternetAndNoCache 5

#define MFLicenseConfigErrorDomain @"MFLicenseConfigErrorDomain"
#define kMFLicenseConfigErrorCodeInvalidDict 1


#endif /* Licensing_h */
