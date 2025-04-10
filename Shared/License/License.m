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
#import "MFPlistEncoder.h"

#import "License.h"

/// - MARK: MFDataClass implementations

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
    #if 0
        MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoPaddleV1)                 /// Standard MMF 3 licenses that we plan to sell on Paddle, verified through our AWS API. (This is the plan as of Oct 2024)
    #endif
    
    /// Special licenses
    #if 0
        MFDataClassImplement1(MFLicenseTypeInfo, MFLicenseTypeInfoHyperWorkV1,              /// Licenses issued by HyperWork mouse company and verified through our AWS API.
                            readonly, strong, nonnull, NSString *, deviceSerialNumber)
        MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadBusinessV1)        /// Perhaps we could introduce a license type for businesses. You could buy multiple/multiseat licenses, and perhaps it would be more expensive / subscription based?. (Sidenote: This licenseType includes `V1`, but not sure that makes sense. The only practical application for 'versioning' the licenseTypes like that I can think of is for paid upgrades, but that doesn't make sense for a subscription-based license I think, but I guess versioning doesn't hurt)
    #endif

    /// V2 licenses:
    ///     Explanation:
    ///     If we ever want to introduce a paid update we could add new V2 licenses
    ///     and then make the old V1 licenses incompatible with the newest version of Mac Mouse Fix.
    #if 0
        MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoGumroadV2)
        MFDataClassImplement0(MFLicenseTypeInfo, MFLicenseTypeInfoPaddleV2)
    #endif

/// Top-level dataclasses

MFDataClassImplement3(MFDataClassBase, MFLicenseState,   readonly, assign,        , BOOL,                          isLicensed,
                                                         readonly, assign,        , MFValueFreshness,              freshness,
                                                         readonly, strong, nonnull, MFLicenseTypeInfo *,           licenseTypeInfo)

MFDataClassImplement4(MFDataClassBase, MFTrialState,     readonly, assign,        , NSInteger,  daysOfUse,
                                                         readonly, assign,        , NSInteger,  daysOfUseUI,
                                                         readonly, assign,        , NSInteger,  trialDays,
                                                         readonly, assign,        , BOOL,       trialIsActive)
    
MFDataClassImplement10(MFDataClassBase, MFLicenseConfig,    readonly, assign,        , MFValueFreshness     , freshness,
                                                            readonly, assign,        , NSInteger            , maxActivations,
                                                            /// ^^ Define max activations
                                                            ///     I want people to activate MMF on as many of their machines  as they'd like.
                                                            ///     This is just so you can't just share one email address + license key combination on some forum and have everyone use that forever. This is probably totally unnecessary.
                                                            readonly, assign,        , NSInteger            , trialDays,
                                                            readonly, assign,        , NSInteger            , price,
                                                            readonly, strong, nonnull, NSString *           , payLink,
                                                            readonly, strong, nonnull, NSString *           , quickPayLink,
                                                            readonly, strong, nonnull, NSString *           , altPayLink,
                                                            readonly, strong, nonnull, NSString *           , altQuickPayLink,
                                                            readonly, strong, nonnull, NSArray<NSString *> *, altPayLinkCountries,
                                                            readonly, strong, nonnull, NSArray<NSString *> *, freeCountries)

/// MARK: - MFDataClass extensions

/// MARK: licenseState extensions

@implementation MFLicenseState (Extensions)

    - (NSObject *)internalStateForEqualityComparison {

        /// Define equality for MFLicenseState
        /// Reasoning:
        /// - We compare all fields except for the `freshness` field - the idea is that the `freshness` determines the *origin* of the data, but, in some sense, isn't *itself* part of the data.
        ///     Also, practically, on the `AboutTabController`, we always first render the UI based on cached values, then we try to load the real values from the server, and then, unless the server data is mismatched with the cache, we don't want to rerender the UI - if we compared on the freshness, we could never detect that the data from the server is the same as from the cache) (As of Oct 2024)

        /// Sidenotes:
        ///     Places where we check equality (as of Oct 2024)
        ///         1. `AboutTabController.updateUI()`
        ///             -> We first perform an equality check on `MFLicenseState`, `MFTrialState` and `MFLicenseConfig` and only update the UI, if the state has changed.
        ///         2. Perhaps other places I forgot about?

        return @[@(self->_isLicensed),
                 self->_licenseTypeInfo ?: NSNull.null]; /// `_licenseTypeInfo` is currently not nullable (as of Oct 2024), but we still fallback to NSNull just in case.
    }

@end

/// MARK: trialState extensions

@implementation MFTrialState (Extensions)

    - (NSObject *)internalStateForEqualityComparison {

        /// Define equality for the MFTrialState
        /// Notes:
        /// - We compare all fields except for `daysOfUseUI` and `trialIsActive`, because those are directly derived from the other fields

        return @[@(self->_daysOfUse),
                 @(self->_trialDays)]; /// Don't forget that trying to `@(box)` nil crashes for some types like `char *`
    }

@end

/// MARK: licenseConfig extensions

@implementation MFLicenseConfig (Extensions)

    NSString *_Nonnull MFLicenseConfigFormattedPrice(MFLicenseConfig *_Nonnull config) {
        /// Note - why USD?: We're selling in $ because you can't include tax in price on Gumroad, and with $ ppl expect that more.
        NSString *result = stringf(@"$%.2f", ((double)config.price)/100.0);
        return result;
    }

    - (instancetype _Nullable) initWithJSONDictionary: (NSMutableDictionary *_Nonnull)dict freshness: (MFValueFreshness)freshness requireSecureCoding: (BOOL)requireSecureCoding {
        
        ///     Explanation: The licenseConfig json dicts we retrieve from the server / cache / fallback *do not* have a 'freshness' field, but our MFLicenseConfig dataclass does.
        ///                We need to add `freshness` in advance so our underlying `initWithPlist:requireSecureCoding:` initializer doesn't fail due to missing fields. (or perhaps it would even produce an invalid object if secureCoding is off?)
        ///                We also need to add `kMFPlistCoder_ClassName` so the underlying initializer knows exactly which MFDataClass to instantiate.
        
        /// Set class
        dict[kMFPlistCoder_ClassName] = [self className];
        
        /// Set freshness
        dict[@"freshness"] = @(freshness);
        
        /// Call underlying init
        self = [self initWithPlist: dict requireSecureCoding: requireSecureCoding];
        
        /// Return
        return self;
    }


    - (NSObject *)internalStateForEqualityComparison {

        ///    This function defines which properties we consider for equality-checking on MFLicenseConfig
        ///
        ///     Notes:
        ///    - We don't check `freshness` because it describes the origin of the data (cache, server, etc) and, in a sense, isn't itself part of the data we're trying to represent.
        ///    - All other properties should be checked - don't forget to update this when adding new properties!
        ///
        ///    Sidenotes: (from the old Swift implementation)
        ///    - I also tried overriding `==` directly instead of `isEqual:`, but it didn't work for some reason. (`==` normally just maps to`isEqual:`, so this is weird.)
        ///    - I accidentally overrode isEqual(to:) instead of isEqual() causing great confusion (it breaks the `==` operator in Swift.)

        return @[@(self->_maxActivations),
                 @(self->_trialDays),
                 @(self->_price),
                 self->_payLink                ?: NSNull.null, /// None of these are currently nullable (as of Oct 2024) but we still fall back to NSNull just in case we change things later.
                 self->_quickPayLink           ?: NSNull.null,
                 self->_altPayLink             ?: NSNull.null,
                 self->_altQuickPayLink        ?: NSNull.null,
                 self->_altPayLinkCountries    ?: NSNull.null,
                 self->_freeCountries          ?: NSNull.null];
    }

@end

/// MARK: licenseType extensions

@implementation MFLicenseTypeInfo (Extensions)

    BOOL MFLicenseTypeIsPersonallyPurchased(MFLicenseTypeInfo *_Nullable info) {

        /// Tells us whether the user had to actively, personally purchase Mac Mouse Fix to obtain this type of license.
        
        if (info == nil ||
            info.class == MFLicenseTypeInfoNotLicensed.class)
        {
            assert(false);
            return NO;
        }
        
        if (info.class == MFLicenseTypeInfoFreeCountry.class)        return NO;
        if (info.class == MFLicenseTypeInfoForce.class)              return NO;
        if (info.class == MFLicenseTypeInfoGumroadV0.class)          return YES;
        if (info.class == MFLicenseTypeInfoGumroadV1.class)          return YES;
        
        #if 0
        if (info.class == MFLicenseTypeInfoPaddleV1.class)           return YES;
        if (info.class == MFLicenseTypeInfoHyperWorkV1.class)        return NO;
        if (info.class == MFLicenseTypeInfoGumroadBusinessV1.class)  return NO; /// Don't forget to add definitions here when you add a new licenseType!
        #endif
        
        
        assert(false);
        DDLogError(@"IsPersonallyPurchased is not defined for licenseType: %@. Defaulting to YES", info.class);
        return YES;
    }

    BOOL MFLicenseTypeRequiresValidLicenseKey(MFLicenseTypeInfo *_Nullable info) {
        
        /// Tells us whether the user has to enter a valid licenseKey to activate the application under this licenseType
        
        if (info == nil ||
            info.class == MFLicenseTypeInfoNotLicensed.class)
        {
            assert(false);
            return NO;
        }
        
        if (info.class == MFLicenseTypeInfoFreeCountry.class)        return NO;
        if (info.class == MFLicenseTypeInfoForce.class)              return NO;
        if (info.class == MFLicenseTypeInfoGumroadV0.class)          return YES;
        if (info.class == MFLicenseTypeInfoGumroadV1.class)          return YES;
        #if 0
        if (info.class == MFLicenseTypeInfoPaddleV1.class)           return YES;
        if (info.class == MFLicenseTypeInfoHyperWorkV1.class)        return YES;
        if (info.class == MFLicenseTypeInfoGumroadBusinessV1.class)  return YES;
        #endif
        
        assert(false);
        DDLogError(@"RequiresValidLicenseKey is not defined for licenseType: %@. Defaulting to YES (since most licenseTypes will probably require a valid license key.)", info.class);
        return YES;
    }

@end
