//
// --------------------------------------------------------------------------
// Licensing.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Most Licensing code is in Swift. 
///     Use this file only for stuff that's not possible in Swift, like creating MFDataClasses, enums or structs that are usable from both objc and swift

#ifndef License_h
#define License_h

#import "MFDataClass.h"

/// Define enums

typedef enum {
    kMFValueFreshnessNone,
    kMFValueFreshnessFresh,     /// Value comes straight from the source-of-truth                (likely a server on the internet)
    kMFValueFreshnessCached,    /// Value comes from a cache                                             (likely because the source of truth is not accessible)
    kMFValueFreshnessFallback,  /// Value comes from a list of fallback values                      (likely because neither the server nor the cache are accessible)
} MFValueFreshness;

typedef enum {
    kMFLicenseReasonUnknown,
    kMFLicenseReasonNone,           /// Unlicensed
    kMFLicenseReasonValidLicense,   /// Normally licensed
    kMFLicenseReasonForce,          /// Licensed due to `FORCE_LICENSED` compilation flag
    kMFLicenseReasonFreeCountry,    /// Licensed since it's used in country like China or Russia where you can't pay for the app
} MFLicenseReason;

typedef enum {
    
    kMFLicenseTypeUnknown,
    
    /// Standard licenses
    kMFLicenseTypeGumroadV0,            /// Old Euro-based licenses that were sold on Gumroad during the MMF 3 Beta.
    kMFLicenseTypeGumroadV1,            /// Standard USD-based Gumroad licenses that were sold on Gumroad after MMF 3 Beta 6 (IIRC).
//    kMFLicenseTypePaddleV1,           /// Standard MMF 3 licenses that we plan to sell on Paddle, verified through our AWS API. (This is the plan as of Oct 2024)

    /// Special licenses
    kMFLicenseTypeHyperWorkV1,                /// Licenses issued by HyperWork mouse company and verified through our AWS API.
//    kMFLicenseTypeBusinessV1,               /// Perhaps we could introduce a license type for businesses. You could buy multiple/multiseat licenses, and perhaps it would be more expensive / subscription based?. (Sidenote: This licenseType includes `V1`, but not sure that makes sense. The only practical application for 'versioning' the licenseTypes like that I can think of is for paid upgrades, but that doesn't make sense for a subscription-based license I think, but I guess versioning doesn't hurt)

    /// V2 licenses:
    ///     Explanation:
    ///     If we ever want to introduce a paid update we could add new V2 licenses
    ///     and then make the old V1 licenses incompatible with the newest version of Mac Mouse Fix.
//    kMFLicenseTypeGumroadV2,
//    kMFLicenseTypePaddleV2,

} MFLicenseType;

///
/// Define metadata classes
///

///     There's exactly one `MFLicenseMetadata` class per 'licenseType' - it holds the relevant metadata for licenses of type `licenseType`.
///
///     This 'metadata' could be useful to adjust the app's behaviour. For example:
///         - Showing a special thank-you message or other easter eggs for people who bought the 'generous' or 'very generous' tiers of a standard license.
///         - Showing the name of the HyperWork mouse that came with the currently active MMF license
///         - Saving the expiration date of a subscription-based business license, so that we can check-in with the licenseServer upon license expiration (And before expiration, we would do offline validation)
///
///     Sidenote on *Metadata Particles*:
///         There might be repeated metadata fields between the different licenseTypes.
///         We were thinking of introducing an extra level of abstraction, where we group the metadataFields into collections called 'MetadataParticles'
///         which can be reused between licenseTypes. E.g. There'd be a `MFLicenseMetadataParticleSeats` particle which is present in the metadata for every licenseType that has multiple seats. It might contain the fields `usedUpSeats` and `nOfSeats` or something like that.
///         However, I decided that this extra abstraction layer is kinda unnecessary and overcomplicates things. Instead, we can just use keyValueCoding to access the repeated metadata fields across the different metadata classes in a uniform way.
///         For example we might use `[license.metadata valueForKey:@"nOfSeats"]` to get the `nOfSeats` regardless of which exact metadata class is being used.
///

MFDataClassInterface0(MFDataClassBase, MFLicenseMetadata)

/// Standard licenses
MFDataClassInterface0(MFLicenseMetadata, MFLicenseMetadataGumroadV0)
MFDataClassInterface0(MFLicenseMetadata, MFLicenseMetadataGumroadV1)

/// Special licenses
MFDataClassInterface0(MFLicenseMetadata, MFLicenseMetadataHyperWorkV1)
//MFDataClass0(MFLicenseMetadata, MFLicenseMetadataBusinessV1) /// We thought about adding the number of seats, a `subscriptionIsPaidForUntil` field (which determines when we need to check in with the licenseServer again to check if the subscription is ongoing.), and a `licensedTo` field in case we want to display the business name on the About tab.

///
/// Define top-level dataclasses
///

MFDataClassInterface3(MFDataClassBase, MFLicenseState,   (assign, readonly), BOOL,               isLicensed,
                                                         (assign, readonly), MFValueFreshness,   freshness,
                                                         (assign, readonly), MFLicenseReason,    licenseReason)
//                                                assign, MFLicenseType, licenseType,
//                                                strong, MFLicenseMetadata * _Nonnull, metadata) /// Note: We wanna add the `licenseType` and `metadata` fields later.

MFDataClassInterface4(MFDataClassBase, MFTrialState,     (assign, readonly), NSInteger,  daysOfUse,
                                                         (assign, readonly), NSInteger,  daysOfUseUI,
                                                         (assign, readonly), NSInteger,  trialDays,
                                                         (assign, readonly), BOOL,       trialIsActive)

/// Define custom errors
///     Notes:
///     - Using simple #define instead of enums because Swift is annoying about those
///     - Most of these are thrown in Gumroad.swift, but `kMFLicenseErrorCodeNoInternetAndNoCache` and `kMFLicenseErrorCodeEmailAndKeyNotFound` are thrown in Licensing.swift.
///     - Overall these should cover everything that can go wrong. With the `kMFLicenseErrorCodeGumroadServerResponseError` catching all the weird edge cases like a refunded license.
///     - The `kMFLicenseErrorCodeGumroadServerResponseError` also catches the case when a user just enters a wrong license.
///     - These could be used to inform the user about what's wrong.

#define MFLicenseErrorDomain @"MFLicenseErrorDomain"

//#define kMFLicenseErrorCodeMismatchedEmails 1 /// Not using emails for authentication anymore. Just licenseKeys
#define kMFLicenseErrorCodeInvalidNumberOfActivations 2
#define kMFLicenseErrorCodeGumroadServerResponseError 3         /// The Gumroad server has responded with `success: false`
#define kMFLicenseErrorCodeServerResponseInvalid 4              /// The server response does not follow the expected format.
#define kMFLicenseErrorCodeKeyNotFound 5
#define kMFLicenseErrorCodeNoInternetAndNoCache 6

//#define kMFLicenseErrorCodeLicensedDueToForceFlag 6
//#define kMFLicenseErrorCodeLicensedDueToFreeCountry 7

#define MFLicenseConfigErrorDomain @"MFLicenseConfigErrorDomain"
#define kMFLicenseConfigErrorCodeInvalidDict 1


#endif /* License_h */

/**
    Other ideas for structs and unions we could use to represent the `MFLicenseAndTrialState`:
        (We should probably delete this at some point)
 
        ```
         union MFLicenseMetadataaa {
             
             /// Each licenseType could have a different set of `metadata` that the app can use to adjust its behaviour
             ///    For example:
             ///    - Showing the name of the HyperWork mouse that came with the currently active MMF license
             ///    - Saving the expiration date of a subscription-based business license, so that we can verify the license with the licenseServer upon expiration (Instead of doing offline verification of the license.)
             ///    - Showing a special thank-you message or other easter eggs for people who bought the 'generous' or 'very generous' tiers of a standard license.

             /// Standard licenses
             struct { /// Metadata for licenses of type `kMFLicenseTypeMMF3GumroadOldEuro`
                 NSInteger option;   /// 1, 2 or 3 --- 1 -> standard option, 2 -> 'generous' supporter, 3 -> 'very generous' supporter
             } MMF3GumroadOldEuro;
             struct {
                 NSInteger option;
             } MMF3Gumroad;
             struct {
                 NSInteger option;
             } MMFPaddle;
             
             /// Special licenses
             struct { /// Metadata for licenses of type `MMF3HyperWork`
                 NSString *deviceName;       /// Name of the HyperWork device which shipped with the activated MMF license
                 NSString *devicePurchaseDate;
             } MMF3HyperWork;
             
             struct {
                 NSInteger seat;
                 NSInteger nOfSeats;
                 NSString *licenseOwner;
                 NSDate *subscriptionPaidForUntil;
             } MMF3Business;
         };
                
        /// Perhaps, instead of having different licenseTypes, we could model the information associated with the licenseTypes more granularly? Kinda like this:
        ///         Note: This idea became the 'Metadata Particles' idea.

        typedef enum {
            kMFLicenseIssuerPaddle,
            kMFLicenseIssuerGumroad,
            kMFLicenseIssuerHyperWork,
        } MFLicenseIssuer;

        typedef enum {
            kMFLicenseVerifierAWS,      /// Paddle and HyperWork licenses are verified through our AWS API
            kMFLicenseVerifierGumroad,  /// Gumroad licenses are verified through the Gumroad API.
        } MFLicenseVerifier;
        ```
 
    Metadata particle implementation idea (As **MFDataClasses**):
 
        ```
         /// NOTEPAD: (Exploring how we might use these datastructures:)
         ///  ```
         ///  for metadataParticle in licenseAndTrialState.license.metadata.allPropertyValues {
         ///         if let particle = metadataParticle as? MFMetaDataParticleSupportedLevel {
         ///         if (particle.supporterLevel.intValue == 3) {
         ///
         ///         }
         ///  ```
         ///
         /// ```
         /// if (type == kMFLicenseTypeMMF3GumroadOldEuro) {
         ///     MFLicenseMetadataMMF3GumroadOldEuro *metadata = [MFLicenseMetadataMMF3GumroadOldEuro new];
         ///     metadata.supporterLevel = @(serverReponse["supportedLevel"]);
         ///     license.metadata = metadata;
         /// }
         /// ```
         ///


         // Define metadata particles

         MFDataClassInterface(MFLicenseMetadataParticle, ())
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleSupporterLevel,    (MFDataProp(NSNumber *supporterLevel)))
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleSeats,             (MFDataProp(NSNumber *seat)
                                                                                                      MFDataProp(NSNumber *nOfSeats)))
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleSubscription,      (MFDataProp(NSDate *subscriptionIsPaidForUntil)))
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleBusiness,          (MFDataProp(NSString *licenseOwner)))
         
         MFDataClassInterfaceSub(MFLicenseMetadataParticle, MFLicenseMetadataParticleHyperWork,         (MFDataProp(NSString *deviceName)
        ```
        
    Metadata  & particles implementation idea (As union of structs):
        ```
        /// NOTEPAD: (Exploring how we might use these datastructures:)
        ///
        ///  for i in range(sizeof(MFLicenseMetadata) / sizeof(MFLicenseMetaDataParticle)) {
        ///      union MFLicenseMetaDataParticle particle = licenseAndTrialState.license.metadata[i]
        ///
        ///                 if (particle.particleID == kMFMetadataParticleIDSupporterLevel)
        ///
        ///                 } else if ()
        ///
        ///  }

        /// Define metadata particles

        struct MFLicenseMetaDataParticle {
            
            enum MFMetadataParticleID {
                
                kMFMetadataParticleIDNone,
                kMFMetadataParticleIDSupporterLevel,
                kMFMetadataParticleIDSeats,
                kMFMetadataParticleIDSubscription,
                kMFMetadataParticleIDHyperWork,
                
            } particleID;
            
            union { /// union of structs of metadataParticles
                struct {
                    enum MFSupporterLevel {
                        kMFSupporterLevelBase,
                        kMFSupporterLevelGenerous,
                        kMFSupporterLevelVeryGenerous,
                    } level;
                } SupporterLevel;
                
                struct {
                    NSInteger seat;
                    NSInteger nOfSeats;
                } Seats;
                
                struct {
                    NSDate *subscriptionPaidForUntil;
                } Subscription;
                
                struct {
                    NSString *deviceName; /// Name of the HyperWork device which shipped with the activated MMF license
                    NSDate *devicePurchaseDate;
                } HyperWork;
            } data;
        };

        struct MFLicenseMetaDataParticles {
            
            struct {
                bool metadataIsPresent;
                enum {
                    base,
                    generous,
                    veryGenerous,
                } level;
            } SupporterLevel;
            
            struct {
                bool metadataIsPresent;
                NSInteger seat;
                NSInteger nOfSeats;
            } Seats;
            
            struct {
                bool metadataIsPresent;
                NSDate *subscriptionPaidForUntil;
            } Subscription;
            
            struct {
                bool metadataIsPresent;
                NSString *deviceName; /// Name of the HyperWork device which shipped with the activated MMF license
                NSDate *devicePurchaseDate;
            } HyperWork;
        };

 
         struct MFLicenseMetadata  {
         
             /// The licenseState has a `metadata` field which contains data that is only present for specific licenseTypes.
             ///    This data could be useful to adjust the app's behaviour.
             ///    For example:
             ///    - Showing the name of the HyperWork mouse that came with the currently active MMF license
             ///    - Saving the expiration date of a subscription-based business license, so that we can verify the license with the licenseServer upon expiration (Instead of doing offline verification of the license.)
             ///    - Showing a special thank-you message or other easter eggs for people who bought the 'generous' or 'very generous' tiers of a standard license.
         
             enum MFLicenseType {
         
                 kMFLicenseTypeUnknown,
         
                 /// Standard licenses
                 kMFLicenseTypeMMF3GumroadOldEuro,  /// Old Euro-based licenses that were sold on Gumroad during the MMF 3 Beta.
                 kMFLicenseTypeMMF3Gumroad,         /// Standard Gumroad licenses that were sold on Gumroad after MMF 3 Beta 6 (IIRC).
                 kMFLicenseTypeMMF3Paddle,          /// Standard MMF 3 licenses sold on Paddle, verified through our AWS API.
         
                 /// Special licenses
                 kMFLicenseTypeMMF3HyperWork,                /// Licenses issued by HyperWork mouse company and verified through our AWS API.
                 kMFLicenseTypeMMF3Business,                 /// Perhaps we could introduce a license type for businesses. You could buy multiple/multiseat licenses, and perhaps it would be more expensive / subscription based?
         
                 /// If we ever want to introduce a paid update we could add new license types like this:
             //    kMFLicenseTypeMMF5Gumroad,
             //    kMFLicenseTypeMMF5Paddle,
         
             } licenseType;
         
             union { /// union of structs of license-type-specific metadata
                 /// Standard licenses
                 struct {
                     struct MFLicenseMetaDataParticle supporterLevel;
                 } MMF3GumroadOldEuro;
                 struct {
                     struct MFLicenseMetaDataParticle supporterLevel;
                 } MMF3Gumroad;
                 struct {
                     struct MFLicenseMetaDataParticle supporterLevel;
                 } MMF3Paddle;
         
                 /// Special licenses
                 struct {
                     struct MFLicenseMetaDataParticle hyperWork;
                 } MMF3HyperWork;
                 struct {
                     struct MFLicenseMetaDataParticle subscription;
                     struct MFLicenseMetaDataParticle seats;
                 } MMF3Business;
         
                 struct MFLicenseMetaDataParticle particleArray[2]; /// ! Keep in sync with largest struct in the union.
             } data;
         };

        ```
 
        Original struct definintions of the top-level dataclasses
            -> We moved to dataclasses because, as soon as you put an object into these structs, they can't be imported into Swift anymore, so we made everythin an object using our `MFDataClass`es
        ```
         typedef struct {
             bool isLicensed;
             MFValueFreshness freshness;
             MFLicenseReason licenseReason;
             MFLicenseType licenseType;
             MFLicenseMetadata *metadata;
         } MFLicenseState;

         typedef struct {
             NSInteger daysOfUse;
             NSInteger daysOfUseUI;
             NSInteger trialDays;
             bool trialIsActive;
         } MFTrialState;

         typedef struct MFLicenseAndTrialState {
             MFLicenseState license;
             MFTrialState trial;
         } MFLicenseAndTrialState;
        ```
 
 */
