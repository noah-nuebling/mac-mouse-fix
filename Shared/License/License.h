//
// --------------------------------------------------------------------------
// Licensing.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Use this only for stuff that's not possible in Swift, like creating enums and structs that are usable from both objc and swift

#ifndef License_h
#define License_h

typedef enum {
    kMFValueFreshnessNone,
    kMFValueFreshnessFresh,
    kMFValueFreshnessCached,
    kMFValueFreshnessFallback,
} MFValueFreshness;

typedef enum {
    kMFLicenseReasonUnknown,
    kMFLicenseReasonNone, /// Unlicensed
    kMFLicenseReasonValidLicense, /// Normally licensed
    kMFLicenseReasonForce, /// Licensed due to `FORCE_LICENSED` compilation flag
    kMFLicenseReasonFreeCountry, /// Licensed since it's used in country like China or Russia where you can't pay for the app
} MFLicenseReason;

typedef struct {
    BOOL isLicensed;
    MFValueFreshness freshness;
    MFLicenseReason licenseReason;
    int daysOfUse;
    int daysOfUseUI;
    int trialDays;
    BOOL trialIsActive;
} MFLicenseAndTrialState;

/// Define custom errors
///     Notes:
///     - Not using enum because Swift is annoying about those
///     - Most of these are thrown in Gumroad.swift, but `kMFLicenseErrorCodeNoInternetAndNoCache` and `kMFLicenseErrorCodeEmailAndKeyNotFound` are thrown in Licensing.swift.
///     - Overall these should cover everything that can go wrong. With the `kMFLicenseErrorCodeGumroadServerResponseError` catching all the weird edge cases like a refunded license.
///     - The `kMFLicenseErrorCodeGumroadServerResponseError` also catches the case when a user just enters a wrong license.
///     - These could be used to inform the user about what's wrong.

#define MFLicenseErrorDomain @"MFLicenseErrorDomain"

//#define kMFLicenseErrorCodeMismatchedEmails 1 /// Not using emails for authentication anymore. Just licenseKeys
#define kMFLicenseErrorCodeInvalidNumberOfActivations 2
#define kMFLicenseErrorCodeGumroadServerResponseError 3
#define kMFLicenseErrorCodeKeyNotFound 4
#define kMFLicenseErrorCodeNoInternetAndNoCache 5

//#define kMFLicenseErrorCodeLicensedDueToForceFlag 6
//#define kMFLicenseErrorCodeLicensedDueToFreeCountry 7

#define MFLicenseConfigErrorDomain @"MFLicenseConfigErrorDomain"
#define kMFLicenseConfigErrorCodeInvalidDict 1


#endif /* License_h */
