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

/// licenseTypeInfo dataclasses

MFDataClassImplement0(MFDataClassBase, MFLicenseTypeInfo)
    
    MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoNotLicensed)
    
    /// Special conditions
    MFDataClassImplement1(MFLicenseTypeInfo, MFLicenseTypeInfoFreeCountry,               /// Licensed since it's used in country like China or Russia where you can't pay for the app
                          readonly, strong, nonnull, NSString *, regionCode)
    MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoForce)                     /// Licensed due to `FORCE_LICENSED` compilation flag
    
    /// Standard licenses
    MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadV0)                /// Old Euro-based licenses that were sold on Gumroad during the MMF 3 Beta.
    MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadV1)                /// Standard USD-based Gumroad licenses that were sold on Gumroad after MMF 3 Beta 6 (IIRC).
    MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoPaddleV1)                 /// Standard MMF 3 licenses that we plan to sell on Paddle, verified through our AWS API. (This is the plan as of Oct 2024)
    
    /// Special licenses
    MFDataClassImplement1(MFLicenseTypeInfo, MFLicenseTypeInfoHyperWorkV1,              /// Licenses issued by HyperWork mouse company and verified through our AWS API.
                          readonly, strong, nonnull, NSString *, deviceSerialNumber)
    MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadBusinessV1)        /// Perhaps we could introduce a license type for businesses. You could buy multiple/multiseat licenses, and perhaps it would be more expensive / subscription based?. (Sidenote: This licenseType includes `V1`, but not sure that makes sense. The only practical application for 'versioning' the licenseTypes like that I can think of is for paid upgrades, but that doesn't make sense for a subscription-based license I think, but I guess versioning doesn't hurt)

    /// V2 licenses:
    ///     Explanation:
    ///     If we ever want to introduce a paid update we could add new V2 licenses
    ///     and then make the old V1 licenses incompatible with the newest version of Mac Mouse Fix.
    MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadV2)
    MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoPaddleV2)

/// Top-level dataclasses

MFDataClassImplement3(MFDataClassBase, MFLicenseState,   readonly, assign,        , BOOL,                          isLicensed,
                                                         readonly, assign,        , MFValueFreshness,              freshness,
                                                         readonly, strong, nonnull, MFLicenseTypeInfo *,           licenseTypeInfo)

MFDataClassImplement4(MFDataClassBase, MFTrialState,     readonly, assign,        , NSInteger,  daysOfUse,
                                                         readonly, assign,        , NSInteger,  daysOfUseUI,
                                                         readonly, assign,        , NSInteger,  trialDays,
                                                         readonly, assign,        , BOOL,       trialIsActive)

/// MARK: MFDataClass extensions

/// Define constant attributes of licenseTypes

@implementation MFLicenseTypeInfo (ConstantAttributes)

BOOL MFLicenseTypeIsPersonallyPurchased(MFLicenseTypeInfo *_Nonnull info) {

    /// Tells us whether the user had to actively, personally purchase Mac Mouse Fix to obtain this type of license.
    
    if (info == nil) { assert(false); return NO; }
    
    if (info.class == MFLicenseTypeInfoFreeCountry.class)        return NO;
    if (info.class == MFLicenseTypeInfoForce.class)              return NO;
    if (info.class == MFLicenseTypeInfoGumroadV0.class)          return YES;
    if (info.class == MFLicenseTypeInfoGumroadV1.class)          return YES;
    if (info.class == MFLicenseTypeInfoPaddleV1.class)           return YES;
    if (info.class == MFLicenseTypeInfoHyperWorkV1.class)        return NO;
    if (info.class == MFLicenseTypeInfoGumroadBusinessV1.class)  return NO;
    
    
    assert(false);
    DDLogError(@"IsPersonallyPurchased is not defined for licenseType: %@. Defaulting to YES", info.class);
    return YES;
}

BOOL MFLicenseTypeRequiresValidLicenseKey(MFLicenseTypeInfo *_Nonnull info) {
    
    /// Tells us whether the user has to enter a valid licenseKey to activate the application under this licenseType
    
    if (info == nil) { assert(false); return NO; }
    
    if (info.class == MFLicenseTypeInfoFreeCountry.class)        return NO;
    if (info.class == MFLicenseTypeInfoForce.class)              return NO;
    if (info.class == MFLicenseTypeInfoGumroadV0.class)          return YES;
    if (info.class == MFLicenseTypeInfoGumroadV1.class)          return YES;
    if (info.class == MFLicenseTypeInfoPaddleV1.class)           return YES;
    if (info.class == MFLicenseTypeInfoHyperWorkV1.class)        return YES;
    if (info.class == MFLicenseTypeInfoGumroadBusinessV1.class)  return YES;
    
    assert(false);
    DDLogError(@"RequiresValidLicenseKey is not defined for licenseType: %@. Defaulting to YES (since most licenseTypes will probably require a valid license key.)", info.class);
    return YES;
}

@end

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

    return @[@(self->_isLicensed), self->_licenseTypeInfo ?: NSNull.null]; /// `_licenseTypeInfo` is currently not nullable (as of Oct 2024), but we still fallback to NSNull just in case.
}

@end

@implementation MFTrialState (CustomEquality)

- (NSArray<id> *)propertyValuesForEqualityComparison {

    /// Define equality for the MFTrialState
    /// Notes:
    /// - We compare all fields except for `daysOfUseUI` and `trialIsActive`, because those are directly derived from the other fields

    return @[@(self->_daysOfUse), @(self->_trialDays)]; /// Don't forget that trying to `@(box)` nil crashes for some types like `char *`
}

@end
