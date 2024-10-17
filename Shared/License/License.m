//
// --------------------------------------------------------------------------
// License.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Most Licensing code is in Swift. 
///     Use this file only for stuff that's shitty / not possible in Swift

#import <Foundation/Foundation.h>

#import "License.h"

///
/// MARK: MFDataClass implementations
///
MFDataClassImplementation0(MFDataClassBase, MFLicenseMetadata)
MFDataClassImplementation0(MFLicenseMetadata, MFLicenseMetadataGumroadV0)
MFDataClassImplementation0(MFLicenseMetadata, MFLicenseMetadataGumroadV1)
MFDataClassImplementation0(MFLicenseMetadata, MFLicenseMetadataHyperWorkV1)

MFDataClassImplementation3(MFDataClassBase, MFLicenseState,   (assign, readonly), BOOL,               isLicensed,
                                                              (assign, readonly), MFValueFreshness,   freshness,
                                                              (assign, readonly), MFLicenseReason,    licenseReason)

MFDataClassImplementation4(MFDataClassBase, MFTrialState,     (assign, readonly), NSInteger,  daysOfUse,
                                                              (assign, readonly), NSInteger,  daysOfUseUI,
                                                              (assign, readonly), NSInteger,  trialDays,
                                                              (assign, readonly), BOOL,       trialIsActive)


///
/// MARK: MFDataClass extensions
///

/// Redefine equality

/// Sidenotes:
///     Places where we check equality (as of Oct 2024)
///         1. `AboutTabController.updateUI()`
///             -> We first perform an equality check on `MFLicenseAndTrialState`, and only update the UI, if the state has changed.
///         2. Perhaps other places I forgot about?

@implementation MFLicenseState (CustomEquality)
 
- (NSArray<id> *)propertyValuesForEqualityComparison {

    /// Define equality for MFLicenseState
    /// Reasoning:
    /// - We compare all fields except for the `freshness` field - the idea is that the `freshness` determines the *origin* of the data, but, in some sense, isn't *itself* part of the data.
    ///     Also, practically, on the `AboutTabController`, we always first render the UI based on cached values, then we try to load the real values from the server, and then, unless the server data is mismatched with the cache, we don't want to rerender the UI (This would be problematic since the Thank You message at the bottom of the About Tab would then be set to something else) (As of Oct 2024)

    return @[@(self->_isLicensed), @(self->_licenseReason)]; /// ... @(self.licenseType), @(self.metadata)]
}

@end

@implementation MFTrialState (CustomEquality)

- (NSArray<id> *)propertyValuesForEqualityComparison {

    /// Define equality for the MFTrialState
    /// Notes:
    /// - We compare all fields except for `daysOfUseUI` and `trialIsActive`, because those are directly derived from the other fields

    return @[@(self->_daysOfUse), @(self->_trialDays)];
}

@end
