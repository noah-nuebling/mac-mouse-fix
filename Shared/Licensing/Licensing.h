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

/// Define MFLicenseState
///     We couldn't defined this as an enum, because Swift doesn't let you return enum values from throwing objc funcs. No idea why.
///     Edit: Using a completion handler and just using bools instead. Delete this.

//typedef NSString * MFLicenseState;
//#define kMFLicenseStateValid @"licenseIsValid"
//#define kMFLicenseStateInvalid @"licenseIsInvalid"
//#define kMFLicenseStateUnknown @"licenseCouldNotBeChecked" /// Throw error instead

/// Define cutsom errors
///     Edit: Unused. Delete

typedef enum {
    kMFLicensingErrorCodeUnknown,
} MFLicensingErrorCode;

#endif /* Licensing_h */
